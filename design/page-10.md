# Ferrata. Pages 10 and 11

Status: settled with the owner on 2026-11-21 (#20)  
Revised: on the watch as the revised mocks draw them (the Daubenhorn grid, owner 2026-11-22; ported in #95, 2026-11-23).  
Parked: too noisy as a design (owner, 2026-11-25, #110); left out of the app and its releases, their code kept (owner, 2026-11-26, #128).  
Reference mock: `design/demo/pages-8-11.html` (live dials held on the left, the options on the right; it opens with this page's settings)  
Widgets: `design/widgets.md` (*difficulty stack*, *ascent gauge*)

The **path stack**: the route's sections as boxes as tall as their length along the route, in a window that moves with the climber. Page 11 is the same stack inside the **ascent gauge** around the screen's edge. Pages 8 and 10 look alike (owner, 2026-11-22, by their old numbers: "make pages 4x look like 5x"); they differ only in what a box's height stands for.

## Settings

| Setting | Value |
|:--|:--|
| Column | 0.1058 of the screen wide, centred on the screen |
| Window | from 0.0865 to 0.9135 of the screen down; on page 11 from 0.1538 to 0.8077, inside the gauge and clear of its numbers |
| Scale | 0.0024 of the screen per metre of path: 344 m in view, 272 m on page 11 |
| The climber | a quarter of the way up the window; the orange ring on the column's left edge, no line across the column |
| Letters | every section's grade right of the column (Bold 0.0673 of the screen), at the middle of its box's part in view, in its colour; the climber's section as large as the next altitude's label (Bold 0.1250; owner, 2026-11-23) and its box filled; placed from the climber's section outwards, left out where they would touch letters already placed |
| Points of interest | symbols (0.0529 across) right of the letters: danger a yellow triangle, exit a green arrow, rest a blue pause (at the middle of the rest), the route's top a red square; dimmed once passed |
| Altitude ticks | every 10 m (50 ft in feet), where the route first reaches each altitude: they crowd on walls and spread on walks |
| Labels | three: the next altitude to reach (SemiBold 0.1250; the first tick above the climber on the stack, which may sit further along the route than the climber; near the top, past the last tick, the topmost), and the nearest tick above and below it that keep clear of it (0.0865); the other ticks bare |
| Fit | everything within 0.4399 of the screen's centre (6 % of the width clear of the edge), within 0.4087 inside the gauge |
| Section names | none |
| Difficulty colours | heat with amber, no purple, a colour per half step; rests shown as W |

Symbols that would touch show one: of those in the climber's range (one tick step before the point to half a step after it, along the stack's axis), the first of danger, exit, rest, top, then the nearest; with none in range, the one nearest the climber.

## Open

- Flat sections: lines, or a minimum height.
