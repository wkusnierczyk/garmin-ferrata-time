"""Tests for tools/route.py: the demo route builds, and each validation rule rejects its case."""
import copy
import json
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
        {"kind": "approach", "at": -20, "alt": 990, "name": "Car park"},
        {"kind": "head", "at": 0, "alt": 1000, "name": "Head"},
        {"kind": "exit", "at": 50, "name": "Exit"},
        {"kind": "landmark", "at": 50, "alt": 1040, "name": "Bench"},
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
    assert list(r) == ["format", "id", "name", "short", "place", "source", "approach", "sections", "points"]
    assert r["format"] == 1
    for s in r["approach"] + r["sections"]:
        assert list(s) == ["len", "up", "grade", "min", "name", "side"]
    for p in r["points"]:
        assert set(p) <= {"kind", "at", "alt", "lat", "lon", "name"}
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
    ("Via dell’Amicizia – Nord", "Via dell'Amicizia - Nord"),
    ("Plain (A-Z), 0-9 / ok.", "Plain (A-Z), 0-9 / ok."),
    ("Kept: + > ~ ° · …", "Kept: + > ~ ° · …"),
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


def test_unknown_kind_not_folded(tmp_path):
    odd = {"kind": "spring", "at": 10, "name": "Quelle Größe"}
    code, out = build(tmp_path, fixture(lambda r: r["points"].append(dict(odd))))
    assert code == 0
    assert odd in out["points"]


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
