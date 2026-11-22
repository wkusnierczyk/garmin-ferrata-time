# Ferrata Time

A Garmin Connect IQ watch app for climbing via ferratas. On the watch it is called **Ferrata** and is listed under Activities & Apps; "Ferrata Time" is the project's name.

Status: design phase. There is an interactive browser demo, a set of design notes, and a first prototype that plays a made-up climb on the watch.

The notes in `design/` predate two decisions: the project is first a standalone watch app, Ferrata, that records the climb itself, and its screens are pages you move between with the buttons. `design/DESIGN.md` is brought up to date after the first prototype (#2).

Images and fonts are stored with [Git LFS](https://git-lfs.com): install it (`brew install git-lfs`,
then `git lfs install`) before cloning.

Tracked in this repository, and in the family's umbrella as
[`wkusnierczyk/garmin-watch-faces#42`](https://github.com/wkusnierczyk/garmin-watch-faces/issues/42).

CI (`.github/workflows/build.yml`) builds the app for the epix Pro (Gen 2) 47 mm on every push to `main` or a `dev-*` branch and on every pull request from this repository, in our private tester image with a throwaway signing key, and runs the route tool's tests (below). Every target device, the store bundle, the unit tests and the checks that need no SDK follow once the design and functionality are settled.

## Prototype 0.1.0

A watch app that plays a made-up climb on the pages from the design sketch, to judge them on the wrist. Nothing is recorded and no sensor is read; the route, the times and the position are invented. One product: the epix Pro (Gen 2) 47 mm.

| Input | Does |
|---|---|
| Up, down | change page |
| Start | pause or resume the demo |
| Hold Up | the Ask list; choosing a question does nothing yet |
| Back | leave |
| Tap beside the box (page 9) | step to the section before or after |

The climb takes about two minutes and starts again after a short pause at the top. It plays at a vertical pace, as on a real via ferrata: walks pass quickly, walls slowly, and each grade above walking takes 10 % longer per metre than the one below; a rest counts as walking and a flat stretch as 5 m, so both pass in a moment. The pages, in order: the profile alone (page 1, version 1, `design/page-1.md`), the difficulty column (page 2, version 1, `design/page-2.md`), ascent and difficulty column side by side (page 3, version 1, `design/page-3.md`), the difficulty stack by ascent (page 4, version 1, `design/page-4.md`) and by path with the ascent (page 5, version 1, `design/page-5.md`), the gauge by length and by ascent (pages 6a and 6b, version 1, `design/page-6.md`), the route from the front (page 7, version 1, `design/page-7.md`), the current difficulty with the ascent gauge (page 8, version 1, `design/page-8.md`), a preview of a section the user picks (page 9, version 1, `design/page-9.md`; tap beside its difficulty box to step), side profile, ladder and profile, vertical ladder, where am I, what's next, time strip, and four large-type pages (height, next hard part, time to the top, exit). The dots on the left edge show which page is on screen; they appear when the app opens, when you come back from the Ask list, or when the page changes, and hide after 2 seconds.

Build and install, with the SDK and the developer key in place. The key is looked for beside the main checkout (`../garmin-keys/developer_key`, also from a git worktree); elsewhere, pass it as a variable, `make sideload DEV_KEY=/path/to/developer_key` (make takes variables, not monkeyc's `-y`):

```sh
make build       # FerrataTime.prg for the epix Pro (Gen 2) 47 mm
make run         # build, start the simulator, load it
make test        # build the unit tests (source/tests/), run them in the simulator
make sideload    # build for the watch on USB and copy it over (brew install libmtp)
```

`tools/launcher_icon.py` renders the launcher icon, an orange climber with arms raised, clipped to the cable, in Garmin's figure style on a transparent background, from `tools/launcher_icon.svg` (`python3 tools/launcher_icon.py 60 resources/drawables/launcher_icon.png`; needs `rsvg-convert`: `brew install librsvg` on macOS, `librsvg2-bin` on Linux).

## Routes

A route is one JSON file, the format of `design/real-functionality.md` (section 4): the approach and the ferrata as sections (`len`, `up`, `grade`, `min`, `name`, `side`) and the points along them (`kind`, `at`, `alt`, `lat`, `lon`, `name`). The app does not read it yet; it still plays the climb in `source/Climb.mc`. Route files are generated, never edited by hand: each is written from a hand-made source of the same shape, `routes/<id>.src.json`, by `tools/route.py` (Python 3, nothing to install).

```sh
make routes      # every routes/<id>.src.json to resources/routes/<id>.json, with routes/<id>.gpx if there
python3 tools/route.py build routes/<id>.src.json -o resources/routes/<id>.json [--gpx routes/<id>.gpx]
```

A route's GPX track, if it has one, is kept beside its source as `routes/<id>.gpx`, and `make routes` passes it with `--gpx`, which fills each point's missing `lat` and `lon` from the track. The track starts at the approach's start (or at the head, without an approach), and the point `at` metres from the head is placed `at` plus the approach's length along it, measured on the map (horizontal distance). The tool warns, without failing, when the track's length differs from the route's by more than 20 %, and for each point past the track's end, which it places at the end. `make routes` fails on a route file in `resources/routes/` with no source. In the source:

- `id` is the source's file name, `routes/<id>.src.json`.
- `at` is metres from the head, negative on the approach. `head` (at 0) and `top` (at the ferrata's length) are required; an `approach` point, at minus the approach's length, only with an `approach` list. Exits and landmarks sit on the boundaries between the ferrata's sections (not on the approach, and not at the head or the top). `lat` and `lon` come together, within -90..90 and -180..180. Other kinds are kept as they are and not checked.
- `grade` is in half steps, as the topo writes it: 1 A, 2 A/B, 3 B … 11 F, 12 F/G; 0 walking, -1 rest.
- `up` may be negative. Between points with an `alt`, the sections' `up` must add up to the altitude difference within 15 m.
- `min`, the guidebook's minutes for a section, may be left out; `len` and `min` are above 0, `side` from -1.0 to 1.0, `short` (the activity's name) 1 to 15 characters.
- Names (`name`, `short`, `place`, and every section's and point's `name`) are folded to the characters the app's fonts carry: letters A to Z and a to z, digits, space and `' ( ) + , - . / : > ~ ° · …`. Accents are dropped (ü to u, é to e, ç to c), special letters spelled out (ß to ss, æ to ae, ø to o, œ to oe, ł to l, þ to th), and curly quotes and dashes written plainly; any other character is an error naming the field and the character. `short` is counted after folding.

The tool lists every problem it finds and writes nothing. Its tests: `python3 -m pytest tools/tests` (needs `pytest`); CI runs them and checks that `make routes` leaves the route files unchanged.

## What it is

The earlier concept, as the notes in `design/` describe it: a watch face plus a separate watch app. One watch app, Ferrata, has replaced both. The user picks a real via ferrata from a list. The watch face then shows:

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
| `design/widgets.md` | The watch app's reusable drawing parts: profile, ascent, difficulty, altitude, poi, difficulty column, difficulty stack, ascent gauge, gauge, flat ascent, next, front view, and the altitude and difficulty column groups |
| `design/page-1.md` | Page 1, version 1: the profile alone, with the widgets around it |
| `design/demo/page-1.html` | Interactive mock of page 1, with its options as settings |
| `design/page-2.md` | Page 2, version 1: the difficulty column with its altitudes |
| `design/demo/page-2.html` | Interactive mock of page 2, with its options as settings |
| `design/page-3.md` | Page 3, version 1: ascent and difficulty column side by side |
| `design/demo/page-3.html` | Interactive mock of page 3, with its options as settings |
| `design/page-4.md` | Page 4, version 1: the difficulty stack by ascent, with points of interest |
| `design/page-5.md` | Page 5, version 1: the difficulty stack by path, with the ascent gauge and points of interest |
| `design/demo/pages-4-5.html` | Interactive mock of pages 4 and 5, the difficulty stack by ascent and by path |
| `design/page-6.md` | Pages 6a and 6b, version 1: the gauge, by length and by ascent |
| `design/demo/page-6.html` | Interactive mock of pages 6a and 6b, with their options |
| `design/page-7.md` | Page 7, version 1: the route from the front |
| `design/demo/page-7.html` | Interactive mock of page 7, with its options as settings |
| `design/page-8.md` | Page 8, version 1: the current difficulty with the ascent gauge |
| `design/demo/page-8.html` | Interactive mock of page 8, with its options as settings |
| `design/page-9.md` | Page 9, version 1: a preview of a section the user picks |
| `design/demo/page-9.html` | Interactive mock of page 9, with its chevrons |
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
