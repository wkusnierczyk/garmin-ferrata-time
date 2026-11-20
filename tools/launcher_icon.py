"""Launcher icon: renders tools/launcher_icon.svg, an orange pictogram on a transparent background.

python3 tools/launcher_icon.py <size> <out.png>

Needs rsvg-convert (macOS: brew install librsvg; Linux: librsvg2-bin).
"""
import pathlib
import shutil
import subprocess
import sys

USAGE = "usage: python3 tools/launcher_icon.py <size> <out.png>"
if len(sys.argv) != 3 or not sys.argv[1].isdigit() or int(sys.argv[1]) < 1:
    sys.exit(USAGE)
size, out = int(sys.argv[1]), sys.argv[2]
if shutil.which("rsvg-convert") is None:
    sys.exit("rsvg-convert not found: brew install librsvg (macOS) or apt install librsvg2-bin (Linux)")
svg = pathlib.Path(__file__).with_name("launcher_icon.svg")
if subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), "-o", out, str(svg)]).returncode:
    sys.exit("rsvg-convert failed")
