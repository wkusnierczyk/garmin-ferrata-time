# Ferrata Time

A Garmin Connect IQ watch face and watch app for climbing via ferratas.

Status: design phase. There is an interactive browser demo, a set of design notes, and a first prototype that plays a made-up climb on the watch.

The notes in `design/` predate two decisions: Ferrata Time is first a standalone watch app that records the climb itself, and its screens are pages you move between with the buttons. `design/DESIGN.md` is brought up to date after the first prototype (#2).

Images and fonts are stored with [Git LFS](https://git-lfs.com): install it (`brew install git-lfs`,
then `git lfs install`) before cloning.

Tracked in this repository, and in the family's umbrella as
[`wkusnierczyk/garmin-watch-faces#42`](https://github.com/wkusnierczyk/garmin-watch-faces/issues/42).

## Prototype 0.0.1

A watch app that plays a made-up climb on the pages from the design sketch, to judge them on the wrist. Nothing is recorded and no sensor is read; the route, the times and the position are invented. One product: the epix Pro (Gen 2) 47 mm.

| Button | Does |
|---|---|
| Up, down | change page |
| Start | pause or resume the demo |
| Hold Up | the Ask list; choosing a question does nothing yet |
| Back | leave |

The climb takes about two minutes and starts again after a short pause at the top. The pages, in order: the profile alone (page 1, version 1, `design/page-1.md`), the difficulty column (page 2, version 1, `design/page-2.md`), ascent and difficulty column side by side (page 3, version 1, `design/page-3.md`), the difficulty stack by ascent (page 4) and by path with the ascent as a gauge (page 5, both in the works, `design/demo/pages-4-5.html`), the gauge (page 6, version 1, `design/page-6.md`), side profile, ladder and profile, vertical ladder, where am I, what's next, time strip, and four large-type pages (height, next hard part, time to the top, exit). The dots on the left edge show which page is on screen.

Build and install, with the SDK and the developer key in place. The key is looked for beside the main checkout (`../garmin-keys/developer_key`, also from a git worktree); elsewhere, pass it as a variable, `make sideload DEV_KEY=/path/to/developer_key` (make takes variables, not monkeyc's `-y`):

```sh
make build       # FerrataTime.prg for the epix Pro (Gen 2) 47 mm
make run         # build, start the simulator, load it
make sideload    # build for the watch on USB and copy it over (brew install libmtp)
```

`tools/launcher_icon.py` draws the launcher icon (`python3 tools/launcher_icon.py 60 resources/drawables/launcher_icon.png`, needs Pillow).

## What it is

The concept as the notes in `design/` describe it. The user picks a real via ferrata from a list. The watch face then shows:

- an outline of the route with the climber's position on it
- vertical meters climbed of the total
- blue dots for rest points ahead and red dots or segments for difficulties ahead
- the time left, and minutes to the next rest or difficulty

A separate, feature-rich watch app (several screens) handles route choice, an overview, a live view, an elevation profile, statistics and a summary.

## Repository layout

| Path | Contents |
|---|---|
| `design/DESIGN.md` | The design record: goals, face, app screens, data model, open questions, decisions |
| `design/demo/index.html` | Self-contained interactive demo. Open it in a browser |
| `design/demo/screenshots/` | Stills of every face layout and app screen |
| `design/widgets.md` | The watch app's reusable drawing parts: profile, ascent, difficulty, altitude, poi, difficulty column, difficulty stack, ascent gauge, gauge, flat ascent, next, and the altitude and difficulty column groups |
| `design/page-1.md` | Page 1, version 1: the profile alone, with the widgets around it |
| `design/demo/page-1.html` | Interactive mock of page 1, with its options as settings |
| `design/page-2.md` | Page 2, version 1: the difficulty column with its altitudes |
| `design/demo/page-2.html` | Interactive mock of page 2, with its options as settings |
| `design/page-3.md` | Page 3, version 1: ascent and difficulty column side by side |
| `design/demo/page-3.html` | Interactive mock of page 3, with its options as settings |
| `design/demo/pages-4-5.html` | Interactive mock of pages 4 and 5, the difficulty stack by ascent and by path |
| `design/page-6.md` | Page 6, version 1: the gauge |
| `design/demo/page-6.html` | Interactive mock of page 6, with its options as settings |
| `design/connect-iq-platform.md` | Platform limits, and what "companion app" means at Garmin |
| `design/route-data.md` | Where real route paths and profiles can come from, and how they reach the watch |
| `design/converter-site.md` | Proposal for a stateless GitHub Pages converter from GPX or OSM to route JSON |
| `design/sensing.md` | Why position and altitude are unreliable on a wall, and what the design does about it |
| `design/ground-truth-plan.md` | How recorded activities will be used to test the assumptions |

`docs/` is kept for user-facing pages, once there is something to use.

## Running the demo

Open `design/demo/index.html` in any modern browser. No build step, no server. Fonts load from Google Fonts when online and fall back to system fonts offline.

The demo uses four routes with rounded figures from public guides. The outlines are schematic sketches, not GPS tracks, and the rest and difficulty positions are placeholders.

## Reading order

1. `design/DESIGN.md`
2. `design/sensing.md` and `design/route-data.md`, the two things most likely to change the design
3. The rest as needed
