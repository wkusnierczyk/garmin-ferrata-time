# Ferrata. Page 9, version 1

Status: settled with the owner on 2026-11-21 (#27)  
Revised: on the watch as the revised mocks draw them (the Daubenhorn grid, owner 2026-11-22; ported in #95, 2026-11-23). The reference mock below is the first version's.  
Reference mock: `design/demo/page-9.html` (the dial held on the left; click the chevrons, or press the left and right arrow keys)  
Widgets: `design/widgets.md` (*gauge*, *gap ascent*, and new here: *selection gauge*, *chevron*, *section points*)

A preview of a section the user picks, built on page 6b. The app's last page for now, after page 8.

## Layout

- The **selection gauge**: page 6b's gauge by ascent (each section's arc the metres it climbs, at least 3°, so a rest has an arc to light up), showing the selection, not the climber. The selected section at full colour, all others dimmed; no climber line. The points as short arcs along the gauge's inside (owner, 2026-11-23: the rings were small and hard to read on the watch): 0.0192 of the screen thick, 0.0577 long with round ends, 0.0096 clear of the sections; a point that would come within 0.0096 of one already placed moves one lane further in (dangers first, then exits, then rests, so the more important keeps the lane nearest the gauge). An arc is lit where the selected section shows the point, dimmed elsewhere; danger yellow, exit green, rest blue.
- The selected section's **difficulty** in the large box (0.3173 by 0.2212 of the screen) centred on the screen, a rest as `W`.
- **Chevrons** left and right of the box, 0.0962 of the screen from it, to step to the section before and after; dimmed on the first and last sections. On the watch a tap level with the box, beside it, steps that way.
- The section's **altitudes** to the metre (SemiBold 0.0962, the unit 0.0577), each centred on the screen with its unit (owner, 2026-11-23), 0.0288 of the screen clear of the box: its top's above the box, its foot's below. A flat section reads the same altitude twice.
- Under the foot's altitude the **points** it includes or is next to, as words (Bold 0.0673, letter-spaced), each in its colour, a dim dot between, centred: `DANGER` red, `EXIT` green, `REST` blue, `TOP` red, in that order. No section name (owner, 2026-11-22).
- A section shows a point that lies in it or at its foot or top, and a rest that is the section itself or right before or after it. An exit at a boundary shows on both sections that meet there.
- At the bottom, the **gap ascent**, showing the climber.
- The page opens on the climber's section; moving to another page and back opens it there again.
- Difficulty colours: heat with amber, no purple, a colour per half step.

## Open

- Buttons for stepping, besides taps, on watches without a touchscreen.
