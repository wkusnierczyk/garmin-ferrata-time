"""Every fill outside Draw.mc takes its colour from Draw.ink (#137).

The SDK's docs say setFill wins over setColor, so a function that fills straight on the Dc after a
plain dc.setColor fills in whatever ink last left (black after frontBrush), not in its colour; only the
simulator resets the fill on setColor, so a test run there cannot see it. A source check instead: no
function outside Draw.mc both calls a Dc fill and sets the colour with dc.setColor.
"""
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SOURCES = sorted(p for p in (REPO / "source").rglob("*.mc") if p.name != "Draw.mc")

FILL = re.compile(r"\bdc\.fill\w*\(")
SET_COLOR = re.compile(r"\bdc\.setColor\(")


def functions(text):
    """Each function's name and body, split at the `function` keyword."""
    parts = re.split(r"^\s*(?:(?:static|hidden|public|private)\s+)*function\s+(\w+)", text, flags=re.M)
    return list(zip(parts[1::2], parts[2::2]))


def offenders(text):
    return [name for name, body in functions(text) if FILL.search(body) and SET_COLOR.search(body)]


def test_fills_outside_draw_take_their_colour_from_ink():
    found = [f"{p.relative_to(REPO)}: {name}" for p in SOURCES for name in offenders(p.read_text())]
    assert found == []


def test_the_check_finds_a_fill_after_set_color():
    text = (
        "function stretch(d as Draw, c as Number) as Void {\n"
        "    var dc = d.dc;\n"
        "    dc.setColor(c, Graphics.COLOR_TRANSPARENT);\n"
        "    dc.fillCircle(1, 2, 3);\n"
        "}\n"
        "function inked(d as Draw, c as Number) as Void {\n"
        "    d.ink(c);\n"
        "    d.dc.fillCircle(1, 2, 3);\n"
        "}\n"
        "function stroke(d as Draw) as Void {\n"
        "    d.dc.setColor(SCALE, Graphics.COLOR_TRANSPARENT);\n"
        "    d.dc.drawArc(1, 2, 3, Graphics.ARC_CLOCKWISE, 0, 90);\n"
        "}\n"
    )
    assert offenders(text) == ["stretch"]
