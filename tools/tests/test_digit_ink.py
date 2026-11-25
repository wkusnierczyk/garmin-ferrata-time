"""Tests for tools/digit-ink.py: source/DigitInk.mc is what it makes from the committed TTF, and the
corners it keeps are never right of the glyphs' ink (#109)."""
import importlib.util
from pathlib import Path

import pytest

# Without fontTools these tests are skipped, and the others still run (CI installs it).
pytest.importorskip("fontTools")

REPO = Path(__file__).resolve().parents[2]
TTF = REPO / "resources" / "fonts" / "BarlowSemiCondensedTabular-SemiBold.ttf"
# The TTF is an LFS object: CI's routes job checks out without LFS, leaving a pointer file in its
# place, so it skips these; the build and unit-test jobs, and a local clone, have the font.
if TTF.read_bytes()[:24] == b"version https://git-lfs.":
    pytest.skip("the TTF is an LFS pointer here (checked out without LFS)", allow_module_level=True)
_spec = importlib.util.spec_from_file_location("digit_ink", REPO / "tools" / "digit-ink.py")
digit_ink = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(digit_ink)


def test_committed_module_is_the_tools():
    want = digit_ink.module(TTF.name, digit_ink.chains(str(TTF)))
    assert (REPO / "source" / "DigitInk.mc").read_text(encoding="utf-8") == want


def test_chain_is_left_of_every_outline_point():
    # At each outline point's height, the kept chain (a polyline from top to bottom) is at or left of it.
    from fontTools.ttLib import TTFont
    font = TTFont(str(TTF))
    glyphs, cmap = font.getGlyphSet(), font.getBestCmap()
    for c, chain in zip(digit_ink.CHARS, digit_ink.chains(str(TTF))):
        pen = digit_ink.Points(glyphs)
        glyphs[cmap[ord(c)]].draw(pen)
        for x, y in pen.points:
            # The chain's leftmost x within half a unit of y: the corners' y are rounded to the unit.
            xs = []
            for (x0, y0), (x1, y1) in zip(chain, chain[1:]):
                lo, hi = max(min(y0, y1), y - 0.5), min(max(y0, y1), y + 0.5)
                if lo > hi:
                    continue
                for yy in (lo, hi):
                    xs.append(x0 if y1 == y0 else x0 + (yy - y0) / (y1 - y0) * (x1 - x0))
            assert xs and min(xs) <= x, (c, x, y)
