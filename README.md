# Ferrata Time

A Garmin Connect IQ watch app for climbing via ferratas. On the watch it is called **Ferrata** and is listed under Activities & Apps; "Ferrata Time" is the project's name. A second app, **Ferrata Demo**, built from the same source, plays a made-up climb (see [Two apps](#two-apps)).

Status: design phase. There is an interactive browser demo, a set of design notes, and a prototype on the watch: Ferrata, which follows a climb by the watch's sensors, and Ferrata Demo, which plays a made-up one.

The notes in `design/` predate two decisions: the project is first a standalone watch app, Ferrata, that records the climb itself, and its screens are pages you move between with the buttons. `design/DESIGN.md` is brought up to date after the first prototype (#2).

Images and fonts are stored with [Git LFS](https://git-lfs.com): install it (`brew install git-lfs`,
then `git lfs install`) before cloning.

Tracked in this repository, and in the family's umbrella as
[`wkusnierczyk/garmin-watch-faces#42`](https://github.com/wkusnierczyk/garmin-watch-faces/issues/42).

CI (`.github/workflows/build.yml`) runs on every push to `main` or a `dev-*` branch and on every pull request from this repository. In our private tester image, with a throwaway signing key, it builds Ferrata, Ferrata Demo and the replay build for the epix Pro (Gen 2) 47 mm, and runs the unit tests in all three in the simulator, under a virtual display. On the runner it runs the tools' tests (below), checks that `make routes` leaves the route files unchanged, and runs `make check-manifests`. Every target device and the store bundle follow once the design and functionality are settled.

## Prototype 0.1.0

Ferrata follows a climb on the pages from the design sketch by the watch's altitude and GPS position; Ferrata Demo plays a made-up climb on the same pages, to judge them on the wrist. Neither records anything yet; the bundled route is invented, and in the demo the times and the position too. Both build for the watches under [Devices](#devices).

### Two apps

One source builds two apps (#140), each with its own app id, name and `.prg`, so both can be on a watch at once:

| | Ferrata | Ferrata Demo |
|---|---|---|
| Reads | the watch's altitude and GPS position, and works out the place on the route from the height climbed and the time | nothing: it plays the made-up climb below |
| Records | the climb, once recording comes (#53) | never |
| Manifest | `manifest.xml` | `manifest-demo.xml`: its own app id and name, and no permissions, as it reads no sensors; the rest as `manifest.xml` (`make check-manifests`) |
| Jungle | `monkey.jungle;ferrata.jungle` | `monkey.jungle;demo.jungle` |
| Build | `make build`, `make sideload`, `make export` | the same with `DEMO=1` |
| Store | the app: `make export` | a beta first, an app of its own under the beta's id: `make export DEMO=1 VERSION=beta`; once the owner is happy with it, the public demo under `manifest-demo.xml`'s id: `make export DEMO=1` |

Which input an app reads is fixed when it is built, not a setting: the Demo climb setting is gone, and neither app has a setting yet. In both the climb starts, pauses and ends through the climb flow below. The demo goes through the same tracker and menus as the sensors, and never records anything: its watch reads 12 m low, and the calibration at the start corrects that, as a real start at a known point would. The build picks the input through `Feed.wantsDemo`, of which `ferrata.jungle` leaves out the `(:demo)` version and `demo.jungle` the `(:nodemo)` one. Ferrata Demo leaves out the sensor input, `SensorInput`, too, so it asks for no permissions. Ferrata carries the rest of the demo (its input, `DemoInput`, and its pace), unused, so the app's unit tests cover it.

### Controls

| Input | Does |
|---|---|
| Up, down | change page during the climb; move in a menu, or step the altitude |
| Start | open the Start menu (ready screen), pause the climb and open its menu, pick the selected row |
| Back | leave at once (ready screen only); during the climb pause it and open its menu; in a menu go back; close SAVED or DISCARDED |
| Hold Up | the Ask list; choosing a question does nothing yet |
| Tap beside the box (page 15) | step to the section before or after; other taps do nothing |

### The climb flow

The screens are drawn by the app (#51), as the flow mock draws them (#121; `design/real-functionality.md`, section 5): every title at the same place and size, white (a grey "at" where the rows say where: START at, CALIBRATE at, END at), figures after the pages' symbols (the path blue, the ascent orange, the stopwatch green), and the menus' selected row in a large pill, its text white and its outline in the row's colour: the head and exits green, the top and End red, calibration light blue. A longer list scrolls with the selected row in the middle. Marks by the buttons on the right say what Start and Back do: a green check by Start, a red cross by Back; on the ready screen a thin green arc along the edge marks Start, as in Garmin's own activities. While the climb is paused, a blue pause symbol (two bars) stands at the top of the pages and of every screen under the pause menu, whose title it is. Every value on these screens follows the watch's units (#144): set to feet, heights and distances are converted (100 m shows as 328 ft, never as 100 ft), and a point's distance shows in feet below 1000 ft, then in miles to one place, as the approach's distance to the head always does; the app never changes the setting, and the route and the climb stay in metres inside. The figures after symbols and the large altitude are laid out for the wider of the two units, so they stand in the same place in either; the summary's line is sized for the unit shown.

- **Ready.** The app opens on the route's name, then its path, ascent and guidebook time. Start opens START at: HEAD, the approach's start by what it is (CAR PARK, TOP STATION; when the route knows its altitude) and ALTITUDE. The first two start there, calibrated to its altitude, on the ferrata or on the approach; ALTITUDE opens the altitude entry at the barometer's reading, and Start there starts on the approach (on a route without one, on the ferrata at that altitude). Back on the ready screen closes the app at once, back to the watch's activities.
- **On the approach** the first page shows the distance and the time left to the head; Up and Down go on to the other pages, which show the approach, and back to it past the first or the last. The distance comes from GPS (#113): a fix counts for 30 s, at the watch's usable accuracy or better. Snapped to the approach's track (its points with `lat` and `lon`: the approach's start, any danger on the way, the head), a fix sets the place and the distance is measured along the track, so walking the wrong way makes it grow. With only the head's coordinates, the distance shown is the straight line to the head; when it is longer than the whole approach and the fix goes, the excess is carried on. A track is used only when it covers the whole approach, that is when the approach's start and the head both have coordinates. Otherwise, and between fixes, the place moves by time and height, at the climber's pace against the approach's guidebook time. The time left is the guidebook time from the place at the climber's pace. Start or Back pauses and offers Continue approach, Start from head (calibrated at the head, a new lap to come with the recording, #53) and End here.
- **On the ferrata**, Start or Back pauses and offers Continue, Calibrate and End. END at offers TOP, EXIT for each exit ahead or within the uncertainty band behind, nearest first, and HERE; each opens its details (its altitude and how far it is, in metres below 1000 m, rounded, then kilometres to one place, or in feet below 1000 ft, then miles; here, the estimated altitude and how far along the route), where Start ends there and Back returns. CALIBRATE at offers the landmark near the place first, when there is one (the head, a landmark, an exit with an altitude or the top, within the band; not one calibrated at already), then LANDMARK, every such point nearest first, and ALTITUDE. A landmark opens its details, titled by what it is (at HEAD, at EXIT, at TOP, or the landmark's type: at REST in blue, at BRIDGE or at SIGN in grey) with its name, altitude and how far it is; Start there calibrates and puts the place at it, however far off the estimate was, and Back returns. An altitude puts the place at the point at that altitude nearest the estimate and corrects the altitude without counting drift. CALIBRATED at then shows the altitude, and the landmark's name in its type's colour, until Start or Back, the climb going on behind it.
- **The altitude entry** shows the altitude alone, starting at the barometer (before a start) or the estimate, at most 100 m outside the route's altitudes, and beside Up and Down the step each makes: the first goes to the next 10 m mark, later ones step 10 m, within the route's lowest and highest altitude; in feet the marks and steps are 50 ft. Start sets it (an altitude entered in feet set in metres), Back returns to the menu.
- **Back** never leaves a climb: it pauses and opens the menu; in the menu it closes it and leaves the climb paused, the pause symbol at the top of the pages. Only Continue resumes.
- **The summary** follows every end: the height climbed, the activity's time (pauses left out) and the drift, each after its symbol, then Save, Resume and Discard. Resume returns to the paused climb as it was before the end; Discard asks once more (DISCARD?, NO or DISCARD). After Save or Discard, SAVED or DISCARDED shows for 3 seconds (Back closes it sooner), then the ready screen. Nothing is recorded yet (#53).
- The GPS prompts, the head's offer on the approach (#113) and a landmark's on the ferrata (#52), are built as menus but not yet triggered.

The climb is the bundled route, `resources/routes/demo.json` (below), counted from the ferrata head: the pages show the ferrata, 640 m long, from the head at 1290 m to the top at 1580 m, climbing 400 m and going down 110 m on the way (the Dihedral, the route's fifth section counting the approach, descends by its height to show a descent, #100), and leave out the 120 m approach: on it they read the ferrata not started, the head next, after the approach's own screen. In the demo a part (the approach, or the ferrata) takes about two minutes, then holds at its end until you end the climb or start the ferrata. It plays at a vertical pace, as on a real via ferrata: each section takes as long as the metres it climbs or descends, so walks pass quickly and walls slowly, up or down, and each grade above walking takes 10 % longer per metre than the one below (a half step 5 %); a rest counts as walking and a flat stretch as 5 m, so both pass in a moment. The pages, in order, as the revised mocks draw them (#95), numbered as the pages mock numbers them (#112): the profile alone (page 1, `design/page-1.md`) and zoomed to 100 m of path around the climber, as large as it fits and centred, the altitude on a half-transparent box, so the route shows through dimmed where it runs under it (page 2), the route from the front (page 3, `design/page-3.md`) and zoomed (page 4), the difficulty column (page 5, `design/page-5.md`) and the same with the altitudes relative to the current section's bottom (page 6), ascent and difficulty column side by side under "NOW" and the altitude (page 7, `design/page-7.md`), the gauge by length and by ascent (pages 12 and 13, `design/page-12.md`), the current difficulty with the ascent gauge (page 14, `design/page-14.md`), a preview of a section the user picks (page 15, `design/page-15.md`; tap beside its difficulty box to step), and the progress in numbers (page 16, `design/page-16.md`): the distance along the path, the ascent and the active time (pauses left out, as on the summary), each as done of the total in the watch's units (metres or feet), `{done} {symbol} {total}`, the path, stairs or a stopwatch in place of "of", then each alone, large, `{symbol} {done}` over `of {total}` (pages 17, 18 and 19). The difficulty stacks, by ascent (pages 8 and 9, `design/page-8.md`) and by path (pages 10 and 11, `design/page-10.md`), are parked, too noisy as a design, and left out of the app: Up and Down go from page 7 to page 12 (#128; their code stays, #110). The prototype's other pages (side profile, ladders, where am I, what's next, time strip, large type) are gone; pages 20 to 37 come back from the mocks one by one. The grades show as the route has them, A to F in half steps (`C/D`), each half step in its own colour, between its two neighbours'. The pages draw in Barlow Semi Condensed, the mocks' typeface (see [Fonts](#fonts)). The dots on the left edge show which page is on screen; they appear when the app opens, when you come back from the Ask list, or when the page changes, and hide after 2 seconds.

Build and install, with the SDK and the developer key in place. The key is looked for beside the main checkout (`../garmin-keys/developer_key`, also from a git worktree); elsewhere, pass it as a variable, `make sideload DEV_KEY=/path/to/developer_key` (make takes variables, not monkeyc's `-y`):

```sh
make build       # FerrataTime.prg for the epix Pro (Gen 2) 47 mm; another watch: make build DEVICE=fenix7x
make run         # build, start the simulator, load it
make test        # build the unit tests (source/tests/), run them in the simulator
make sideload    # build for the watch on USB and copy it over (brew install libmtp)
make export      # export/FerrataTime.iq, the store bundle for every product, signed with the key (about 70 s)
```

Each takes `DEMO=1` for Ferrata Demo: `make build DEMO=1` builds `FerrataTime-demo.prg`, `make sideload DEMO=1` puts it on the watch beside Ferrata, and `make test DEMO=1` runs the unit tests in its build. `DEMO`, `REPLAY` and `VERSION` are read from the command line only, never from the environment.

The store publishes a bundle the moment it is uploaded, so the bundles are named for where they go (playbook, `reference/store.md`):

```sh
make export DEMO=1 VERSION=beta   # export/FerrataTime-demo-beta.iq: Ferrata Demo's store beta
make export DEMO=1                # export/FerrataTime-demo.iq: the public demo, once the beta has served; not before
```

A store beta is an app of its own, with its own id: `BETA_ID` in the `Makefile`, which `tools/export-beta.sh` puts into a copy of the tree, never into `manifest-demo.xml`, and checks in the bundle; the first beta upload creates the beta app in the store under it. Ferrata has no beta. `make check-manifests` (Python only; `make export` runs it first) checks that `manifest-demo.xml` is `manifest.xml` but for the app id, the name and the sensors' permissions: a product added to one is added to both.

`tools/launcher_icon.py` renders the launcher icon, an orange climber with arms raised, clipped to the cable, in Garmin's figure style on a transparent background, from `tools/launcher_icon.svg` (needs `rsvg-convert`: `brew install librsvg` on macOS, `librsvg2-bin` on Linux). Each watch asks for its icon at its own size, so the icons are generated rather than drawn by hand (#133): `make icons` runs `garmin-graphics-generator icons` with `tools/launcher_icon.py` as its renderer, which draws the SVG at every size the supported watches ask for into `resources-icon-<size>/`, the largest also into `resources/drawables/launcher_icon.png`, maps each product in `manifest.xml` to its size in `monkey.jungle`, and writes the table under [Devices](#devices); `make check-icons` checks all of it, the icons' pixels against the drawing too (`tools/launcher_icon.py check`). The generator is not on PyPI: `make install-garmin-graphics-generator` installs it in a virtual environment of its own. Run as a script, `python3 tools/launcher_icon.py <size> <out.png>` draws one size.

## Devices

Ferrata supports a watch when it has all of these (#116, owner, 2026-11-26):

- **Connect IQ API 5.0 or above** (`minApiLevel` in `manifest.xml`). The fonts are bitmaps, 27 per resolution, and from API 4.0 they load into the graphics pool rather than the app's memory; no watch in the catalogue has API 4.x.
- **A barometer.** The app follows the climb by barometric altitude (`design/sensing.md`); without one it has no use.
- **A round colour screen of 280 px or more**, MIP or AMOLED. Below 280 px the smallest text (the units beside the altitudes, 0.0385 of the width) falls to 8–10 px and several pages crowd; the fēnix 7S (240 px) and Forerunner 255S (218 px) were looked at in the simulator and left out, and 240 and 260 px wait for a layout that fits them (#131). Rectangular and semi-octagonal screens are left out too (the Venu X1, #130; the Venu Sq 2; the Instinct 3 Solar and Instinct E; the AMOLED Instincts are round and in).
- **768 KB for a watch app, and the full watchdog.** The Forerunner 255 and 255S have 512 KB and half the watchdog, and stop on page 1's first draw (#132); they and their Music versions are out by size anyway (260 and 218 px).

That gives 54 watches in six resolutions, each with its own font set (`resources-round-<n>x<n>/fonts/`, see [Fonts](#fonts)):

| Resolution | Screen | Watches (`manifest.xml` ids) |
|---|---|---|
| 280 x 280 | MIP | `enduro3`, `enduro4`, `fenix7x`, `fenix7xpro`, `fenix7xpronowifi`, `fenix8solar51mm`, `fenix9prosolar51mm` |
| 360 x 360 | AMOLED | `fr265s`, `venu2s` |
| 390 x 390 | AMOLED | `approachs7042mm`, `descentg2`, `descentmk343mm`, `epix2pro42mm`, `fr165`, `fr165m`, `fr170`, `fr170m`, `fr57042mm`, `instinct3amoled45mm`, `instinctcrossoveramoled`, `marq2`, `marq2aviator`, `venu3s`, `venu441mm` |
| 416 x 416 | AMOLED | `approachs7243mm`, `d2airx10`, `d2mach1`, `epix2`, `epix2pro47mm`, `fenix843mm`, `fenix943mm`, `fenix9pro43mm`, `fenixe`, `fr265`, `instinct3amoled50mm`, `venu2`, `venu2plus` |
| 454 x 454 | AMOLED | `approachs7047mm`, `approachs7247mm`, `d2mach2`, `d2mach2pro`, `descentmk351mm`, `epix2pro51mm`, `fenix847mm`, `fenix8pro47mm`, `fenix947mm`, `fenix9pro47mm`, `fr57047mm`, `fr965`, `fr970`, `marq3`, `venu3`, `venu445mm` |
| 466 x 466 | AMOLED | `fenix9pro51mm` |

Left out for want of a barometer: the vívoactive 5 and 6, the Approach S50, the Bounce 2 (`bounce2`, in the SDK's device reference only) and the Forerunner 70, whose SDK definition lists a pressure history although the watch has no barometer (its elevation is GPS). The MIP watches show 64 colours and no transparency, so the grade colours and page 2's half-transparent box get a MIP palette and fallback (#39). Every watch shows the launcher icon drawn at its own size (#133); CI builds the epix Pro (Gen 2) 47 mm only, until every resolution (#11).

Each supported product is mapped to the icon its device asks for (generated by `make icons`):

| Product                 |    Icon |
| :---------------------- | ------: |
| approachs7047mm         | 70 x 70 |
| d2airx10                | 70 x 70 |
| venu2                   | 70 x 70 |
| venu2plus               | 70 x 70 |
| venu3                   | 70 x 70 |
| venu3s                  | 70 x 70 |
| approachs7247mm         | 65 x 65 |
| d2mach2                 | 65 x 65 |
| d2mach2pro              | 65 x 65 |
| fenix847mm              | 65 x 65 |
| fenix8pro47mm           | 65 x 65 |
| fenix947mm              | 65 x 65 |
| fenix9pro47mm           | 65 x 65 |
| fenix9pro51mm           | 65 x 65 |
| fr57047mm               | 65 x 65 |
| fr965                   | 65 x 65 |
| fr970                   | 65 x 65 |
| marq3                   | 65 x 65 |
| venu445mm               | 65 x 65 |
| venu2s                  | 61 x 61 |
| approachs7042mm         | 60 x 60 |
| approachs7243mm         | 60 x 60 |
| d2mach1                 | 60 x 60 |
| descentg2               | 60 x 60 |
| descentmk343mm          | 60 x 60 |
| descentmk351mm          | 60 x 60 |
| epix2                   | 60 x 60 |
| epix2pro42mm            | 60 x 60 |
| epix2pro47mm            | 60 x 60 |
| epix2pro51mm            | 60 x 60 |
| fenix843mm              | 60 x 60 |
| fenix943mm              | 60 x 60 |
| fenix9pro43mm           | 60 x 60 |
| fenixe                  | 60 x 60 |
| fr265                   | 60 x 60 |
| fr265s                  | 60 x 60 |
| instinct3amoled45mm     | 60 x 60 |
| instinct3amoled50mm     | 60 x 60 |
| marq2                   | 60 x 60 |
| marq2aviator            | 60 x 60 |
| fr165                   | 54 x 54 |
| fr165m                  | 54 x 54 |
| fr170                   | 54 x 54 |
| fr170m                  | 54 x 54 |
| fr57042mm               | 54 x 54 |
| venu441mm               | 54 x 54 |
| enduro3                 | 40 x 40 |
| enduro4                 | 40 x 40 |
| fenix7x                 | 40 x 40 |
| fenix7xpro              | 40 x 40 |
| fenix7xpronowifi        | 40 x 40 |
| fenix8solar51mm         | 40 x 40 |
| fenix9prosolar51mm      | 40 x 40 |
| instinctcrossoveramoled | 38 x 38 |

## Routes

A route is one JSON file, the format of `design/real-functionality.md` (section 4): the approach and the ferrata as sections (`len`, `up`, `grade`, `min`, `name`, `side`) and the points along them (`kind`, `at`, `alt`, `type`, `lat`, `lon`, `name`). The app reads the bundled route, `resources/routes/demo.json` (the 0.1.0 demo climb), when it starts, and its pages show one part of it at a time: the ferrata, from the head, or the approach. Climbed height and the route's total are height gained, the sum of the positive `up`. The profile (page 1) and the front view (page 3) draw the route's real height, down as well as up, the profile from the route's lowest point to its highest; the pages that stack sections by height (the gauge by ascent, pages 13 and 15, and the parked stack by ascent, pages 8 and 9) stack them by height gained, so a section that loses height draws flat there, and the parked stacks' altitude ticks mark where the route rises. Every altitude a page shows is the real one, and so is the climber's place on the ascent widgets (#100): the line beside the profile (pages 1, 2 and 7), the ascent gauge (page 14, and the parked pages 9 and 11) and the ascent along the gauge's gap (pages 12, 13 and 15) show the real height from the head to the top, so the climber's ring pulls back down on a descent, its numbers the real height above the head and the top's less that; amounts climbed (the parked stacks, the gauge by ascent's arcs, the climbed totals) stay height gained. A section that loses height has its grade box drawn as a trapezium narrower at its foot, on every page with grade boxes (1 to 7, 12 to 15), and page 15 shows a descent's start, the higher altitude, above its box. In the bundled demo route the Dihedral descends. Two real routes come with the app too, made from the owner's own recordings, for the route list to pick from (#141; until it lands the app climbs the demo): the Daubenhorn (Leukerbad; `resources/routes/daubenhorn.json`), from the Gemmi top station down a 2400 m approach to the head at the Untere Schmitte (2070 m), then 1545 m of ferrata gaining 841 m, no section going down, to the route book at 2912 m, with an exit at the Obere Freiheit (2303 m); and the Sulzfluh (St. Antönien; `resources/routes/sulzfluh.json`), from the Partnun car park P6 (1700 m, the last public one) up a 2778 m approach to the head at 2366 m, then 595 m of ferrata gaining 451 m to the summit at 2817 m, with no exit. Both carry coordinates on their approach's start, head and top, the Daubenhorn's on its exit too, and on the landmarks the recordings place (all but the Daubenhorn's 2-rope bridge and Via Konst board, until a climb places them). The Sulzfluh's approach, its length and its start's coordinates, comes from bergsteigen.com's planned track from P6, the owner's recording starting at the head. On the approach the distance to the head from GPS (#113) is approximate until the route carries the approach's real track (#143): each route's approach track is only its two ends, a straight line where the path winds. The pages follow the watch's units as the screens do (#148): set to feet, every height and distance on them is converted, never relabelled. The ascent's two numbers (beside the profile's line on pages 1, 2 and 7, on the ascent gauge and along the gauge's gap) are to the metre, or to 5 ft, so the Daubenhorn's 841 m reads 2760 ft; the distance on the next line (pages 3, 4 and 12 to 14) is to 5 m, or to 20 ft, so "C/D 125 m" reads "C/D 420 ft". The ascent's line on the profile and the group on pages 3 and 4 (its altitude and its next line) are laid out for the widest value in the unit shown, so they stay in place during a climb; a change of units may re-lay the page, as it does the summary's line. The pages draw the grades in these half steps (`A/B`, `C/D`), each in its own colour (#95); the K scale is a setting to come (#58). The next hard part is the next one at D or above, by its own grade, so C/D is not hard. A section without `min` gets an estimate by a hiker's rule (DIN 33466: 300 m an hour up, 500 m an hour down, 4 km an hour along; the larger of the two, plus half the smaller; at least a minute). Route files are generated, never edited by hand: each is written from a hand-made source of the same shape, `routes/<id>.src.json`, by `tools/route.py` (Python 3, nothing to install).

```sh
make routes      # every routes/<id>.src.json to resources/routes/<id>.json, with routes/<id>.gpx if there
python3 tools/route.py build routes/<id>.src.json -o resources/routes/<id>.json [--gpx routes/<id>.gpx]
```

A route's GPX track, if it has one, is kept beside its source as `routes/<id>.gpx`, and `make routes` passes it with `--gpx`, which fills each point's missing `lat` and `lon` from the track. The track starts at the approach's start (or at the head, without an approach), and the point `at` metres from the head is placed `at` plus the approach's length along it. Distance along the track counts height: each step from its horizontal distance and the change in the track points' elevations (`<ele>`), which comes close to the length along the cable that a route's lengths measure. A track point without an elevation takes one interpolated, by horizontal distance, between its nearest neighbours that have one (before the first or after the last, the nearest), with a warning saying how many; a track with no elevations at all is measured on the map, as before. This suits tracks whose elevations come from an elevation model; raw GPS or barometric elevations carry noise that makes the track read long and places the points early, and the tool does not smooth them. An `<ele>` that is empty or not a number is an error. The tool warns, without failing, when the track's length, measured the same way, differs from the route's by more than 20 %, and for each point past the track's end, which it places at the end. `make routes` fails on a route file in `resources/routes/` with no source. A track that is someone's own recording is not committed (as with the replay, below): the Daubenhorn's and the Sulzfluh's are the owner's, so they have no `routes/<id>.gpx` (git ignores `routes/*.gpx`: a track there is read by `make routes` but never committed), and their points' `lat` and `lon` are written in the source by hand, read off the recording. In the source:

- `id` is the source's file name, `routes/<id>.src.json`.
- `at` is metres from the head, negative on the approach. `head` (at 0) and `top` (at the ferrata's length) are required; an `approach` point, at minus the approach's length, only with an `approach` list. The `approach` point has a `type`, what it is (`Car park`, `Top station`, `Village`), which the Start menu shows in its place, and every landmark has one of `rest`, `bridge` or `sign`, which its details show (#121); no other point has one. Exits and landmarks sit on the boundaries between the ferrata's sections (not on the approach, and not at the head or the top). `lat` and `lon` come together, within -90..90 and -180..180. Other kinds are kept as they are and not checked, but for their `name`, folded as below.
- `grade` is in half steps, as the topo writes it: 1 A, 2 A/B, 3 B … 11 F, 12 F/G; 0 walking, -1 rest.
- `up` may be negative. Between points with an `alt`, the sections' `up` must add up to the altitude difference within 15 m.
- `min`, the guidebook's minutes for a section, may be left out; `len` and `min` are above 0, `side` from -1.0 to 1.0, `short` (the activity's name) 1 to 15 characters.
- Names (`name`, `short`, `place`, every section's and point's `name`, points of any kind, and every point's `type`) are folded to the characters the app's fonts carry: letters A to Z and a to z, digits, space and `' ( ) + , - . / : > ? ~ ° · – …`. Accents are dropped (ü to u, é to e, ç to c), special letters spelled out (ß to ss, æ to ae, ø to o, œ to oe, ł to l, þ to th), quotes of every kind written as `'` (the fonts have no double quote), the en dash kept, other dashes and the minus as `-`, the fraction slash as `/`, the micro sign as `u`, and invisible marks (soft hyphens, zero-width spaces and joiners, variation selectors) dropped; any other character is an error naming the field and the character. `short` is counted after folding.

The tool lists every problem it finds and writes nothing. The tools' tests, this one's and the replay tool's (below): `python3 -m pytest tools/tests`, with `pytest` and Garmin's FIT SDK for Python installed (`pip install -r tools/requirements.txt`, in a virtual environment); CI runs them and checks that `make routes` leaves the route files unchanged.

## Replay

A replay build plays a recorded climb through the tracker in the simulator, faster than real time, in the place of the watch's sensors: the end-to-end test of calibration, place and pace while the routes are closed. Simulator only, and Ferrata's, not the demo's (`REPLAY=1` takes no `DEMO=1`): it never records anything, `make sideload` refuses it, and the app's own build (`make build`) carries no recording and never plays one (it holds the `ReplayInput` class, unused, so the unit tests reach it). The recording is a FIT file (an activity recorded on a Garmin watch, with barometric altitude), which `tools/fit2replay.py` turns into `resources-replay/replay.json`: an entry every 10 s, and one at the end, `[t, alt, lat, lon]` (the local time of day in seconds, the altitude in whole metres, the position in degrees to 5 decimals), each interpolated between the records around it that have it, across any gap, and `null` before the first or after the last record that has it. Entries are written only where the recording has records: across a gap (the watch stopped, or a stretch without records) there are none, and the replay interpolates across it; the tool warns when a replay runs to more than 5000 entries (about 14 hours, some 300 KB of the watch app's 768 KB when loaded). The replay plays 60 times faster than the recording, a minute of the climb a second, so a 5 h 40 climb takes under 6 minutes, and then holds at its end. A recording is someone's own track: `resources-replay/replay.json` and every `.fit` file are ignored by git, and neither is ever committed.

```sh
pip install -r tools/requirements.txt   # the FIT SDK for Python, garmin-fit-sdk (in a virtual environment)
make replay FIT=/path/to/track.fit      # resources-replay/replay.json; PYTHON=... names the interpreter
make run REPLAY=1                       # FerrataTime-replay.prg, the replay in the simulator
make test REPLAY=1                      # the unit tests in the replay build, on that recording
```

In a replay build the replay stands in for the sensors, and starts as they do, through the climb flow: the recording plays from its start when a climb starts (the Start menu and the altitude entry only look at its first altitude), and again from its start for the next climb, after Save or Discard. The route climbed is still the demo's, not the recorded one's, until the route list (#141) picks the Daubenhorn.

## Fonts

The app draws every page in its own bitmap fonts made from [Barlow Semi Condensed](https://github.com/jpt/barlow), the typeface of the mocks, in SemiBold for text and numbers and in Bold for the difficulty boxes and the words beside them, instead of the watch's system fonts (#62). It was Barlow Condensed until the owner picked Semi Condensed as more readable (#109). Its figures are tabular, as the mocks set them (`font-variant-numeric: tabular-nums`): every digit has one width, so a number that counts does not shift.

A text the mock draws at `font-size: N` at 416 px draws on the watch at N px too, with the same cap height (0.7 of N) and the same advances to the nearest pixel: `ttf2bmp`'s size is the em, as CSS's `font-size` is, and `make fonts` rounds each glyph's advance to the nearest pixel where `ttf2bmp` rounds it up.

The sizes are one table, `resources/fonts/sizes.json`: each font's weight, its size as a share of the screen's width (the designs are in proportions), its pixels at the 416 px reference, and its glyphs. `tools/font-config.py` writes from it `resources/fonts/fonts.xml`, `resources/fonts/charsets.json` and `source/FontSizes.mc`, which nobody edits by hand. A page asks for a size in the table (`d.semi(share)`, `d.bold(share)`, `Fonts` in `source/Draw.mc`), and `make check-fonts` fails on one that is not; a widget drawn at a factor (the current difficulty group at 1.5 on pages 3, 4 and 14) gets the nearest size, the larger on a tie. The mocks use only these sizes, rounding a scaled one the same way, so what a mock shows is what the watch draws:

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
| `SemiBold52` | SemiBold | 0.1250 (12.50 %) | 52 | values |
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

Text fonts hold only what the app draws (owner, 2026-11-22): the letters A to Z and a to z, the digits, the space and `' ( ) + , - . / : > ? ~ ° · – …`, the punctuation the code and the mock pages use (parentheses, comma and period come from route names such as "Grosser Spalt (var. E)"; the question mark from a call sign where the route has no emergency number, the en dash from a time not known yet, `–:––`). Route names cannot be predicted, so the route tool folds accented letters to plain ones and rejects anything else the fonts lack (#84); `make check-fonts` fails on a string literal in `source/` outside this set. Number fonts hold the digits, `:`, `-`, `–` and the space; the 52 px one, which the flow's rows of figures share with the pages (owner, 2026-11-26), also `.` and the letters of "here" (`values`); grade fonts the box letters and digits (A to F with half steps such as `C/D`, `K1` to `K6` and `K3/4`, `R`, `W`, `E`).

The reference resolution is 416x416, the epix Pro (Gen 2) 47 mm's, in `resources/fonts/resolutions.json`: `resources/fonts/fonts.xml` gives each font's size there in pixels (the share times 416), and [`garmin-font-scaler`](https://github.com/wkusnierczyk/garmin-font-scaler) derives every other resolution's from it with [`ttf2bmp`](https://github.com/wkusnierczyk/ttf2bmp). Every supported resolution is a target (see [Devices](#devices)): 280, 360, 390, 416, 454 and 466. The sizes by resolution, as the scaler writes them to `fonts.md`:

<!-- fonts.md: start -->
| Resolution | Shape |   Element    |                Font                 | Size |
| ---------: | :---- | :----------- | :---------------------------------- | ---: |
|  280 x 280 | round | Bold18       | BarlowSemiCondensedTabular bold     |   12 |
|  280 x 280 | round | Bold20       | BarlowSemiCondensedTabular bold     |   13 |
|  280 x 280 | round | Bold24       | BarlowSemiCondensedTabular bold     |   16 |
|  280 x 280 | round | Bold26       | BarlowSemiCondensedTabular bold     |   18 |
|  280 x 280 | round | Bold28       | BarlowSemiCondensedTabular bold     |   19 |
|  280 x 280 | round | Bold30       | BarlowSemiCondensedTabular bold     |   20 |
|  280 x 280 | round | Bold34       | BarlowSemiCondensedTabular bold     |   23 |
|  280 x 280 | round | Bold36       | BarlowSemiCondensedTabular bold     |   24 |
|  280 x 280 | round | Bold52       | BarlowSemiCondensedTabular bold     |   35 |
|  280 x 280 | round | Bold70       | BarlowSemiCondensedTabular bold     |   47 |
|  280 x 280 | round | Semi bold104 | BarlowSemiCondensedTabular semibold |   70 |
|  280 x 280 | round | Semi bold16  | BarlowSemiCondensedTabular semibold |   11 |
|  280 x 280 | round | Semi bold18  | BarlowSemiCondensedTabular semibold |   12 |
|  280 x 280 | round | Semi bold20  | BarlowSemiCondensedTabular semibold |   13 |
|  280 x 280 | round | Semi bold22  | BarlowSemiCondensedTabular semibold |   15 |
|  280 x 280 | round | Semi bold24  | BarlowSemiCondensedTabular semibold |   16 |
|  280 x 280 | round | Semi bold28  | BarlowSemiCondensedTabular semibold |   19 |
|  280 x 280 | round | Semi bold30  | BarlowSemiCondensedTabular semibold |   20 |
|  280 x 280 | round | Semi bold32  | BarlowSemiCondensedTabular semibold |   22 |
|  280 x 280 | round | Semi bold36  | BarlowSemiCondensedTabular semibold |   24 |
|  280 x 280 | round | Semi bold40  | BarlowSemiCondensedTabular semibold |   27 |
|  280 x 280 | round | Semi bold44  | BarlowSemiCondensedTabular semibold |   30 |
|  280 x 280 | round | Semi bold46  | BarlowSemiCondensedTabular semibold |   31 |
|  280 x 280 | round | Semi bold52  | BarlowSemiCondensedTabular semibold |   35 |
|  280 x 280 | round | Semi bold58  | BarlowSemiCondensedTabular semibold |   39 |
|  280 x 280 | round | Semi bold64  | BarlowSemiCondensedTabular semibold |   43 |
|  280 x 280 | round | Semi bold84  | BarlowSemiCondensedTabular semibold |   57 |
|  360 x 360 | round | Bold18       | BarlowSemiCondensedTabular bold     |   16 |
|  360 x 360 | round | Bold20       | BarlowSemiCondensedTabular bold     |   17 |
|  360 x 360 | round | Bold24       | BarlowSemiCondensedTabular bold     |   21 |
|  360 x 360 | round | Bold26       | BarlowSemiCondensedTabular bold     |   22 |
|  360 x 360 | round | Bold28       | BarlowSemiCondensedTabular bold     |   24 |
|  360 x 360 | round | Bold30       | BarlowSemiCondensedTabular bold     |   26 |
|  360 x 360 | round | Bold34       | BarlowSemiCondensedTabular bold     |   29 |
|  360 x 360 | round | Bold36       | BarlowSemiCondensedTabular bold     |   31 |
|  360 x 360 | round | Bold52       | BarlowSemiCondensedTabular bold     |   45 |
|  360 x 360 | round | Bold70       | BarlowSemiCondensedTabular bold     |   61 |
|  360 x 360 | round | Semi bold104 | BarlowSemiCondensedTabular semibold |   90 |
|  360 x 360 | round | Semi bold16  | BarlowSemiCondensedTabular semibold |   14 |
|  360 x 360 | round | Semi bold18  | BarlowSemiCondensedTabular semibold |   16 |
|  360 x 360 | round | Semi bold20  | BarlowSemiCondensedTabular semibold |   17 |
|  360 x 360 | round | Semi bold22  | BarlowSemiCondensedTabular semibold |   19 |
|  360 x 360 | round | Semi bold24  | BarlowSemiCondensedTabular semibold |   21 |
|  360 x 360 | round | Semi bold28  | BarlowSemiCondensedTabular semibold |   24 |
|  360 x 360 | round | Semi bold30  | BarlowSemiCondensedTabular semibold |   26 |
|  360 x 360 | round | Semi bold32  | BarlowSemiCondensedTabular semibold |   28 |
|  360 x 360 | round | Semi bold36  | BarlowSemiCondensedTabular semibold |   31 |
|  360 x 360 | round | Semi bold40  | BarlowSemiCondensedTabular semibold |   35 |
|  360 x 360 | round | Semi bold44  | BarlowSemiCondensedTabular semibold |   38 |
|  360 x 360 | round | Semi bold46  | BarlowSemiCondensedTabular semibold |   40 |
|  360 x 360 | round | Semi bold52  | BarlowSemiCondensedTabular semibold |   45 |
|  360 x 360 | round | Semi bold58  | BarlowSemiCondensedTabular semibold |   50 |
|  360 x 360 | round | Semi bold64  | BarlowSemiCondensedTabular semibold |   55 |
|  360 x 360 | round | Semi bold84  | BarlowSemiCondensedTabular semibold |   73 |
|  390 x 390 | round | Bold18       | BarlowSemiCondensedTabular bold     |   17 |
|  390 x 390 | round | Bold20       | BarlowSemiCondensedTabular bold     |   19 |
|  390 x 390 | round | Bold24       | BarlowSemiCondensedTabular bold     |   22 |
|  390 x 390 | round | Bold26       | BarlowSemiCondensedTabular bold     |   24 |
|  390 x 390 | round | Bold28       | BarlowSemiCondensedTabular bold     |   26 |
|  390 x 390 | round | Bold30       | BarlowSemiCondensedTabular bold     |   28 |
|  390 x 390 | round | Bold34       | BarlowSemiCondensedTabular bold     |   32 |
|  390 x 390 | round | Bold36       | BarlowSemiCondensedTabular bold     |   34 |
|  390 x 390 | round | Bold52       | BarlowSemiCondensedTabular bold     |   49 |
|  390 x 390 | round | Bold70       | BarlowSemiCondensedTabular bold     |   66 |
|  390 x 390 | round | Semi bold104 | BarlowSemiCondensedTabular semibold |   98 |
|  390 x 390 | round | Semi bold16  | BarlowSemiCondensedTabular semibold |   15 |
|  390 x 390 | round | Semi bold18  | BarlowSemiCondensedTabular semibold |   17 |
|  390 x 390 | round | Semi bold20  | BarlowSemiCondensedTabular semibold |   19 |
|  390 x 390 | round | Semi bold22  | BarlowSemiCondensedTabular semibold |   21 |
|  390 x 390 | round | Semi bold24  | BarlowSemiCondensedTabular semibold |   22 |
|  390 x 390 | round | Semi bold28  | BarlowSemiCondensedTabular semibold |   26 |
|  390 x 390 | round | Semi bold30  | BarlowSemiCondensedTabular semibold |   28 |
|  390 x 390 | round | Semi bold32  | BarlowSemiCondensedTabular semibold |   30 |
|  390 x 390 | round | Semi bold36  | BarlowSemiCondensedTabular semibold |   34 |
|  390 x 390 | round | Semi bold40  | BarlowSemiCondensedTabular semibold |   38 |
|  390 x 390 | round | Semi bold44  | BarlowSemiCondensedTabular semibold |   41 |
|  390 x 390 | round | Semi bold46  | BarlowSemiCondensedTabular semibold |   43 |
|  390 x 390 | round | Semi bold52  | BarlowSemiCondensedTabular semibold |   49 |
|  390 x 390 | round | Semi bold58  | BarlowSemiCondensedTabular semibold |   54 |
|  390 x 390 | round | Semi bold64  | BarlowSemiCondensedTabular semibold |   60 |
|  390 x 390 | round | Semi bold84  | BarlowSemiCondensedTabular semibold |   79 |
|  416 x 416 | round | Bold18       | BarlowSemiCondensedTabular bold     |   18 |
|  416 x 416 | round | Bold20       | BarlowSemiCondensedTabular bold     |   20 |
|  416 x 416 | round | Bold24       | BarlowSemiCondensedTabular bold     |   24 |
|  416 x 416 | round | Bold26       | BarlowSemiCondensedTabular bold     |   26 |
|  416 x 416 | round | Bold28       | BarlowSemiCondensedTabular bold     |   28 |
|  416 x 416 | round | Bold30       | BarlowSemiCondensedTabular bold     |   30 |
|  416 x 416 | round | Bold34       | BarlowSemiCondensedTabular bold     |   34 |
|  416 x 416 | round | Bold36       | BarlowSemiCondensedTabular bold     |   36 |
|  416 x 416 | round | Bold52       | BarlowSemiCondensedTabular bold     |   52 |
|  416 x 416 | round | Bold70       | BarlowSemiCondensedTabular bold     |   70 |
|  416 x 416 | round | Semi bold104 | BarlowSemiCondensedTabular semibold |  104 |
|  416 x 416 | round | Semi bold16  | BarlowSemiCondensedTabular semibold |   16 |
|  416 x 416 | round | Semi bold18  | BarlowSemiCondensedTabular semibold |   18 |
|  416 x 416 | round | Semi bold20  | BarlowSemiCondensedTabular semibold |   20 |
|  416 x 416 | round | Semi bold22  | BarlowSemiCondensedTabular semibold |   22 |
|  416 x 416 | round | Semi bold24  | BarlowSemiCondensedTabular semibold |   24 |
|  416 x 416 | round | Semi bold28  | BarlowSemiCondensedTabular semibold |   28 |
|  416 x 416 | round | Semi bold30  | BarlowSemiCondensedTabular semibold |   30 |
|  416 x 416 | round | Semi bold32  | BarlowSemiCondensedTabular semibold |   32 |
|  416 x 416 | round | Semi bold36  | BarlowSemiCondensedTabular semibold |   36 |
|  416 x 416 | round | Semi bold40  | BarlowSemiCondensedTabular semibold |   40 |
|  416 x 416 | round | Semi bold44  | BarlowSemiCondensedTabular semibold |   44 |
|  416 x 416 | round | Semi bold46  | BarlowSemiCondensedTabular semibold |   46 |
|  416 x 416 | round | Semi bold52  | BarlowSemiCondensedTabular semibold |   52 |
|  416 x 416 | round | Semi bold58  | BarlowSemiCondensedTabular semibold |   58 |
|  416 x 416 | round | Semi bold64  | BarlowSemiCondensedTabular semibold |   64 |
|  416 x 416 | round | Semi bold84  | BarlowSemiCondensedTabular semibold |   84 |
|  454 x 454 | round | Bold18       | BarlowSemiCondensedTabular bold     |   20 |
|  454 x 454 | round | Bold20       | BarlowSemiCondensedTabular bold     |   22 |
|  454 x 454 | round | Bold24       | BarlowSemiCondensedTabular bold     |   26 |
|  454 x 454 | round | Bold26       | BarlowSemiCondensedTabular bold     |   28 |
|  454 x 454 | round | Bold28       | BarlowSemiCondensedTabular bold     |   31 |
|  454 x 454 | round | Bold30       | BarlowSemiCondensedTabular bold     |   33 |
|  454 x 454 | round | Bold34       | BarlowSemiCondensedTabular bold     |   37 |
|  454 x 454 | round | Bold36       | BarlowSemiCondensedTabular bold     |   39 |
|  454 x 454 | round | Bold52       | BarlowSemiCondensedTabular bold     |   57 |
|  454 x 454 | round | Bold70       | BarlowSemiCondensedTabular bold     |   76 |
|  454 x 454 | round | Semi bold104 | BarlowSemiCondensedTabular semibold |  113 |
|  454 x 454 | round | Semi bold16  | BarlowSemiCondensedTabular semibold |   17 |
|  454 x 454 | round | Semi bold18  | BarlowSemiCondensedTabular semibold |   20 |
|  454 x 454 | round | Semi bold20  | BarlowSemiCondensedTabular semibold |   22 |
|  454 x 454 | round | Semi bold22  | BarlowSemiCondensedTabular semibold |   24 |
|  454 x 454 | round | Semi bold24  | BarlowSemiCondensedTabular semibold |   26 |
|  454 x 454 | round | Semi bold28  | BarlowSemiCondensedTabular semibold |   31 |
|  454 x 454 | round | Semi bold30  | BarlowSemiCondensedTabular semibold |   33 |
|  454 x 454 | round | Semi bold32  | BarlowSemiCondensedTabular semibold |   35 |
|  454 x 454 | round | Semi bold36  | BarlowSemiCondensedTabular semibold |   39 |
|  454 x 454 | round | Semi bold40  | BarlowSemiCondensedTabular semibold |   44 |
|  454 x 454 | round | Semi bold44  | BarlowSemiCondensedTabular semibold |   48 |
|  454 x 454 | round | Semi bold46  | BarlowSemiCondensedTabular semibold |   50 |
|  454 x 454 | round | Semi bold52  | BarlowSemiCondensedTabular semibold |   57 |
|  454 x 454 | round | Semi bold58  | BarlowSemiCondensedTabular semibold |   63 |
|  454 x 454 | round | Semi bold64  | BarlowSemiCondensedTabular semibold |   70 |
|  454 x 454 | round | Semi bold84  | BarlowSemiCondensedTabular semibold |   92 |
|  466 x 466 | round | Bold18       | BarlowSemiCondensedTabular bold     |   20 |
|  466 x 466 | round | Bold20       | BarlowSemiCondensedTabular bold     |   22 |
|  466 x 466 | round | Bold24       | BarlowSemiCondensedTabular bold     |   27 |
|  466 x 466 | round | Bold26       | BarlowSemiCondensedTabular bold     |   29 |
|  466 x 466 | round | Bold28       | BarlowSemiCondensedTabular bold     |   31 |
|  466 x 466 | round | Bold30       | BarlowSemiCondensedTabular bold     |   34 |
|  466 x 466 | round | Bold34       | BarlowSemiCondensedTabular bold     |   38 |
|  466 x 466 | round | Bold36       | BarlowSemiCondensedTabular bold     |   40 |
|  466 x 466 | round | Bold52       | BarlowSemiCondensedTabular bold     |   58 |
|  466 x 466 | round | Bold70       | BarlowSemiCondensedTabular bold     |   78 |
|  466 x 466 | round | Semi bold104 | BarlowSemiCondensedTabular semibold |  116 |
|  466 x 466 | round | Semi bold16  | BarlowSemiCondensedTabular semibold |   18 |
|  466 x 466 | round | Semi bold18  | BarlowSemiCondensedTabular semibold |   20 |
|  466 x 466 | round | Semi bold20  | BarlowSemiCondensedTabular semibold |   22 |
|  466 x 466 | round | Semi bold22  | BarlowSemiCondensedTabular semibold |   25 |
|  466 x 466 | round | Semi bold24  | BarlowSemiCondensedTabular semibold |   27 |
|  466 x 466 | round | Semi bold28  | BarlowSemiCondensedTabular semibold |   31 |
|  466 x 466 | round | Semi bold30  | BarlowSemiCondensedTabular semibold |   34 |
|  466 x 466 | round | Semi bold32  | BarlowSemiCondensedTabular semibold |   36 |
|  466 x 466 | round | Semi bold36  | BarlowSemiCondensedTabular semibold |   40 |
|  466 x 466 | round | Semi bold40  | BarlowSemiCondensedTabular semibold |   45 |
|  466 x 466 | round | Semi bold44  | BarlowSemiCondensedTabular semibold |   49 |
|  466 x 466 | round | Semi bold46  | BarlowSemiCondensedTabular semibold |   52 |
|  466 x 466 | round | Semi bold52  | BarlowSemiCondensedTabular semibold |   58 |
|  466 x 466 | round | Semi bold58  | BarlowSemiCondensedTabular semibold |   65 |
|  466 x 466 | round | Semi bold64  | BarlowSemiCondensedTabular semibold |   72 |
|  466 x 466 | round | Semi bold84  | BarlowSemiCondensedTabular semibold |   94 |
<!-- fonts.md: end -->

Regenerating them:

```sh
make font-sources   # fetch Barlow Semi Condensed from google/fonts and give it tabular figures (needs fontTools)
make fonts          # the bitmaps, fonts.md, fonts.sha256 and the two tables above (needs ttf2bmp and garmin-font-scaler)
make check-fonts    # check all of it against the configuration and source/Draw.mc (Python only)
```

`make font-sources` takes `BarlowSemiCondensed-SemiBold.ttf`, `BarlowSemiCondensed-Bold.ttf` and `OFL.txt` from [`google/fonts`](https://github.com/google/fonts/tree/60824dce48f7dd28fe7d65559f2da1f6e04e585b/ofl/barlowsemicondensed), `ofl/barlowsemicondensed/` at commit `60824dce48f7dd28fe7d65559f2da1f6e04e585b`, holds each to its SHA-256 in the `Makefile`, and runs `tools/tabular-figures.py` on the two weights: it points the digits at the font's own tabular figures and renames the family Barlow Semi Condensed Tabular. The results are `resources/fonts/BarlowSemiCondensedTabular-SemiBold.ttf` and `-Bold.ttf`; the same inputs give the same bytes. It then writes `source/DigitInk.mc` with `tools/digit-ink.py`: the left side of the number glyphs' ink, from the SemiBold's outlines, which keeps the ascent's numbers on pages 1 and 2 on the round screen (#109); `tools/tests/test_digit_ink.py` holds it to the TTF. `tools/tabular-figures.py` needs [fontTools](https://github.com/fonttools/fonttools) 4.60.2 or newer (the committed TTFs were made with 4.60.2), in a virtual environment on Apple's Python, as Homebrew's cannot bootstrap pip on macOS:

```sh
/usr/bin/python3 -m venv .dev/scratchpad/fonttools
.dev/scratchpad/fonttools/bin/pip install fonttools==4.60.2
make font-sources FONTTOOLS_PYTHON=.dev/scratchpad/fonttools/bin/python
```
 `make check-ttf2bmp` and `make check-garmin-font-scaler` check the two font tools, and `make install-ttf2bmp` and `make install-garmin-font-scaler` install them into `~/.local/bin`, as in Climber Time.

Barlow Semi Condensed is copyright 2017 The Barlow Project Authors and licensed under the [SIL Open Font License 1.1](https://openfontlicense.org), in `resources/fonts/OFL-BarlowSemiCondensed.txt`. Barlow Semi Condensed Tabular is a modified version under the same licence; Barlow declares no Reserved Font Name.

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
| `design/demo/pages.html` | The pages mock: every page, 1 to 37, live on one grid, the parked ones (8 to 11) framed red |
| `design/page-1.md` | Pages 1 and 2: the profile alone, with the widgets around it, and zoomed |
| `design/demo/page-1.html` | Interactive mock of pages 1 and 2, with their options as settings |
| `design/page-3.md` | Pages 3 and 4, version 1: the route from the front, and zoomed |
| `design/demo/page-3.html` | Interactive mock of pages 3 and 4, with their options as settings |
| `design/page-5.md` | Pages 5 and 6: the difficulty column with its altitudes, absolute and relative |
| `design/demo/page-5.html` | Interactive mock of pages 5 and 6, with their options as settings |
| `design/page-7.md` | Page 7, version 1: ascent and difficulty column side by side |
| `design/demo/page-7.html` | Interactive mock of page 7, with its options as settings |
| `design/page-8.md` | Pages 8 and 9: the difficulty stack by ascent, with points of interest; 9 inside the ascent gauge (parked, not in the app: #110, #128) |
| `design/page-10.md` | Pages 10 and 11: the difficulty stack by path, with points of interest; 11 inside the ascent gauge (parked, not in the app: #110, #128) |
| `design/demo/pages-8-11.html` | Interactive mock of pages 8 to 11, the difficulty stack by ascent and by path |
| `design/page-12.md` | Pages 12 and 13, version 1: the gauge, by length and by ascent |
| `design/demo/page-12.html` | Interactive mock of pages 12 and 13, with their options |
| `design/page-14.md` | Page 14, version 1: the current difficulty with the ascent gauge |
| `design/demo/page-14.html` | Interactive mock of page 14, with its options as settings |
| `design/page-15.md` | Page 15, version 1: a preview of a section the user picks |
| `design/demo/page-15.html` | Interactive mock of page 15, with its chevrons |
| `design/page-16.md` | Pages 16 to 19: progress as done and total, with symbols |
| `design/demo/page-16.html` | Interactive mock of pages 16 to 19: the numbers, the distance, the ascent and the time |
| `design/demo/page-20.html` | Interactive mock of page 20: the time per difficulty |
| `design/demo/page-21.html` | Interactive mock of page 21: the ascent per difficulty |
| `design/demo/page-22.html` | Interactive mock of pages 22 and 23: the margin to the last departure, and as durations |
| `design/demo/page-24.html` | Interactive mock of pages 24 and 25: the daylight, and as durations |
| `design/demo/page-26.html` | Interactive mock of pages 26 and 27: the battery, and as durations |
| `design/demo/page-28.html` | Interactive mock of pages 28 to 31: the next exit, the next rest, the next danger, and to the top |
| `design/demo/page-32.html` | Interactive mock of pages 32 to 34: the vertical speed, against the previous climb and against a partner |
| `design/demo/page-35.html` | Interactive mock of pages 35 and 36: moving and resting, and with the total below |
| `design/demo/page-37.html` | Interactive mock of page 37: the hard climbing still ahead |
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
