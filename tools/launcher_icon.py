"""Launcher icon: renders tools/launcher_icon.svg, an orange pictogram on a transparent background.

The renderer of make icons (#133): garmin-graphics-generator icons -R tools/launcher_icon.py calls
render(size) once per size the products' devices ask for, and writes resources-icon-<size>/.
Ferrata Demo's icons (#149) are the same drawing with a white outline, to tell the two apps apart in
the launcher: -R tools/launcher_icon.py:render_demo writes demo/resources-icon-<size>/, which only
demo.jungle maps. The outline is drawn from the app's drawing, never copied, so a change to the
drawing reaches the demo's icon at the next make icons. Run as a script, it renders one size to a
file, or checks the committed icons of both apps against the drawing (what garmin-graphics-generator
icons --check does not: it checks sizes and the mapping only):

python3 tools/launcher_icon.py <size> <out.png>
python3 tools/launcher_icon.py demo <size> <out.png>
python3 tools/launcher_icon.py check

Needs rsvg-convert (macOS: brew install librsvg; Linux: librsvg2-bin). Pillow too for render(),
render_demo(), check and the demo mode: the environment make install-garmin-graphics-generator
makes has it. The demo mode writes PNG whatever the output's name.
"""
import pathlib
import shutil
import subprocess
import sys

SVG = pathlib.Path(__file__).with_name("launcher_icon.svg")
USAGE = "usage: python3 tools/launcher_icon.py [demo] <size> <out.png> | check"
ROOT = SVG.parent.parent
FALLBACK = ROOT / "resources" / "drawables" / "launcher_icon.png"
# Ferrata Demo's icons (#149). No fallback of their own: every product the demo's manifest lists is
# mapped in demo.jungle, and make check-icons reports one that is not.
DEMO_ICONS = ROOT / "demo"

# The demo's outline: its width a fraction of the icon's edge, so it is the same weight at every
# size (1.1 px at 38, 2.1 px at 70), and its colour. It is grown from the drawing's own shape at
# SUPERSAMPLE times the size and resampled down, so its edge is antialiased; the orange drawing over
# it is the app's, drawn natively at the size, so the two icons differ by the outline only.
OUTLINE = 0.03
OUTLINE_COLOUR = (0xFF, 0xFF, 0xFF)
SUPERSAMPLE = 8
NO_RSVG = "rsvg-convert not found: brew install librsvg (macOS) or apt install librsvg2-bin (Linux)"
NO_PILLOW = "Pillow not found: run with the generator's Python (make install-garmin-graphics-generator)"


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


def render_demo(size):
    """Ferrata Demo's icon at size x size, as an RGBA Pillow image: render(size) over a white
    outline OUTLINE * size wide, the renderer garmin-graphics-generator calls for the demo."""
    import io

    from PIL import Image, ImageChops

    edge = size * SUPERSAMPLE
    with Image.open(io.BytesIO(rasterise(edge))) as image:
        shape = image.convert("RGBA").getchannel("A")
    # The shape grown by a disc of the outline's radius: the lightest of its copies shifted to every
    # point of the disc. Slow in principle, but under a second for every size together.
    radius = OUTLINE * edge
    reach = int(radius)
    grown = shape.copy()
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            if (dx or dy) and dx * dx + dy * dy <= radius * radius:
                shifted = Image.new("L", (edge, edge))
                shifted.paste(shape, (dx, dy))
                grown = ImageChops.lighter(grown, shifted)
    outline = Image.new("RGBA", (size, size), OUTLINE_COLOUR + (0,))
    outline.putalpha(grown.resize((size, size), Image.Resampling.BOX))
    return Image.alpha_composite(outline, render(size))


def check():
    """Every resources-icon-<size>/ icon and the fallback hold what render() draws now, and every
    demo/resources-icon-<size>/ icon what render_demo() draws: decoded pixels, not file bytes, so
    zlib's output on another platform does not matter. 1 on a mismatch."""
    from PIL import Image

    icons = [(icon, render) for icon in sorted(ROOT.glob("resources-icon-*/drawables/launcher_icon.png"))]
    icons.append((FALLBACK, render))
    demo = sorted(DEMO_ICONS.glob("resources-icon-*/drawables/launcher_icon.png"))
    icons += [(icon, render_demo) for icon in demo]
    fail = 0 if demo else 1
    if not demo:
        print(f"  FAIL  {DEMO_ICONS.relative_to(ROOT)}/ has no icons")
    for icon, renderer in icons:
        with Image.open(icon) as image:
            w, h = image.size
            same = w == h and image.convert("RGBA").tobytes() == renderer(w).tobytes()
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
    args = sys.argv[1:]
    demo = args[:1] == ["demo"]
    args = args[1:] if demo else args
    if len(args) != 2 or not args[0].isdigit() or int(args[0]) < 1:
        sys.exit(USAGE)
    try:
        if demo:
            render_demo(int(args[0])).save(args[1], format="PNG")
        else:
            pathlib.Path(args[1]).write_bytes(rasterise(int(args[0])))
    except RuntimeError as error:
        sys.exit(str(error))
    except ImportError:
        sys.exit(NO_PILLOW)
