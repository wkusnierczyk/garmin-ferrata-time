# Ferrata. Page 4, version 1

Status: settled with the owner on 2026-11-21 (#20)  
Reference mock: `design/demo/pages-4-5.html` (live dials held on the left, the options on the right; it opens with this page's settings)  
Widgets: `design/widgets.md` (*difficulty stack*)

The **ascent stack** alone: the route's sections as boxes as tall as the metres they climb, in a window that moves with the climber. The app's fourth page.

## Settings

| Setting | Value |
|:--|:--|
| Scale | 3 px per metre: 96 m in view, 24 m below the climber and 72 m above |
| Altitude ticks | every 20 m (100 ft in feet) |
| The next altitude above the climber | 200 % of the other tick labels |
| The altitudes just above and below it | 150 % |
| The climber | the orange ring on the column's left edge; no line or tick across the column |
| Section names | on, on the right |
| Points of interest | on: rings on the column's right edge |
| Their names | on, while the climber is in range (one tick step before to half a step after) |
| Difficulty colours | heat with amber, no purple; rests shown as W |

## Points of interest

Four kinds, in the colours of the other pages: danger yellow, exit green, rest blue (at the middle of the rest), the route's top red; dimmed once passed. Names are the kind ("Danger", "Exit", "Rest", "Top"); a rest's section keeps its own name (such as Bench) in white, which gives way while the point's name shows. Points whose rings would touch show one ring: of those in range, the first of danger, exit, rest, top, with its name; with none in range, the one nearest the climber, unnamed.

## Not in the app yet

The watch code on #20 has the ring on the left, no line, and the 200 % and 150 % labels; it still draws at 2.5 px per metre and has no points of interest. Both come with the next port, when the owner asks for a sideload.

## Open

- A title above the stack, or the current difficulty and altitude below it, as in the sketch.
- Flat sections: lines, or a minimum height.
