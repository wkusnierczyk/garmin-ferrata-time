# Ferrata. Widgets

Status: settled with the owner on 2026-11-20 (#16)  
Reference mock: `design/demo/page-1.html`

The watch app's pages are built from widgets: drawing parts that a page places and sizes, meant for reuse across pages. Coordinates are in the design's 416 px screen. Each widget takes the climber's state (the guidebook minute reached, and from it the distance along the route, the height climbed and which section the climber is in) and its own options.

Shared colours:

| Use | Colour |
|---|---|
| Climber | orange `#ff6f3c`, the launcher icon's |
| Rest | blue `#3a86ff` |
| Exit, start | green `#3fd77f` |
| Danger, top | red `#ff4b4b` |
| Passed or climbed | the colour at a third of its brightness |

## profile

The route seen from the side, from its start at the lower left to its top at the upper right.

- The sections in their difficulty colours, drawn as thick lines with round ends. Climbed parts are dimmed.
- No inclination degrees, no text, no exit lines, no marks beneath the route.
- Points on the route as hollow rings, black inside so the route breaks there, dimmed once the climber has passed them:
  - rests: blue, at the middle of the rest stretch;
  - exits: green, where the exit leaves;
  - dangers: red, where the route has them.
- The climber: an orange outline around the stretch of route they could be on, from the position's uncertainty (25 m up or down). It is short on steep ground and long on flat ground. Drawn as a wide orange line with a narrower black one inside it, under the sections.
- The top: a hollow white ring.

Options: the difficulty colour map; danger points shown or not.

## ascent

The route's height as a vertical line, with the climber on it.

- A thin grey line from the start (bottom) to the top.
- The start and the top as a green and a red dot at the line's ends. On by default; an option turns them off.
- The climber's height as an orange ring on the line, sized so that at either end it rings the end's dot.
- Stacking, back to front: the line; the ring's black inside, hiding the line; the end dots; the ring's orange outline.
- Two numbers left of the line, right-aligned a small space before the ring:
  - below the ring, the metres climbed; above it, the metres left;
  - each centred on its stretch of the line, but kept clear of the ring as it nears either end;
  - and never past the line's end: once a number is level with the end it stays there.

Options: the end dots on or off.

## difficulty

What the climber is on, and what the uncertainty reaches.

- Three slots sharing a bottom edge: a larger middle box, and two smaller satellites (0.72 of its size) a narrow gap (5 px) from its edges. The middle box stays put; the satellites follow its width.
- Middle: the section the climber is estimated to be in.
- Satellites: when the uncertainty stretch reaches past that section, the nearest thing behind goes left and the nearest ahead goes right. A thing is the neighbouring section, or an exit or danger point inside the stretch; a point wins a tie with a section boundary. Empty slots stay empty.
- Grades `W` (walk) and `K1` to `K5`: filled boxes in the profile's colour map, black letters.
- Rest `R`, exit `E`, danger `D`: outlined boxes in their colours, letters in the same colour.
- The letters are centred in the box both ways, on the capitals' height.

Options: the profile's colour map and danger setting, so the two always agree; and which kinds of point it shows, each of rests, exits and dangers on or off (all off by default: the poi word in the altitude group names them; the prototype shows none). With rests off, a rest stretch shows as `W`.

## altitude

The approximate altitude above sea level.

- A number and its unit, white and grey; no fill or outline.
- Rounded to 10 m, or 50 ft, since the position is known only to within 25 m. Metres or feet; proposed: following the watch's elevation setting.
- The number is right-aligned in a box as wide as the widest altitude this route can show, measured once per route and unit, so it does not shift as the digits change. The unit follows the box.

## poi

The point of interest the uncertainty stretch covers, as one word.

- `REST`, `EXIT` or `DANGER`, in the rest blue, the exit green or the danger red; bold capitals, no box.
- Shown only while such a point lies within the stretch; nothing otherwise.
- With several, the nearest to the climber's estimate wins; on a tie, danger before exit before rest.

Options: dangers follow the profile's danger setting.

## difficulty column

The difficulty widget turned upright: the sections around the climber.

- Five slots in a column, centred vertically: the current section in the middle, the two before it below, the two after it above. Missing slots, near the start or the top, stay empty; the current box does not move.
- All boxes the same size (64 by 40 px), whatever their letters. The current one is 8 % larger, letters included, and filled in its colour with black letters.
- The others are outlined, letters in the outline's colour: before the climber at 55 % of their colour, after it at full colour.
- Letters `W` and `K1` to `K5`. A rest shows as `W`; the mock can show it as `R`.

Options: the colour map.

## difficulty stack

The difficulty column to scale: the sections as boxes in a window that moves with the climber. Two variants:

- **ascent stack:** each box as tall as the metres its section climbs (2.5 px per metre on page 4). A flat section has no height: it is a line across the column at its altitude, in its own colour.
- **path stack:** each box as tall as its section's length along the route (1 px per metre on page 5). Flat sections are boxes; walls are short.

In the app, ascent or path is a setting.

- The climber stays a quarter of the way up from the window's bottom, marked by a white line across the column with the climber's orange ring on the column's right edge, clear of the letters.
- The boxes meet with no gap. The current one is filled, letters black and larger; the others are black with their sides in their colour, letters in it; those behind the climber at 55 % of their colour.
- A border between two boxes takes the colour of the one closer to the current section, the current one's own next to it. The route's start and top close the column in the end box's colour.
- Letters are centred on the part of a box in view, left out when it is too short for them.
- Altitude ticks on the left, every 10 m (or 50 ft), only along the route, labelled right-aligned. In the path stack a tick sits where the route first reaches its altitude, so ticks crowd on walls and spread on walks; a label that would touch the one below is left out.
- Section names on the right, centred on the part in view, greyed behind the climber, cut with an ellipsis to fit the round screen.

Options: ascent or path; the scale; the tick step; names on or off; the colour map. Open: the tick resolution, the scales, and flat sections in the ascent stack (lines, or a minimum height).

## Groups

Widgets that are placed together, as one reusable unit.

### difficulty column group

- The **difficulty column**, with the altitudes where the difficulty changes to its right.
- Each altitude is level with a border between two boxes, and is the altitude where the route passes from the lower box's section to the upper one's; optionally also at the column's outer edges.
- Rounded like the altitude widget (10 m or 50 ft), right-aligned in a box as wide as the widest the route can show, 10 px right of the column, the unit after each.
- Column and altitudes are centred on the screen as one group.

Options: the altitudes at the outer edges; metres or feet.

### altitude group

- **altitude**, with **poi** under it.
- The poi word is right-aligned with the altitude number, not its unit, a small space below the digits.
- Placed by where the altitude's box starts and the top of its digits.

## Open

- The difficulty colour map for the earlier pages. Pages 1 and 2 use heat with amber and no purple (owner, 2026-11-21). No via ferrata scale (Hüsler K1 to K6, Schall A to E, French F to ED) defines colours. Candidates in the mock: the prototype's heat map (grey, light blue, yellow, orange, red, purple); heat with amber and no purple (grey, light blue, yellow, amber, orange, red); ski piste; viridis; one orange hue. A map must read on black, stay distinct when dimmed, and not clash with the climber's orange, the exits' green and the dangers' red.
- Where danger points come from in route data (`design/route-data.md`).
