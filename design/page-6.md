# Ferrata. Page 6, version 1

Status: settled with the owner on 2026-11-21 (#21)  
Reference mock: `design/demo/page-6.html` (a live dial with a slider and playback, and the options as settings)  
Widgets: `design/widgets.md`

The route as a gauge around the edge, the current difficulty large in the middle. The app's sixth page.

## Layout

- The **gauge** around the edge, from the lower left over the top to the lower right, each section's arc its length along the route.
- The current difficulty in a large filled box (132 by 92 px) in the middle, a rest as `W`.
- Above it, one line on a shared baseline: the **poi** word ending just left of the centre, shown only while a point is within the uncertainty; the **altitude**, always, its number right-aligned with the box's right edge and its unit past it.
- Below it, **next**: the next section of a different difficulty and the distance to its start along the route, rounded to 5 m ("K4 in 125 m", the grade in its colour), or "Top in …" after the last change.
- At the bottom, the **flat ascent**: start on the left, top on the right.
- Difficulty colours: heat with amber, no purple.

On the watch, the big letters use a scalable bold font (Roboto Condensed Bold where the watch has it): the system's number fonts have no letters.
