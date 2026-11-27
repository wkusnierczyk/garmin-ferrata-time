# Ferrata. Pages 16 to 19: progress, done of total

Status: ported from the demo the owner checked on the epix and the fēnix 7X (2026-11-27, #67)  
Reference mock: `design/demo/page-16.html` (the pages mock, https://claude.ai/artifact/25DgbSs6bbNuALdcyw3X5A; page 16 was 10, 10c, 10d and 10e before #112)  
Code: `source/Numbers.mc` (the number pages, 16 to 37, as they are ported), the symbols `source/Symbols.mc`

The climb in numbers: how far, how high and how long, each as done of the total.

## Values

Each from the climber's state (`Climb.State`, which the tracker builds), as pages 1 to 15 read it:

- **Distance**: metres along the path, each section's length and height combined (as the profile's path), done of the route's, to the metre.
- **Ascent**: metres gained (the sum of the positive `up`, as Garmin counts ascent) of the route's total, to the metre.
- **Time**: the time passed since the part started, pauses included, of the estimate: the time passed and what is left of the guidebook's minutes at the climber's pace so far, as `h:mm`.

The units are metres, as in the mock; the watch's feet setting is not followed yet (an open question on #67).

## Page 16: three rows

- One row each for the distance, the ascent and the time: `{done} {symbol} {total} m`, the symbol in place of "of": the path (blue), stairs with an arrow (orange), a stopwatch (green), the flow's symbols (`Symbols.row`).
- The values done white, right-aligned before the symbol; the totals light grey (`#c8d0d0`), left-aligned after it; the unit grey (SemiBold 0.0769), 0.0096 of the width after the total; the time has none. The rows align on the symbols.
- The values in SemiBold 0.1538 (64 px at 416) or 0.125 (52), the larger at which the widest rows fit with 6 % of the width clear of the edge, both sides as wide as the widest total. Chosen once per route, so nothing moves through the climb; again only should the time's estimate gain a digit (ten hours).
- The symbols 0.87 of the size across, 0.0288 of the width from the numbers either side, their centres 0.36 of the size above the baseline; the rows 1.4 of the size apart, the three centred on the screen by their digits (which stand 0.71 of the size).

## Pages 17, 18 and 19: one row, large

- The distance (page 17), the ascent (page 18) or the time (page 19) alone: `{symbol} {done}` over `of {total}`, both right-aligned at one edge, the unit after each.
- The value done in SemiBold 0.25 (104 px at 416), white; "of " in SemiBold 0.0962, grey, then the total in SemiBold 0.2019 (84), light grey; the unit SemiBold 0.0769, grey, 0.012 of the width after the numbers.
- The symbol 0.7 of the large size (0.175 of the width), 0.0385 before the value done, its centre half the digits' height above the first baseline.
- The right edge is set by the widest the value done can get, the total at the large size, so it stays put as the value grows; only the symbol moves with the value's width. The group is centred on the screen across, and the two lines, 0.0577 apart, by their digits' height.

## Fit

Every size is a share of the screen's width, so the pages scale to every resolution the app builds for (280 to 466 px); the tests (`source/tests/NumbersTest.mc`) check on the demo and the Daubenhorn that page 16 keeps its size through the climb and its rows on the screen (6 % clear at 64), and that pages 17 to 19 keep their right edge and lines in place at every place and stay on the screen.

## On the approach

As pages 1 to 15 for now: they show the part in use, the approach. The ferrata not started (0 of each total, no head on pages 16 and later, design/real-functionality.md, *On the approach*) comes with #90.
