# Sensing

Why the design treats position and difficulty as uncertain, and what it does about that.

Garmin's position and altitude are known to be unreliable on a wall. The mechanisms below are general physics and common experience, not measurements from this project. The ground-truth plan (`ground-truth-plan.md`) is how they get measured.

## Contents

1. [Signals and how they fail](#1-signals-and-how-they-fail)
2. [Altitude is not enough](#2-altitude-is-not-enough)
3. [Design response](#3-design-response)
4. [What the face may and may not show](#4-what-the-face-may-and-may-not-show)
5. [What to measure](#5-what-to-measure)

## 1. Signals and how they fail

| Signal | Good at | Fails by |
|---|---|---|
| Barometric altitude | Short-range changes: meters gained over minutes | Drifts with the weather. Roughly 8 to 10 m per hPa near sea level (general physics, unmeasured here). A front passing during a 3 hour climb can move it by tens of meters |
| GPS position | Open terrain | On a wall the rock blocks part of the sky and reflects signals (multipath). Position can jump or smear. Horizontal position is the least trustworthy signal on a via ferrata |
| GPS altitude | Nothing much | Worse than horizontal position |
| Clock | Everything about time | Nothing. It is the most reliable signal there is |
| Button press at a landmark | A ground-truth anchor | Depends on the climber remembering to press |

## 2. Altitude is not enough

Altitude along a route is not a one-to-one map to position:

- Traverses are flat. A walk, a traverse from a bench and the foot of the next wall can all sit within about 10 m of each other, so altitude cannot tell them apart.
- Absolute altitude carries drift. A mapping from altitude to position inherits the drift.
- Route data has its own error. In the Fürenwand example, three altitude sources disagree by about 100 m for one landmark.

## 3. Design response

1. Make **measured vertical gain** and **elapsed time** the headline numbers.
2. Use **relative altitude since the last landmark**, not absolute altitude.
3. Apply a **forward-only** rule: progress never goes backwards.
4. Offer a **manual sync** at landmarks: start, a bench, a ladder base.
5. Use time and the forward-only rule to cross traverses, with GPS as a weak hint at best.
6. Show position with an **uncertainty band** and difficulty as a **range**.

## 4. What the face may and may not show

May:

- Meters climbed, measured.
- Time left, from the guidebook time and the climber's pace so far.
- A position dot with a visible band.
- "Hard section ahead" with a minutes estimate.

May not:

- A big, confident grade letter for the section under the climber.
- A countdown in meters to a difficulty, as if position were known to the meter.
- A grade switch with more precision than the data supports.

## 5. What to measure

- How well two ascents of the same route agree in altitude over time.
- Where the plateaus (traverses) are in real traces.
- Barometric drift over a typical climb, from start and end altitude of a loop or a known return.
- How far GPS strays from the route on a wall.
- How much a landmark press improves the estimate.
