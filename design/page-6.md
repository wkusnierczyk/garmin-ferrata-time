# Ferrata. Pages 6a and 6b, version 1

Status: settled with the owner on 2026-11-21 (#21)  
Reference mock: `design/demo/page-6.html` (both versions held on the left, the options on the right; it opens with these settings)  
Widgets: `design/widgets.md`

The route as a gauge around the edge, the current difficulty large in the middle. The app's sixth page, in two versions that differ only in the gauge (owner, 2026-11-21):

- **6a:** each section's arc is its length along the route.
- **6b:** each section's arc is the metres it climbs: walks and rests shrink, walls take most of the arc.

## Layout

- The **gauge** around the edge, from the lower left over the top to the lower right, each section's arc its length along the route (6a) or the metres it climbs (6b).
- Each section at least **3°** of the sweep, the others sharing the rest in proportion (#28): by ascent, the two rests and the two short climbs (Band and Bridge, 5 m up) would otherwise be under a degree. Sections are one degree apart. The mock's menu tries none, 2, 3 or 5°.
- The climber as a **thicker orange line** (0.0144 of the screen wide, round ends) on the gauge's inner side, 0.0072 clear of the sections, over the stretch they could be on (the uncertainty, 25 m up or down). It replaced the first version's orange outline around that stretch, which covered the sections (owner, 2026-11-21); the mock keeps the outline as an option.
- The current difficulty in a large filled box (0.3173 by 0.2212 of the screen) in the middle, a rest as `W`.
- Above it, one line on a shared baseline: the **poi** word ending just left of the centre, shown only while a point is within the uncertainty; the **altitude**, always, its number right-aligned with the box's right edge and its unit past it.
- Below it, **next**: the next section of a different difficulty and the distance to its start along the route, rounded to 5 m ("K4 in 125 m", the grade in its colour), or "Top in …" after the last change.
- At the bottom, the **flat ascent**: start on the left, top on the right.
- Difficulty colours: heat with amber, no purple.

On the watch, the big letters use a scalable bold font (Roboto Condensed Bold where the watch has it): the system's number fonts have no letters.
