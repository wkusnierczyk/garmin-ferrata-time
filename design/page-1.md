# Ferrata. Page 1, version 1

Status: settled with the owner on 2026-11-20 (#16)  
Revised: on the watch as the revised mocks draw them (the Daubenhorn grid, owner 2026-11-22; ported in #95, 2026-11-23).  
Reference mock: `design/demo/page-1.html` (a live dial with a slider and playback, and the options as settings)  
Widgets: `design/widgets.md`

The app's first page: the profile alone, with the numbers moved into widgets around it (it replaced the prototype's side-profile page, page A). Page 1a, the second page, is the same page with the profile zoomed.

## Layout

- Difficulty colours: heat with amber, no purple (grey, light blue, yellow, amber, orange, red), a colour for each half step (`design/widgets.md`).
- **profile** and **ascent** share the start point: the ascent line rises from the profile's first point, and its top is level with the profile's end. Together they span a rectangle, from 0.2212 to 0.8462 of the screen across and from 0.2212 to 0.7644 down.
- Descents (#56, #100): the profile draws the route's real height, so a section that loses height goes down, and it spans the rectangle from the route's lowest point to its highest. The ascent is a position too (owner, 2026-11-23): its ring follows the real height from the head to the top, and pulls back down on a descent, level with the climber on the profile; its numbers are the real height above the head and the top's less that. On a route that dips below its start, or climbs above its end before coming down to it, the profile's first point or its end is then no longer level with the ascent line's ends, and the ring waits at the line's end. The altitude group shows the real altitude. A descending section's difficulty box is a trapezium narrower at its foot (`design/widgets.md`, *difficulty*).
- **difficulty**, without points (rests, exits, dangers), under the profile, centred on the screen, 40 % larger than on other pages (the middle box's letters Bold 0.0865 of the screen, the satellites' 0.0625), the boxes' tops on one line a box gap (0.0120) below the climber's ring at the start (owner, 2026-11-23: it sat small in the rectangle's lower right; the round screen has more room under the profile, in the middle).
- The **altitude group** (altitude, with poi under it) in the rectangle's upper left: the top of the altitude's digits level with the top of the ascent's top number when that sits at the line's end, 0.31 of the number's size above the line's end (owner, 2026-11-23: it was level with the line's end, lower than the number beside it), its box starting a small space right of the ascent line's ring.

## Page 1a: the profile zoomed

- The profile shows 100 m of path (each section's length and height combined) around the climber, a fifth of it behind and the rest ahead, slid inside the route near its ends, at one scale across and up.
- The window at the largest scale that fits the rectangle, centred in it, worked out once per window (owner, 2026-11-23, #102). No search for a placement clear of the widgets: the search cost too much on the watch, and while it ran the profile was drawn over the altitude.
- The altitude group sits on a half-transparent black box (50 %), so where the zoomed route runs under it, it shows through half-dimmed (#102): 0.0144 of the screen of padding round the group, rounded by as much; as wide as the route's widest altitude with its unit, as tall as the digits' capitals and, when there is a poi word, the gap under them and the word's capitals. Drawn over the profile, under the altitude group. It needs alpha blending (Connect IQ 4.0, the epix's AMOLED).
- The route is cut just right of the ascent widget and 0.0337 of the screen past the rectangle elsewhere. A rest is drawn as walking ground (its stretch is too long to leave out), its ring kept.
- Everything else as on page 1.

## Removed from page A

- The clock, the altitude line, the climbed and time-to-top figures, and the distance along.
- The inclination degrees on steep sections.
- The dashed exit lines with arrow marks, and the rest marks beneath the route.
- The white dot and the grey band for the climber, replaced by the orange outline.
