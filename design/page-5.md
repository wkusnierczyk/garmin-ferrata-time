# Ferrata. Page 5, version 1

Status: settled with the owner on 2026-11-21 (#20)  
Reference mock: `design/demo/pages-4-5.html` (live dials held on the left, the options on the right; it opens with this page's settings)  
Widgets: `design/widgets.md` (*difficulty stack*, *ascent gauge*)

The **path stack** with the **ascent gauge** around it: the route's sections as boxes as tall as their length along the route, in a window that moves with the climber, and the height climbed as an arc around the screen's edge. The app's fifth page.

## Settings

| Setting | Value |
|:--|:--|
| Scale | 0.0024 of the screen per metre of path: 288 m in view |
| Altitude ticks | every 10 m (50 ft in feet), where the route first reaches each altitude: they crowd on walls and spread on walks |
| The next altitude to reach | 200 % of the other tick labels: the first tick above the altitude now, which may sit further along the route than the climber |
| The altitudes just above and below it | 150 % |
| The climber | the orange ring on the column's left edge; no line or tick across the column |
| Section names | on, on the right, stopping inside the gauge |
| Points of interest | on: rings on the column's right edge, as on page 4 |
| Their names | on, while the climber is in range: one tick step (10 m of path) before to half a step after |
| Ascent gauge | an arc from the start (lower left) over the top to the route's top (lower right), the climber's ring at the height climbed, the start and top as green and red dots, the metres climbed and left past its ends |
| Layout | the stack centred as a group: tick labels (as wide as the larger label), column, 0.1923 of the screen's width for names |
| Difficulty colours | heat with amber, no purple; rests shown as W |

Points of interest as on page 4 (`design/page-4.md`): danger yellow, exit green, rest blue, the top red; one ring per group of touching rings, by precedence in range (danger, exit, rest, top) and by nearness out of it.

## Open

- The range for point names is measured in metres of path, with the altitude tick step as its unit; whether it should be measured in height instead.
