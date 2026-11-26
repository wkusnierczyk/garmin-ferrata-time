# Changelog

Everything in Ferrata Time that a user could notice, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project follows
[semantic versioning](https://semver.org/spec/v2.0.0.html). A section is a code release, tagged `vX.Y.Z`,
and the app's version is the one in `manifest.xml`.

Each section is headed `## X.Y.Z -- YYYY-MM-DD`, two hyphens and the date the tag is pushed.

Issue numbers in parentheses point at
[the tracker](https://github.com/wkusnierczyk/garmin-ferrata-time/issues), where the reasoning behind
each change is recorded in full.

## Unreleased

### Changed

* The pages are renumbered 1 to 37 in the order they come, and the route from the front comes
  third, after the profile and its zoom: pages 1 to 15 now, 16 to 37 to follow. (#112)

## 0.1.0 -- 2026-11-21

The prototype: a sideloadable demo that plays a made-up climb on the app's pages, to judge them on
the wrist. Nothing is recorded and no sensor is read. One product, the epix Pro (Gen 2) 47 mm; not
published in the store. It builds on 0.0.1's demo (#5), whose pages (side profile, ladder and the
rest) follow the new ones.

### Added

* The installed app is named Ferrata. (#6)
* A launcher icon: a climber clipped to the cable. (#8)
* The demo plays the climb at a vertical pace: walks pass quickly, walls slowly. (#19)
* Page dots on the left edge show on a page change and hide after 2 seconds. (#25)
* Pages 1 to 8 colour the difficulty from yellow through amber and orange to red, with no purple
  at the hard end. (#16)
* Page 1: the profile alone, with ascent, difficulty and altitude. (#16)
* Page 2: the difficulty column with its altitudes. (#17)
* Page 3: ascent and the difficulty column side by side. (#18)
* Pages 4 and 5: the difficulty stack by ascent and by path, with the points of interest on its
  edge and their names as the climber passes. (#20)
* Pages 6a and 6b: the gauge by length and by ascent, the climber as a line inside it; every
  section spans at least 3°, so even a short one shows. (#21, #28)
* Page 7: the route from the front. (#22)
* Page 8: the current difficulty group with the ascent gauge. (#23)
* Page 9: a preview of a section you pick; tap beside its box to step. (#27)
* One set of point colours and symbols across the pages: exit green, rest blue, danger yellow, the
  top red. (#24)
