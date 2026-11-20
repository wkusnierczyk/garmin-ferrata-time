# Connect IQ platform notes

What the platform allows, and what it means for this project. Items marked unverified come from documentation or forum reports and have not been tested on a device.

## Contents

1. [App types](#1-app-types)
2. [What companion app means](#2-what-companion-app-means)
3. [Memory and background limits](#3-memory-and-background-limits)
4. [Storage](#4-storage)
5. [Redraw rate](#5-redraw-rate)
6. [Reading route files](#6-reading-route-files)
7. [Phone app options](#7-phone-app-options)
8. [Consequences for the design](#8-consequences-for-the-design)

## 1. App types

Connect IQ has four app types: watch face, device (watch) app, widget and data field. A watch face has almost no input. A device app can have several screens and full button handling and can run as an activity.

## 2. What companion app means

At Garmin, a companion app is a **phone app** (Android or iOS) built with the Connect IQ Mobile SDK that exchanges messages with a Monkey C app on the watch. It is not an on-watch app.

- The iOS SDK is standalone but launches Garmin Connect Mobile for device selection. The Android SDK goes through Garmin Connect Mobile.
- Caveats: message delivery is not guaranteed, the watch cannot start the companion app, and there are reported SDK reliability bugs.

Separately, the Connect IQ phone app (the store) lets users change a face's settings. Those settings screens are limited in functionality and design. More complex settings would need a dedicated phone app, which is exactly what a companion app is.

In this repository, the on-watch multi-screen app is called the **watch app**.

## 3. Memory and background limits

- A watch face has a small memory budget. Its background process has a smaller one.
- Faces can only make web requests from the background service.
- The background service runs at most every 5 minutes and for at most 30 seconds.
- `makeWebRequest` can fail with -402 (response too large) or -403 (out of memory) when responses are big. Keep route files small.

## 4. Storage

`Application.Storage` limits are documented inconsistently:

| Source | Per value | Total |
|---|---|---|
| Programmer's guide | 8 KB per key | 128 KB |
| API reference | 32 KB per value | device dependent |
| One forum tester | not stated | about 90 KB |

Design assumption: keep each route at a few KB, and keep only one or two routes on the watch at a time.

Storage is probably per app. A separate watch app may therefore not be able to write a selected route that a watch face reads. Unverified. Testing this is on the next-steps list.

## 5. Redraw rate

A watch face redraws once a minute in low power mode and once a second after a wrist gesture. The position dot on the face therefore moves in steps unless the user raises their wrist.

## 6. Reading route files

The watch cannot parse GPX files. `PersistedContent` can read stored courses, routes and waypoints, but apps can only save waypoints. Workarounds:

- A server (or the converter site) parses the GPX and produces compact JSON.
- A phone app such as gimporter or gexporter converts GPX into FIT courses.

## 7. Phone app options

| Option | Good for | Cost |
|---|---|---|
| Connect IQ settings only | Simple options | Very limited UI |
| Companion phone app (Mobile SDK) | Rich settings, importing routes, stats and summaries on a big screen | A second codebase on two platforms, SDK reliability caveats, no guaranteed delivery |
| Web page (converter site) plus a catalogue fetched by the watch app | Getting routes onto the watch without a phone app | Needs connectivity at selection time, not on the wall |

The recommended starting point is the third option, with a phone app only if user imports become a real need.

## 8. Consequences for the design

- Routes must be small and preprocessed.
- Route selection on a face is hard. Either the face and the app are one app, or the choice is made through face settings.
- Everything the climber needs on the wall must work offline.
- Do not rely on the face redrawing more than once a minute in low power mode.
