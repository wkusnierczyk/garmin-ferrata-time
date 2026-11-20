"""Launcher icon: renders tools/launcher_icon.svg, an orange pictogram on a transparent background.

python3 tools/launcher_icon.py <size> <out.png>

Needs rsvg-convert (macOS: brew install librsvg; Linux: librsvg2-bin).
"""
import pathlib
import subprocess
import sys

size, out = int(sys.argv[1]), sys.argv[2]
svg = pathlib.Path(__file__).with_name("launcher_icon.svg")
subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), "-o", out, str(svg)], check=True)
