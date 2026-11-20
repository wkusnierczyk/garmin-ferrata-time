"""Prototype launcher icon: a route climbing in grade colours, drawn at 4x and downsampled.

python3 tools/launcher_icon.py <size> <out.png>
"""
import sys
from PIL import Image, ImageDraw

size, out = int(sys.argv[1]), sys.argv[2]
S = size * 4
im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.ellipse([0, 0, S - 1, S - 1], fill=(20, 24, 27, 255))
u = S / 60
# (x, y) points of the route, and the grade colour of each leg (as the app's palette)
pts = [(10, 46), (19, 43), (23, 30), (33, 28), (37, 17), (44, 15), (50, 9)]
cols = [(107, 114, 128), (247, 157, 60), (255, 209, 102), (239, 71, 111), (142, 202, 230), (176, 92, 255)]
for (a, b), c in zip(zip(pts, pts[1:]), cols):
    d.line([a[0] * u, a[1] * u, b[0] * u, b[1] * u], fill=c + (255,), width=int(4.2 * u))
for p in pts[1:-1]:
    r = 2.1 * u
    d.ellipse([p[0] * u - r, p[1] * u - r, p[0] * u + r, p[1] * u + r], fill=cols[pts.index(p)] + (255,))
x, y = pts[3]
d.ellipse([(x - 4) * u, (y - 4) * u, (x + 4) * u, (y + 4) * u], fill=(245, 245, 245, 255))
im.resize((size, size), Image.LANCZOS).save(out)
