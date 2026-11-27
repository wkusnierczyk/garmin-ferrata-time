"""Launcher icon: renders tools/launcher_icon.svg, an orange pictogram on a transparent background.

The renderer of make icons (#133): garmin-graphics-generator icons -R tools/launcher_icon.py calls
render(size) once per size the products' devices ask for, and writes resources-icon-<size>/. Run as
a script, it renders one size to a file, or checks the committed icons against the drawing (what
garmin-graphics-generator icons --check does not: it checks sizes and the mapping only):

python3 tools/launcher_icon.py <size> <out.png>
python3 tools/launcher_icon.py check

Needs rsvg-convert (macOS: brew install librsvg; Linux: librsvg2-bin); render() needs Pillow too.
"""
import pathlib
import shutil
import subprocess
import sys

SVG = pathlib.Path(__file__).with_name("launcher_icon.svg")
USAGE = "usage: python3 tools/launcher_icon.py <size> <out.png> | check"
ROOT = SVG.parent.parent
FALLBACK = ROOT / "resources" / "drawables" / "launcher_icon.png"
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


def check():
    """Every resources-icon-<size>/ icon and the fallback hold what render() draws now: decoded
    pixels, not file bytes, so zlib's output on another platform does not matter. 1 on a mismatch."""
    from PIL import Image

    icons = sorted(ROOT.glob("resources-icon-*/drawables/launcher_icon.png")) + [FALLBACK]
    fail = 0
    for icon in icons:
        with Image.open(icon) as image:
            w, h = image.size
            same = w == h and image.convert("RGBA").tobytes() == render(w).tobytes()
        print(f"  {'OK  ' if same else 'FAIL'}  {icon.relative_to(ROOT)} is what the renderer draws")
        fail += not same
    print("\nALL CONSISTENT\n" if not fail else f"\n{fail} PROBLEM(S): run make icons\n")
    return 1 if fail else 0


if __name__ == "__main__":
    if sys.argv[1:] == ["check"]:
        try:
            sys.exit(check())
        except RuntimeError as error:
            sys.exit(str(error))
    if len(sys.argv) != 3 or not sys.argv[1].isdigit() or int(sys.argv[1]) < 1:
        sys.exit(USAGE)
    try:
        png = rasterise(int(sys.argv[1]))
    except RuntimeError as error:
        sys.exit(str(error))
    pathlib.Path(sys.argv[2]).write_bytes(png)
