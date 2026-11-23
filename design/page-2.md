# Ferrata. Pages 2 and 2a

Status: settled with the owner on 2026-11-21 (#17)  
Revised: on the watch as the revised mocks draw them (the Daubenhorn grid, owner 2026-11-22; ported in #95, 2026-11-23).  
Reference mock: `design/demo/page-2.html` (a live dial with a slider and playback, and the options as settings)  
Widgets: `design/widgets.md`

The difficulty widget turned upright, as a variant of the ascent widget: the sections around the climber, and the altitudes where the difficulty changes. The app's third page, after pages 1 and 1a; page 2a, the fourth, is the same page with relative altitudes.

## Layout

- The **difficulty column group**, centred on the screen: the current section second from the bottom, one section before it below and three after it above (owner, 2026-11-23: it was in the middle, two and two); the current box 35 % larger than the others, its letters Bold 0.0865 of the screen (owner, 2026-11-23: it was 8 %).
- The altitudes from the current section's bottom up to the column's top edge (owner, 2026-11-23: the bottom of the section before it is no longer shown).
- Difficulty colours: heat with amber, no purple (grey, light blue, yellow, amber, orange, red); the half steps' letters (`C/D`) and colours.

## Page 2a: relative altitudes

- As page 2, but each altitude is its height above the **bottom of the current section**: `0` there, a plus sign above it, a minus sign (a hyphen) below it, where the route descends: "+137", "0", "-20".
- The route's own heights, not the climber's estimate, so finer than the altitude widget: to the metre, or to 5 ft.
- Right-aligned in a box as wide as the widest difference the column can show on the route (worked out once per route), the unit after each.

## Open

- A rest is flat, so the altitudes at its two borders are equal (in the demo, 1380 above 1380 at the Ledge). Merge the rest into its neighbour, skip one altitude, or keep both.
