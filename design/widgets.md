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

Options: the profile's colour map and danger setting, so the two always agree; and which kinds of point it shows, each of rests, exits and dangers on or off (all on in the mock; to be settled). With rests off, a rest stretch shows as `W`.

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

## Open

- The difficulty colour map. No via ferrata scale (Hüsler K1 to K6, Schall A to E, French F to ED) defines colours. Candidates in the mock: the prototype's heat map (grey, light blue, yellow, orange, red, purple); heat with amber and no purple (grey, light blue, yellow, amber, orange, red); ski piste; viridis; one orange hue. A map must read on black, stay distinct when dimmed, and not clash with the climber's orange, the exits' green and the dangers' red.
- Where danger points come from in route data (`design/route-data.md`).
