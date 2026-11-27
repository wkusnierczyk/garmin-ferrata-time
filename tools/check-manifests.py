#!/usr/bin/env python3
"""Check that Ferrata Demo's manifest is Ferrata's but for the app id and name (#140).

The two apps build from one source and share monkey.jungle, whose launcher icon mapping covers
manifest.xml's products, so manifest-demo.xml must list the same products and carry the same
version, type, entry, icon, API level, languages and barrels. The application id and name tell them
apart, and those must differ. So do the permissions, in one known way: the demo reads no sensors
(SensorInput is (:nodemo)), so it asks for the app's permissions less SENSORS_ONLY; every other
permission the app asks for, the demo's code needs too. Checked rather than generated, as Matrix Time's edition manifests are: the duplicate is
small, and a check in CI cannot be forgotten. Pure Python, no SDK.

    python3 tools/check-manifests.py [APP_MANIFEST DEMO_MANIFEST]   (both, or neither)

Exits 1 and lists every difference, or 0.
"""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
NS = {"iq": "http://www.garmin.com/xml/connectiq"}
# The attributes that tell the two apps apart; every other one must match.
OWN = ("id", "name")
# The permissions only the sensors' code needs, which the demo leaves out.
SENSORS_ONLY = {"Positioning", "Sensor"}


def read(path):
    """The application's attributes, and its products, permissions, languages and barrels."""
    app = ET.parse(path).getroot().find("iq:application", NS)
    if app is None:
        raise ValueError(f"{path}: no iq:application")
    return {
        "attributes": dict(app.attrib),
        "products": [e.get("id") for e in app.findall("iq:products/iq:product", NS)],
        "permissions": sorted(e.get("id") for e in app.findall("iq:permissions/iq:uses-permission", NS)),
        "languages": sorted((e.text or "").strip() for e in app.findall("iq:languages/iq:language", NS)),
        "barrels": sorted(ET.tostring(e, encoding="unicode").strip() for e in app.findall("iq:barrels/*", NS)),
    }


def differences(app_path, demo_path):
    """Every way the demo's manifest is not the app's but for its id and name."""
    a, d = read(app_path), read(demo_path)
    found = []
    for key in OWN:
        if a["attributes"].get(key) == d["attributes"].get(key):
            found.append(f"the same {key} in both, {a['attributes'].get(key)!r}: the demo needs its own")
    for key in sorted(set(a["attributes"]) | set(d["attributes"])):
        if key not in OWN and a["attributes"].get(key) != d["attributes"].get(key):
            found.append(f"{key}: {a['attributes'].get(key)!r} in the app, {d['attributes'].get(key)!r} in the demo")
    if a["products"] != d["products"]:
        only_a = [p for p in a["products"] if p not in d["products"]]
        only_d = [p for p in d["products"] if p not in a["products"]]
        if only_a or only_d:
            found.append(f"products only in the app: {only_a}; only in the demo: {only_d}")
        else:
            found.append("the products are the same but in another order")
    want = sorted(set(a["permissions"]) - SENSORS_ONLY)
    if d["permissions"] != want:
        found.append(f"permissions: {d['permissions']} in the demo, {want} wanted (the app's, less {sorted(SENSORS_ONLY)})")
    for key in ("languages", "barrels"):
        if a[key] != d[key]:
            found.append(f"{key}: {a[key]} in the app, {d[key]} in the demo")
    return found


def main(argv):
    if len(argv) not in (1, 3):
        print(f"usage: {argv[0]} [APP_MANIFEST DEMO_MANIFEST]", file=sys.stderr)
        return 2
    app_path, demo_path = (argv[1], argv[2]) if len(argv) == 3 else (REPO / "manifest.xml", REPO / "manifest-demo.xml")
    found = differences(app_path, demo_path)
    for f in found:
        print(f"{Path(demo_path).name}: {f}", file=sys.stderr)
    if found:
        return 1
    print(f"{Path(demo_path).name} is {Path(app_path).name} but for the app id, name and the sensors' permissions.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
