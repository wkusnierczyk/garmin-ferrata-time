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

The representative is the product in its family with the lowest Connect IQ version (the lowest
connectIQVersion among its definition's partNumbers), the alphabetically first on a tie. Resources
are the same across a family, but the API is not: an API newer than the oldest product's compiles on
the rest of the family and fails on that one, so the oldest is the one to build. Within a version the
choice does not matter, so the rule there is the one that needs no judgement and does not shift
under a diff.

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
    """The manifest's product ids, leaving out any in an XML comment."""
    text = re.sub(r'<!--.*?-->', '', Path(manifest).read_text(), flags=re.S)
    return re.findall(r'<iq:product id="([^"]+)"', text)


def definition(root, product):
    """The product's compiler.json, or None with no definition."""
    f = os.path.join(root, product, 'compiler.json')
    if not os.path.exists(f):
        return None
    with open(f) as fh:
        return json.load(fh)


def family(root, product):
    """The product's deviceFamily, e.g. round-416x416, or None with no definition."""
    d = definition(root, product)
    return d and d['deviceFamily']


def version(root, product):
    """The product's lowest connectIQVersion over its partNumbers, as a tuple, e.g. (5, 0, 0)."""
    parts = definition(root, product).get('partNumbers') or [{}]
    return min(tuple(int(n) for n in p.get('connectIQVersion', '0').split('.')) for p in parts)


def build_set(root, ids):
    """[(family, product)], one per family, the lowest version first; exits naming any undefined product."""
    missing = [p for p in ids if family(root, p) is None]
    if missing:
        sys.exit(f'the manifest names products with no device definition under\n  {root}\n'
                 f'  {", ".join(missing)}\n'
                 'Download them in the SDK manager (for CI: rebuild the tester image\'s resources\n'
                 'layer with them); monkeyc cannot build without them.')
    families = {}
    for p in sorted(ids, key=lambda p: (version(root, p), p)):
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
