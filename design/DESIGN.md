# Ferrata Time. Design

Status: design phase, interactive demo only  
Version: 0.1  
Date: 2026-11-20  
Owner: Wacek  
Platform: Garmin Connect IQ, Monkey C  
Reference demo: `demo/index.html`

The installed app is called **Ferrata**: it is an activity, not a watch face, so it does not take the family's "Time" name. "Ferrata Time" names the project and the repository. The watch face planned in sections 3 and 4, and in the constraints and decisions that mention it, predates the move to one watch app and is not planned for now; this document is brought up to date after the first prototype. This document records the design as settled so far, and separates what is decided from what is open. The demo is the behavioural reference for the layouts; where this document and the demo disagree, this document wins.

## Contents

1. [Overview](#1-overview)
2. [Goals and non-goals](#2-goals-and-non-goals)
3. [Components](#3-components)
4. [Watch face](#4-watch-face)
5. [Watch app](#5-watch-app)
6. [Routes in the demo](#6-routes-in-the-demo)
7. [Progress and sensing](#7-progress-and-sensing)
8. [Route data model](#8-route-data-model)
9. [Platform constraints](#9-platform-constraints)
10. [Open questions](#10-open-questions)
11. [Decisions and rationale](#11-decisions-and-rationale)
12. [Next steps](#12-next-steps)

## 1. Overview

A practical companion for climbing a via ferrata. It is the serious counterpart to a purely decorative climbing-wall watch face. The user chooses a real route; the watch shows where they are on it, how much is left, and what is coming: rests and hard sections.

The design has one deliberate bias, set after looking at how Garmin sensors behave on a rock wall (see section 7): **measured vertical gain and elapsed time are the headline numbers**. Position along the route and the difficulty under the climber's feet are estimates, and the design shows them as estimates.

## 2. Goals and non-goals

Goals:

- Select an actual via ferrata from a list.
- Show an outline of the route on the face.
- Show progress: a point on the route, meters climbed of meters total.
- Show rest points ahead (blue) and difficulties ahead (red).
- Show vertical distance climbed and remaining, and time estimates.
- Work offline on the wall, with no phone connection.

Non-goals for the first version:

- Turn-by-turn navigation to the route start.
- Live position from GPS as the primary signal.
- Importing arbitrary routes on the watch.
- Social features, route recording and sharing.

## 3. Components

| Component | Role | Status |
|---|---|---|
| Watch face | Glanceable progress. Limited features, almost no input | Designed in the demo |
| Watch app | Multi-screen experience: choose, overview, live, profile, stats, summary | Designed in the demo |
| Route catalogue | Compact route files, one per via ferrata | Format proposed (section 8) |
| Converter site | Stateless web page that turns GPX or OSM data into route files | Proposed, see `converter-site.md` |
| Phone app | Optional, for complex settings or user imports | Not designed. See `connect-iq-platform.md` |

Terminology: in Garmin's vocabulary a "companion app" is a phone app that talks to a watch app through the Connect IQ Mobile SDK. The watch-side multi-screen app in this design is not a companion app. It is called the watch app.

## 4. Watch face

Two layouts are in the demo. The choice between them is open (section 10).

### 4.1 Path layout

- Time at the top, in monospaced digits.
- The route outline in the middle, with the climber's position as a dot with a halo. The part already climbed is drawn in a different tone from the part ahead.
- Rest markers are blue, difficulty segments are red.
- Big number: meters climbed, with the total beside it ("144 / 370 m").
- Time left, as H:MM.
- Left of the path: next rest, with minutes. Right of the path: next difficulty, with minutes.

### 4.2 Ring layout

- The route is unrolled around the bezel as an arc, with the position as a dot on it.
- Time at the top of the centre, meters climbed large below it, then "of N m", then time left.
- Next rest and next difficulty at the bottom, as small dots with minutes.

### 4.3 Shared rules

- Time to the next marker is shown in minutes, not meters. Minutes work on traverses where there is no altitude change.
- Digits that tick use monospaced fonts so nothing jitters as they change.
- Layers can be switched off in the demo: rests, difficulties, next-marker times.
- Display variants: AMOLED, and MIP with a 64-color palette (each channel 00, 55, AA or FF).
- The face redraws once a minute in low power mode, so the position dot moves in steps. On a wrist gesture it redraws every second.
- Mürren to Gimmelwald descends. The face counts meters descended, and the outline uses up to 3 times vertical exaggeration.

## 5. Watch app

Screens in the demo:

| Screen | Purpose |
|---|---|
| Routes | List of via ferratas with place, grade and duration |
| Overview | Route summary, warnings such as "No emergency exit", START button |
| Live path | Full-screen outline with position and marker names |
| Live profile | Elevation profile with position |
| Live stats | Climbed, remaining, elapsed, pace |
| Summary | After the climb: totals and time against the guidebook |

What goes where:

| Feature | Watch face | Watch app |
|---|---|---|
| Choose a route | No input | List, then overview |
| Route outline | Small, with position | Full screen |
| Climbed and total | One number | Climbed, remaining, elapsed |
| Rest points | Blue dots, minutes to next | Named, with climb to go |
| Difficulties | Red segments, minutes to next | Named, with climb to go |
| Time estimate | Time left | Guidebook time, own pace, finish time |
| Elevation profile | None | Own screen |

## 6. Routes in the demo

Figures are rounded from public guides. Outlines are schematic. Rest and difficulty positions are placeholders.

| Route | Place | Grade | Climb | Guidebook time | Emergency exit |
|---|---|---|---|---|---|
| Allmenalp | Kandersteg BE | C/D | 370 m | 165 min | No |
| Fürenwand | Engelberg OW | K4 to K5 | 580 m | 180 min | No |
| Tälli | Gadmen BE | K3 | 500 m | 180 min | Yes |
| Mürren to Gimmelwald | Mürren BE | K3 | 300 m descent | 150 min | Yes |

The demo model: each route is a polyline of waypoints smoothed with two Chaikin iterations. Progress is a fraction of arc length. Planned minutes are scaled to route minutes, and a pace factor (70 to 160 percent) scales actual time. Markers are fractions of arc length.

Known inconsistency: the demo gives Fürenwand 580 m of climb, while a start at 1240 m and an exit at 1800 m would give 560 m. To be resolved with real data.

## 7. Progress and sensing

Full reasoning is in `sensing.md`. The design consequences:

1. **Headline numbers are measured.** Vertical gain since start and elapsed time come from the barometer and the clock. They do not depend on knowing where on the route the climber is.
2. **Position is an estimate.** Show it with an uncertainty band on the dot, not a single crisp point.
3. **Progress only moves forward.** A via ferrata is climbed in one direction.
4. **Relative beats absolute.** Altitude gained since the last landmark is more reliable than absolute altitude, because barometric altitude drifts with the weather.
5. **Landmark sync.** A button press at a known landmark (start, a bench, a ladder base) resets accumulated drift.
6. **Altitude is not enough on traverses.** Sections at the same height cannot be told apart by altitude. Time and the forward-only rule fill in, with GPS as a weak hint at best.
7. **Do not show false precision.** No big confident grade letter, and nothing like "hard section in 1 m". Show ranges or "hard section ahead".

The demo does not yet show uncertainty. Adding it is a next step.

## 8. Route data model

Proposal only. The target is roughly 1 to 3 KB per route, to be measured, so that a route fits in watch storage and in a background web response.

```json
{
  "id": "fuerenwand",
  "name": "Fürenwand",
  "place": "Engelberg OW",
  "grade": "K4-K5",
  "gradeScale": "SAC K",
  "totalClimbM": 580,
  "guideMinutes": 180,
  "emergencyExit": false,
  "outline": [[0.0, 0.0], [0.04, 0.07]],
  "profile": [[0.0, 0], [0.05, 30]],
  "markers": [
    {"type": "rest", "at": 0.31, "name": "Ledge"},
    {"type": "hard", "from": 0.07, "to": 0.22, "label": "Steep dihedral"}
  ],
  "source": {"geometry": "OSM way 123", "elevation": "swisstopo", "text": "SAC"},
  "dataVersion": 1
}
```

- `outline`: 100 to 200 simplified points, normalised coordinates.
- `profile`: pairs of arc-length fraction and meters climbed.
- `markers`: fractions of arc length.
- `source`: provenance, kept for licence compliance (OSM is ODbL).

## 9. Platform constraints

Details and sources are in `connect-iq-platform.md`. The ones that shape the design:

- A watch face has a tiny memory budget, and its background process is smaller still.
- A face can only make web requests from the background service, at most every 5 minutes and for at most 30 seconds.
- Storage limits are documented inconsistently: 8 KB per key and 128 KB total in the guide, 32 KB per value and a device-dependent total in the API reference, about 90 KB in one tester's report.
- Storage is probably per app. A separate watch app may not be able to hand a route to the face. Unverified.
- The watch cannot parse GPX. Routes must be preprocessed.

## 10. Open questions

| Item | Status | Notes |
|---|---|---|
| Face layout | Open | Path or ring |
| Route hand-off | Open, risky | Can a watch app feed a face? Probably not (per-app storage). May need one app, or route choice in face settings |
| Route delivery | Open | Bundled, hosted catalogue fetched by the app, or phone app. See `route-data.md` |
| Position source | Open | Depends on recorded ground truth. See `ground-truth-plan.md` |
| Which altitude-to-position mapping | Open | Depends on measured data. See `ground-truth-plan.md` |
| Route geometry source | Open | GPX upload (needs a SAC subscription) or OSM only |
| Marker data | Open | SAC text can prefill; positions need checking against real data |
| Escape points | Open | Mark exits on routes that have them? |
| Uncertainty display | Open | Band on the dot, ring grading, range display |
| Fürenwand total climb | Open | 560 m or 580 m |
| Licensing of route text and geometry | Open | SAC pages state no licence; OSM is ODbL |

## 11. Decisions and rationale

| Decision | Reason |
|---|---|
| Demo before any code | Settle design and functionality cheaply |
| Face limited, multi-screen watch app separate | A face has almost no input and tiny memory |
| Minutes to next marker, not meters | Works on traverses with no altitude change |
| Measured gain and elapsed time as headline | These are the signals the sensors give reliably |
| Position and grade shown as uncertain | GPS degrades on walls; barometric altitude drifts |
| Forward-only progress | A route is climbed in one direction |
| Landmark button syncs | Reset drift at known points |
| Routes preprocessed off-watch | The watch cannot parse GPX and has little memory |
| Monospaced digits for ticking numbers | No jitter as digits change |
| Say "watch app", not "companion app" | Garmin's term means a phone app |

## 12. Next steps

1. Obtain recorded activities for ground truth (`ground-truth-plan.md`), Fürenwand first.
2. Add uncertainty to the demo: a band on the position dot, a graded ring, range display.
3. Choose the face layout.
4. Decide route delivery, and test the hand-off question on a real device or simulator.
5. Build the converter site (`converter-site.md`) once the data source is chosen.
6. Build a small barometric landmark logger to collect data on real climbs.
7. Start the Monkey C implementation.
