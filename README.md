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

A watch app that plays a made-up climb on the pages from the design sketch, to judge them on the wrist. Nothing is recorded; the route is invented, and in the demo the times and the position too. One product: the epix Pro (Gen 2) 47 mm.

One setting, **Demo climb** (on by default), on the watch (hold Up, then Settings, then Demo) and in the Connect IQ app on the phone. On, the app plays the made-up climb below; off, it reads the watch's altitude and GPS position instead, and works out the place on the route from the height climbed and the time. Until the climb's start menu comes (#51), the sensors start from wherever the watch is, on the approach, without setting the altitude from a known point, so the place moves by time alone. Changing the setting starts the climb again. The demo goes through the same tracker as the sensors: its watch reads 12 m low, and the start at the head corrects that, as a real start at a known point would.

| Input | Does |
|---|---|
| Up, down | change page |
| Start | pause or resume the climb (the demo stops with it) |
| Hold Up | the Ask list; choosing a question does nothing yet; its last item, Settings, opens the settings |
| Back | leave |
| Tap beside the box (page 9) | step to the section before or after |

The climb is the bundled route, `resources/routes/demo.json` (below), counted from the ferrata head: the pages show the ferrata, 640 m long, from the head at 1290 m to the top at 1580 m, climbing 400 m and going down 110 m on the way (the Dihedral, the route's fifth section counting the approach, descends by its height to show a descent, #100), and leave out the 120 m approach, which they will show as its own stretch only while the climber is on it. The climb takes about two minutes and starts again after a short pause at the top. It plays at a vertical pace, as on a real via ferrata: each section takes as long as the metres it climbs or descends, so walks pass quickly and walls slowly, up or down, and each grade above walking takes 10 % longer per metre than the one below (a half step 5 %); a rest counts as walking and a flat stretch as 5 m, so both pass in a moment. The pages, in order, as the revised mocks draw them (#95): the profile alone (page 1, `design/page-1.md`) and zoomed to 100 m of path around the climber, as large as it fits and centred, the altitude on a half-transparent box, so the route shows through dimmed where it runs under it (page 1a), the difficulty column (page 2, `design/page-2.md`) and the same with the altitudes relative to the current section's bottom (page 2a), ascent and difficulty column side by side under "NOW" and the altitude (page 3, `design/page-3.md`), the difficulty stack by ascent (pages 4 and 4a, `design/page-4.md`) and by path (pages 5 and 5a, `design/page-5.md`), the second of each inside the ascent gauge, the gauge by length and by ascent (pages 6a and 6b, `design/page-6.md`), the route from the front (page 7, `design/page-7.md`) and zoomed (page 7a), the current difficulty with the ascent gauge (page 8, `design/page-8.md`), and a preview of a section the user picks (page 9, `design/page-9.md`; tap beside its difficulty box to step). The prototype's other pages (side profile, ladders, where am I, what's next, time strip, large type) are gone; pages 10 to 19 come back from the mocks one by one. The grades show as the route has them, A to F in half steps (`C/D`), each half step in its own colour, between its two neighbours'. The pages draw in Barlow Condensed, the mocks' typeface (see [Fonts](#fonts)). The dots on the left edge show which page is on screen; they appear when the app opens, when you come back from the Ask list, or when the page changes, and hide after 2 seconds.

Build and install, with the SDK and the developer key in place. The key is looked for beside the main checkout (`../garmin-keys/developer_key`, also from a git worktree); elsewhere, pass it as a variable, `make sideload DEV_KEY=/path/to/developer_key` (make takes variables, not monkeyc's `-y`):

```sh
make build       # FerrataTime.prg for the epix Pro (Gen 2) 47 mm
make run         # build, start the simulator, load it
make test        # build the unit tests (source/tests/), run them in the simulator
make sideload    # build for the watch on USB and copy it over (brew install libmtp)
```

`tools/launcher_icon.py` renders the launcher icon, an orange climber with arms raised, clipped to the cable, in Garmin's figure style on a transparent background, from `tools/launcher_icon.svg` (`python3 tools/launcher_icon.py 60 resources/drawables/launcher_icon.png`; needs `rsvg-convert`: `brew install librsvg` on macOS, `librsvg2-bin` on Linux).

## Routes

A route is one JSON file, the format of `design/real-functionality.md` (section 4): the approach and the ferrata as sections (`len`, `up`, `grade`, `min`, `name`, `side`) and the points along them (`kind`, `at`, `alt`, `lat`, `lon`, `name`). The app reads the bundled route, `resources/routes/demo.json` (the 0.1.0 demo climb), when it starts, and its pages show one part of it at a time: the ferrata, from the head, or the approach. Climbed height and the route's total are height gained, the sum of the positive `up`. The profile (page 1) and the front view (page 7) draw the route's real height, down as well as up, the profile from the route's lowest point to its highest; the pages that stack sections by height (the difficulty stack by ascent, page 4, and the gauge by ascent, pages 6b and 9) stack them by height gained, so a section that loses height draws flat there, and the stacks' altitude ticks mark where the route rises. Every altitude a page shows is the real one, and so is the climber's place on the ascent widgets (#100): the line beside the profile (pages 1 and 3), the ascent gauge (pages 4a, 5a and 8) and the ascent along the gauge's gap (pages 6a, 6b and 9) show the real height from the head to the top, so the climber's ring pulls back down on a descent, its numbers the real height above the head and the top's less that; amounts climbed (the stacks, the gauge by ascent's arcs, the climbed totals) stay height gained. A section that loses height has its grade box drawn as a trapezium narrower at its foot, on every page with grade boxes (1, 2, 3, 6 to 9), and page 9 shows a descent's start, the higher altitude, above its box. In the bundled demo route the Dihedral descends. The pages draw the grades in these half steps (`A/B`, `C/D`), each in its own colour (#95); the K scale is a setting to come (#58). The next hard part is the next one at D or above, by its own grade, so C/D is not hard. A section without `min` gets an estimate by a hiker's rule (DIN 33466: 300 m an hour up, 500 m an hour down, 4 km an hour along; the larger of the two, plus half the smaller; at least a minute). Route files are generated, never edited by hand: each is written from a hand-made source of the same shape, `routes/<id>.src.json`, by `tools/route.py` (Python 3, nothing to install).

```sh
make routes      # every routes/<id>.src.json to resources/routes/<id>.json, with routes/<id>.gpx if there
python3 tools/route.py build routes/<id>.src.json -o resources/routes/<id>.json [--gpx routes/<id>.gpx]
```

A route's GPX track, if it has one, is kept beside its source as `routes/<id>.gpx`, and `make routes` passes it with `--gpx`, which fills each point's missing `lat` and `lon` from the track. The track starts at the approach's start (or at the head, without an approach), and the point `at` metres from the head is placed `at` plus the approach's length along it. Distance along the track counts height: each step from its horizontal distance and the change in the track points' elevations (`<ele>`), which comes close to the length along the cable that a route's lengths measure. A track point without an elevation takes one interpolated, by horizontal distance, between its nearest neighbours that have one (before the first or after the last, the nearest), with a warning saying how many; a track with no elevations at all is measured on the map, as before. This suits tracks whose elevations come from an elevation model; raw GPS or barometric elevations carry noise that makes the track read long and places the points early, and the tool does not smooth them. An `<ele>` that is empty or not a number is an error. The tool warns, without failing, when the track's length, measured the same way, differs from the route's by more than 20 %, and for each point past the track's end, which it places at the end. `make routes` fails on a route file in `resources/routes/` with no source. In the source:

- `id` is the source's file name, `routes/<id>.src.json`.
- `at` is metres from the head, negative on the approach. `head` (at 0) and `top` (at the ferrata's length) are required; an `approach` point, at minus the approach's length, only with an `approach` list. Exits and landmarks sit on the boundaries between the ferrata's sections (not on the approach, and not at the head or the top). `lat` and `lon` come together, within -90..90 and -180..180. Other kinds are kept as they are and not checked, but for their `name`, folded as below.
- `grade` is in half steps, as the topo writes it: 1 A, 2 A/B, 3 B … 11 F, 12 F/G; 0 walking, -1 rest.
- `up` may be negative. Between points with an `alt`, the sections' `up` must add up to the altitude difference within 15 m.
- `min`, the guidebook's minutes for a section, may be left out; `len` and `min` are above 0, `side` from -1.0 to 1.0, `short` (the activity's name) 1 to 15 characters.
- Names (`name`, `short`, `place`, and every section's and point's `name`, points of any kind) are folded to the characters the app's fonts carry: letters A to Z and a to z, digits, space and `' ( ) + , - . / : > ~ ° · …`. Accents are dropped (ü to u, é to e, ç to c), special letters spelled out (ß to ss, æ to ae, ø to o, œ to oe, ł to l, þ to th), quotes of every kind written as `'` (the fonts have no double quote), dashes and the minus as `-`, the fraction slash as `/`, the micro sign as `u`, and invisible marks (soft hyphens, zero-width spaces and joiners, variation selectors) dropped; any other character is an error naming the field and the character. `short` is counted after folding.

The tool lists every problem it finds and writes nothing. The tools' tests, this one's and the replay tool's (below): `python3 -m pytest tools/tests`, with `pytest` and Garmin's FIT SDK for Python installed (`pip install -r tools/requirements.txt`, in a virtual environment); CI runs them and checks that `make routes` leaves the route files unchanged.

## Replay

A replay build plays a recorded climb through the tracker in the simulator, faster than real time, in the place of the watch's sensors: the end-to-end test of calibration, place and pace while the routes are closed. Simulator only: it never records anything, `make sideload` refuses it, and the app's own build (`make build`) carries no recording and never plays one (it holds the `ReplayInput` class, unused, so the unit tests reach it). The recording is a FIT file (an activity recorded on a Garmin watch, with barometric altitude), which `tools/fit2replay.py` turns into `resources-replay/replay.json`: an entry every 10 s, and one at the end, `[t, alt, lat, lon]` (the local time of day in seconds, the altitude in whole metres, the position in degrees to 5 decimals), each interpolated between the records around it that have it, across any gap, and `null` before the first or after the last record that has it. Entries are written only where the recording has records: across a gap (the watch stopped, or a stretch without records) there are none, and the replay interpolates across it; the tool warns when a replay runs to more than 5000 entries (about 14 hours, some 300 KB of the watch app's 768 KB when loaded). The replay plays 60 times faster than the recording, a minute of the climb a second, so a 5 h 40 climb takes under 6 minutes, and then holds at its end. A recording is someone's own track: `resources-replay/replay.json` and every `.fit` file are ignored by git, and neither is ever committed.

```sh
pip install -r tools/requirements.txt   # the FIT SDK for Python, garmin-fit-sdk (in a virtual environment)
make replay FIT=/path/to/track.fit      # resources-replay/replay.json; PYTHON=... names the interpreter
make run REPLAY=1                       # FerrataTime-replay.prg, the replay in the simulator
make test REPLAY=1                      # the unit tests in the replay build, on that recording
```

In a replay build the replay stands in for the sensors whatever the Demo climb setting says, and starts as they do: from wherever the recording starts, unsynced, so until the climb's start menu comes (#51) the place moves by time alone. The bundled route is still the demo's, not the recorded one's, until Daubenhorn comes (#55).

## Fonts

The app draws every page in its own bitmap fonts made from [Barlow Condensed](https://github.com/jpt/barlow), the typeface of the mocks, in SemiBold for text and numbers and in Bold for the difficulty boxes and the words beside them, instead of the watch's system fonts (#62). Its figures are tabular, as the mocks set them (`font-variant-numeric: tabular-nums`): every digit has one width, so a number that counts does not shift.

A text the mock draws at `font-size: N` at 416 px draws on the watch at N px too, with the same cap height (0.7 of N) and the same advances to the nearest pixel: `ttf2bmp`'s size is the em, as CSS's `font-size` is, and `make fonts` rounds each glyph's advance to the nearest pixel where `ttf2bmp` rounds it up.

The sizes are one table, `resources/fonts/sizes.json`: each font's weight, its size as a share of the screen's width (the designs are in proportions), its pixels at the 416 px reference, and its glyphs. `tools/font-config.py` writes from it `resources/fonts/fonts.xml`, `resources/fonts/charsets.json` and `source/FontSizes.mc`, which nobody edits by hand. A page asks for a size in the table (`d.semi(share)`, `d.bold(share)`, `Fonts` in `source/Draw.mc`), and `make check-fonts` fails on one that is not; a widget drawn at a factor (page 7's group at 1.15, page 8's at 1.5) gets the nearest size, the larger on a tie. The mocks use only these sizes, rounding a scaled one the same way, so what a mock shows is what the watch draws:

<!-- font sizes: start -->
| Font | Weight | Share of the width | At 416 px | Glyphs |
|:-|:-|-:|-:|:-|
| `SemiBold16` | SemiBold | 0.0385 (3.85 %) | 16 | text |
| `SemiBold18` | SemiBold | 0.0433 (4.33 %) | 18 | text |
| `SemiBold20` | SemiBold | 0.0481 (4.81 %) | 20 | text |
| `SemiBold22` | SemiBold | 0.0529 (5.29 %) | 22 | text |
| `SemiBold24` | SemiBold | 0.0577 (5.77 %) | 24 | text |
| `SemiBold28` | SemiBold | 0.0673 (6.73 %) | 28 | text |
| `SemiBold30` | SemiBold | 0.0721 (7.21 %) | 30 | text |
| `SemiBold32` | SemiBold | 0.0769 (7.69 %) | 32 | text |
| `SemiBold36` | SemiBold | 0.0865 (8.65 %) | 36 | text |
| `SemiBold40` | SemiBold | 0.0962 (9.62 %) | 40 | text |
| `SemiBold44` | SemiBold | 0.1058 (10.58 %) | 44 | text |
| `SemiBold46` | SemiBold | 0.1106 (11.06 %) | 46 | text |
| `SemiBold52` | SemiBold | 0.1250 (12.50 %) | 52 | numbers |
| `SemiBold58` | SemiBold | 0.1394 (13.94 %) | 58 | numbers |
| `SemiBold64` | SemiBold | 0.1538 (15.38 %) | 64 | numbers |
| `SemiBold84` | SemiBold | 0.2019 (20.19 %) | 84 | numbers |
| `SemiBold104` | SemiBold | 0.2500 (25.00 %) | 104 | numbers |
| `Bold18` | Bold | 0.0433 (4.33 %) | 18 | text |
| `Bold20` | Bold | 0.0481 (4.81 %) | 20 | text |
| `Bold24` | Bold | 0.0577 (5.77 %) | 24 | text |
| `Bold26` | Bold | 0.0625 (6.25 %) | 26 | text |
| `Bold28` | Bold | 0.0673 (6.73 %) | 28 | text |
| `Bold30` | Bold | 0.0721 (7.21 %) | 30 | text |
| `Bold34` | Bold | 0.0817 (8.17 %) | 34 | text |
| `Bold36` | Bold | 0.0865 (8.65 %) | 36 | text |
| `Bold52` | Bold | 0.1250 (12.50 %) | 52 | grades |
| `Bold70` | Bold | 0.1683 (16.83 %) | 70 | grades |
<!-- font sizes: end -->

Text fonts hold only what the app draws (owner, 2026-11-22): the letters A to Z and a to z, the digits, the space and `' ( ) + , - . / : > ~ ° · …`, the punctuation the code and the mock pages use (parentheses, comma and period come from route names such as "Grosser Spalt (var. E)"). Route names cannot be predicted, so the route tool folds accented letters to plain ones and rejects anything else the fonts lack (#84); `make check-fonts` fails on a string literal in `source/` outside this set. Number fonts hold the digits, `:`, `-` and the space; grade fonts the box letters and digits (A to F with half steps such as `C/D`, `K1` to `K6` and `K3/4`, `R`, `W`, `E`).

The reference resolution is 416x416, the epix Pro (Gen 2) 47 mm's, in `resources/fonts/resolutions.json`: `resources/fonts/fonts.xml` gives each font's size there in pixels (the share times 416), and [`garmin-font-scaler`](https://github.com/wkusnierczyk/garmin-font-scaler) derives every other resolution's from it with [`ttf2bmp`](https://github.com/wkusnierczyk/ttf2bmp). The epix is the only target so far. The sizes by resolution, as the scaler writes them to `fonts.md`:

<!-- fonts.md: start -->
| Resolution | Shape |   Element    |              Font               | Size |
| ---------: | :---- | :----------- | :------------------------------ | ---: |
|  416 x 416 | round | Bold18       | BarlowCondensedTabular bold     |   18 |
|  416 x 416 | round | Bold20       | BarlowCondensedTabular bold     |   20 |
|  416 x 416 | round | Bold24       | BarlowCondensedTabular bold     |   24 |
|  416 x 416 | round | Bold26       | BarlowCondensedTabular bold     |   26 |
|  416 x 416 | round | Bold28       | BarlowCondensedTabular bold     |   28 |
|  416 x 416 | round | Bold30       | BarlowCondensedTabular bold     |   30 |
|  416 x 416 | round | Bold34       | BarlowCondensedTabular bold     |   34 |
|  416 x 416 | round | Bold36       | BarlowCondensedTabular bold     |   36 |
|  416 x 416 | round | Bold52       | BarlowCondensedTabular bold     |   52 |
|  416 x 416 | round | Bold70       | BarlowCondensedTabular bold     |   70 |
|  416 x 416 | round | Semi bold104 | BarlowCondensedTabular semibold |  104 |
|  416 x 416 | round | Semi bold16  | BarlowCondensedTabular semibold |   16 |
|  416 x 416 | round | Semi bold18  | BarlowCondensedTabular semibold |   18 |
|  416 x 416 | round | Semi bold20  | BarlowCondensedTabular semibold |   20 |
|  416 x 416 | round | Semi bold22  | BarlowCondensedTabular semibold |   22 |
|  416 x 416 | round | Semi bold24  | BarlowCondensedTabular semibold |   24 |
|  416 x 416 | round | Semi bold28  | BarlowCondensedTabular semibold |   28 |
|  416 x 416 | round | Semi bold30  | BarlowCondensedTabular semibold |   30 |
|  416 x 416 | round | Semi bold32  | BarlowCondensedTabular semibold |   32 |
|  416 x 416 | round | Semi bold36  | BarlowCondensedTabular semibold |   36 |
|  416 x 416 | round | Semi bold40  | BarlowCondensedTabular semibold |   40 |
|  416 x 416 | round | Semi bold44  | BarlowCondensedTabular semibold |   44 |
|  416 x 416 | round | Semi bold46  | BarlowCondensedTabular semibold |   46 |
|  416 x 416 | round | Semi bold52  | BarlowCondensedTabular semibold |   52 |
|  416 x 416 | round | Semi bold58  | BarlowCondensedTabular semibold |   58 |
|  416 x 416 | round | Semi bold64  | BarlowCondensedTabular semibold |   64 |
|  416 x 416 | round | Semi bold84  | BarlowCondensedTabular semibold |   84 |
<!-- fonts.md: end -->

Regenerating them:

```sh
make font-sources   # fetch Barlow Condensed from google/fonts and give it tabular figures (needs fontTools)
make fonts          # the bitmaps, fonts.md, fonts.sha256 and the two tables above (needs ttf2bmp and garmin-font-scaler)
make check-fonts    # check all of it against the configuration and source/Draw.mc (Python only)
```

`make font-sources` takes `BarlowCondensed-SemiBold.ttf`, `BarlowCondensed-Bold.ttf` and `OFL.txt` from [`google/fonts`](https://github.com/google/fonts/tree/60824dce48f7dd28fe7d65559f2da1f6e04e585b/ofl/barlowcondensed), `ofl/barlowcondensed/` at commit `60824dce48f7dd28fe7d65559f2da1f6e04e585b`, holds each to its SHA-256 in the `Makefile`, and runs `tools/tabular-figures.py` on the two weights: it points the digits at the font's own tabular figures and renames the family Barlow Condensed Tabular. The results are `resources/fonts/BarlowCondensedTabular-SemiBold.ttf` and `-Bold.ttf`; the same inputs give the same bytes. `tools/tabular-figures.py` needs [fontTools](https://github.com/fonttools/fonttools) 4.60.2 or newer (the committed TTFs were made with 4.60.2; 4.68.0 gives the same bytes), in a virtual environment on Apple's Python, as Homebrew's cannot bootstrap pip on macOS:

```sh
/usr/bin/python3 -m venv .dev/scratchpad/fonttools
.dev/scratchpad/fonttools/bin/pip install fonttools==4.60.2
make font-sources FONTTOOLS_PYTHON=.dev/scratchpad/fonttools/bin/python
```
 `make check-ttf2bmp` and `make check-garmin-font-scaler` check the two font tools, and `make install-ttf2bmp` and `make install-garmin-font-scaler` install them into `~/.local/bin`, as in Climber Time.

Barlow Condensed is copyright 2017 The Barlow Project Authors and licensed under the [SIL Open Font License 1.1](https://openfontlicense.org), in `resources/fonts/OFL-BarlowCondensed.txt`. Barlow Condensed Tabular is a modified version under the same licence; Barlow declares no Reserved Font Name.

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
| `design/widgets.md` | The watch app's reusable drawing parts: profile, ascent, difficulty, altitude, poi, difficulty column, difficulty stack, ascent gauge, gauge, gap ascent, next, front view, the profile zoomed, and the altitude, current difficulty and difficulty column groups |
| `design/page-1.md` | Pages 1 and 1a: the profile alone, with the widgets around it, and zoomed |
| `design/demo/page-1.html` | Interactive mock of page 1, with its options as settings |
| `design/page-2.md` | Pages 2 and 2a: the difficulty column with its altitudes, absolute and relative |
| `design/demo/page-2.html` | Interactive mock of page 2, with its options as settings |
| `design/page-3.md` | Page 3, version 1: ascent and difficulty column side by side |
| `design/demo/page-3.html` | Interactive mock of page 3, with its options as settings |
| `design/page-4.md` | Pages 4 and 4a: the difficulty stack by ascent, with points of interest; 4a inside the ascent gauge |
| `design/page-5.md` | Pages 5 and 5a: the difficulty stack by path, with points of interest; 5a inside the ascent gauge |
| `design/demo/pages-4-5.html` | Interactive mock of pages 4 and 5, the difficulty stack by ascent and by path |
| `design/page-6.md` | Pages 6a and 6b, version 1: the gauge, by length and by ascent |
| `design/demo/page-6.html` | Interactive mock of pages 6a and 6b, with their options |
| `design/page-7.md` | Pages 7 and 7a: the route from the front, and zoomed |
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
| `design/real-functionality.md` | The design for 0.2.0: a real route on the watch, live progress, the climb recorded as a Garmin activity |

`docs/` is kept for user-facing pages, once there is something to use.

## Running the demo

Open `design/demo/index.html` in any modern browser. No build step, no server. Fonts load from Google Fonts when online and fall back to system fonts offline.

The demo uses four routes with rounded figures from public guides. The outlines are schematic sketches, not GPS tracks, and the rest and difficulty positions are placeholders.

## Reading order

1. `design/DESIGN.md`
2. `design/sensing.md` and `design/route-data.md`, the two things most likely to change the design
3. The rest as needed
