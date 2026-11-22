"""Route tool: builds a route file (design/real-functionality.md, section 4) from a hand-written
source, checks it, and fills the points' coordinates from a GPX track.

python3 tools/route.py build routes/<id>.src.json -o resources/routes/<id>.json [--gpx track.gpx]

The source has the output's shape. The output lists its keys in a fixed order, one section or point
per line, so a rebuild of an unchanged source changes nothing. On any error it prints every problem
found, one per line, writes nothing and exits 1. Python 3, standard library only.
"""
import argparse
import json
import math
import sys
import xml.etree.ElementTree as ET

FORMAT = 1
TOP_KEYS = ["format", "id", "name", "short", "place", "source", "approach", "sections", "points"]
SECTION_KEYS = ["len", "up", "grade", "min", "name", "side"]
POINT_KEYS = ["kind", "at", "alt", "lat", "lon", "name"]
KINDS = {"approach", "head", "landmark", "danger", "exit", "top"}
SHORT_MAX = 15  # the SDK's suggested maximum for a session name
ALT_TOLERANCE = 15  # metres between the sections' height and the known altitudes
EARTH_RADIUS = 6371000.0


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
    if "format" in r and r["format"] != FORMAT:
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
                for k in ("lat", "lon"):
                    if k in p and not is_num(p[k]):
                        out.append(f"{label}: {k} is a number")
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
    if len(r["short"]) > SHORT_MAX:
        out.append(f"short is at most {SHORT_MAX} characters ({len(r['short'])})")

    # Coordinates come in pairs.
    for p in pts:
        if ("lat" in p) != ("lon" in p):
            out.append(f"{point_label(p)}: lat and lon come together")
    return out


def check(r):
    """Every problem with route r, as messages; empty when it is valid."""
    return check_shape(r) or check_rules(r)


def haversine(lat1, lon1, lat2, lon2):
    """Great-circle distance in metres."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_RADIUS * math.asin(math.sqrt(a))


def read_gpx(path):
    """The track points of a GPX file, as (lat, lon), whatever its namespace."""
    track = []
    for el in ET.parse(path).iter():
        if el.tag.rsplit("}", 1)[-1] == "trkpt":
            track.append((float(el.get("lat")), float(el.get("lon"))))
    if len(track) < 2:
        raise RouteError([f"{path}: a track has at least two points"])
    return track


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


def build(r, track=None):
    """Route r checked and in canonical form; lat and lon filled from track where missing."""
    problems = check(r)
    if problems:
        raise RouteError(problems)
    approach_len = sum(s["len"] for s in r.get("approach", []))

    def section(s):
        s = ordered(s, SECTION_KEYS)
        s["side"] = float(s["side"])
        return s

    def point(p):
        if p["kind"] not in KINDS:
            return p
        p = dict(p)
        if track is not None and "lat" not in p:
            p["lat"], p["lon"] = (round(v, 6) for v in position(track, approach_len + p["at"]))
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
        return json.dumps(v, ensure_ascii=False)

    lines = []
    for k, v in r.items():
        if isinstance(v, list):
            items = ",\n".join(f"    {one(x)}" for x in v)
            lines.append(f"  {one(k)}: [\n{items}\n  ]")
        else:
            lines.append(f"  {one(k)}: {one(v)}")
    return "{\n" + ",\n".join(lines) + "\n}\n"


def main(argv=None):
    ap = argparse.ArgumentParser(prog="route.py", description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build", help="check a route source and write the route file")
    b.add_argument("source", help="the hand-written source, routes/<id>.src.json")
    b.add_argument("-o", "--output", required=True, help="the route file to write")
    b.add_argument("--gpx", help="a track from the approach's start (or the head) to the top")
    args = ap.parse_args(argv)

    try:
        with open(args.source, encoding="utf-8") as f:
            data = json.load(f)
        track = read_gpx(args.gpx) if args.gpx else None
        text = render(build(data, track))
    except RouteError as e:
        for p in e.problems:
            print(f"{args.source}: {p}", file=sys.stderr)
        return 1
    except (OSError, json.JSONDecodeError, ET.ParseError, TypeError, ValueError) as e:
        print(f"{args.source}: {e}", file=sys.stderr)
        return 1
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
