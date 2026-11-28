# Ferrata. Pages 5 and 6

Status: settled with the owner on 2026-11-21 (#17)  
Revised: on the watch as the revised mocks draw them (the Daubenhorn grid, owner 2026-11-22; ported in #95, 2026-11-23).  
Reference mock: `design/demo/page-5.html` (a live dial with a slider and playback, and the options as settings)  
Widgets: `design/widgets.md`

The difficulty widget turned upright, as a variant of the ascent widget: the sections around the climber, and the altitudes where the difficulty changes. The app's fifth page, after pages 1 to 4; page 6, the sixth, is the same page with relative altitudes.

## Layout

- The **difficulty column group**, centred on the screen: the current section second from the bottom, one section before it below and three after it above (owner, 2026-11-23: it was in the middle, two and two); the current box 35 % larger than the others, its letters Bold 0.0865 of the screen (owner, 2026-11-23: it was 8 %). Every box of a section that loses height, filled or outlined, is a trapezium narrower at its foot (#100).
- The altitudes from the current section's bottom up to the column's top edge (owner, 2026-11-23: the bottom of the section before it is no longer shown).
- **On the ferrata, as large as fits** (owner, 2026-11-28, #160): nothing stands beside the column, so the whole group, boxes, gaps and altitudes, is drawn larger about the screen's centre until its farthest corner is 4 % of the screen's width from the bezel (within 0.46 of the width from the centre). The corners are those of the group's widest extent: the route's widest altitude (page 6: the widest difference) and its unit beside the larger box, and the top altitude's capitals above the column. So the size is worked out once per route and unit and holds still along the climb. On the approach the pages keep page 7's size: the HEAD line needs the room.
- The watch's fonts do not scale: the altitudes and their unit take the nearest SemiBold in the size table, and the factor is the largest at which those, measured, fit (a step to the next font that would not fit is not taken; a pixel is kept for drawing in whole pixels). The box letters take the nearest Bold; the table has none between 36 and 52 px at 416, so the current box's letters stay Bold 36 while the box grows.
- Difficulty colours: heat with amber, no purple (grey, light blue, yellow, amber, orange, red); the half steps' letters (`C/D`) and colours.

## Page 6: relative altitudes

- As page 5, but each altitude is its height above the **bottom of the current section**: `0` there, a plus sign above it, a minus sign (a hyphen) below it, where the route descends: "+137", "0", "-20".
- The route's own heights, not the climber's estimate, so finer than the altitude widget: to the metre, or to 5 ft.
- Right-aligned in a box as wide as the widest difference the column can show on the route (worked out once per route), the unit after each.

## Open

- A rest is flat, so the altitudes at its two borders are equal (in the demo, 1380 above 1380 at the Ledge). Merge the rest into its neighbour, skip one altitude, or keep both.
