# Real functionality (0.2.0)

Status: agreed with the owner 2026-11-21, not yet built
Builds on: the 0.1.0 prototype (pages 1 to 9 as revised for 0.1.0 in #16 to #28, and the demo clock)

0.1.0 is a demo: one made-up route in `source/Climb.mc`, and a clock that walks the climber up it. 0.2.0 makes the app usable on a real via ferrata: a real route on the watch, the climber's real progress, and the climb saved as a Garmin activity.

## Contents

1. [Intent](#1-intent)
2. [Goals, non-goals, anti-goals](#2-goals-non-goals-anti-goals)
3. [Approaches considered](#3-approaches-considered)
4. [Route file](#4-route-file)
5. [Climb flow](#5-climb-flow)
6. [Altitude sync](#6-altitude-sync)
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

- One real route bundled with the app: **Fürenwand** (Engelberg), the route the ground-truth plan and the owner's recordings are about.
- A route file format that also serves the later library and route builder (section 10) unchanged.
- Start, pause, continue and end a climb on the watch, with the approach optional.
- Altitude synced to the route's known points, by the app's own offset.
- The pages 1 to 9 driven by the real estimate, unchanged in look.
- The climb saved as a Garmin activity: mountaineering, named after the route, approach and ascent as laps.
- The demo still runs, in the simulator and on the watch, through the same code path.
- Lite only, on the epix Pro (Gen 2) 47 mm, as today (owner). Other watches come once the app's memory, processing and storage needs are known, chosen by hardware, capabilities and screen resolution. A fēnix 7X Solar sideload (MIP, 280 px, 64 colours) is a look-only check of the pages, not a supported device. Its first look (owner, 2026-11-21): readable and stable, no crashes; the amber heat scale is poor in 64 colours, so a MIP palette is needed before MIP watches are supported.

Non-goals for 0.2.0:

- The route library and the route builder (designed later, section 10).
- A companion phone app.
- GPS matched to the track as a position signal.
- More than one route, or choosing a route on the watch.
- Premium, and the Lite/Premium split.
- Other watches (above).
- A via ferrata activity type at Garmin (to ask for once the app is production-ready).

Anti-goals (a failure even if it works):

- Changing the watch's altimeter calibration. The app keeps its own offset; the device's settings and Garmin's auto-calibration are untouched.
- Syncing altitude, or switching approach to ascent, without the climber confirming.
- Progress going backwards on its own, or a confident position the data does not support (`sensing.md`, section 4). The one exception is a landmark sync the climber confirms (section 6).
- Losing a climb by accident. Back during a climb opens the menu rather than leaving (section 5), and the tracker state is kept in storage, so after a crash or a restart the app resumes the climb's progress. Connect IQ cannot save a recording partway and keep adding to it, so an unsaved recording is lost when the app stops; on resume a new session starts under the same name, paused, beginning with an ascent or approach lap as the phase was, so one climb becomes two activities. That is accepted (my call, after the builder check).

## 3. Approaches considered

| Decision | Options | Picked |
|---|---|---|
| Route in | (a) compiled into the app from a `tools/` script; (b) fetched from GitHub Pages | (a) for 0.2.0. (b) is the later library and reuses the format |
| Position | (a) climbed height, time across flat stretches, forward-only; (b) height blended with GPS matched to the track | (a). GPS strays on walls (`sensing.md`); (b) only if the Fürenwand recordings show it helps |
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
  "name": "Fürenwand",
  "short": "Fürenwand",
  "place": "Engelberg OW",
  "source": {"geometry": "...", "elevation": "swisstopo", "text": "link to the SAC page, no prose"},
  "approach": [
    {"len": 120, "up": 20, "grade": 0, "min": 12, "name": "Approach", "side": -1.0}
  ],
  "sections": [
    {"len": 35, "up": 90, "grade": 3, "min": 20, "name": "First wall", "side": -0.3}
  ],
  "points": [
    {"kind": "approach", "at": -120, "alt": 1015, "lat": 46.8, "lon": 8.4, "name": "Car park"},
    {"kind": "head",     "at": 0,    "alt": 1035, "lat": 46.8, "lon": 8.4, "name": "Fürenwand"},
    {"kind": "landmark", "at": 330,  "alt": 1180, "lat": 46.8, "lon": 8.4, "name": "Bench"},
    {"kind": "exit",     "at": 440,  "alt": 1290, "lat": 46.8, "lon": 8.4, "name": "Band exit"},
    {"kind": "danger",   "at": 55,   "name": "Loose rock"},
    {"kind": "top",      "at": 640,  "alt": 1850, "lat": 46.8, "lon": 8.4, "name": "Top"}
  ]
}
```

The numbers above are placeholders, not Fürenwand's.

- `sections` are the ferrata, from the head to the top; `approach` (optional) are the sections before the head. Each list replaces `LEN`, `UP`, `GRADE`, `MIN`, `NAME` and `SIDE` while the climber is on that part, so the pages' helpers (`dAt`, `uAt`, `totalU` and the rest) count from the start of the part shown: from the head during the ascent. `grade` keeps the demo's coding: 0 walking, 1 to 5 K1 to K5, -1 rest. Rests are encoded only this way; there is no `rest` point kind.
- `points` replace `EXIT_AT`, `EXIT_NAME`, `DANGER_AT` and `START_ALT`. `at` is metres from the head: negative on the approach, so the `approach` point sits at minus the approach's length. Exits and landmarks lie on section boundaries (the script checks), since the pages index exits by section. `alt`, `lat` and `lon` are optional: a point with `alt` is a **known point** and can sync altitude; a point with `lat` and `lon` can prompt by GPS.
- Kinds: `approach`, `head`, `landmark` (a point partway with a known altitude, for a mid-climb sync: a bench, a ladder base, a bridge), `danger`, `exit`, `top`. The app ignores kinds it does not know, so later kinds do not break older apps (my call).
- `up` may be negative in the format, for down-climbs and bridges that lose height, so library routes need no format change (my call). The 0.2.0 pages stack sections by height and assume it only rises, so in 0.2.0 the script rejects negative `up` and the route total is the plain sum, which then equals the gross ascent; pages that draw descents come with the first route that needs them.
- `head` and `top` are required; `approach`, landmarks and exits are optional.
- `short`: the activity name, at most 15 characters (the SDK's suggested maximum for a session name).

The script takes a GPX track and a hand-written file with the sections and points, fills missing altitudes from swisstopo where useful, and checks that the sections add up to the known points' altitudes within a tolerance. The file stays a few KB (`route-data.md`, section 3).

## 5. Climb flow

```
Route loaded ─ Start ─┬─ At ferrata head ───────────────▶ ASCENT    (sync: head)
                      ├─ At <approach point> ─▶ APPROACH  (sync: approach point; only if it has an altitude)
                      └─ Elsewhere ─▶ APPROACH            (no sync)
                                         │
                            Start button │  or GPS within about 50 m of the head:
                                         │  vibrate and open the same menu
                                         ▼
                                  ┌─ Continue approach
                                  └─ Start ferrata ascent ─▶ ASCENT (sync: head)

APPROACH ─ Start button ─▶ PAUSED ─ menu above, plus  End here ─▶ summary

ASCENT ─ Start button ─▶ PAUSED ─┬─ Continue
                                 ├─ Sync here    (at a landmark: sync to its altitude and place, continue)
                                 ├─ End at top   ─▶ summary   (check: top)
                                 ├─ End at exit  ─▶ summary   (check: exit, if known)
                                 └─ End here     ─▶ summary   (no check)

Back during APPROACH, ASCENT or PAUSED ─▶ the same menu as Start
summary ─▶ Save or Discard
```

- "At <approach point>" shows only when the route's `approach` point has an altitude; "Elsewhere" is any other place, with no sync until the head (my call, after review).
- The Start button pauses in both phases, as in Garmin's own activities (the owner's flow); the menu opens paused.
- "End at exit" lists the exits within the uncertainty band or ahead of it, nearest first, so an estimate that ran ahead does not hide the exit the climber is at.
- "Sync here" lists the landmarks within the uncertainty band or the nearest by GPS. GPS within about 50 m of a landmark vibrates and opens the pause menu, as at the head (owner, 2026-11-21).
- "End here" ends anywhere, for a retreat or turning back on the approach, with no altitude check (my call, after review). An approach-only activity may be saved.
- Back never leaves a climb: it opens the menu, and the only way out is an End (my call).
- GPS proximity never acts on its own: it vibrates and opens the menu; the climber chooses.
- After the summary: save or discard, as in Garmin's own activities.
- The approach and the ascent are separate laps.

## 6. Altitude sync

- The app reads the watch's altitude and adds its own **offset**. The watch's calibration is not touched.
- At a known point the climber confirms (section 5), and the offset becomes `known altitude − watch altitude`.
- A confirmed landmark sync also sets the place to the landmark's `at`, which may move it back once, because the climber said where they are, and resets the uncertainty band (my call, after review: a confirmed landmark is the strongest position fix there is, `sensing.md` section 3).
- The change in offset at each sync after the first is **drift** since the previous one. It is kept and saved with the activity: approach drift at the head, climb drift at the top or exit.
- At the end, the check against the top's or exit's known altitude is recorded, not applied to the climb already done.
- Before the first sync (started elsewhere, no known approach start), altitude shows as unsynced: the watch's own reading, marked as such.
- A sync can move the shown altitude by a few metres at once. That is expected; apart from a landmark sync, progress stays forward-only.

## 7. Progress estimate

Inputs: climbed height since the head (synced altitude minus the head's), elapsed time, and the route.

**Counting from the head** (owner): "climbed", the route's total and the pages' bars count from the ferrata head, matching the published total. The approach is shown only while the climber is on it, as its own stretch before the head; once the ascent starts, the pages show the ferrata.

- **Height to place.** Height maps to a stretch of the route: from the first distance at or ahead of the current place reaching that height to the last before the route next leaves it (`firstDistanceAt` and `lastDistanceAt` exist but assume a rising route; with descents they search only ahead of the current place). On a climb the stretch is short; on a traverse it is long.
- **Time across flats.** Within that stretch, the place advances with elapsed time at the climber's pace against the guidebook minutes.
- **Forward-only.** The place never moves back.
- **Uncertainty.** The band shown on the pages is the width of the stretch plus a drift allowance that grows with time since the last sync, replacing the demo's fixed `UNCERTAINTY`.
- **Pace.** Elapsed time so far against the guidebook minutes for the part done. **Paused time counts as climbing time** for pace and time left, because guidebook times include rests. The recorded activity still pauses as Garmin does (section 8). This is to be tried on a real climb (owner, 2026-11-21).
- **Time left** is the guidebook minutes still ahead, scaled by that pace.

During the approach, progress along the approach sections uses the same rule; if the climber started elsewhere, the approach progress is time-based only until the head.

## 8. Recording

- `ActivityRecording.createSession` with `:sport => Activity.SPORT_MOUNTAINEERING` (in the SDK since API 3.2.0; the manifest needs 5.0.0) and `:name` set to the route's name, for example "Fürenwand".
- `:name` is the route's `short` name.
- The manifest gains the `Fit`, `FitContributor`, `Positioning` and `Sensor` permissions.
- Start, pause, continue and stop follow the climb flow; the activity timer pauses on pause.
- Laps: one for the approach, one for the ascent.
- Custom fields (`FitContributor`): per record, the section index and the estimated place along the route (numbers: record messages take no strings); per session, the last sync offset and the total drift, so the climb can be reviewed in Garmin Connect and compared with the ground-truth data.
- The phone uploads the saved activity to Garmin Connect; nothing in the app handles the upload.

## 9. Code structure

- **Route.** `Climb.mc`'s constants become variables filled from the loaded route, one part at a time (approach or ferrata, section 4). The helpers the pages use (`dAt`, `uAt`, `mAt`, `count`, `heightAtDistance`, the exits and dangers) keep their meaning within the part shown, so the pages change as little as possible.
- **Tracker.** Owns the climb state (approach, ascent, paused, ended), the offset and drift, the place estimate and the pace. `Climb.State` today is built from one guidebook minute and derives everything from it; it gains a second way to be built, from the tracker's independent values (place, height, elapsed time, start clock, pace, uncertainty band), and the pages read the band from the state instead of the constant `Climb.UNCERTAINTY`. The demo input keeps the minute-based way. It takes readings from an **input**:
  - the **sensor input**: the watch's altitude, position and the clock;
  - the **demo input**: the 0.1.0 simulated climb on the bundled route, producing the same readings. The demo goes through the same menus but never records a Garmin activity, so demo runs do not reach Garmin Connect (my call).
- **Recorder.** Wraps the session, laps and custom fields; driven by the tracker's state changes.
- **Menus.** The start menu, the approach menu, the pause menu and the end summary, in the app's existing delegate.

## 10. Later: library and route builder

Not in 0.2.0, but the route file is designed for them.

- **Library.** A set of static files: an index and one route file each, at a URL. The app's settings hold the library URL, defaulting to ours; anyone may host their own copy (a fork) and point the setting at it. The watch app downloads a route through the phone's connection and keeps one or two in storage.
- **Route builder.** A web page first (the converter site in `converter-site.md`): the climber gives a GPX file, a screenshot of the route's topo and the description text; an LLM turns them into a route file; the climber reviews and corrects it before it is used. It publishes into a library or under a short code the watch app can fetch. Open there: who pays for the LLM calls and holds the key.
- **Companion phone app** (the owner's sketch: phone app with a desktop mirror over Wi-Fi, the same inputs and the LLM step, transfer to the watch): considered after the web page.

## 11. Left to the builder

- What the tracker state in storage holds, and how often it is written.
- Whether altitude comes from `Activity.Info.altitude` or from pressure in `Sensor.Info`, and the sampling rate.
- How compact the resource is.
- The menus' look, within the app's existing style.
- The drift allowance in the uncertainty band, until the ground-truth data sets it.
- How the demo input is selected (a setting, or the simulator only).

## 12. Open questions

- Fürenwand's real data: sections, grades, guidebook times, known points with altitudes and coordinates, exits. Needs the owner's sources and recordings.
- Whether a recorded mountaineering activity shows in Garmin Connect with the expected icon and our name: one sideloaded test recording.
- The GPS prompt radius (about 50 m proposed) on the real wall.
