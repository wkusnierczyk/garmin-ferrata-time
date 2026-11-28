"""Every fill outside Draw.mc takes its colour from Draw.ink (#137).

The SDK's docs say setFill wins over setColor, so a function that fills straight on the Dc without
ink fills in whatever ink last left (black after frontBrush), not in its colour; only the simulator
resets the fill on setColor, so a test run there cannot see it. A source check instead: every function
outside Draw.mc that calls a fill straight on a receiver (a Dc under any name) also calls ink.
"""
import re
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SOURCES = sorted(p for p in (REPO / "source").rglob("*.mc") if p.name != "Draw.mc")

# A fill on a receiver: the identifier before the dot, whitespace and line breaks allowed. A receiver
# with a capital is a module or class (Symbols.fill), not a Dc.
FILL = re.compile(r"(\w*)\s*\.\s*fill\w*\s*\(")
INK = re.compile(r"\bink\s*\(")
FUNCTION = re.compile(
    r"^\s*(?:\(:\w+\)\s*)*(?:(?:static|hidden|public|private|protected)\s+)*function\s+(\w+)", re.M)


def functions(text):
    """Each function's name and body, comments gone, split at the `function` keyword and what may come
    before it (annotations such as (:debug), access and static)."""
    parts = FUNCTION.split(re.sub(r"//[^\n]*", "", text))
    return list(zip(parts[1::2], parts[2::2]))


def fills(body):
    return any(not m.group(1)[:1].isupper() for m in FILL.finditer(body))


def offenders(text):
    return [name for name, body in functions(text) if fills(body) and not INK.search(body)]


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


CASES = [
    ("no colour call: the fill inherits what ink left", """
    function joints(d as Draw) as Void {
        d.dc.fillCircle(1, 2, 3);
    }"""),
    ("a helper filling after its caller's setColor", """
    function caller(d as Draw, c as Number) as Void {
        d.dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        helper(d.dc);
    }
    function helper(g as Graphics.Dc) as Void {
        g.fillRectangle(0, 0, 4, 4);
    }"""),
    ("a Dc under another name", """
    function other(screen as Graphics.Dc, c as Number) as Void {
        screen.setColor(c, Graphics.COLOR_TRANSPARENT);
        screen.fillPolygon([[0, 0], [1, 1], [0, 1]]);
    }"""),
    ("whitespace before the dot and the bracket, the call split", """
    function spaced(d as Draw) as Void {
        d.dc
            .fillCircle (1, 2, 3);
    }"""),
]


@pytest.mark.parametrize("name, text", CASES, ids=[c[0] for c in CASES])
def test_the_check_finds_a_fill_without_ink(name, text):
    assert offenders(text) != [], name


@pytest.mark.parametrize("prefix", ["protected ", "(:debug) ", "(:debug)\n    hidden "])
def test_the_splitter_keeps_each_function_apart(prefix):
    text = (
        "function inked(d as Draw, c as Number) as Void {\n"
        "    d.ink(c);\n"
        "    d.dc.fillCircle(1, 2, 3);\n"
        "}\n"
        f"{prefix}function bare(d as Draw) as Void {{\n"
        "    d.dc.fillCircle(1, 2, 3);\n"
        "}\n"
    )
    assert offenders(text) == ["bare"]


def test_comments_neither_fill_nor_ink():
    text = (
        "// dc.fillCircle in a comment above\n"
        "function commented(d as Draw) as Void {\n"
        "    d.dc.drawLine(0, 0, 1, 1); // then dc.fillCircle(1, 2, 3)\n"
        "}\n"
        "function inkInComment(d as Draw) as Void {\n"
        "    // d.ink(c) would go here\n"
        "    d.dc.fillCircle(1, 2, 3);\n"
        "}\n"
    )
    assert offenders(text) == ["inkInComment"]


def test_a_module_function_called_fill_is_not_a_dc_fill():
    text = (
        "function symbol(d as Draw, c as Number) as Void {\n"
        "    Symbols.fill(d, 0.5, 0.5, 1.0, PTS, c);\n"
        "}\n"
    )
    assert offenders(text) == []
