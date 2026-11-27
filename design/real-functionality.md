# Real functionality (0.2.0)

Status: agreed with the owner 2026-11-21; the climb flow and the approach on the pages 2026-11-25; not yet built
Builds on: the 0.1.0 prototype (pages 1 to 15, then numbered 1 to 9, as revised for 0.1.0 in #16 to #28, and the demo clock)

0.1.0 is a demo: one made-up route in `source/Climb.mc`, and a clock that walks the climber up it. 0.2.0 makes the app usable on a real via ferrata: a real route on the watch, the climber's real progress, and the climb saved as a Garmin activity.

## Contents

1. [Intent](#1-intent)
2. [Goals, non-goals, anti-goals](#2-goals-non-goals-anti-goals)
3. [Approaches considered](#3-approaches-considered)
4. [Route file](#4-route-file)
5. [Climb flow](#5-climb-flow)
6. [Altitude calibration](#6-altitude-calibration)
7. [Progress estimate](#7-progress-estimate)
8. [Recording](#8-recording)
9. [Code structure](#9-code-structure)
10. [Later: library and route builder](#10-later-library-and-route-builder)
11. [Left to the builder](#11-left-to-the-builder)
12. [Open questions](#12-open-questions)

## 1. Intent

Three things stand between the prototype and a climb:

1. **Route in.** The watch needs a real route's sections, known points and exits.
2. **Live progress.** The pages need the climber's real place on the route, from the watch's sensors.
3. **Recording.** The climb must end up in Garmin Connect as an activity, synced through the phone like any other.

The design rests on `sensing.md`: climbed height and elapsed time are the measured numbers; position on the route is an estimate and is shown as one.

## 2. Goals, non-goals, anti-goals

Goals:

- One real route bundled with the app: **Daubenhorn** (Leukerbad), which the owner has climbed and recorded (2025-08-07, a FIT file with barometric altitude). It has an exit (the Obere Freiheit), landmarks, variants, and stretches that lose height on both the approach and the ferrata (owner, 2026-11-21; the Fürenwand, earlier proposed, only climbs and has no exit, so it would leave those paths untested). The Fürenwand's data is kept for the later library.
- A **replay input**: the owner's recorded climb fed through the tracker in the simulator, faster than real time, as the end-to-end test of calibration, place, pace and the menus while the routes are closed for the season.
- A route file format that also serves the later library and route builder (section 10) unchanged.
- Start, pause, continue and end a climb on the watch, with the approach optional.
- Altitude calibrated at the route's known points, by the app's own offset.
- The pages driven by the real estimate. Their look has moved on since 0.1.0 (#95, #100, #109); page numbers here are the pages mock's 1 to 37, as in the design pages (#112).
- The climb saved as a Garmin activity: mountaineering, named after the route, approach and ascent as laps.
- The demo still runs, in the simulator and on the watch, through the same code path.
- Lite only, on the epix Pro (Gen 2) 47 mm, as today (owner). Other watches come once the app's memory, processing and storage needs are known, chosen by hardware, capabilities and screen resolution. A fēnix 7X Solar sideload (MIP, 280 px, 64 colours) is a look-only check of the pages, not a supported device. Its first look (owner, 2026-11-21): readable and stable, no crashes; the amber heat scale is poor in 64 colours, so a MIP palette is needed before MIP watches are supported.

Non-goals for 0.2.0:

- The route library and the route builder (designed later, section 10).
- A companion phone app.
- GPS matched to the track as a position signal on the ferrata. On the approach, open terrain, GPS gives the distance to the head (#113).
- More than one route, or choosing a route on the watch.
- Premium, and the Lite/Premium split.
- Other watches (above).
- A via ferrata activity type at Garmin (to ask for once the app is production-ready).

Anti-goals (a failure even if it works):

- Changing the watch's altimeter calibration. The app keeps its own offset; the device's settings and Garmin's auto-calibration are untouched.
- Calibrating altitude, or switching approach to ascent, without the climber confirming.
- Progress going backwards on its own, or a confident position the data does not support (`sensing.md`, section 4). The one exception is a calibration the climber makes (section 6).
- Losing a climb by accident. Back during a climb opens the menu rather than leaving (section 5), and the tracker state is kept in storage, so after a crash or a restart the app resumes the climb's progress. Connect IQ cannot save a recording partway and keep adding to it, so an unsaved recording is lost when the app stops; on resume a new session starts under the same name, paused, beginning with an ascent or approach lap as the phase was, so one climb becomes two activities. That is accepted (my call, after the builder check).

## 3. Approaches considered

| Decision | Options | Picked |
|---|---|---|
| Route in | (a) compiled into the app from a `tools/` script; (b) fetched from GitHub Pages | (a) for 0.2.0. (b) is the later library and reuses the format |
| Position | (a) climbed height, time across flat stretches, forward-only; (b) height blended with GPS matched to the track | (a) on the ferrata. GPS strays on walls (`sensing.md`); (b) only if the recordings show it helps. The approach uses GPS for the distance to the head (#113) |
| Demo and real | (a) one tracker, two inputs: real sensors or simulated; (b) replace the demo | (a). The simulator and the demo keep exercising every page |
| Route builder (later) | (a) a web page; (b) a companion phone app with a desktop mirror over Wi-Fi | (a) first, (b) considered later (owner). The page is cheaper: no two phone platforms, no local server |
| Activity sport | mountaineering, rock climbing (sub-sport bouldering) | Mountaineering: a long effort with position and altitude. Bouldering records short attempts on problems |

## 4. Route file

This format supersedes the proposal in `DESIGN.md` section 8 (outline, profile and markers as arc-length fractions) and the size targets in `route-data.md` section 3, which were for that outline-based format: geometry here is only the sections' `side` and the points' coordinates, so a route is smaller.

One JSON file per route. The `tools/` script writes it; the app reads it as a JSON resource (`Rez.JsonData`) in 0.2.0, and from storage once routes are downloaded (section 10).

It carries what the pages read today from `Climb.mc`, plus the known points:

```json
{
  "format": 1,
  "id": "fuerenwand",
  "name": "Daubenhorn",
  "short": "Daubenhorn",
  "place": "Engelberg OW",
  "source": {"geometry": "...", "elevation": "swisstopo", "text": "link to the SAC page, no prose"},
  "approach": [
    {"len": 120, "up": 20, "grade": 0, "min": 12, "name": "Approach", "side": -1.0}
  ],
  "sections": [
    {"len": 35, "up": 90, "grade": 6, "min": 20, "name": "First wall", "side": -0.3}
  ],
  "points": [
    {"kind": "approach", "at": -120, "alt": 1015, "type": "Car park", "lat": 46.8, "lon": 8.4, "name": "Car park"},
    {"kind": "head",     "at": 0,    "alt": 1035, "lat": 46.8, "lon": 8.4, "name": "Untere Schmitte"},
    {"kind": "landmark", "at": 330,  "alt": 1180, "type": "rest", "lat": 46.8, "lon": 8.4, "name": "Bench"},
    {"kind": "exit",     "at": 440,  "alt": 1290, "lat": 46.8, "lon": 8.4, "name": "Band exit"},
    {"kind": "danger",   "at": 55,   "name": "Loose rock"},
    {"kind": "top",      "at": 640,  "alt": 1850, "lat": 46.8, "lon": 8.4, "name": "Top"}
  ]
}
```

The numbers above are placeholders, not the Daubenhorn's.

- `sections` are the ferrata, from the head to the top; `approach` (optional) are the sections before the head. The pages always show the ferrata: `sections` replace `LEN`, `UP`, `GRADE`, `MIN`, `NAME` and `SIDE`, so the pages' helpers (`dAt`, `uAt`, `totalU` and the rest) count from the head. On the approach the ferrata reads not started, and the `approach` sections serve only the distance and time to the head (section 7, *On the approach*). `grade` is the topo's grade as written, in half steps (owner, 2026-11-21: keep, do not round): 1 A, 2 A/B, 3 B, 4 B/C, 5 C, 6 C/D, 7 D, 8 D/E, 9 E, 10 E/F, 11 F, 12 F/G; 0 walking (W), -1 rest. Walking is the approach's: the head is the boundary, so a flat walk after it takes a ferrata grade (owner, 2026-11-25), and the script rejects 0 in `sections`. Rests are encoded only this way; there is no `rest` point kind. A variant section carries the normal line's grade, the harder one in its name.
- `points` replace `EXIT_AT`, `EXIT_NAME`, `DANGER_AT` and `START_ALT`. `at` is metres from the head: negative on the approach, so the `approach` point sits at minus the approach's length. Exits and landmarks lie on section boundaries (the script checks), since the pages index exits by section. `alt`, `lat` and `lon` are optional: a point with `alt` is a **known point**, where the climber can calibrate; a point with `lat` and `lon` can prompt by GPS. The `approach` point carries its `type`, what it is (`Car park`, `Top station`, `Village`): the Start menu names it so, never by its own name; every `landmark` carries its `type`, one of `rest`, `bridge` and `sign`, by which its details are titled (REST blue as the pages' rests, BRIDGE and SIGN grey) (owner, #121).
- Kinds: `approach`, `head`, `landmark` (a point partway with a known altitude, for a mid-climb calibration: a bench, a ladder base, a bridge), `danger`, `exit`, `top`. The app ignores kinds it does not know, so later kinds do not break older apps (my call).
- `up` may be negative, for down-climbs, traverses and clefts that lose height: the Daubenhorn loses height on its approach (Gemmi 2348 to 2070) and twice on the ferrata (owner's recording). **Climbed** is height gained: the sum of the positive `up`, as Garmin reports ascent, and the route's total is the same sum. The pages that stack sections by height (the difficulty columns, the stack, the gauge by ascent) stack by gained height, so a section that loses height draws as flat there; the profile (page 1) draws the real height, down as well as up. The position estimate maps the **net** height measured since the head onto the route ahead (section 7).
- `head` and `top` are required; `approach`, landmarks and exits are optional.
- `short`: the activity name, at most 15 characters (the SDK's suggested maximum for a session name).

The script takes a GPX track and a hand-written file with the sections and points, fills missing altitudes from swisstopo where useful, and checks that the sections add up to the known points' altitudes within a tolerance. The file stays a few KB (`route-data.md`, section 3).

## 5. Climb flow

The flow as mocked and picked (owner, 2026-11-22/23; #51), its screens revised screen by screen (owner, 2026-11-26; #121, F1 to F26): https://claude.ai/artifact/2VzLQcS7pNgvmsHApnFb18

```
Ready screen ─ Start ─▶ START at ─┬─ HEAD ───────────────────────▶ ASCENT    (calibrated: head)
                                  ├─ <approach point's type> ─────▶ APPROACH  (calibrated: that point; only if it has an altitude)
                                  └─ ALTITUDE ─▶ altitude entry ──▶ APPROACH  (calibrated: the altitude entered)
                                         │
                            Start button │  or GPS within about 50 m of the head:
                                         │  vibrate and offer the first two, without pausing (once): HEAD?
                                         ▼
                                  ┌─ Continue approach
                                  ├─ Start from head ─▶ ASCENT (calibrated: head)
                                  └─ End here ─▶ summary   (from the pause menu only)

ASCENT ─ Start button ─▶ PAUSED ─┬─ Continue
                                 ├─ Calibrate ─▶ CALIBRATE at ─┬─ <landmark nearby> ─▶ its details ─▶ calibrated
                                 │                             ├─ LANDMARK ─▶ at LANDMARK, nearest first ─▶ details ─▶ calibrated
                                 │                             └─ ALTITUDE ─▶ altitude entry ─▶ calibrated
                                 └─ End ───────▶ END at ───────┬─ TOP  ─▶ its details ─▶ summary   (check: top)
                                                               ├─ EXIT ─▶ its details ─▶ summary   (check: exit; one row per exit ahead or in the band)
                                                               └─ HERE ─▶ its details ─▶ summary   (no check)

Back during APPROACH or ASCENT ─▶ PAUSED, the same menu as Start
GPS within about 50 m of a landmark ahead ─▶ PAUSED, Calibrate selected
summary ─▶ Save, Resume or Discard
```

- **The screens** follow the revised mock (#121). Every title sits at the ready screen's place and size, white, with a grey "at" where the rows say where (START at, CALIBRATE at, END at, at ALTITUDE, at LANDMARK, CALIBRATED at). Figures stand after the pages' symbols (the path blue, the ascent orange, the stopwatch green, an altitude after a peak, the drift after an up-and-down arrow). Marks by the buttons on the right say what they do: a green check by Start, a red cross by Back, each on a half-transparent square; on the ready screen a thin green arc along the edge by Start, as Garmin's own activities have (owner, 2026-11-26). While the climb is paused, a blue pause symbol, two bars with no disk, stands at the top of the pages and of every screen under the pause menu; it is the pause menu's title.
- **Before Start**, a ready screen: the route's name, then its path, ascent and guidebook time after their symbols, and a thin green arc by Start. Back there closes the app at once, back to the watch's activities (owner, 2026-11-26: no APP CLOSED). Back in the Start menu returns to the ready screen.
- **Start** offers HEAD, the approach's start by its type (TOP STATION, CAR PARK; section 4), only when the route knows that point's altitude, and ALTITUDE. The first two calibrate to their altitude. ALTITUDE opens the altitude entry at the barometer's reading, so Start at once starts on the approach without a change; Back there returns to the Start menu. On a route with no approach, ALTITUDE starts the ascent at the point at that altitude nearest the head (my call).
- **The font**, menus and pages alike, is Barlow Semi Condensed (owner, 2026-11-25; #109).
- **The menus** are drawn by the app in the pages' colours and font. The selected row is one large pill, its label white, one line, the outline alone in the row's colour: the head and exits green, the top and End red, calibration light blue, a landmark its type's (REST blue, BRIDGE and SIGN grey). DISCARD, the one destructive row, has its pill filled red. A list longer than four rows scrolls with the selected row in the middle.
- **On the approach**, its own screen (F4: the distance and the time to the head) is the first page, and Up and Down go on to the pages, which show the approach (section 7), and past either end of them back to it (owner, 2026-11-26). A climb on the approach starts on it, and the ferrata on its first page. Start pauses and offers Continue approach, Start from head and End here, which ends at once. Within about 50 m of the head (GPS) the watch vibrates and offers the first two without pausing, once (HEAD?); nothing happens until the climber chooses, and Back closes the offer and the approach goes on.
- **On the ferrata**, Start pauses and offers Continue, Calibrate and End. END at offers TOP, one EXIT row per exit, and HERE. An exit's row shows only while the exit is ahead or within the uncertainty band behind, nearest first, so an estimate that ran ahead does not hide the exit the climber is at. Each opens its details (titled at TOP, at EXIT with the exit's name, or HERE): its altitude and how far it is, or here the estimated altitude and how far along the route. Start there ends, Back returns.
- **Calibrate** is there at any place on the ferrata. It opens with the most likely first: near a landmark (within the band, or about 50 m by GPS) that landmark by name, then LANDMARK, then ALTITUDE; elsewhere only the last two. A landmark already calibrated at is not suggested again. For the suggestion and the LANDMARK list, the head and the top count as landmarks; only `landmark` points prompt by GPS.
- **LANDMARK** lists the head, the landmarks, the exits and the top, nearest to the estimated place first, by name. Picking one, there or as Calibrate's suggestion, opens its details, titled by what it is (at REST, at BRIDGE, at SIGN, at HEAD, at EXIT, at TOP) with its name, its altitude and how far ahead or back it is. Start there calibrates there however far off the estimate is; Back returns.
- **ALTITUDE** starts at the estimated altitude and shows it alone, with the step each of Up and Down would make beside them. The first Up or Down rounds it to the next 10 m mark up or down; later presses step 10 m. It stays within the route's lowest and highest altitude, approach included; a barometer reading outside that range shows as it is, and the first press brings it in (my call), both steps then showing that change. The place moves to the point at that altitude nearest the estimate. Start sets it; Back returns to the menu it came from (Calibrate, or Start).
- **After a calibration** the place and the drift change, and a confirmation, CALIBRATED at with the altitude, and the landmark's name in its type's colour when it was one, stays until Start or Back; the climb goes on behind it.
- **Nearing a landmark**: GPS within about 50 m of a `landmark` point ahead (it needs `lat` and `lon`, section 4) vibrates and opens the pause menu once, with Calibrate selected, which then offers that landmark first. This pauses the climb, as the Start button would; the owner accepted it (#51). No such prompt within about 50 m after a calibration.
- **Back** never leaves a climb: it pauses and opens the same menu. Back in a submenu or a point's details returns to its menu; in the pause menu it closes the menu and leaves the climb paused (the pause symbol at the top of the pages). While paused with the menu closed, Start or Back reopens the menu; only Continue resumes. Back on the summary does nothing.
- **The summary** follows every end: the route's name, then the height climbed, the time and the drift after their symbols, then Save, Resume and Discard, in that order, so Discard is last. Resume returns to the paused climb as it was before the end, the end's check undone. Discard asks once more (DISCARD?, NO or DISCARD). After Save or Discard, SAVED or DISCARDED for 3 s (Back closes it sooner), then the ready screen.
- GPS proximity never acts on its own: it vibrates and opens or offers a menu; the climber chooses. The one effect it has is the landmark prompt's pause.
- The Start button pauses, as in Garmin's own activities; an approach-only activity may be saved.
- The approach and the ascent are separate laps.

### Grades on the watch

- The watch shows grades on the topos' scale, A to F with half steps ("C/D"), by default; walking, the approach, is W. A setting, changeable on the watch, switches to the K scale (A K1, B K2, C K3, D K4, E K5, F K6, half steps as "K3/4"); the owner is indifferent, so A to F is the default.
- The pages' colours follow the half steps: each half step sits between its two neighbours on the existing scale.
- "Hard" (the pages' next hard section, the hardest ahead) is D and above, as K4 and above was in the demo (my call).

## 6. Altitude calibration

The climber's action is **Calibrate** (owner, 2026-11-23: Garmin's own word for the altimeter, and every option corrects the altitude), not Sync.

- The app reads the watch's altitude and adds its own **offset**. The watch's own calibration is not touched.
- Every start calibrates: at the head or the approach's start point to its altitude, or At altitude to the altitude entered (unchanged, the offset is 0). There is no uncalibrated state any more (the 0.2.0 plan's "unsynced" altitude went with the Elsewhere start).
- At a known point the offset becomes `known altitude − watch altitude`; At altitude sets it from the altitude the climber enters.
- Calibrating at a landmark also sets the place to the landmark's `at`, which may move it back, because the climber said where they are, and resets the uncertainty band (my call, after review: a confirmed landmark is the strongest position fix there is, `sensing.md` section 3). At altitude moves the place to the point at that altitude nearest the estimate.
- The change in offset at each calibration at a known point, after the first, is **drift** since the previous one; an entered altitude is a guess, so it resets the offset without counting as drift (my call). It is kept and saved with the activity: approach drift at the head, climb drift at the top or exit.
- At the end, the check against the top's or exit's known altitude is recorded, not applied to the climb already done.
- A calibration can move the shown altitude by a few metres at once. That is expected; apart from a calibration, progress stays forward-only.

## 7. Progress estimate

Inputs: climbed height since the head (calibrated altitude minus the head's), elapsed time, and the route.

**Counting from the head** (owner): "climbed", the route's total and the pages' bars count from the ferrata head, matching the published total. The pages show the ferrata only; on the approach it reads not started (*On the approach* below).

- **Height to place.** Height maps to a stretch of the route: from the first distance at or ahead of the current place reaching that height to the last before the route next leaves it (`firstDistanceAt` and `lastDistanceAt` exist but assume a rising route; with descents they search only ahead of the current place). On a climb the stretch is short; on a traverse it is long.
- **Time across flats.** Within that stretch, the place advances with elapsed time at the climber's pace against the guidebook minutes.
- **Forward-only.** The place never moves back on its own; only a calibration the climber makes may move it back (section 6).
- **Uncertainty.** The band shown on the pages is the width of the stretch plus a drift allowance that grows with time since the last calibration, replacing the demo's fixed `UNCERTAINTY`.
- **Pace.** Elapsed time so far against the guidebook minutes for the part done. **Paused time counts as climbing time** for pace and time left, because guidebook times include rests. The recorded activity still pauses as Garmin does (section 8). This is to be tried on a real climb (owner, 2026-11-21).
- **Time left** is the guidebook minutes still ahead, scaled by that pace.

During the approach, the distance and time to the head come from GPS where it can, else from time at the climber's pace against the approach's guidebook minutes (*On the approach* below).

### On the approach (#90)

Owner's decisions, 2026-11-22 to 2026-11-25, mocked in the pages mock (https://claude.ai/artifact/25DgbSs6bbNuALdcyw3X5A, "Start on the approach"):

- **Every page is there on the approach** (owner, 2026-11-26): after the approach's own screen (F4, section 5), which comes first, as below.
- **The head is the boundary.** Everything before it is the approach, graded W (walking); everything after it is the ferrata, so a flat walk after the head is graded as the ferrata's section (A), not W.
- **The ferrata reads not started**: 0 climbed, the whole route ahead. Nothing shows a height from the approach; the ferrata's own heights stay (the 0 and total ascent, the column's border altitudes, the section preview's altitudes).
- **The current grade is W**, the ferrata's first section next.
- **No climber outline** on the route drawings: they draw the ferrata only, so there is no place for it until the head. Drawing the approach, with the outline on it, is parked (#111).
- **The head as the next point**, its distance and the time to it at the climber's pace, on pages 1–7 and 12–15 only: on pages 5–7 as one line, "HEAD in {distance} {time}". Pages 16 and later show no head. Pages 20 and 21 have no row for the head: they show the grades, and the approach is not one.
- **The activity covers everything**, the approach included: pages 35 and 36 count the walk-in as moving time.
- The distance to the head comes from GPS where it can (#113): along the route's track, else straight to the head, else from the place, which time and height move. A fix counts for 30 s, at the watch's usable accuracy (`Position.QUALITY_USABLE`) or better; older or worse, time and height move the place on from where the last fix put the climber. Snapped to the track, a fix sets the place, and the distance may grow: walking the wrong way shows as a longer way to the head (owner, 2026-11-27). The part's first fix does not count the stretch between the assumed place and the fix as walked, so a start in the wrong place leaves the pace as it was. Straight to the head is the distance shown only: it is no place on the route, so time and height still move the place, and the time to the head is the guidebook time from there at the climber's pace. Straight to the head farther than the whole approach puts the place at the approach's start, and when the fix goes the metres beyond it are carried, taken off first by time at the approach's average pace; the next fix or the ferrata clears them. The track is the approach's points with `lat` and `lon` (the approach's start, any danger on it, the head), which `route.py` places from the GPX track; the fix is snapped to the lines between them and the distance taken along them in the route's metres. A track that does not cover the whole approach (no coordinates on the head, or none on the approach's start) is not used: then the distance is the straight line to the head when the head has coordinates, else the place's.
- The approach's guidebook time and length come from the route data (`approach`), as the route's author gives them.
- The forecasts (arrival, margin to the last departure, daylight, battery) include the rest of the approach, so they move with the estimates as the climber walks it.

## 8. Recording

- `ActivityRecording.createSession` with `:sport => Activity.SPORT_MOUNTAINEERING` (in the SDK since API 3.2.0; the manifest needs 5.0.0) and `:name` set to the route's name, for example "Daubenhorn".
- `:name` is the route's `short` name.
- The manifest gains the `Fit`, `FitContributor`, `Positioning` and `Sensor` permissions.
- Start, pause, continue and stop follow the climb flow; the activity timer pauses on pause.
- Laps: one for the approach, one for the ascent.
- Custom fields (`FitContributor`): per record, the section index and the estimated place along the route (numbers: record messages take no strings); per session, the last calibration's offset and the total drift, so the climb can be reviewed in Garmin Connect and compared with the ground-truth data.
- The phone uploads the saved activity to Garmin Connect; nothing in the app handles the upload.

## 9. Code structure

- **Route.** `Climb.mc`'s constants become variables filled from the loaded route, one part at a time (approach or ferrata, section 4). The helpers the pages use (`dAt`, `uAt`, `mAt`, `count`, `heightAtDistance`, the exits and dangers) keep their meaning within the part shown, so the pages change as little as possible.
- **Tracker.** Owns the climb state (approach, ascent, paused, ended), the offset and drift, the place estimate and the pace. `Climb.State` today is built from one guidebook minute and derives everything from it; it gains a second way to be built, from the tracker's independent values (place, height, elapsed time, start clock, pace, uncertainty band), and the pages read the band from the state instead of the constant `Climb.UNCERTAINTY`. The demo input keeps the minute-based way. It takes readings from an **input**:
  - the **sensor input**: the watch's altitude, position and the clock;
  - the **demo input**: the 0.1.0 simulated climb on the bundled route, producing the same readings. The demo goes through the same menus but never records a Garmin activity, so demo runs do not reach Garmin Connect (my call).
  - the **replay input** (simulator only): a recorded climb's barometric altitude, position and timestamps, played back faster than real time, never recorded. The recording is converted on the computer into a compact resource by a `tools/` script; it is not shipped in release builds.
- **Recorder.** Wraps the session, laps and custom fields; driven by the tracker's state changes.
- **Menus.** Views the app draws (not `Menu2`), in the pages' style: the ready screen, the Start menu, the altitude entry, the approach's pause menu and the head offer, the pause menu with its End and Calibrate submenus, the At landmark list, the CALIBRATED confirmation, the summary and Discard's confirmation, driven from the app's existing delegate.

## 10. Later: library and route builder

Not in 0.2.0, but the route file is designed for them.

- **Library.** A set of static files: an index and one route file each, at a URL. The app's settings hold the library URL, defaulting to ours; anyone may host their own copy (a fork) and point the setting at it. The watch app downloads a route through the phone's connection and keeps one or two in storage.
- **Route builder.** A web page first (the converter site in `converter-site.md`): the climber gives a GPX file, a screenshot of the route's topo and the description text; an LLM turns them into a route file; the climber reviews and corrects it before it is used. It publishes into a library or under a short code the watch app can fetch. Open there: who pays for the LLM calls and holds the key.
- **Companion phone app** (the owner's sketch: phone app with a desktop mirror over Wi-Fi, the same inputs and the LLM step, transfer to the watch): considered after the web page.

## 11. Left to the builder

- What the tracker state in storage holds, and how often it is written.
- Whether altitude comes from `Activity.Info.altitude` or from pressure in `Sensor.Info`, and the sampling rate.
- How compact the resource is.
- The drift allowance in the uncertainty band, until the ground-truth data sets it.
- How the demo input is selected (a setting, or the simulator only).

## 12. Open questions

- The Daubenhorn's section list: about 60 graded pitches from the topo, grouped into sections with heights from the owner's recording; how to mark variants (Grosser Spalt E, Via Konst bypass) until the format has them.
- Whether a recorded mountaineering activity shows in Garmin Connect with the expected icon and our name: one sideloaded test recording.
- The GPS prompt radius (about 50 m proposed) on the real wall.
