#!/usr/bin/env python3
"""Make a Barlow Condensed weight draw tabular figures by default (#62).

    python3 tools/tabular-figures.py <BarlowCondensed-Weight.ttf> <BarlowCondensedTabular-Weight.ttf>

The pages draw numbers that change every second; with Barlow's default, proportional figures they
shift as they count (a 1 is 0.27 em, a 4 up to 0.48). The mocks set `font-variant-numeric:
tabular-nums`, which picks the font's own tabular figures (`zero.tf` ... `nine.tf`, the `tnum`
feature). A bitmap font has no features, and ttf2bmp renders what the character map points at, so
this points 0 to 9 at the tabular glyphs and renames the family "Barlow Condensed Tabular" (a
modified version, as the SIL OFL asks of one; Barlow declares no Reserved Font Name). Nothing else
changes. The timestamp is kept, so the same input gives the same bytes.

Needs fontTools (`pip install fonttools`). `make font-sources` runs it on the weights it fetches.
"""
import sys

from fontTools.ttLib import TTFont

FAMILY, TABULAR = "Barlow Condensed", "Barlow Condensed Tabular"
DIGITS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]


def main(src, dst):
    font = TTFont(src, recalcTimestamp=False)
    order = set(font.getGlyphOrder())
    missing = [g + ".tf" for g in DIGITS if g + ".tf" not in order]
    if missing:
        sys.exit(f"{src}: no tabular figures ({', '.join(missing)})")
    for table in font["cmap"].tables:
        if table.isUnicode():
            for i, name in enumerate(DIGITS):
                if 0x30 + i in table.cmap:
                    table.cmap[0x30 + i] = name + ".tf"
    widths = {font["hmtx"][g + ".tf"][0] for g in DIGITS}
    if len(widths) != 1:
        sys.exit(f"{src}: the tabular figures have {len(widths)} advances, not one")
    # Family (1), full name (4), PostScript name (6), typographic family (16), and the unique id (3).
    for rec in font["name"].names:
        if rec.nameID in (1, 3, 4, 16):
            rec.string = rec.toUnicode().replace(FAMILY, TABULAR)
        elif rec.nameID == 6:
            rec.string = rec.toUnicode().replace("BarlowCondensed", "BarlowCondensedTabular")
    font.save(dst, reorderTables=False)
    print(f"{dst}: 0-9 drawn by the tabular figures, {widths.pop()} units each")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__.strip().splitlines()[2].strip())
    main(sys.argv[1], sys.argv[2])
