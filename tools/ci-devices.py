#!/usr/bin/env python3
"""Print CI's build set: one product per deviceFamily, as "<family> <product>" (#11).

Compiling every product in manifest.xml would be fifty-odd builds of, mostly, the same inputs.
Resource qualifiers resolve per deviceFamily, so within a family the compiler sees the same sources,
bitmaps and layout; one product per family is the smallest set that still compiles every resolution
the app ships. Copied from Climber Time (wkusnierczyk/garmin-climber-time#5), itself from Matrix Time
(wkusnierczyk/garmin-matrix-time#102), for the build job in .github/workflows/build.yml.

The launcher icon is the exception: its size is per product (monkey.jungle's mapping, #133), so the
builds compile one product's icon per family, not every product's. make check-icons, in CI too,
holds the rest: the mapping and every icon's pixels.

Families come from the SDK's own device definitions rather than from the resources-round-<WxH>/
directory names, so a product added to the manifest is covered the moment it is added, with no second
list here to forget. A product the manifest names and the definitions lack is an error, not a skip:
that is exactly the state in which make export fails at release time, and CI is the place to hear of
it first. Ferrata Demo's manifest lists the same products (make check-manifests), so this set is its
too.

The representative is the alphabetically first product in its family: which one does not matter,
that is the point of grouping by family, so the rule is the one that needs no judgement and does not
shift under a diff.

    tools/ci-devices.py [MANIFEST]    MANIFEST defaults to manifest.xml

Needs nothing but Python 3 and the device definitions the SDK manager downloads: macOS's, then
Linux's (the tester image's, under HOME=/root); CIQ_DEVICES names the directory outright.
"""
import json
import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEVICE_DIRS = ['~/Library/Application Support/Garmin/ConnectIQ/Devices', '~/.Garmin/ConnectIQ/Devices']


def devices_dir():
    """The device definitions' directory: CIQ_DEVICES, else the first of DEVICE_DIRS that exists."""
    named = os.environ.get('CIQ_DEVICES')
    candidates = [named] if named else [os.path.expanduser(d) for d in DEVICE_DIRS]
    for d in candidates:
        if os.path.isdir(d):
            return d
    sys.exit('no device definitions found; looked in:\n  ' + '\n  '.join(candidates))


def products(manifest):
    return re.findall(r'<iq:product id="([^"]+)"', Path(manifest).read_text())


def family(root, product):
    """The product's deviceFamily, e.g. round-416x416, or None with no definition."""
    f = os.path.join(root, product, 'compiler.json')
    if not os.path.exists(f):
        return None
    with open(f) as fh:
        return json.load(fh)['deviceFamily']


def build_set(root, ids):
    """[(family, product)], one per family, sorted by family; exits naming any undefined product."""
    missing = [p for p in ids if family(root, p) is None]
    if missing:
        sys.exit(f'the manifest names products with no device definition under\n  {root}\n'
                 f'  {", ".join(missing)}\n'
                 'Download them in the SDK manager (for CI: rebuild the tester image\'s resources\n'
                 'layer with them); monkeyc cannot build without them.')
    families = {}
    for p in sorted(ids):
        families.setdefault(family(root, p), p)
    return sorted(families.items())


def main(argv):
    if len(argv) > 2:
        sys.exit(__doc__)
    manifest = argv[1] if len(argv) == 2 else REPO / 'manifest.xml'
    for f, p in build_set(devices_dir(), products(manifest)):
        print(f, p)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
