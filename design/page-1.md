# Ferrata. Page 1, version 1

Status: settled with the owner on 2026-11-20 (#16)  
Reference mock: `design/demo/page-1.html` (a live dial with a slider and playback, and the options as settings)  
Widgets: `design/widgets.md`

The prototype's side-profile page (page A) stays as it is. Page 1, version 1 is a simpler page beside it, and the app's first page: the profile alone, with the numbers moved into widgets around it.

## Layout

- Difficulty colours: heat with amber, no purple (grey, light blue, yellow, amber, orange, red).
- **profile** and **ascent** share the start point: the ascent line rises from the profile's first point, and its top is level with the profile's end. Together they span a rectangle, in the mock from (92, 92) to (352, 318).
- Descents (#56): the profile draws the route's real height, so a section that loses height goes down, and it spans the rectangle from the route's lowest point to its highest; the ascent counts height gained, as Garmin does, and still spans the rectangle from the start to the top. On a route that dips below its start, or climbs above its end before coming down to it, the profile's first point or its end is then no longer level with the ascent line's ends. The altitude group shows the real altitude.
- **difficulty**, without points (rests, exits, dangers), in the rectangle's lower right: its bottom on the rectangle's bottom, its widest possible extent (two-character boxes in all three slots) ending at the rectangle's right edge, so the middle box does not move.
- The **altitude group** (altitude, with poi under it) in the rectangle's upper left: the top of the altitude's digits level with the rectangle's top, its box starting a small space right of the ascent line's ring.

## Removed from page A

- The clock, the altitude line, the climbed and time-to-top figures, and the distance along.
- The inclination degrees on steep sections.
- The dashed exit lines with arrow marks, and the rest marks beneath the route.
- The white dot and the grey band for the climber, replaced by the orange outline.
