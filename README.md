# Ferrata Time

A Garmin Connect IQ watch face and watch app for climbing via ferratas.

Status: design phase. There is an interactive browser demo and a set of design notes. There is no Monkey C code yet.

The notes below predate two decisions: Ferrata Time is first a standalone watch app that records the climb itself, and its screens are pages you move between with the buttons. `design/DESIGN.md` is brought up to date after the first prototype (#2).

Images and fonts are stored with [Git LFS](https://git-lfs.com): install it (`brew install git-lfs`,
then `git lfs install`) before cloning.

Tracked in this repository, and in the family's umbrella as
[`wkusnierczyk/garmin-watch-faces#42`](https://github.com/wkusnierczyk/garmin-watch-faces/issues/42).

## What it is

The user picks a real via ferrata from a list. The watch face then shows:

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
