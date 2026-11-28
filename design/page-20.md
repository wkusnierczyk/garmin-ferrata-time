# Ferrata. Page 20: time per grade

Status: ported from the mock and the demo's scratch port (2026-11-28, #68); the owner's check on the watch to come  
Reference mock: `design/demo/page-20.html` (the pages mock; page 20 was 11 before #112)  
Code: `source/Numbers.mc` (`timePerGrade`), its menu `source/FlowMenus.mc` (`openPageMenu`)

The time spent in each grade so far, after pages 16 to 19 (`design/page-16.md`), the cycle's last page.

## Values

- **One row per grade the part has**: the route's half steps (W, A, A/B ... F/G), hardest at the top, a walk (W) the last. A rest is no row (the mock: owner, 2026-11-22). A grade the part does not have gets no row.
- **The time in a grade**: the guidebook's minutes of its sections done, and of the current section up to the place, at the climber's pace (the tracker's, as the time left on the other pages), as `h:mm`. A rest's time counts in no grade.
- The grades are named and coloured as on pages 1 to 15 (`Widgets.BOX_NAME`, `Palette`); the K scale comes with #58.

## Layout

- Each row `{time} in {grade}`, aligned on "in": the time white, right-aligned before it; "in" grey (`#99aaaa`), SemiBold 0.0769 (32 px at 416), 0.024 of the width from the columns either side; the grade Bold in its colour, left-aligned after it.
- The current grade at full brightness, the others at 0.85, a grade still at 0:00 (and not the current one) at 0.4.
- The times in SemiBold, at the largest size from 0.1538 (64 px) down the size table (58, 52, 46, 44, 40, 36, 32: the mock's steps) at which a row for every grade of the part keeps 6 % of the width clear of the edge, each row's own box measured (from the widest time to the widest grade name, from the digits' top to the baseline), so the middle rows use the round screen's extra width; 32 if none does. The grades Bold at the largest size not above it (52 px at most).
- The rows 1.05 of the size apart, centred on the screen as a block, the "in" column off the middle by half the difference of the two columns' widths.
- The left column is as wide as the widest time (`0:00`, or `00:00` past ten hours in one grade) and as page 21's widest ascent in metres and in feet (as many digits as the most the part climbs in one grade, with its unit): pages 20 and 21 share one size (the mock). The digits are tabular.
- Chosen once per part (again only when a grade passes ten hours), from every grade of the part, shown or not, so nothing moves through the climb.

## The menu

Holding Up on page 20 opens its menu, drawn as the climb flow's: the title ROWS at 0:00, the rows Show and Hide, on the one in use. Start on a row sets it and closes the menu; Back closes it as it was. The climb goes on behind it. The choice is kept in the watch's storage across launches; Show is the default.

- **Show**: every grade of the part, those still at 0:00 dimmed.
- **Hide**: only the grades with time and the current one, centred again as a block, so the page grows as the climb goes on; the size and the columns stay as with every row.

## Fit

Every size is a share of the screen's width, so the page scales to every resolution the app builds for (280 to 466 px). The tests (`source/tests/GradesTest.mc`) check, on the demo's ferrata and approach and on the Daubenhorn's and the Sulzfluh's ferratas and approaches, that at every place the layout is the one chosen at the start and every row keeps 6 % of the width clear of the edge, and that the page draws with every row and with the zeros hidden.

## On the approach

As pages 1 to 19 for now: it shows the part in use, the approach, a walk (W) alone. The ferrata not started (every grade at 0:00, none current; design/real-functionality.md, *On the approach*) comes with #90.
