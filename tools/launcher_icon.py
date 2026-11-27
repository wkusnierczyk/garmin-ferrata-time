"""Launcher icon: renders tools/launcher_icon.svg, an orange pictogram on a transparent background.

The renderer of make icons (#133): garmin-graphics-generator icons -R tools/launcher_icon.py calls
render(size) once per size the products' devices ask for, and writes resources-icon-<size>/. Run as
a script, it renders one size to a file:

python3 tools/launcher_icon.py <size> <out.png>

Needs rsvg-convert (macOS: brew install librsvg; Linux: librsvg2-bin); render() needs Pillow too.
"""
import pathlib
import shutil
import subprocess
import sys

SVG = pathlib.Path(__file__).with_name("launcher_icon.svg")
USAGE = "usage: python3 tools/launcher_icon.py <size> <out.png>"
NO_RSVG = "rsvg-convert not found: brew install librsvg (macOS) or apt install librsvg2-bin (Linux)"


def rasterise(size):
    """The SVG drawn at size x size by rsvg-convert, as PNG bytes."""
    if shutil.which("rsvg-convert") is None:
        raise RuntimeError(NO_RSVG)
    result = subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size), str(SVG)], capture_output=True
    )
    if result.returncode:
        raise RuntimeError("rsvg-convert failed: " + result.stderr.decode(errors="replace").strip())
    return result.stdout


def render(size):
    """The icon at size x size, as an RGBA Pillow image: the renderer garmin-graphics-generator calls."""
    import io

    from PIL import Image

    with Image.open(io.BytesIO(rasterise(size))) as image:
        return image.convert("RGBA")


if __name__ == "__main__":
    if len(sys.argv) != 3 or not sys.argv[1].isdigit() or int(sys.argv[1]) < 1:
        sys.exit(USAGE)
    try:
        png = rasterise(int(sys.argv[1]))
    except RuntimeError as error:
        sys.exit(str(error))
    pathlib.Path(sys.argv[2]).write_bytes(png)
