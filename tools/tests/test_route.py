"""Tests for tools/route.py: the demo route builds, and each validation rule rejects its case."""
import copy
import json
import math
import shutil
import subprocess
from pathlib import Path

import pytest

import route

REPO = Path(__file__).resolve().parents[2]
DEMO = REPO / "routes" / "demo.src.json"

# A minimal valid route: a 20 m approach, two ferrata sections, and every point kind.
MINIMAL = {
    "format": 1,
    "units": "m",
    "id": "t",
    "name": "Test",
    "short": "Test",
    "place": "Here",
    "source": {"geometry": "x", "elevation": "x", "text": "x"},
    "approach": [{"len": 20, "up": 10, "grade": 0, "min": 5, "name": "Walk", "side": 0.0}],
    "sections": [
        {"len": 50, "up": 40, "grade": 3, "min": 10, "name": "Wall", "side": -0.5},
        {"len": 30, "up": 20, "grade": 5, "min": 8, "name": "Ridge", "side": 0.5},
    ],
    "points": [
        {"kind": "approach", "at": -20, "alt": 990, "type": "Car park", "name": "Car park"},
        {"kind": "head", "at": 0, "alt": 1000, "name": "Head"},
        {"kind": "exit", "at": 50, "name": "Exit"},
        {"kind": "landmark", "at": 50, "alt": 1040, "type": "rest", "name": "Bench"},
        {"kind": "danger", "at": 60, "name": "Loose"},
        {"kind": "top", "at": 80, "alt": 1060, "name": "Top"},
    ],
}


def fixture(change=None):
    """A copy of MINIMAL, with change(route) applied to it."""
    r = copy.deepcopy(MINIMAL)
    if change:
        change(r)
    return r


def build(tmp_path, data, gpx=None):
    """Write data as a source, build it; return the exit code and the output (or None)."""
    rid = data.get("id") if isinstance(data, dict) and isinstance(data.get("id"), str) else "x"
    src = tmp_path / f"{rid}.src.json"
    out = tmp_path / "r.json"
    src.write_text(data if isinstance(data, str) else json.dumps(data))
    out.unlink(missing_ok=True)
    argv = ["build", str(src), "-o", str(out)]
    if gpx is not None:
        g = tmp_path / "t.gpx"
        g.write_text(gpx)
        argv += ["--gpx", str(g)]
    code = route.main(argv)
    return code, (json.loads(out.read_text()) if out.exists() else None)


def rejects(tmp_path, capsys, data, message):
    code, out = build(tmp_path, data)
    err = capsys.readouterr().err
    assert code == 1
    assert out is None
    assert message in err


def point(r, kind):
    return next(p for p in r["points"] if p["kind"] == kind)


def test_demo_builds(tmp_path):
    out = tmp_path / "demo.json"
    assert route.main(["build", str(DEMO), "-o", str(out)]) == 0
    r = json.loads(out.read_text())
    assert list(r) == ["format", "units", "id", "name", "short", "place", "source", "approach", "sections", "points"]
    assert r["format"] == 1
    for s in r["approach"] + r["sections"]:
        assert list(s) == ["len", "up", "grade", "min", "name", "side"]
    for p in r["points"]:
        assert set(p) <= {"kind", "at", "alt", "type", "lat", "lon", "name"}
        assert list(p)[:2] == ["kind", "at"] and list(p)[-1] == "name"


def test_minimal_builds(tmp_path):
    assert build(tmp_path, fixture())[0] == 0


# Rule 1: exactly one head (at 0) and one top; an approach point only with an approach list, at
# minus its length.

def test_rule1_no_head(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r["points"].remove(point(r, "head"))),
            "exactly one head point")


def test_rule1_two_tops(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r["points"].append(dict(point(r, "top")))),
            "exactly one top point")


def test_rule1_head_not_at_zero(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "head").update(at=5)),
            "the head point is at 0")


def test_rule1_approach_point_without_approach(tmp_path, capsys):
    def change(r):
        del r["approach"]
        point(r, "approach")["at"] = 0
    rejects(tmp_path, capsys, fixture(change), "an approach point needs an approach list")


def test_rule1_approach_point_not_at_start(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "approach").update(at=-10)),
            "the approach point is at -20 (minus the approach's length)")


# A point's type (#121): what the approach point is, a Top station or a Car park, which the Start menu
# shows in its place, a non-empty name; what a landmark is, rest, bridge or sign, which its details
# show; required on both, and on no other point.

def test_type_written_after_alt(tmp_path):
    code, out = build(tmp_path, fixture())
    assert code == 0
    assert list(point(out, "approach")) == ["kind", "at", "alt", "type", "name"]
    assert point(out, "approach")["type"] == "Car park"


def test_type_missing_on_approach_point(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "approach").pop("type")),
            "approach 'Car park': type is missing (what the point is, as Top station or Car park)")


@pytest.mark.parametrize("blank", ["", "   "])
def test_type_empty(tmp_path, capsys, blank):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "approach").update(type=blank)),
            "approach 'Car park': type is not empty")


def test_type_not_a_string(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "approach").update(type=3)),
            "approach 1 'Car park': type is a string")


def test_type_only_on_approach_and_landmarks(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "exit").update(type="rest")),
            "exit 'Exit': type is for the approach point and landmarks only")


@pytest.mark.parametrize("kind", ["rest", "bridge", "sign"])
def test_landmark_types(tmp_path, kind):
    code, out = build(tmp_path, fixture(lambda r: point(r, "landmark").update(type=kind)))
    assert code == 0
    assert list(point(out, "landmark")) == ["kind", "at", "alt", "type", "name"]
    assert point(out, "landmark")["type"] == kind


def test_landmark_type_missing(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "landmark").pop("type")),
            "landmark 'Bench': type is missing (rest, bridge or sign)")


@pytest.mark.parametrize("kind", ["bench", "Rest", ""])
def test_landmark_type_from_the_set(tmp_path, capsys, kind):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "landmark").update(type=kind)),
            f"landmark 'Bench': type is rest, bridge or sign, not {kind!r}")


def test_type_folded(tmp_path, capsys):
    code, out = build(tmp_path, fixture(lambda r: point(r, "approach").update(type="Bergstation Größe")))
    assert code == 0
    assert point(out, "approach")["type"] == "Bergstation Grosse"
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "approach").update(type="Station!")),
            "approach 1 'Car park': type: '!' (U+0021) is not in the fonts' charset")


# Rule 2: exits and landmarks on section boundaries.

def test_rule2_exit_off_boundary(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "exit").update(at=45)),
            "exit 'Exit' at 45 is not on a section boundary")


def test_rule2_landmark_off_boundary(tmp_path, capsys):
    def change(r):
        point(r, "landmark").update(at=40, alt=1032)
    rejects(tmp_path, capsys, fixture(change), "landmark 'Bench' at 40 is not on a section boundary")


# Rule 3: every at within the route; the top at the ferrata's length.

def test_rule3_point_beyond_top(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "danger").update(at=90)),
            "danger 'Loose' at 90 is outside -20..80")


def test_rule3_point_before_approach(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "danger").update(at=-30)),
            "danger 'Loose' at -30 is outside -20..80")


def test_rule3_top_not_at_length(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "top").update(at=70)),
            "the top point is at 80 (the ferrata's length)")


# Rule 4: known altitudes agree with the sections within 15 m.

def test_rule4_alt_mismatch(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "top").update(alt=1076)),
            "'Bench' (at 50) to 'Top' (at 80): the sections climb 20 m, the altitudes 36 m")


def test_rule4_within_tolerance(tmp_path):
    assert build(tmp_path, fixture(lambda r: point(r, "top").update(alt=1075)))[0] == 0


def test_known_alts_use_net_height(tmp_path, capsys):
    # A section that loses 30 m: the net height between head and top is 40 - 30 = 10 m, whereas the
    # gained height is 40 m. Rule 4 compares the net height.
    def change(r):
        r["sections"][1]["up"] = -30
        point(r, "top")["alt"] = 1010
    assert build(tmp_path, fixture(change))[0] == 0
    rejects(tmp_path, capsys, fixture(lambda r: change(r) or point(r, "top").update(alt=1040)),
            "the sections climb -30 m, the altitudes 0 m")


# Rule 5: grade, len, min, side in range.

@pytest.mark.parametrize("grade", [-2, 13, 2.5])
def test_rule5_grade(tmp_path, capsys, grade):
    rejects(tmp_path, capsys, fixture(lambda r: r["sections"][0].update(grade=grade)),
            "section 1 'Wall': grade is an integer from -1 to 12")


def test_rule5_len(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r["approach"][0].update(len=0)),
            "approach 1 'Walk': len is above 0")


def test_rule5_min(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r["sections"][1].update(min=0)),
            "section 2 'Ridge': min is above 0")


def test_rule5_side(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r["sections"][1].update(side=1.5)),
            "section 2 'Ridge': side is from -1.0 to 1.0")


def test_min_optional(tmp_path):
    # Guidebook minutes may be missing, from one section or all of them.
    def change(r):
        for s in r["approach"] + r["sections"]:
            del s["min"]
    code, out = build(tmp_path, fixture(change))
    assert code == 0
    assert all("min" not in s for s in out["sections"])


# Rule 6: short at most 15 characters.

def test_rule6_short(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r.update(short="Sixteen chars ab")),
            "short is at most 15 characters (16)")


# Keys and types.

def test_missing_key(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r["sections"][0].pop("name")),
            "section 1: name is missing")


def test_unknown_key(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r["sections"][0].update(mins=10)),
            "section 1 'Wall': unknown key mins")


def test_format(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r.update(format=2)), "format is 1")


def test_negative_up_allowed(tmp_path):
    def change(r):
        r["sections"][1]["up"] = -5
        point(r, "top")["alt"] = 1035
    assert build(tmp_path, fixture(change))[0] == 0


def test_unknown_kind_kept(tmp_path):
    odd = {"kind": "spring", "at": 999, "flow": "good", "name": "Water"}
    code, out = build(tmp_path, fixture(lambda r: r["points"].append(dict(odd))))
    assert code == 0
    assert odd in out["points"]


def test_errors_all_reported(tmp_path, capsys):
    def change(r):
        r["short"] = "x" * 20
        r["sections"][0]["grade"] = 20
    rejects(tmp_path, capsys, fixture(change), "short is at most 15 characters")
    # rejects() consumed stderr; build once more to see both messages together.
    build(tmp_path, fixture(change))
    err = capsys.readouterr().err
    assert "short is at most" in err and "grade is an integer" in err


# GPX.

def gpx(points):
    pts = "".join(f'<trkpt lat="{lat}" lon="{lon}"><ele>0</ele></trkpt>' for lat, lon in points)
    return ('<?xml version="1.0"?><gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">'
            f"<trk><trkseg>{pts}</trkseg></trk></gpx>")


def test_gpx_fills_lat_lon(tmp_path):
    # A straight track due north, 3 points; the approach plus the ferrata is 100 m, and the track
    # is made about as long. The landmark at 50 m from the head is 70 m along the track.
    length = route.haversine(46.0, 8.0, 46.001, 8.0)
    track = [(46.0, 8.0), (46.0005, 8.0), (46.001, 8.0)]

    def change(r):
        point(r, "landmark")["at"] = 50
    code, out = build(tmp_path, fixture(change), gpx=gpx(track))
    assert code == 0
    lm = point(out, "landmark")
    assert lm["lat"] == pytest.approx(46.0 + 0.001 * 70 / length, abs=1e-5)
    assert lm["lon"] == pytest.approx(8.0, abs=1e-5)
    # The approach point is the track's start.
    ap = point(out, "approach")
    assert (ap["lat"], ap["lon"]) == (pytest.approx(46.0, abs=1e-6), pytest.approx(8.0, abs=1e-6))


def test_gpx_midpoint(tmp_path):
    # Without an approach the track starts at the head; a point at half its length gets the midpoint.
    length = route.haversine(46.0, 8.0, 46.001, 8.0)

    def change(r):
        del r["approach"]
        r["points"].remove(point(r, "approach"))
        r["sections"] = [{"len": round(length), "up": 0, "grade": 1, "name": "Flat", "side": 0.0}]
        r["points"] = [
            {"kind": "head", "at": 0, "alt": 1000, "name": "Head"},
            {"kind": "danger", "at": round(length / 2), "name": "Middle"},
            {"kind": "top", "at": round(length), "alt": 1000, "name": "Top"},
        ]
    code, out = build(tmp_path, fixture(change), gpx=gpx([(46.0, 8.0), (46.0005, 8.0), (46.001, 8.0)]))
    assert code == 0
    mid = point(out, "danger")
    assert mid["lat"] == pytest.approx(46.0005, abs=1e-5)
    assert mid["lon"] == pytest.approx(8.0, abs=1e-5)


def test_gpx_keeps_given_lat_lon(tmp_path):
    code, out = build(tmp_path, fixture(lambda r: point(r, "top").update(lat=47.0, lon=9.0)),
                      gpx=gpx([(46.0, 8.0), (46.001, 8.0)]))
    assert code == 0
    assert (point(out, "top")["lat"], point(out, "top")["lon"]) == (47.0, 9.0)


def test_lat_without_lon(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: point(r, "top").update(lat=47.0)),
            "top 'Top': lat and lon come together")


def test_demo_output_is_current():
    # resources/routes/demo.json is what make routes writes from routes/demo.src.json.
    built = route.render(route.build(json.loads(DEMO.read_text())))
    assert (REPO / "resources" / "routes" / "demo.json").read_text() == built


# Review of PR #78.

def test_nan_rejected(tmp_path, capsys):
    # NaN in a field no rule reaches (source) still fails, on load.
    text = json.dumps(MINIMAL).replace('"geometry": "x"', '"geometry": NaN')
    rejects(tmp_path, capsys, text, "NaN is not a number a route can hold")


def test_infinity_rejected(tmp_path, capsys):
    text = json.dumps(MINIMAL).replace('"side": -0.5', '"side": Infinity')
    rejects(tmp_path, capsys, text, "Infinity is not a number a route can hold")


def test_nan_not_written():
    # render() never writes what JSON cannot hold, whatever reaches it.
    with pytest.raises(ValueError):
        route.render({"source": {"x": float("nan")}})


@pytest.mark.parametrize("fmt", [True, 1.0, "1"])
def test_format_is_the_integer_1(tmp_path, capsys, fmt):
    rejects(tmp_path, capsys, fixture(lambda r: r.update(format=fmt)), "format is 1")


@pytest.mark.parametrize("kind,at", [("exit", 0), ("exit", 80), ("landmark", 0), ("landmark", 80)])
def test_rule2_not_at_head_or_top(tmp_path, capsys, kind, at):
    def change(r):
        p = point(r, kind)
        p["at"] = at
        p.pop("alt", None)
    rejects(tmp_path, capsys, fixture(change), f"at {at} is at the head or the top, not between them")


@pytest.mark.parametrize("key,value,message", [
    ("lat", 469.0, "lat is a number from -90 to 90"),
    ("lat", -90.5, "lat is a number from -90 to 90"),
    ("lon", 181, "lon is a number from -180 to 180"),
])
def test_lat_lon_range(tmp_path, capsys, key, value, message):
    def change(r):
        point(r, "top").update(lat=46.0, lon=8.0)
        point(r, "top")[key] = value
    rejects(tmp_path, capsys, fixture(change), message)


def test_gpx_length_mismatch_warns(tmp_path, capsys):
    # The route is 100 m; a track of about 222 m builds, with a warning.
    code, _ = build(tmp_path, fixture(), gpx=gpx([(46.0, 8.0), (46.002, 8.0)]))
    err = capsys.readouterr().err
    assert code == 0
    assert "t.gpx: warning: the track is 222 m long, the route 100 m (more than 20% apart)" in err


def test_gpx_clamp_warns(tmp_path, capsys):
    # A track of about 56 m: the points past it are placed at its end, each with a warning.
    code, out = build(tmp_path, fixture(), gpx=gpx([(46.0, 8.0), (46.0005, 8.0)]))
    err = capsys.readouterr().err
    assert code == 0
    assert "warning: top 'Top' at 80 lies 44 m beyond the track's end: placed at its end" in err
    assert "warning: head 'Head'" not in err
    assert point(out, "top")["lat"] == pytest.approx(46.0005)


def test_gpx_close_enough_is_quiet(tmp_path, capsys):
    length = route.haversine(46.0, 8.0, 46.0009, 8.0)  # about 100 m, the route's length
    assert 95 < length < 105
    code, _ = build(tmp_path, fixture(), gpx=gpx([(46.0, 8.0), (46.0009, 8.0)]))
    assert code == 0
    assert "warning" not in capsys.readouterr().err


def test_missing_output_dir(tmp_path, capsys):
    src = tmp_path / "t.src.json"
    src.write_text(json.dumps(MINIMAL))
    assert route.main(["build", str(src), "-o", str(tmp_path / "no" / "t.json")]) == 1
    err = capsys.readouterr().err
    assert "No such file or directory" in err and "Traceback" not in err


def test_gpx_errors_name_file_and_point_and_come_with_route_errors(tmp_path, capsys):
    bad = ('<gpx xmlns="http://www.topografix.com/GPX/1/1"><trk><trkseg>'
           '<trkpt lat="46" lon="8"/><trkpt lat="x" lon="8"/><trkpt lat="46.001" lon="8"/>'
           '</trkseg></trk></gpx>')
    code, out = build(tmp_path, fixture(lambda r: r.update(short="")), gpx=bad)
    err = capsys.readouterr().err
    assert code == 1 and out is None
    assert "t.gpx: track point 2: lat and lon are numbers" in err
    assert "t.src.json: short is not empty" in err


def test_gpx_unreadable(tmp_path, capsys):
    rejects_gpx = build(tmp_path, fixture(), gpx="<gpx><trk>")
    assert rejects_gpx[0] == 1
    assert "t.gpx: " in capsys.readouterr().err


def test_short_not_empty(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r.update(short="")), "short is not empty")


def test_id_is_file_stem(tmp_path, capsys):
    src = tmp_path / "other.src.json"
    src.write_text(json.dumps(MINIMAL))
    assert route.main(["build", str(src), "-o", str(tmp_path / "o.json")]) == 1
    assert "id is 'other', the source's file name (<id>.src.json)" in capsys.readouterr().err


def test_source_name(tmp_path, capsys):
    src = tmp_path / "t.json"
    src.write_text(json.dumps(MINIMAL))
    assert route.main(["build", str(src), "-o", str(tmp_path / "o.json")]) == 1
    assert "the source is named <id>.src.json" in capsys.readouterr().err


# make routes, in a copy of the parts of the repository it uses.

def repo_copy(tmp_path):
    for rel in ("Makefile", "tools/route.py", "routes/demo.src.json"):
        (tmp_path / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(REPO / rel, tmp_path / rel)
    (tmp_path / "resources" / "routes").mkdir(parents=True)
    shutil.copy(REPO / "resources/routes/routes.xml", tmp_path / "resources/routes/routes.xml")
    return tmp_path


def make_routes(root):
    return subprocess.run(["make", "--no-print-directory", "routes"], cwd=root,
                          capture_output=True, text=True)


needs_make = pytest.mark.skipif(shutil.which("make") is None, reason="needs make")


@needs_make
def test_make_routes_uses_gpx(tmp_path):
    root = repo_copy(tmp_path)
    (root / "routes/demo.gpx").write_text(gpx([(46.0, 8.0), (46.0068, 8.0)]))  # about 760 m
    res = make_routes(root)
    assert res.returncode == 0, res.stderr
    out = json.loads((root / "resources/routes/demo.json").read_text())
    assert all("lat" in p and "lon" in p for p in out["points"])


@needs_make
def test_make_routes_rejects_orphan(tmp_path):
    root = repo_copy(tmp_path)
    (root / "resources/routes/gone.json").write_text("{}")
    res = make_routes(root)
    assert res.returncode != 0
    assert "resources/routes/gone.json has no source, routes/gone.src.json" in res.stderr


# Names folded to the fonts' text charset (#84).

@pytest.mark.parametrize("text,folded", [
    ("Klettersteig Brünnstein", "Klettersteig Brunnstein"),
    ("Cascade de l'Été", "Cascade de l'Ete"),
    ("Garçon", "Garcon"),
    ("Große Zinne", "Grosse Zinne"),
    ("Bjørnø Ærø", "Bjorno AEro"),
    ("Œuvre", "OEuvre"),
    ("Łódź", "Lodz"),
    ("Đakovo", "Dakovo"),
    ("Þingvellir", "Thingvellir"),
    ("Via dell’Amicizia — Nord", "Via dell'Amicizia - Nord"),
    ("Via dell’Amicizia – Nord", "Via dell'Amicizia – Nord"),
    ("Plain (A-Z), 0-9 / ok.", "Plain (A-Z), 0-9 / ok."),
    ("Kept: + > ? ~ ° · – …", "Kept: + > ? ~ ° · – …"),
])
def test_fold(text, folded):
    assert route.fold(text) == folded


def test_names_folded(tmp_path):
    def change(r):
        r.update(name="Große Wand", short="Große", place="Zürich")
        r["approach"][0]["name"] = "Zustieg über Wiese"
        r["sections"][0]["name"] = "Été"
        point(r, "top")["name"] = "Gipfel Ærø"
    code, out = build(tmp_path, fixture(change))
    assert code == 0
    assert (out["name"], out["short"], out["place"]) == ("Grosse Wand", "Grosse", "Zurich")
    assert out["approach"][0]["name"] == "Zustieg uber Wiese"
    assert out["sections"][0]["name"] == "Ete"
    assert point(out, "top")["name"] == "Gipfel AEro"


def test_unknown_kind_folded(tmp_path, capsys):
    # Points of unknown kinds pass through unchecked, but their names are folded and checked too.
    odd = {"kind": "spring", "at": 999, "flow": "good", "name": "Quelle Größe"}
    code, out = build(tmp_path, fixture(lambda r: r["points"].append(dict(odd))))
    assert code == 0
    assert dict(odd, name="Quelle Grosse") in out["points"]
    rejects(tmp_path, capsys, fixture(lambda r: r["points"].append(dict(odd, name="Quelle!"))),
            "spring 7 'Quelle!': name: '!' (U+0021) is not in the fonts' charset")


@pytest.mark.parametrize("text,folded", [
    # NFKD first, then the table: accents on special letters.
    ("Ǿ ǿ ǣ Ǽ", "O o ae AE"),
    # Quotes, of any kind, to the apostrophe; the charset has no double quote.
    ("“A” „B“ «C» ‛D’ ʼE `F′", "'A' 'B' 'C' 'D' 'E 'F'"),
    # The plain double quote too (Codex on #86).
    ('Ferrata "Nord"', "Ferrata 'Nord'"),
    # Minus and fraction slash.
    ("−5 1⁄2", "-5 1/2"),
    # Micro sign and Greek mu.
    ("µm μm", "um um"),
    # Invisible marks dropped: soft hyphen, zero-width space, non-joiner, joiner, variation selector.
    ("Klet\u00adter\u200bsteig\u200c\u200d\ufe0f", "Klettersteig"),
])
def test_fold_more(text, folded):
    assert route.fold(text) == folded


@pytest.mark.parametrize("change,message", [
    (lambda r: r.update(name="Ferrata → Top"),
     "name: '→' (U+2192) is not in the fonts' charset"),
    (lambda r: r["sections"][1].update(name="Ridge 漢"),
     "section 2 'Ridge 漢': name: '漢' (U+6F22) is not in the fonts' charset"),
    (lambda r: point(r, "danger").update(name="Loose!"),
     "danger 5 'Loose!': name: '!' (U+0021) is not in the fonts' charset"),
])
def test_fold_rejects_what_the_fonts_lack(tmp_path, capsys, change, message):
    rejects(tmp_path, capsys, fixture(change), message)


def test_short_length_counts_folded(tmp_path, capsys):
    # ß becomes ss: 15 characters as written, 16 folded.
    rejects(tmp_path, capsys, fixture(lambda r: r.update(short="Große Wand abcd")),
            "short is at most 15 characters (16)")


CHARSETS = REPO / "resources" / "fonts" / "charsets.json"


@pytest.mark.skipif(not CHARSETS.exists(), reason="the fonts' charsets land with #62 (PR #77)")
def test_text_charset_is_the_fonts():
    # Every font that draws letters is a text font, and they share one charset: the tool's.
    fonts = json.loads(CHARSETS.read_text(encoding="utf-8"))
    text = [set(f["fontCharset"]) for f in fonts if "a" in f["fontCharset"]]
    assert text and all(c == route.TEXT_CHARSET for c in text)


# GPX points placed by distance along the track including height (#85).

def gpx3d(points):
    """A track of (lat, lon, ele) points; ele None leaves the point without an elevation."""
    pts = "".join(f'<trkpt lat="{lat}" lon="{lon}">' + ("" if ele is None else f"<ele>{ele}</ele>")
                  + "</trkpt>" for lat, lon, ele in points)
    return ('<?xml version="1.0"?><gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">'
            f"<trk><trkseg>{pts}</trkseg></trk></gpx>")


def one_section(length, up, mid_at):
    """A route with no approach: one section, a danger point at mid_at, the top at its length."""
    def change(r):
        del r["approach"]
        r["sections"] = [{"len": length, "up": up, "grade": 5, "name": "Wall", "side": 0.0}]
        r["points"] = [
            {"kind": "head", "at": 0, "alt": 1000, "name": "Head"},
            {"kind": "danger", "at": mid_at, "name": "Middle"},
            {"kind": "top", "at": length, "alt": 1000 + up, "name": "Top"},
        ]
    return fixture(change)


def test_gpx_steep_midpoint(tmp_path, capsys):
    # A flat step, then a steep one: about 56 m across, then 56 m across and 300 m up. Along the
    # track in 3D it is about 361 m, the route's length, so it builds without a warning; the point
    # halfway up the steep step is at the middle of that step on the map, not past the track's end
    # as the horizontal distance would place it.
    flat = route.haversine(46.0, 8.0, 46.0005, 8.0)
    steep = math.hypot(flat, 300)
    length = int(flat + steep)  # within the track, or the top would lie past its end
    track = [(46.0, 8.0, 1000), (46.0005, 8.0, 1000), (46.001, 8.0, 1300)]
    code, out = build(tmp_path, one_section(length, 300, round(flat + steep / 2)), gpx=gpx3d(track))
    assert code == 0
    assert "warning" not in capsys.readouterr().err
    mid = point(out, "danger")
    assert mid["lat"] == pytest.approx(46.00075, abs=1e-5)
    assert point(out, "top")["lat"] == pytest.approx(46.001, abs=1e-5)


def test_gpx_length_is_3d():
    flat = route.haversine(46.0, 8.0, 46.001, 8.0)
    assert route.track_length([(46.0, 8.0, 0.0), (46.001, 8.0, 300.0)]) == pytest.approx(math.hypot(flat, 300))


def test_gpx_flat_track_as_before():
    # Equal elevations, or none, measure the horizontal distance.
    track = [(46.0, 8.0), (46.0005, 8.0), (46.001, 8.0)]
    flat = route.haversine(46.0, 8.0, 46.001, 8.0)
    for ele in (500.0, None):
        t = [(la, lo, ele) for la, lo in track]
        assert route.track_length(t) == pytest.approx(flat)
        assert route.position(t, flat / 4) == pytest.approx((46.00025, 8.0), abs=1e-7)


def test_gpx_missing_elevation_interpolated():
    # Between points with an elevation, by horizontal distance; before the first and after the last,
    # the nearest one.
    track = [(46.0, 8.0, None), (46.0, 8.0, 0.0), (46.00025, 8.0, None), (46.001, 8.0, None),
             (46.001, 8.0, 300.0), (46.0015, 8.0, None)]
    filled, n = route.fill_elevations(track)
    assert n == 4
    assert [e for _, _, e in filled] == pytest.approx([0.0, 0.0, 75.0, 300.0, 300.0, 300.0])


def test_gpx_no_elevation_at_all_as_before():
    track = [(46.0, 8.0, None), (46.001, 8.0, None)]
    assert route.fill_elevations(track) == (track, 0)


def test_gpx_missing_elevation_warns(tmp_path, capsys):
    track = [(46.0, 8.0, 1000), (46.0005, 8.0, None), (46.0009, 8.0, 1000)]
    code, _ = build(tmp_path, fixture(), gpx=gpx3d(track))
    assert code == 0
    assert ("t.gpx: warning: 1 of 3 track points have no elevation: interpolated from their "
            "neighbours") in capsys.readouterr().err


def test_gpx_no_elevation_is_quiet(tmp_path, capsys):
    code, _ = build(tmp_path, fixture(), gpx=gpx3d([(46.0, 8.0, None), (46.0009, 8.0, None)]))
    assert code == 0
    assert "warning" not in capsys.readouterr().err


def test_gpx_reads_elevation(tmp_path):
    g = tmp_path / "t.gpx"
    g.write_text(gpx3d([(46.0, 8.0, 1000.5), (46.001, 8.0, None)]))
    assert route.read_gpx(str(g)) == [(46.0, 8.0, 1000.5), (46.001, 8.0, None)]


@pytest.mark.parametrize("ele", ["high", ""])
def test_gpx_bad_elevation(tmp_path, capsys, ele):
    bad = gpx3d([(46.0, 8.0, 1000), (46.001, 8.0, ele)])
    code, out = build(tmp_path, fixture(), gpx=bad)
    assert code == 1 and out is None
    assert "t.gpx: track point 2: ele is a number" in capsys.readouterr().err


# Units (owner, #143): declared in the source, never assumed; a route file is in metres.

def test_units_missing(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r.pop("units")), "units is missing")


def test_units_unknown(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r.update(units="yd")), "units is m or ft, not 'yd'")


def test_feet_converted_to_metres(tmp_path):
    # The approach 100 ft (30.48 m), then 150 ft and 100 ft of ferrata: each boundary converted and
    # rounded, so the exit at 150 ft (45.72 m) stays on the first section's end, 46 m.
    def change(r):
        r["units"] = "ft"
        r["approach"][0].update(len=100, up=30)
        r["sections"][0].update(len=150, up=130)
        r["sections"][1].update(len=100, up=70)
        alts = {"approach": 3250, "head": 3280, "landmark": 3410, "top": 3480}
        for p in r["points"]:
            p["at"] = {"approach": -100, "head": 0, "exit": 150, "landmark": 150, "danger": 200, "top": 250}[p["kind"]]
            if p["kind"] in alts:
                p["alt"] = alts[p["kind"]]
    code, out = build(tmp_path, fixture(change))
    assert code == 0
    assert out["units"] == "m"
    assert [s["len"] for s in out["approach"] + out["sections"]] == [30, 46, 30]
    assert [s["up"] for s in out["approach"] + out["sections"]] == [9, 40, 21]
    assert [p["at"] for p in out["points"]] == [-30, 0, 46, 46, 61, 76]
    assert point(out, "head")["alt"] == 1000 and point(out, "top")["alt"] == 1061
    assert out["sections"][0]["min"] == 10  # minutes are not lengths


def test_feet_checked_in_metres(tmp_path, capsys):
    # 15 m is 49 ft: altitudes 60 ft off the sections' height are more than 15 m apart.
    def change(r):
        r["units"] = "ft"
        point(r, "top")["alt"] += 60
    rejects(tmp_path, capsys, fixture(change), "(more than 15 m apart)")


# The approach's track (#143): from the GPX, thinned, from the approach's start to the head; or the
# source's own.

def north(n, step):
    """n points due north from (46.0, 8.0), step degrees of latitude apart."""
    return [(round(46.0 + i * step, 7), 8.0) for i in range(n)]


def test_gpx_writes_the_approach_track(tmp_path):
    # The fixture's 20 m approach and 80 m ferrata along a straight track due north, a point every
    # metre or so: the approach's track runs from the start to the head, about 20 m, thinned to its
    # ends, which are the points' own coordinates.
    code, out = build(tmp_path, fixture(), gpx=gpx(north(91, 0.00001)))
    assert code == 0
    assert list(out) == route.TOP_KEYS
    head, start = point(out, "head"), point(out, "approach")
    assert out["track"] == [[round(start["lat"], 5), round(start["lon"], 5)],
                            [round(head["lat"], 5), round(head["lon"], 5)]]
    assert 19 < route.haversine(*out["track"][0], *out["track"][1]) < 21


def test_track_cut_at_the_points_nearest_the_start_and_the_head(tmp_path):
    # A track from 100 m before the approach's start to 100 m past the top; the start and the head
    # have their own coordinates, so the track is cut at its points nearest them.
    def change(r):
        point(r, "approach").update(lat=46.001, lon=8.0)
        point(r, "head").update(lat=46.0012, lon=8.0)
    code, out = build(tmp_path, fixture(change), gpx=gpx(north(30, 0.0001)))
    assert code == 0
    assert out["track"] == [[46.001, 8.0], [46.0012, 8.0]]


def test_track_follows_a_bend_and_drops_a_standstill(tmp_path):
    # 300 m north, a cloud of fixes standing still at the corner, 300 m east: the approach. The track
    # keeps the corner and drops the cloud.
    my, mx = route.flat(46.0)
    leg1 = [(46.0 + i * 10 / my, 8.0) for i in range(31)]
    corner = leg1[-1]
    cloud = [(corner[0] + dy / my, corner[1] + dx / mx) for dx, dy in
             [(3, 4), (-5, 2), (6, -3), (-2, -6), (4, 5), (-6, -1)] * 5]
    leg2 = [(corner[0], corner[1] + i * 10 / mx) for i in range(1, 31)]
    head = leg2[-1]

    def change(r):
        r["approach"][0].update(len=600, up=0, min=10)
        r["sections"] = [{"len": 80, "up": 60, "grade": 3, "min": 10, "name": "Wall", "side": 0.0}]
        r["points"] = [
            {"kind": "approach", "at": -600, "alt": 1000, "type": "Car park", "lat": 46.0, "lon": 8.0, "name": "Car park"},
            {"kind": "head", "at": 0, "alt": 1000, "lat": round(head[0], 6), "lon": round(head[1], 6), "name": "Head"},
            {"kind": "top", "at": 80, "alt": 1060, "name": "Top"},
        ]
    code, out = build(tmp_path, fixture(change), gpx=gpx(leg1 + cloud + leg2))
    assert code == 0
    t = out["track"]
    assert len(t) == 3
    assert route.haversine(*t[1], *corner) < 2
    assert 595 < sum(route.haversine(*a, *b) for a, b in zip(t, t[1:])) < 605


def test_thin_keeps_within_tolerance():
    # A zigzag 3 m to either side of a line is within TRACK_THIN: only the ends are kept; at 8 m, every
    # vertex is.
    my, mx = route.flat(46.0)
    for side, kept in ((3, 2), (8, 11)):
        pts = [(46.0 + i * 20 / my, 8.0 + (side if i % 2 else 0) / mx) for i in range(11)]
        assert len(route.thin(pts)) == kept


def test_no_track_without_an_approach(tmp_path):
    code, out = build(tmp_path, fixture(lambda r: (r.pop("approach"), r["points"].pop(0))),
                      gpx=gpx(north(10, 0.0001)))
    assert code == 0
    assert "track" not in out


def test_source_track_is_kept(tmp_path):
    def change(r):
        point(r, "head").update(lat=46.0002, lon=8.0)
        r["track"] = [[46.0, 8.0], [46.0001, 8], [46.0002, 8.0]]
    code, out = build(tmp_path, fixture(change), gpx=gpx(north(10, 0.0001)))
    assert code == 0
    assert out["track"] == [[46.0, 8.0], [46.0001, 8.0], [46.0002, 8.0]]


@pytest.mark.parametrize("track,message", [
    ([[46.0, 8.0]], "track lists at least two [lat, lon]"),
    ("x", "track lists at least two [lat, lon]"),
    ([[46.0, 8.0], [46.0]], "track 2: [lat, lon], lat from -90 to 90, lon from -180 to 180"),
    ([[46.0, 8.0], [91.0, 8.0]], "track 2: [lat, lon]"),
    ([[46.0, 8.0], [46.0, "8"]], "track 2: [lat, lon]"),
])
def test_track_shape(tmp_path, capsys, track, message):
    rejects(tmp_path, capsys, fixture(lambda r: r.update(track=track)), message)


def test_track_needs_an_approach(tmp_path, capsys):
    def change(r):
        r.pop("approach")
        r["points"].pop(0)
        point(r, "head").update(lat=46.0002, lon=8.0)
        r["track"] = [[46.0, 8.0], [46.0002, 8.0]]
    rejects(tmp_path, capsys, fixture(change), "a track needs an approach list")


def test_track_needs_the_heads_coordinates(tmp_path, capsys):
    rejects(tmp_path, capsys, fixture(lambda r: r.update(track=[[46.0, 8.0], [46.0002, 8.0]])),
            "a track needs the head's lat and lon")


def test_track_ends_at_the_head(tmp_path, capsys):
    def change(r):
        point(r, "head").update(lat=46.001, lon=8.0)
        point(r, "approach").update(lat=46.0, lon=8.0)
        r["track"] = [[46.0005, 8.0], [46.0007, 8.0]]
    rejects(tmp_path, capsys, fixture(change), "the track ends 33 m from head 'Head' (more than 25 m)")


def test_track_starts_at_the_start(tmp_path, capsys):
    def change(r):
        point(r, "head").update(lat=46.001, lon=8.0)
        point(r, "approach").update(lat=46.0, lon=8.0)
        r["track"] = [[46.0005, 8.0], [46.001, 8.0]]
    rejects(tmp_path, capsys, fixture(change), "the track starts 56 m from approach 'Car park' (more than 25 m)")


# From PR #166's review.

def test_track_cut_at_the_heads_first_pass(tmp_path):
    # Finding 1: a recording that goes on past the head to the top and comes back the same way passes
    # the head twice, the second time nearer it. The track stops at the first pass.
    def change(r):
        point(r, "approach").update(lat=46.0, lon=8.0)
        point(r, "head").update(lat=46.00018, lon=8.0)
    my, mx = route.flat(46.0)
    out_ = [(46.0 + i * 5 / my, 8.0 + 3 / mx) for i in range(21)]  # 100 m north, 3 m east of the head
    back = [(46.0 + (100 - i * 5) / my, 8.0) for i in range(21)]  # and back, right over it
    code, out = build(tmp_path, fixture(change), gpx=gpx(out_ + back))
    assert code == 0
    length = sum(route.haversine(*a, *b) for a, b in zip(out["track"], out["track"][1:]))
    assert 18 < length < 22


def test_no_track_when_the_recording_misses_the_start(tmp_path, capsys):
    # Finding 2: a recording that starts at the head has no approach in it. No track is written, as
    # without the recording, and a warning says why.
    def change(r):
        point(r, "approach").update(lat=45.99, lon=8.0)
        point(r, "head").update(lat=46.0, lon=8.0)
    code, out = build(tmp_path, fixture(change), gpx=gpx(north(10, 0.0001)))
    assert code == 0
    assert "track" not in out
    assert ("t.gpx: warning: no approach track: the track comes no nearer than 1112 m to approach "
            "'Car park' (more than 25 m)") in capsys.readouterr().err


def test_no_track_when_the_recording_misses_the_head(tmp_path, capsys):
    def change(r):
        point(r, "approach").update(lat=46.0, lon=8.0)
        point(r, "head").update(lat=46.0, lon=8.01)
    code, out = build(tmp_path, fixture(change), gpx=gpx(north(10, 0.0001)))
    assert code == 0
    assert "track" not in out
    assert "no approach track: the track comes no nearer than 772 m to head 'Head'" in capsys.readouterr().err


def turns(track):
    """The turn at each inner vertex, in degrees: 0 straight on, 180 straight back."""
    my, mx = route.flat(track[0][0])
    out = []
    for a, b, c in zip(track, track[1:], track[2:]):
        u = ((b[1] - a[1]) * mx, (b[0] - a[0]) * my)
        v = ((c[1] - b[1]) * mx, (c[0] - b[0]) * my)
        cos = (u[0] * v[0] + u[1] * v[1]) / (math.hypot(*u) * math.hypot(*v))
        out.append(math.degrees(math.acos(max(-1.0, min(1.0, cos)))))
    return out


def test_thin_drops_a_jittery_standstill():
    # Finding 6: 300 m north with a standstill halfway whose fixes wander out and back up to 22 m to
    # the side, beyond TRACK_SPACING, as the Daubenhorn's recording does. No vertex sends the track
    # back the way it came, and its length stays close.
    my, mx = route.flat(46.0)
    leg1 = [(46.0 + i * 5 / my, 8.0) for i in range(31)]
    mid = leg1[-1]
    cloud = [(mid[0] + dy / my, mid[1] + dx / mx) for dx, dy in
             [(20, 1), (0, -1), (22, 2), (-1, 0), (18, -2), (1, 1), (21, 0), (0, 2)] * 4]
    leg2 = [(mid[0] + i * 5 / my, 8.0) for i in range(1, 31)]
    t = route.thin(leg1 + cloud + leg2)
    assert max(turns(t), default=0) <= route.TRACK_REVERSAL
    assert 295 < sum(route.haversine(*a, *b) for a, b in zip(t, t[1:])) < 330


def test_thin_keeps_a_hairpin():
    # A switchback 10 m wide, 100 m up and 100 m back: its turn is kept, its length too.
    my, mx = route.flat(46.0)
    pts = ([(46.0 + i / my, 8.0) for i in range(101)] + [(46.0 + 100 / my, 8.0 + j / mx) for j in range(1, 10)]
           + [(46.0 + (100 - i) / my, 8.0 + 10 / mx) for i in range(101)])
    t = route.thin(pts)
    assert 190 < sum(route.haversine(*a, *b) for a, b in zip(t, t[1:])) < 215


def test_feet_heights_rounded_cumulatively(tmp_path):
    # Finding 8: 30 sections of 5 ft up each are 150 ft, 46 m; rounded one by one they would be
    # 30 × 2 m, 60 m.
    def change(r):
        r["units"] = "ft"
        del r["approach"]
        r["sections"] = [{"len": 10, "up": 5, "grade": 3, "min": 1, "name": f"S{i}", "side": 0.0}
                         for i in range(30)]
        r["points"] = [{"kind": "head", "at": 0, "alt": 3280, "name": "Head"},
                       {"kind": "top", "at": 300, "alt": 3430, "name": "Top"}]
    code, out = build(tmp_path, fixture(change))
    assert code == 0
    assert sum(s["up"] for s in out["sections"]) == 46
    assert sum(s["len"] for s in out["sections"]) == 91


def test_feet_too_short_for_a_metre(tmp_path, capsys):
    # A 1 ft section is under a metre: rejected, not written as 0 m.
    def change(r):
        r["units"] = "ft"
        r["sections"][0]["len"], r["sections"][1]["len"] = 49, 1  # 14.94 m and 15.24 m: both 15
        for p in r["points"]:
            p["at"] = {"approach": -20, "head": 0, "exit": 49, "landmark": 49, "danger": 25, "top": 50}[p["kind"]]
    rejects(tmp_path, capsys, fixture(change), "section 2 'Ridge': len is under a metre (1 ft)")


def test_thin_keeps_a_narrow_hairpin():
    # Codex on PR #166: fixes a metre apart, 100 m out, 5 m across, 100 m back. Both legs are kept
    # (sustained travel is never a reversal to drop), the length within a few per cent of 205 m.
    my, mx = route.flat(46.0)
    pts = ([(46.0 + i / my, 8.0) for i in range(101)] + [(46.0 + 100 / my, 8.0 + j / mx) for j in range(1, 5)]
           + [(46.0 + (100 - i) / my, 8.0 + 5 / mx) for i in range(101)])
    t = route.thin(pts)
    # The spacing cuts the turn's corner by up to TRACK_SPACING: 192 m, 6 % short, and no more.
    assert 190 < sum(route.haversine(*a, *b) for a, b in zip(t, t[1:])) < 215
    assert max(p[0] for p in t) > 46.0 + 90 / my  # the far end is still there


def hairpin_to_head(tmp_path, approach_len):
    """Codex on PR #166: an approach 100 m out, 5 m across and 100 m back, fixes a metre apart, to a
    head 5 m from its start; built with the approach approach_len long."""
    my, mx = route.flat(46.0)
    pts = ([(46.0 + i / my, 8.0) for i in range(101)] + [(46.0 + 100 / my, 8.0 + j / mx) for j in range(1, 5)]
           + [(46.0 + (100 - i) / my, 8.0 + 5 / mx) for i in range(101)])
    head = pts[-1]

    def change(r):
        r["approach"][0]["len"] = approach_len
        point(r, "approach").update(at=-approach_len, lat=46.0, lon=8.0)
        point(r, "head").update(lat=round(head[0], 7), lon=round(head[1], 7))
    return build(tmp_path, fixture(change), gpx=gpx(pts))


def test_track_takes_the_heads_pass_by_progress(tmp_path):
    # The recording passes within 25 m of the head at its start, then reaches it 205 m on. The pass
    # whose distance along the recording is nearest the approach's 205 m is the head's.
    code, out = hairpin_to_head(tmp_path, 205)
    assert code == 0
    t = out["track"]
    assert 190 < sum(route.haversine(*a, *b) for a, b in zip(t, t[1:])) < 215


def test_no_track_when_no_pass_matches_the_length(tmp_path, capsys):
    # The approach said to be 2000 m: neither pass, about 0 m and 205 m along, is within half to
    # twice that, so no track, with a warning.
    code, out = hairpin_to_head(tmp_path, 2000)
    assert code == 0
    assert "track" not in out
    err = capsys.readouterr().err
    assert "no approach track: the track reaches head 'Head' 0 and 205 m along it, the approach is 2000 m" in err
