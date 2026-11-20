# Route data

How realistic is it to get real route paths and elevation profiles onto the watch? Realistic, with preprocessing. This note covers the sources, the size budget and the delivery options.

## Contents

1. [Summary](#1-summary)
2. [Sources](#2-sources)
3. [Size budget](#3-size-budget)
4. [Delivery options](#4-delivery-options)
5. [Pipeline](#5-pipeline)
6. [Licensing and attribution](#6-licensing-and-attribution)
7. [Open questions](#7-open-questions)

## 1. Summary

- The watch cannot parse GPX, and has little memory, so every route is preprocessed into a compact file of about 1 to 3 KB (an estimate to be measured).
- Published route descriptions such as those of the Swiss Alpine Club (SAC) are text. They do not contain a path. Geometry has to come from GPX or from OpenStreetMap (OSM).
- Elevation along the path can be filled in from swisstopo, so the path source does not need reliable heights.
- Rest and difficulty markers can be prefilled from SAC text, but their positions need checking against real data.

## 2. Sources

| Source | Gives | Caveats |
|---|---|---|
| SAC route portal pages | Grade, times, text description, landmarks | Text only. No GPX or coordinates on public pages. GPX is for subscribers. No licence is stated |
| OpenStreetMap | Geometry of ways tagged `highway=via_ferrata`, a difficulty scale in `via_ferrata_scale`, and `route=via_ferrata` relations | Tagging is inconsistent. The start of a relation is not reliably computable |
| swisstopo `api3.geo.admin.ch/rest/services/profile.json` | Elevation along a polyline | Outside Switzerland the grid is 10 m |
| Recorded activities (FIT or GPX) | Real traces with barometric altitude | Garmin position and altitude are noisy on walls. Useful as ground truth, not as clean geometry |
| User GPX files | Geometry | Quality varies, heights especially; check them against an elevation model and recorded ascents |

## 3. Size budget

Targets, to be measured on the real format:

- 100 to 200 outline points per route after simplification.
- Profile as pairs of arc-length fraction and meters climbed.
- Markers as fractions of arc length.

That is expected to land at roughly 1 to 3 KB per route, comfortably inside the lowest storage figure (8 KB per key) and a background web response.

## 4. Delivery options

| Option | How | Pros | Cons |
|---|---|---|---|
| Bundled | Routes compiled into the app resources | Offline, simple, no storage questions | Update means a new release. App size grows with the catalogue |
| Hosted catalogue | The watch app fetches JSON files from GitHub Pages in the foreground | Easy updates, no phone app | Needs connectivity at selection time. A face cannot do this in the foreground, only through the background service |
| Phone app | User imports a route, the phone sends it to the watch | Arbitrary user routes | A second codebase, no guaranteed delivery, SDK bugs |

Starting recommendation: bundle a handful of routes for the first version, and add the hosted catalogue once the format is stable.

## 5. Pipeline

```
GPX file or OSM way
   -> elevation from swisstopo
   -> simplify to 100 to 200 points
   -> prefill markers from SAC text (by hand or assisted)
   -> check markers against recorded activities
   -> compact JSON
```

The converter site in `converter-site.md` is the proposed home for the first four steps.

## 6. Licensing and attribution

- OSM data is under the Open Database Licence (ODbL). Derived route files need attribution, and the licence terms for derived databases apply.
- SAC pages state no licence. Facts such as grade and duration are one thing, wording is another. Do not copy SAC prose into the catalogue. Link to the SAC page instead.
- The route file format carries a `source` field so provenance travels with each route.

This is a practical note, not legal advice.

## 7. Open questions

- Does the swisstopo profile service allow browser requests from another origin (CORS)? Untested.
- Does an SAC subscription allow using downloaded GPX in a derived work?
- Which OSM via ferrata ways are complete and trustworthy for the first routes?
- How much hand work are markers, per route?
