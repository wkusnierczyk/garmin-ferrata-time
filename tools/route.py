"""Route tool: builds a route file (design/real-functionality.md, section 4) from a hand-written
source, checks it, and fills the points' coordinates from a GPX track.

python3 tools/route.py build routes/<id>.src.json -o resources/routes/<id>.json [--gpx track.gpx]

The source has the output's shape. The output lists its keys in a fixed order, one section or point
per line, so a rebuild of an unchanged source changes nothing. On any error it prints every problem
found, one per line, writes nothing and exits 1; it warns, without failing, when the track's
length is far from the route's and for each point past the track's end. Names are folded to the
fonts' text charset: accents dropped, special letters spelled out. Python 3, standard library only.
"""
import argparse
import copy
import json
import math
import os
import sys
import unicodedata
import xml.etree.ElementTree as ET

FORMAT = 1
TOP_KEYS = ["format", "id", "name", "short", "place", "source", "approach", "sections", "points"]
SECTION_KEYS = ["len", "up", "grade", "min", "name", "side"]
POINT_KEYS = ["kind", "at", "alt", "lat", "lon", "name"]
KINDS = {"approach", "head", "landmark", "danger", "exit", "top"}
SHORT_MAX = 15  # the SDK's suggested maximum for a session name
ALT_TOLERANCE = 15  # metres between the sections' height and the known altitudes
EARTH_RADIUS = 6371000.0
# What a name may hold after folding: the text fonts' charset, which carries only the characters the
# app draws. A copy of resources/fonts/charsets.json's (#62, PR #77), to be read from it once it lands;
# until then a test compares the two whenever the file is there.
TEXT_CHARSET = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 '()+,-./:>~°·…")
# What NFKD leaves: letters it does not take apart, spelled out; typographic marks, written plainly
# (the charset has no double quote, so every quote becomes '); invisible marks, dropped.
FOLD = {
    "ß": "ss", "ẞ": "SS", "æ": "ae", "Æ": "AE", "œ": "oe", "Œ": "OE", "ø": "o", "Ø": "O",
    "ł": "l", "Ł": "L", "đ": "d", "Đ": "D", "ð": "d", "Ð": "D", "þ": "th", "Þ": "Th",
    "ħ": "h", "Ħ": "H", "ı": "i", "ŧ": "t", "Ŧ": "T", "ŋ": "ng", "Ŋ": "Ng", "μ": "u",
    "‘": "'", "’": "'", "‛": "'", "“": "'", "”": "'", "„": "'", "«": "'", "»": "'", "ʼ": "'",
    "`": "'", "′": "'", "‚": ",",
    "‐": "-", "‑": "-", "‒": "-", "–": "-", "—": "-", "−": "-", "⁄": "/",
    "\u00ad": "", "\u200b": "", "\u200c": "", "\u200d": "",
    **{chr(c): "" for c in range(0xFE00, 0xFE10)},  # variation selectors
}


class RouteError(Exception):
    def __init__(self, problems):
        super().__init__("\n".join(problems))
        self.problems = problems


def is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def is_num(v):
    return (isinstance(v, (int, float)) and not isinstance(v, bool)) and math.isfinite(v)


def section_label(part, i, s):
    name = s.get("name") if isinstance(s, dict) else None
    return f"{part} {i}" + (f" '{name}'" if isinstance(name, str) else "")


def point_label(p):
    return f"{p['kind']} '{p['name']}'"


def check_shape(r):
    """Keys present, none unknown, of the right types. The other rules assume these hold."""
    out = []
    if not isinstance(r, dict):
        return ["the route is a JSON object"]
    for k in r:
        if k not in TOP_KEYS:
            out.append(f"unknown key {k}")
    for k in TOP_KEYS:
        if k not in r and k != "approach":
            out.append(f"{k} is missing")
    if "format" in r and not (is_int(r["format"]) and r["format"] == FORMAT):
        out.append(f"format is {FORMAT}")
    for k in ("id", "name", "short", "place"):
        if k in r and not isinstance(r[k], str):
            out.append(f"{k} is a string")
    if "source" in r and not isinstance(r["source"], dict):
        out.append("source is an object")

    for part, key in (("approach", "approach"), ("section", "sections")):
        if key not in r:
            continue
        lst = r[key]
        if not isinstance(lst, list) or not lst:
            out.append(f"{key} lists at least one section")
            continue
        for i, s in enumerate(lst, 1):
            if not isinstance(s, dict):
                out.append(f"{part} {i} is an object")
                continue
            label = section_label(part, i, s)
            for k in s:
                if k not in SECTION_KEYS:
                    out.append(f"{label}: unknown key {k}")
            for k in SECTION_KEYS:
                if k not in s and k != "min":
                    out.append(f"{label}: {k} is missing")
            if "name" in s and not isinstance(s["name"], str):
                out.append(f"{label}: name is a string")
            for k in ("len", "up", "min"):
                if k in s and not is_int(s[k]):
                    out.append(f"{label}: {k} is an integer")
            if "side" in s and not is_num(s["side"]):
                out.append(f"{label}: side is a number")

    if "points" in r:
        if not isinstance(r["points"], list):
            out.append("points is a list")
        else:
            for i, p in enumerate(r["points"], 1):
                if not isinstance(p, dict) or not isinstance(p.get("kind"), str):
                    out.append(f"point {i} is an object with a kind")
                    continue
                if p["kind"] not in KINDS:
                    continue  # unknown kinds pass through unchecked: later formats may add kinds
                label = f"{p['kind']} {i}" + (f" '{p['name']}'" if isinstance(p.get("name"), str) else "")
                for k in p:
                    if k not in POINT_KEYS:
                        out.append(f"{label}: unknown key {k}")
                for k in ("kind", "at", "name"):
                    if k not in p:
                        out.append(f"{label}: {k} is missing")
                if "name" in p and not isinstance(p["name"], str):
                    out.append(f"{label}: name is a string")
                for k in ("at", "alt"):
                    if k in p and not is_int(p[k]):
                        out.append(f"{label}: {k} is an integer")
                for k, lim in (("lat", 90), ("lon", 180)):
                    if k in p and not (is_num(p[k]) and -lim <= p[k] <= lim):
                        out.append(f"{label}: {k} is a number from -{lim} to {lim}")
    return out


def known_points(r):
    return [p for p in r["points"] if p["kind"] in KINDS]


def profile(r):
    """The approach and the ferrata as one list of (start, end, up), start and end from the head."""
    approach = r.get("approach", [])
    d = -sum(s["len"] for s in approach)
    out = []
    for s in approach + r["sections"]:
        out.append((d, d + s["len"], s["up"]))
        d += s["len"]
    return out


def height_at(prof, at):
    """Net height from the start of the profile to `at`, interpolated within a section."""
    h = 0.0
    for d0, d1, up in prof:
        if at >= d1:
            h += up
        else:
            if at > d0:
                h += (at - d0) / (d1 - d0) * up
            break
    return h


def check_rules(r):
    out = []
    pts = known_points(r)
    approach_len = sum(s["len"] for s in r.get("approach", []))
    length = sum(s["len"] for s in r["sections"])

    # 1. Exactly one head (at 0) and one top; an approach point only with an approach list, at
    # minus its length.
    for kind in ("head", "top"):
        n = sum(1 for p in pts if p["kind"] == kind)
        if n != 1:
            out.append(f"exactly one {kind} point ({n} found)")
    for p in pts:
        if p["kind"] == "head" and p["at"] != 0:
            out.append("the head point is at 0")
    approach_pts = [p for p in pts if p["kind"] == "approach"]
    if approach_pts and "approach" not in r:
        out.append("an approach point needs an approach list")
    elif len(approach_pts) > 1:
        out.append(f"at most one approach point ({len(approach_pts)} found)")
    elif approach_pts and approach_pts[0]["at"] != -approach_len:
        out.append(f"the approach point is at {-approach_len} (minus the approach's length)")

    # 2. Exits and landmarks on a boundary of the ferrata's sections.
    bounds = {0}
    d = 0
    for s in r["sections"]:
        d += s["len"]
        bounds.add(d)
    for p in pts:
        if p["kind"] in ("exit", "landmark") and p["at"] not in bounds:
            out.append(f"{point_label(p)} at {p['at']} is not on a section boundary")
        elif p["kind"] in ("exit", "landmark") and p["at"] in (0, length):
            # An exit starts a section, and the head and the top are known points already.
            out.append(f"{point_label(p)} at {p['at']} is at the head or the top, not between them")

    # 3. Every point on the route; the top at the ferrata's length.
    for p in pts:
        if not -approach_len <= p["at"] <= length:
            out.append(f"{point_label(p)} at {p['at']} is outside {-approach_len}..{length}")
    for p in pts:
        if p["kind"] == "top" and p["at"] != length:
            out.append(f"the top point is at {length} (the ferrata's length)")

    # 4. Between consecutive known points, the sections' net height matches the altitudes.
    prof = profile(r)
    known = sorted((p for p in pts if "alt" in p), key=lambda p: p["at"])
    for a, b in zip(known, known[1:]):
        up = height_at(prof, b["at"]) - height_at(prof, a["at"])
        alt = b["alt"] - a["alt"]
        if abs(up - alt) > ALT_TOLERANCE:
            out.append(f"'{a['name']}' (at {a['at']}) to '{b['name']}' (at {b['at']}): the sections "
                       f"climb {up:g} m, the altitudes {alt} m (more than {ALT_TOLERANCE} m apart)")

    # 5. Grades, lengths, minutes and sides in range. Up may be negative.
    for part, key in (("approach", "approach"), ("section", "sections")):
        for i, s in enumerate(r.get(key, []), 1):
            label = section_label(part, i, s)
            if not (is_int(s["grade"]) and -1 <= s["grade"] <= 12):
                out.append(f"{label}: grade is an integer from -1 to 12")
            if s["len"] <= 0:
                out.append(f"{label}: len is above 0")
            if "min" in s and s["min"] <= 0:
                out.append(f"{label}: min is above 0")
            if not -1.0 <= s["side"] <= 1.0:
                out.append(f"{label}: side is from -1.0 to 1.0")

    # 6. The short name fits a session name.
    if not r["short"]:
        out.append("short is not empty")
    if len(r["short"]) > SHORT_MAX:
        out.append(f"short is at most {SHORT_MAX} characters ({len(r['short'])})")

    # Coordinates come in pairs.
    for p in pts:
        if ("lat" in p) != ("lon" in p):
            out.append(f"{point_label(p)}: lat and lon come together")
    return out


def fold(text):
    """text with accents dropped (NFKD, combining marks removed) and what remains looked up in
    FOLD, so a letter with an accent on a special letter (ǿ, ǣ) folds too. What it returns may still
    hold characters outside TEXT_CHARSET."""
    out = []
    for c in text:
        if c in TEXT_CHARSET:  # kept as it is, even where NFKD would take it apart (… to ...)
            out.append(c)
            continue
        for d in unicodedata.normalize("NFKD", c):
            if not unicodedata.combining(d):
                out.append(d if d in TEXT_CHARSET else FOLD.get(d, d))
    return "".join(out)


def fold_names(r):
    """A copy of route r with every name, short and place folded, points of unknown kinds included,
    and a problem for each character left outside TEXT_CHARSET. Fields of the wrong type stay as
    they are, for check_shape to report."""
    if not isinstance(r, dict):
        return r, []
    r = copy.deepcopy(r)
    out = []

    def one(obj, key, label):
        if not isinstance(obj.get(key), str):
            return
        obj[key] = fold(obj[key])
        for c in dict.fromkeys(obj[key]):
            if c not in TEXT_CHARSET:
                out.append(f"{label}{key}: {c!r} (U+{ord(c):04X}) is not in the fonts' charset")

    for k in ("name", "short", "place"):
        one(r, k, "")
    for part, key in (("approach", "approach"), ("section", "sections")):
        if isinstance(r.get(key), list):
            for i, s in enumerate(r[key], 1):
                if isinstance(s, dict):
                    one(s, "name", f"{section_label(part, i, s)}: ")
    if isinstance(r.get("points"), list):
        for i, p in enumerate(r["points"], 1):
            if isinstance(p, dict):
                kind, name = p.get("kind"), p.get("name")
                one(p, "name", f"{kind if isinstance(kind, str) else 'point'} {i}"
                    + (f" '{name}'" if isinstance(name, str) else "") + ": ")
    return r, out


def check(r, stem=None):
    """Every problem with route r, as messages; empty when it is valid. stem: the source's file
    name without .src.json, which the id must equal."""
    out = check_shape(r) or check_rules(r)
    if stem is not None and isinstance(r, dict) and isinstance(r.get("id"), str) and r["id"] != stem:
        out.append(f"id is {stem!r}, the source's file name (<id>.src.json)")
    return out


def haversine(lat1, lon1, lat2, lon2):
    """Great-circle distance in metres."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_RADIUS * math.asin(math.sqrt(a))


def read_gpx(path):
    """The track points of a GPX file, as (lat, lon), whatever its namespace."""
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError) as e:
        raise RouteError([f"{path}: {e}"])
    track, problems = [], []
    n = 0
    for el in root.iter():
        if el.tag.rsplit("}", 1)[-1] != "trkpt":
            continue
        n += 1
        try:
            lat, lon = float(el.get("lat")), float(el.get("lon"))
        except (TypeError, ValueError):
            problems.append(f"{path}: track point {n}: lat and lon are numbers")
            continue
        if not (math.isfinite(lat) and math.isfinite(lon) and -90 <= lat <= 90 and -180 <= lon <= 180):
            problems.append(f"{path}: track point {n}: lat {lat}, lon {lon} out of range")
            continue
        track.append((lat, lon))
    if not problems and len(track) < 2:
        problems.append(f"{path}: a track has at least two points")
    if problems:
        raise RouteError(problems)
    return track


def track_length(track):
    return sum(haversine(*a, *b) for a, b in zip(track, track[1:]))


def position(track, dist):
    """The track's position `dist` metres along it, interpolated; its end beyond its length."""
    if dist <= 0:
        return track[0]
    done = 0.0
    for (la0, lo0), (la1, lo1) in zip(track, track[1:]):
        step = haversine(la0, lo0, la1, lo1)
        if step > 0 and done + step >= dist:
            f = (dist - done) / step
            return la0 + f * (la1 - la0), lo0 + f * (lo1 - lo0)
        done += step
    return track[-1]


def ordered(obj, keys):
    return {k: obj[k] for k in keys if k in obj}


TRACK_TOLERANCE = 0.20  # the share by which the track's length may differ from the route's


def build(r, track=None, stem=None, warnings=None):
    """Route r folded, checked and in canonical form; lat and lon filled from track where missing.
    Warnings about the track go into the list `warnings`, when given."""
    r, problems = fold_names(r)
    problems = check(r, stem) + problems
    if problems:
        raise RouteError(problems)
    warnings = [] if warnings is None else warnings
    approach_len = sum(s["len"] for s in r.get("approach", []))
    route_len = approach_len + sum(s["len"] for s in r["sections"])
    if track is not None:
        tlen = track_length(track)
        if abs(tlen - route_len) > TRACK_TOLERANCE * route_len:
            warnings.append(f"the track is {tlen:.0f} m long, the route {route_len} m "
                            f"(more than {TRACK_TOLERANCE:.0%} apart)")

    def section(s):
        s = ordered(s, SECTION_KEYS)
        s["side"] = float(s["side"])
        return s

    def point(p):
        if p["kind"] not in KINDS:
            return p
        p = dict(p)
        if track is not None and "lat" not in p:
            dist = approach_len + p["at"]
            if dist > tlen:
                warnings.append(f"{point_label(p)} at {p['at']} lies {dist - tlen:.0f} m beyond the "
                                "track's end: placed at its end")
            p["lat"], p["lon"] = (round(v, 6) for v in position(track, dist))
        for k in ("lat", "lon"):
            if k in p:
                p[k] = float(p[k])
        return ordered(p, POINT_KEYS)

    out = ordered(r, TOP_KEYS)
    if "approach" in out:
        out["approach"] = [section(s) for s in r["approach"]]
    out["sections"] = [section(s) for s in r["sections"]]
    out["points"] = [point(p) for p in r["points"]]
    return out


def render(r):
    """The route as JSON text: top-level keys one per line, each section and point on its own."""
    def one(v):
        return json.dumps(v, ensure_ascii=False, allow_nan=False)

    lines = []
    for k, v in r.items():
        if isinstance(v, list):
            items = ",\n".join(f"    {one(x)}" for x in v)
            lines.append(f"  {one(k)}: [\n{items}\n  ]")
        else:
            lines.append(f"  {one(k)}: {one(v)}")
    return "{\n" + ",\n".join(lines) + "\n}\n"


def reject_constant(name):
    raise ValueError(f"{name} is not a number a route can hold")


def main(argv=None):
    ap = argparse.ArgumentParser(prog="route.py", description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build", help="check a route source and write the route file")
    b.add_argument("source", help="the hand-written source, routes/<id>.src.json")
    b.add_argument("-o", "--output", required=True, help="the route file to write")
    b.add_argument("--gpx", help="a track from the approach's start (or the head) to the top")
    args = ap.parse_args(argv)

    name = os.path.basename(args.source)
    stem = name[:-len(".src.json")] if name.endswith(".src.json") else None
    problems, warnings = [], []
    try:
        with open(args.source, encoding="utf-8") as f:
            data = json.load(f, parse_constant=reject_constant)
    except (OSError, ValueError) as e:
        print(f"{args.source}: {e}", file=sys.stderr)
        return 1
    if stem is None:
        problems.append(f"{args.source}: the source is named <id>.src.json")
    track = None
    if args.gpx:
        try:
            track = read_gpx(args.gpx)
        except RouteError as e:
            problems += e.problems
    try:
        text = render(build(data, track, stem, warnings))
    except RouteError as e:
        problems = [f"{args.source}: {p}" for p in e.problems] + problems
    except ValueError as e:  # a number JSON cannot hold, in a field the checks do not reach
        problems.insert(0, f"{args.source}: {e}")
    for w in warnings:
        print(f"{args.gpx}: warning: {w}", file=sys.stderr)
    if problems:
        for p in problems:
            print(p, file=sys.stderr)
        return 1
    try:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(text)
    except OSError as e:
        print(f"{args.output}: {e}", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
