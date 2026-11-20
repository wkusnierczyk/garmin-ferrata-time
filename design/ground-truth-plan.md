# Ground-truth plan

Recorded Garmin activities are the way to replace assumptions with measurements. This note says what is needed and what will be computed.

Status: waiting for activities from the owner.

## Contents

1. [What is needed](#1-what-is-needed)
2. [What will be computed](#2-what-will-be-computed)
3. [Decisions the results feed](#3-decisions-the-results-feed)
4. [Handling the files](#4-handling-the-files)

## 1. What is needed

- Original FIT files from Garmin Connect, if possible. FIT keeps altitude and sensor detail that GPX can lose. GPX is acceptable.
- Fürenwand first, then any other via ferrata.
- Two or more ascents of the same route, so repeatability can be measured.
- Laps or button presses at landmarks, where they exist.
- For each activity: the watch model and the date, because weather affects barometric drift.

## 2. What will be computed

1. Altitude against time, and where the flat plateaus (traverses) are.
2. Disagreement between two ascents of the same route, as a function of progress.
3. Which altitude-to-position mapping the data supports (a sketch scaled linearly, a sketch stretched between landmark heights, or heights from a GPX track), and the real size of the uncertainty (compared with the assumed plus or minus 20 m).
4. Barometric drift over the climb, from start and end altitudes or a known return point.
5. How far GPS strays on the wall, against the route geometry.
6. Whether laps at landmarks reduce the uncertainty.
7. The Fürenwand total climb, to settle 560 m against 580 m.

## 3. Decisions the results feed

| Result | Decision |
|---|---|
| Altitude repeatability | Resolution of any altitude-to-position table |
| Plateau lengths | How long the "position unknown" stretches are, and whether time alone can bridge them |
| Drift | Whether relative-from-landmark is enough, or whether a correction is needed |
| GPS scatter | Whether GPS is worth using at all, even as a weak hint |
| Landmark gain | Whether a manual sync button is worth its place on the face or app |
| Total climb | Route data for Fürenwand |

## 4. Handling the files

- Keep raw activity files out of the repository unless the owner decides otherwise. They contain personal location and timing data.
- Analysis scripts and aggregate results can be committed. Use a separate `data/` folder that is git-ignored for raw files.
