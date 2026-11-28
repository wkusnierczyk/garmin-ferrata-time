# Ferrata. Pages 16 to 19: progress, done of total

Status: ported from the demo the owner checked on the epix and the fēnix 7X (2026-11-27, #67)  
Reference mock: `design/demo/page-16.html` (the pages mock, https://claude.ai/artifact/25DgbSs6bbNuALdcyw3X5A; page 16 was 10, 10c, 10d and 10e before #112)  
Code: `source/Numbers.mc` (the number pages, 16 to 37, as they are ported), the symbols `source/Symbols.mc`

The climb in numbers: how far, how high and how long, each as done of the total.

## Values

Each from the climber's state (`Climb.State`, which the tracker builds), as pages 1 to 15 read it:

- **Distance**: along the path, each section's length and height combined (as the profile's path), done of the part's, to the metre or foot.
- **Ascent**: height gained (the sum of the positive `up`, as Garmin counts ascent) of the part's total, to the metre or foot; a part that gains nothing reads 0 of 0.
- **Time**: the active time, the approach and the ferrata with the pauses left out (the tracker's `activeS`, the time the summary shows), of the estimate: the active time and what is left of the guidebook's minutes at the climber's pace so far, as `h:mm`. The stopwatch always means active time (owner, 2026-11-27).

Distance and ascent are in the watch's elevation units, metres or feet (`Widgets.feet()`, as on pages 1 to 15; owner, 2026-11-27): the system settings decide, and the app never overrides them. The time is the same in either.

## Page 16: three rows

- One row each for the distance, the ascent and the time: `{done} {symbol} {total} m`, the symbol in place of "of": the path (blue), stairs with an arrow (orange), a stopwatch (green), the flow's symbols (`Symbols.row`).
- The values done white, right-aligned before the symbol; the totals light grey (`#c8d0d0`), left-aligned after it; the unit (`m` or `ft`) grey (SemiBold 0.0769), 0.0096 of the width after the total; the time has none. The rows align on the symbols.
- The values in SemiBold 0.125 (52 px at 416), as in the demo the owner checked and as the later pages' rows of figures (owner, 2026-11-28: 46 px was too small on the watch), keeping 4 % of the width clear of the edge, not the 6 % the other pages keep. Only where a row would come closer than that (a five-digit total, such as a 12 km approach's path) do the values step down the size table (`resources/fonts/sizes.json`: 46, 44, 40 ...) to the largest at which none does. Each row is measured on its own, in the font drawn, in metres and in feet: from its value done (as wide as its total at most) to its total and unit, from its digits' top to its baseline, and its symbol's box. Chosen once per part, so nothing moves through the climb; again only when the time's estimate crosses ten hours (`h:mm` a digit wider), which is checked each frame from two numbers, not by formatting the row.
- The symbols 0.87 of the size across, 0.0288 of the width from the numbers either side, their centres 0.36 of the size above the baseline; the rows 1.4 of the size apart, the three centred on the screen by their digits (which stand 0.71 of the size).

## Pages 17, 18 and 19: one row, large

- The distance (page 17), the ascent (page 18) or the time (page 19) alone: `{symbol} {done}` over `of {total}`, both right-aligned at one edge, the unit after each.
- The value done in SemiBold 0.25 (104 px at 416), white; "of " in SemiBold 0.0962, grey, then the total in SemiBold 0.2019 (84), light grey; the unit SemiBold 0.0769, grey, 0.012 of the width after the numbers.
- Where the group would come within 6 % of the width of the edge (a four-digit value on the 360 and 390 px screens, a five-digit one anywhere), the value steps down through the size table from 104 (84, 64, 58 ...) until it fits in metres and in feet, the total at the size nearest 84/104 of it and the gaps in proportion. Chosen once per part, as page 16's.
- The symbol 0.7 of the value's size (0.175 of the width at 104), 0.0385 before the value done (at 104), its centre half the digits' height above the first baseline.
- The right edge is set by the widest the value done can get, the total at the large size, so it stays put as the value grows; only the symbol moves with the value's width. The group is centred on the screen across, and the two lines, 0.0577 apart, by their digits' height.

## Fit

Every size is a share of the screen's width, so the pages scale to every resolution the app builds for (280 to 466 px). The tests (`source/tests/NumbersTest.mc`) check, in metres and in feet, on the demo's ferrata and approach, the Daubenhorn and a 12 km approach (a five-digit path), with an estimate past ten hours: that at every place page 16's rows keep 4 % of the width clear, at 52 with four-digit totals and a smaller size for the five-digit one, and pages 17 to 19 keep 6 % of the width clear of the edge, their size, their right edge and their lines.

## On the approach

As pages 1 to 15 for now: they show the part in use, the approach. The ferrata not started (0 of each total, no head on pages 16 and later, design/real-functionality.md, *On the approach*) comes with #90.
