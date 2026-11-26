# Ferrata. Widgets

Status: settled with the owner on 2026-11-20 (#16)  
Revised: as the revised mocks draw them (the Daubenhorn grid, owner 2026-11-22; on the watch from #95, 2026-11-23).  
Reference mock: `design/demo/page-1.html`

The watch app's pages are built from widgets: drawing parts that a page places and sizes, meant for reuse across pages. Sizes and positions are fractions of the screen's width (the screen is round, so of its height too), to four decimals here: the mocks' px ÷ 416. The code carries them to six, so that on the 416 px epix they land on the mocks' pixels. Each widget takes the climber's state (the guidebook minute reached, and from it the distance along the route, the height climbed and which section the climber is in) and its own options.

The options below are the mocks'. The app draws each page with the settings it was settled with, so it does not yet carry every option: page 1, for example, has one switch for the difficulty widget's points and always shows danger points.

Shared colours:

| Use | Colour |
|---|---|
| Climber | orange `#ff6f3c`, the launcher icon's |
| Rest | blue `#3a86ff` |
| Exit, start | green `#3fd77f` |
| Danger | yellow `#ffd60a`, a warning, on every page: rings, boxes, symbols and words (owner, 2026-11-23); red is the route's top only |
| Top | red `#ff4b4b` |
| Passed or climbed | the colour at a third of its brightness |

Difficulty colours: heat with amber, no purple, for walking and A to E (grey, light blue, yellow, amber, orange, red), F taking E's. The route's grades are half steps (1 A, 2 A/B ... 12 F/G), and the pages draw them as such (#95): each half step its letters (`C/D`) and its own colour, the rounded mean of its two neighbours' channel by channel, as the mocks' `halfSteps`. The K scale is a setting to come (#58).

## profile

The route seen from the side, from its start at the left to its end at the right.

- The route's real height, down as well as up (#56): a section that loses height goes down. The drawing spans the route's lowest point to its highest; without descents those are the start and the top.
- The sections in their difficulty colours, drawn as thick lines with round ends. Climbed parts are dimmed.
- No inclination degrees, no text, no exit lines, no marks beneath the route.
- Points on the route as hollow rings, black inside so the route breaks there, dimmed once the climber has passed them:
  - rests: blue, at the middle of the rest stretch;
  - exits: green, where the exit leaves;
  - dangers: yellow, where the route has them.
- The climber: an orange outline around the stretch of route they could be on, from the position's uncertainty (25 m up or down). It is short on steep ground and long on flat ground. Drawn as a wide orange line with a narrower black one inside it, under the sections.
- The top: a hollow white ring.

Options: the difficulty colour map; danger points shown or not.

## ascent

The route's height as a vertical line, with the climber on it.

- A thin grey line from the start (bottom) to the top.
- Sizes (owner, 2026-11-22: slightly larger): the ring 0.0264 of the screen in radius with a 0.0072 pen, the end dots 0.0180, the numbers SemiBold 0.0673.
- The start and the top as a green and a red dot at the line's ends. On by default; an option turns them off.
- The climber's height as an orange ring on the line, sized so that at either end it rings the end's dot. The line runs from the head to the top's real (net) height, and the ring is a position on it, the real height (#100; owner, 2026-11-23): on a descent it pulls back down. Where the route dips below the head, or climbs above its top before coming down to it, the ring stays at the line's end and the numbers say how far past it.
- Stacking, back to front: the line; the ring's black inside, hiding the line; the end dots; the ring's orange outline.
- Two numbers left of the line, right-aligned a small space before the ring:
  - below the ring, the real height above the head now; above it, the top's real height less that (#100: on a descent the lower number falls and the upper grows). Amounts climbed stay height gained: the stacks (parked), the gauge by ascent's arcs and the climbed totals;
  - each centred on its stretch of the line, but kept clear of the ring as it nears either end;
  - and never past the line's end: once a number is level with the end it stays there.

Options: the end dots on or off.

## difficulty

What the climber is on, and what the uncertainty reaches.

- Three slots sharing a top edge (owner, 2026-11-23: under the profile the round screen narrows below them): a larger middle box, and two smaller satellites (0.72 of its size) a narrow gap (0.0120 of the screen) from its edges, all at a size the page sets (page 1: 140 %). The middle box stays put; the satellites follow its width.
- Middle: the section the climber is estimated to be in.
- Satellites: when the uncertainty stretch reaches past that section, the nearest thing behind goes left and the nearest ahead goes right. A thing is the neighbouring section, or an exit or danger point inside the stretch; a point wins a tie with a section boundary. Empty slots stay empty.
- Grades `W` (walk) and `A` to `F/G` in half steps: filled boxes in the profile's colour map, black letters; a box as wide as its letters, 0.1106 of the screen for one, 0.1394 for more.
- A section that loses height has its box as a **trapezium**, narrower at its foot (#100; owner, 2026-11-23), so a descent is not taken for a climb: the rectangle's top, height, rounded corners and colour, its foot 0.8 of its top's width, the same black letters; an outlined box an outlined trapezium. The same on every page with grade boxes: the difficulty boxes (pages 1, 2), the difficulty column (5, 6, 7: every descending box in it, filled or outlined), the large box (12, 13, 15) and the current difficulty group's (3, 4, 14). The stacks (pages 8 to 11) show grades as letters with no box. Connect IQ has no rounded polygon: the app draws the trapezium inset by the corner radius, grown by it on every side, a circle on each corner.
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

- `REST`, `EXIT` or `DANGER`, in the rest blue, the exit green or the danger yellow; bold capitals letter-spaced 0.0024 of the screen, no box.
- Shown only while such a point lies within the stretch; nothing otherwise.
- With several, the nearest to the climber's estimate wins; on a tie, danger before exit before rest.

Options: dangers follow the profile's danger setting.

## difficulty column

The difficulty widget turned upright: the sections around the climber.

- Five slots in a column, centred vertically: the current section second from the bottom, the one before it below, the three after it above (owner, 2026-11-23; it was in the middle, two and two). Missing slots, near the start or the top, stay empty; the current box does not move.
- All boxes the same size (0.1538 by 0.0962 of the screen), whatever their letters. The current one is 35 % larger (owner, 2026-11-23; it was 8 %) and filled in its colour with black letters, Bold 0.0865.
- The others are outlined, letters in the outline's colour: before the climber at 55 % of their colour, after it at full colour.
- A section that loses height, filled or outlined, as a trapezium narrower at its foot (*difficulty*, #100).
- Letters `W` and `A` to `F/G`. A rest shows as `W`; the mock can show it as `R`.

Options: the colour map; a rest as `W` or as `R` (the mock's switch; the app shows `W`).

## difficulty stack

Parked with pages 8 to 11: too noisy as a design, not in the app (#110, #128); the code stays.

The sections to scale: boxes in a narrow column centred on the screen (0.1058 of its width), in a window that moves with the climber. Two variants:

- **ascent stack** (pages 8, 9): each box as tall as the metres its section climbs (0.0072 of the screen per metre). A flat section has no height: it is a line across the column at its altitude, in its own colour. So is a section that loses height: the stack counts height gained (#56).
- **path stack** (pages 10, 11): each box as tall as its section's length along the route (0.0024 of the screen per metre). Flat sections are boxes; walls are short.

The rest is common:

- The climber stays a quarter of the way up from the window's bottom, marked by the climber's orange ring on the column's left edge. No line crosses the column.
- The boxes meet with no gap. The current one is filled; the others are black with their sides in their colour; those behind the climber at 55 % of their colour.
- A border between two boxes takes the colour of the one closer to the current section, the current one's own next to it. The route's start and top close the column in the end box's colour.
- Every section's grade right of the column, at the middle of its box's part in view (a flat section's at its line), in its colour, Bold 0.0673 of the screen, the climber's section as large as the next altitude's label (0.1250); placed from the climber's section outwards and left out where they would touch letters already placed or leave the screen.
- Points of interest as symbols (0.0529 across) right of the letters at their place on the column, dimmed once passed: danger a yellow triangle, exit a green arrow pointing down to the right, rest a blue pause (the middle of the rest), the top a red square. Symbols that would touch show one: of those in the climber's range (from one tick step before the point to half a step after it, along the stack's axis), the first of danger, exit, rest, top, then the nearest; with none in range, the one nearest the climber.
- Altitude ticks on the left, at a step the page sets (page 8: 20 m or 100 ft; page 10: 10 m or 50 ft), only along the route. A tick sits where the route rises through its altitude (#56): in the path stack where it first reaches it, so ticks crowd on walls and spread on walks; on a descent none, and a climb after a descent marks again the altitudes it passes a second time. The labels are real altitudes.
- Three labels, right-aligned 0.0337 of the screen left of the column: the next altitude to reach (SemiBold 0.1250; the first tick above the climber on the stack: by path it may sit further along the route than the climber, and after a descent its altitude may be below the one now; near the top, past the last tick, the topmost), and the nearest tick above and below it that keep clear of it (0.0865). The other ticks are bare.
- Everything within a radius of the screen's centre the page sets: 6 % of the width clear of the edge, or inside the ascent gauge.

Open: the scales, and flat sections in the ascent stack (lines, or a minimum height).

## ascent gauge

The ascent widget bent around the screen's edge.

- A thin grey arc from the start at the lower left, over the top, to the route's top at the lower right (284°), leaving the bottom free.
- The climber's orange ring on it at the real height, a position as on the *ascent* line (#100): it pulls back on a descent; the start and top as green and red dots.
- In the gap at the bottom, the *ascent*'s two numbers: the real height above the head beside the start's dot and the top's less that beside the top's, facing inwards (0.0192 of the screen past the dots' edges), so the larger numbers stay on the screen.

Options: the end dots on or off.

## gauge

The route around the screen's edge, from its start at the lower left, over the top, to its top at the lower right (284°), leaving the bottom free.

- Each section gets at least 3° of the 284°, the others sharing the rest in proportion, so no section is too short to draw or see (by ascent, rests and short climbs would be under a degree; the watch draws arcs in whole degrees, and one under a degree came out as a full circle, #28). Within a section, positions follow the distance along it.
- Sections a hair apart, none after the last, so the gauge ends where the gap ascent's top dot is; climbed parts dimmed.
- Rests, exits and dangers as hollow rings on it, dimmed once passed.
- The climber as a thicker orange line (0.0144 of the screen wide, round ends) on the gauge's inner side, 0.0072 clear of the sections, over the stretch they could be on. (The first version's orange outline around that stretch covered the sections.)
- By length (page 12) or by ascent (page 13): each section's arc its length along the route, or the metres it climbs, at least 3°; sections one degree apart. By ascent a section that loses height climbs none, and takes 3° as a flat one does (#56).

## gap ascent

The ascent widget along the gauge's gap at the bottom (pages 12, 13 and 15): the start and top as green and red dots on the gauge's two ends, the *ascent*'s two numbers beside them facing inwards (the real height above the head, and the top's less that; #100) (0.0144 of the screen from the dots), and between the numbers a grey line the climber's ring travels, reaching up to each number as drawn: it grows when a number is short and shrinks when it is long (the no-jitter rule given up for this widget on purpose, owner 2026-11-22). The ring is a position, the real height: it pulls back on a descent (#100).

## next

The next section of a different difficulty (a rest counts as walking) and the distance to its start along the route, rounded to 5 m, without "in": "C/D 125 m", the grade in its colour; "Top …" after the last change. Bold, centred; the page sets its size.

## front view

The route seen from the front, as on a topo photo of the face: up is height, across is sideways travel; traverses and walks run nearly flat, walls go nearly straight up. The height is the real one, so a descent goes down (#56).

- The sections in their difficulty colours, climbed parts dimmed, round joints.
- Rests, exits and dangers as hollow rings, dimmed once passed; the start and the top as a green and a red dot.
- The climber as the orange outline of the stretch they could be on, rounded at its ends.
- Fitted into a box, one scale across and up.
- Zoomed (page 4): the zoom window's part fitted into the box, at least 20 m each way; the rest of the route runs on past it.

## profile zoomed

The profile of the zoom window: 100 m of path (each section's length and height combined) around the climber, a fifth of it behind and the rest ahead, slid inside the route near its ends, at one scale across and up, as large as it fits the box, centred in it (page 2: `design/page-1.md`; the altitude group sits on a half-transparent box there, #102). A rest is drawn as walking ground there, its ring kept.

## current difficulty group

The current difficulty with what surrounds it, as one unit; its sizes scale together (pages 3, 4 and 14 draw it 50 % larger), each text at the font table's nearest size.

- The current difficulty in a filled box (0.2115 by 0.1490 of the screen at base size), Bold 0.1106, a rest as `W`; a trapezium narrower at its foot for a section that loses height (*difficulty*, #100). The group's placement on pages 3 and 4 is the rectangle's: the trapezium's top is as wide.
- Above it, the altitude with its unit, centred on the box together (owner, 2026-11-23), its baseline 0.0288 of the screen above the box (below it, the next line's capitals as far below; the same gap on pages 3, 4 and 12 to 15): on pages 3 and 4 SemiBold 0.0962 and 0.0577 whatever the scale; on page 14 0.0625 and 0.0385 times the scale.
- Below it, **next** without "in": "C/D 125 m", Bold 0.0577 times the scale, the grade in its colour, centred.
- Page 14 only: the point of interest as a word under the next line (Bold 0.0673, letter-spaced, in its colour, centred), the ferrata's head (`HEAD`, green; never START, as the climb may start on the approach, owner 2026-11-23) and the route's top (`TOP`, red) too while the uncertainty reaches them; the nearest wins, on a tie danger, exit, rest, top, start. Pages 3 and 4 show none (owner, 2026-11-22).

## Groups

Widgets that are placed together, as one reusable unit.

### difficulty column group

- The **difficulty column**, with the altitudes where the difficulty changes to its right.
- Each altitude is level with a border between two boxes, and is the altitude where the route passes from the lower box's section to the upper one's; from the current section's bottom up (always shown, even with no box below it), and optionally also at the column's top edge. The bottom of the section before the current one is not shown (owner, 2026-11-23).
- Rounded like the altitude widget (10 m or 50 ft), right-aligned in a box as wide as the widest the route can show, 0.0240 of the screen right of the column, the unit after each.
- Relative (page 6): each the height above the current section's bottom, signed ("+137", "0", "-20"), to the metre or 5 ft, from the route's own heights; the box as wide as the widest difference the column can show on the route.
- Placed by its left edge and vertical centre; page 5 centres column and altitudes on the screen as one group, page 7 places it by the side of the ascent.

Options: the altitudes at the outer edges; metres or feet; the unit after every altitude or only the last (the mock's switch; the app shows it after each).

### altitude group

- **altitude**, with **poi** under it.
- The poi word is right-aligned with the altitude number, not its unit, a small space below the digits.
- Placed by where the altitude's box starts and the top of its digits.

## Open

- The difficulty colour map. Pages 1 to 15 use heat with amber and no purple (owner, 2026-11-21), a colour per half step; the pages after them take it as they come back. No via ferrata scale (Hüsler K1 to K6, Schall A to E, French F to ED) defines colours. Candidates in the mock: the prototype's heat map (grey, light blue, yellow, orange, red, purple); heat with amber and no purple (grey, light blue, yellow, amber, orange, red); ski piste; viridis; one orange hue. A map must read on black, stay distinct when dimmed, and not clash with the climber's orange, the exits' green and the dangers' red.
- Where danger points come from in route data (`design/route-data.md`).

## selection gauge (page 15)

Page 13's gauge by ascent showing a selected section, not the climber: the selected section at full colour, all others dimmed, no climber line. The points as filled disks just inside the gauge (0.0433 of the screen across), 0.0096 clear of the sections and of each other, a point moving one lane further in where it would touch one already placed (dangers first, then exits, then rests); a disk is lit where the selected section shows the point (*section points*), dimmed elsewhere.

## chevron (page 15)

A left- or right-pointing chevron, round-ended, white; dimmed when there is nothing that way.

## section points (page 15)

The points a section includes or is next to, as words under its foot's altitude: the ferrata's head for the first section (on the ferrata only; the approach starts elsewhere and ends at the head, so it shows neither HEAD nor TOP), a point in it or at its foot or top, a rest that is the section itself or right before or after it, the route's top for the last section; `HEAD` (green), `DANGER` (yellow), `EXIT` (green), `REST` (blue), `TOP` (red), in that order, Bold 0.0673, letter-spaced, a dim dot between, centred.
