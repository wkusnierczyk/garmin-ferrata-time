# Converter site

Proposal for a small, stateless web page, hosted on GitHub Pages, that turns a route source into a route file the watch app can load.

Status: proposal. Nothing is built.

## Contents

1. [Idea](#1-idea)
2. [What it can and cannot do](#2-what-it-can-and-cannot-do)
3. [Flow](#3-flow)
4. [Outputs](#4-outputs)
5. [Risks](#5-risks)
6. [Build order](#6-build-order)

## 1. Idea

A single static page with no server and no stored state. The user brings a GPX file or points at an OSM way. The page does the conversion in the browser and offers a compact JSON file to download or publish to the catalogue.

## 2. What it can and cannot do

Can:

- Parse GPX in the browser.
- Fetch geometry for an OSM way or relation from an OSM API.
- Fetch elevation along the path from swisstopo.
- Simplify the path to 100 to 200 points.
- Let the user place or edit rest and difficulty markers on a profile view.
- Export compact JSON.

Cannot:

- Turn an SAC route description into a path. The pages are text only, with no coordinates and no GPX.
- Guarantee that markers are right. SAC text can prefill names and rough positions only.

## 3. Flow

1. Input: a GPX file, or an OSM way or relation id.
2. Elevation: query swisstopo along the polyline. Outside Switzerland the grid is 10 m.
3. Simplify: reduce to about 100 to 200 points, preserving shape and steep sections.
4. Markers: prefill from pasted SAC text if the user wants, then place and adjust by hand against the profile.
5. Export: compact JSON, plus a preview of how it renders on the face.

## 4. Outputs

- A route JSON file, as in section 8 of `DESIGN.md`.
- A preview image of the face for the route.
- Optionally a pull request to a catalogue folder.

The catalogue is a folder of JSON files served by GitHub Pages. The watch app fetches an index and then the chosen route.

## 5. Risks

| Risk | Note |
|---|---|
| CORS | Browser requests to swisstopo and OSM APIs from a GitHub Pages origin are untested |
| Licensing | OSM is ODbL. SAC states no licence. See `route-data.md` |
| Data quality | OSM tagging is inconsistent. User GPX may be noisy or disagree with other sources |
| SAC access | GPX is for subscribers. Whether it can be used in a derived work is not established |
| Scraping | Do not scrape SAC pages. Prefill from text the user pastes |

## 6. Build order

1. GPX upload, swisstopo elevation, simplification, JSON export. This works without any SAC dependency.
2. Profile view with manual marker placement.
3. OSM way lookup.
4. Face preview using the demo's renderer.
5. Catalogue publishing.
