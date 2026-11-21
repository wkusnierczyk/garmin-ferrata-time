# Ferrata. Page 9, version 1

Status: settled with the owner on 2026-11-21 (#27)  
Reference mock: `design/demo/page-9.html` (the dial held on the left; click the chevrons, or press the left and right arrow keys)  
Widgets: `design/widgets.md` (*gauge*, *flat ascent*, and new here: *selection gauge*, *chevron*, *section points*)

A preview of a section the user picks, built on page 6b. The app's ninth page, after page 8.

## Layout

- The **selection gauge**: page 6b's gauge by ascent (each section's arc the metres it climbs, at least 3°, so a rest has an arc to light up), showing the selection, not the climber. The selected section at full colour, all others dimmed; no climber line. The points as rings just inside the gauge, 4 px clear of the sections, so the gauge holds only the sections; a ring is lit where the selected section shows its symbol, dimmed elsewhere.
- In the middle, the selected section's **difficulty** in the large box (132 by 92 px), a rest as `W`.
- **Chevrons** left and right of the box, 40 px from it, to step to the section before and after; dimmed on the first and last sections. On the watch a tap level with the box, beside it, steps that way.
- Above the box, the section's **altitudes**, foot to top: "1380 to 1490 m", "to" and the unit grey, centred. A flat section reads the same altitude twice.
- Below the box, the section's **name**, followed by the **symbols** of the points it includes or is next to, standing on the name's baseline (a descender such as the y in "gully" does not move them), the whole centred. Order: danger (yellow triangle), exit (green arrow down to the right), rest (blue pause), top (red square).
- A section shows a point that lies in it or at its foot or top, and a rest that is the section itself or right before or after it. An exit at a boundary shows on both sections that meet there.
- At the bottom, the **flat ascent**, showing the climber.
- The page opens on the climber's section; moving to another page and back opens it there again.
- Difficulty colours: heat with amber, no purple.

## Open

- Buttons for stepping, besides taps, on watches without a touchscreen.
