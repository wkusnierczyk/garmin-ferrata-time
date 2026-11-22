#!/usr/bin/env python3
"""Check that the bitmap fonts agree with their configuration, Draw.mc and README.md (#62).

    python3 tools/check-font-config.py              (make check-fonts)
    python3 tools/check-font-config.py --write      (make fonts: record the hashes, write README.md's tables)

Cut down from Climber Time's (wkusnierczyk/garmin-climber-time#17), itself from Matrix Time's. The
sources of truth are resources/fonts/resolutions.json (the reference resolution and the targets),
resources/fonts/fonts.xml (each font's size at the reference, in its .fnt filename) and
resources/fonts/charsets.json (each font's glyphs). garmin-font-scaler derives the rest: the
resources-<family>/fonts directories and fonts.md, whose size table README.md copies. This script
derives what those must be and checks them, never the reverse. It also holds Draw.mc's sizes, which
are fractions of the screen's width, to fonts.xml's, and the mocks' sizes to the fonts they merge
into. Pure Python, no SDK, no font tools.
"""
import hashlib
import json
import math
import os
import re
import struct
import sys
import zlib

WRITE = '--write' in sys.argv[1:]
HASHES = 'fonts.sha256'
# Where the SDK manager keeps the device definitions: macOS, then Linux. CIQ_DEVICES overrides.
DEVICE_DIRS = ['~/Library/Application Support/Garmin/ConnectIQ/Devices', '~/.Garmin/ConnectIQ/Devices']
LICENCE = 'resources/fonts/OFL-BarlowCondensed.txt'
CIQ_SHAPES = {'round', 'semiround', 'rectangle', 'semioctagon'}

# The fonts by weight, smallest first, as Draw.mc's Fonts.SEMI and Fonts.BOLD list them.
FACES = {'SemiBold': 'BarlowCondensedTabular-SemiBold', 'Bold': 'BarlowCondensedTabular-Bold'}
IDS = {'SemiBold': ['SemiBold18', 'SemiBold22', 'SemiBold30', 'SemiBold36', 'SemiBold46', 'SemiBold58', 'SemiBold84'],
       'Bold': ['Bold18', 'Bold26', 'Bold36', 'Bold52', 'Bold70']}

# The glyphs each font draws (owner, 2026-11-22: only what the app needs). Text: letters, digits,
# the space, and the punctuation the code and the mock pages draw: ' ( ) + , - . / : > ~ ° · …
# (the parentheses, the comma and the period from route names in the mocks, "Grosser Spalt (var.
# E)", "Bridge, summit wall"). Route names are folded to these by the route tool (#84). Numbers: what the large figures show, counts
# and h:mm. Grades: the letters and digits of the difficulty boxes (A to F with half steps such as
# C/D, K1 to K6 and K3/4, R, W and E).
LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
TEXT = LETTERS + " '()+,-./:>~°·…"
NUMBERS = ' -:0123456789'
GRADES = '/0123456789ABCDEFGKRW'
CHARSETS = {'SemiBold18': TEXT, 'SemiBold22': TEXT, 'SemiBold30': TEXT, 'SemiBold36': TEXT,
            'SemiBold46': TEXT, 'SemiBold58': NUMBERS, 'SemiBold84': NUMBERS,
            'Bold18': TEXT, 'Bold26': TEXT, 'Bold36': TEXT, 'Bold52': GRADES, 'Bold70': GRADES}

# The sizes the mocks draw in (.dev/mocks/pages-sulzfluh, pages-daubenhorn; px at 416 px wide), by
# weight, and the font each merges into: the nearest, the larger on a tie, as Fonts.nearest picks.
# The mocks live outside the repository, so this list is their record here; what the code asks for
# is derived from source/ below (DRAW).
MOCK = {'SemiBold': [15, 16.5, 18, 18.4, 20, 20.2, 22, 24, 25, 27, 28, 29.9, 30, 32, 34, 36, 36.8, 39,
                     40, 44, 46, 52, 56, 58, 64, 84],
        'Bold': [18.72, 20, 24, 26, 27.6, 28, 28.08, 30, 34, 36, 36.8, 52.9, 69, 70]}

# Barlow Condensed, in font units: ascender and descender (hhea), cap height (OS/2), and the
# tabular figures' advance, per weight. ttf2bmp rounds up: lineHeight = ceil(size x 1.2 em),
# base = size (the ascender is 1 em), which Draw.CAP (0.7) relies on.
UPM, ASC, DESC, CAP = 1000, 1000, 200, 700
FIGURE = {'SemiBold': 475, 'Bold': 498}

fail = []


def ok(cond, msg):
    print(f"  {'OK  ' if cond else 'FAIL'}  {msg}")
    if not cond:
        fail.append(msg)


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def sha(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


FONT_RE = re.compile(r'<font\s+id="(\w+)"\s+filename="([^"]+)"')
ATTR_RE = re.compile(r'(\w+)="([^"]*)"')
ELEM_RE = re.compile(r'<font\s([^>]*?)/>')


def font_elements(text):
    return [dict(ATTR_RE.findall(e)) for e in ELEM_RE.findall(text)]


def scaler_shape(text):
    """The scaler's output: a declaration, <resources><fonts>, <font/> elements, nothing else."""
    body = re.sub(r'\s+', '', ELEM_RE.sub('', text))
    return re.sub(r'^<\?xml[^>]*\?>', '', body) == '<resources><fonts></fonts></resources>'


def fnt(path):
    """lineHeight, base, and {char: xadvance}, from an AngelCode .fnt."""
    text = read(path)
    line = int(re.search(r'lineHeight=(\d+)', text).group(1))
    base = int(re.search(r'\bbase=(\d+)', text).group(1))
    adv = {chr(int(i)): int(a) for i, a in re.findall(r'^char id=(\d+)\s.*?xadvance=(-?\d+)', text, re.M)}
    return line, base, adv


def png_alpha(path):
    """Rows of alpha values from an 8-bit RGBA PNG, the format ttf2bmp writes."""
    data = open(path, 'rb').read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f"{path}: not a PNG (a Git LFS pointer not checked out?)")
    pos, idat, width = 8, b'', 0
    while pos < len(data):
        n, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b'IHDR':
            width, _, depth, colour = struct.unpack('>IIBB', body[:10])
            if (depth, colour) != (8, 6):
                raise ValueError(f"{path}: not 8-bit RGBA")
        elif kind == b'IDAT':
            idat += body
        pos += 12 + n
    raw, stride, rows, prev, at = zlib.decompress(idat), width * 4, [], bytearray(width * 4), 0
    while at < len(raw):
        kind, line = raw[at], bytearray(raw[at + 1:at + 1 + stride])
        at += 1 + stride
        for x in range(stride):
            a = line[x - 4] if x >= 4 else 0
            b, c = prev[x], (prev[x - 4] if x >= 4 else 0)
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif kind == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append([line[x] for x in range(3, stride, 4)])
        prev = line
    return rows


def spills(path, gap=3):
    """The glyphs with ink in the gap columns after their cell: ttf2bmp cuts a glyph whose ink starts
    left of its origin (Barlow's j) at its cell and spills the rest into the gap before it, and the
    watch draws a cell's next column too, a faint mark after the glyph before (an i)."""
    text = read(path)
    alpha = png_alpha(os.path.join(os.path.dirname(path), re.search(r'file="([^"]+)"', text).group(1)))
    width, out = len(alpha[0]), []
    for m in re.finditer(r'^char id=(\d+)\s+x=(\d+)\s+y=(\d+)\s+width=(\d+)\s+height=(\d+)', text, re.M):
        cid, x0, y0, w, h = map(int, m.groups())
        if any(x0 + w + dx < width and alpha[y0 + y][x0 + w + dx] for dx in range(gap) for y in range(h)):
            out.append(chr(cid))
    return out


# ---------------------------------------------------------------- sources of truth
res = json.loads(read('resources/fonts/resolutions.json'))
ref = res['reference']
rw, rh = ref['resolution']
targets = [(t['resolution'][0], t['resolution'][1], t['shape']) for t in res['targets']]
print("\nSOURCE OF TRUTH")
print(f"  resolutions.json  reference = {rw}x{rh} {ref['shape']}, {len(targets)} target(s)")
base_fonts = font_elements(read('resources/fonts/fonts.xml'))
refsize = {}
for e in base_fonts:
    m = re.match(r'(.+)-(\d+)\.fnt$', e.get('filename', ''))
    if not m:
        ok(False, f"fonts.xml {e.get('id')}: filename {e.get('filename')!r} is not <name>-<size>.fnt")
        continue
    refsize[e['id']] = (m.group(1), int(m.group(2)))
    print(f"  fonts.xml         {e['id']:10} -> {e['filename']}  ({int(m.group(2)) / rw:.2%} of the width)")


def size_at(fid, w, h):
    """The scaler's rule: round(reference size x k), k the constraining dimension's ratio."""
    return round(refsize[fid][1] * min(w / rw, h / rh))


# ---------------------------------------------------------------------- chain
print("\nCHAIN")
want_ids = [i for ws in IDS.values() for i in ws]
ok(list(refsize) == want_ids, f"fonts.xml declares exactly {want_ids}, in that order (found {list(refsize)})")
for weight, ids in IDS.items():
    ok(all(refsize.get(i, ('',))[0] == FACES[weight] for i in ids), f"the {weight} fonts are all {FACES[weight]}")
    sizes = [refsize[i][1] for i in ids if i in refsize]
    ok(sizes == sorted(set(sizes)) and all(i == f"{weight}{s}" for i, s in zip(ids, sizes)),
       f"the {weight} sizes rise, one font each, each id naming its size: the scaler names a bitmap by face "
       "and size, so two fonts at one size overwrite each other")
ok((rw, rh, ref['shape']) in targets, f"reference {rw}x{rh} {ref['shape']} is one of the targets")
for shape in sorted({ref['shape']} | {s for _, _, s in targets}):
    ok(shape in CIQ_SHAPES, f"shape {shape!r} is a Connect IQ deviceFamily shape")
for face in FACES.values():
    ok(os.path.exists(f'resources/fonts/{face}.ttf'), f"resources/fonts/{face}.ttf is there")
ok(os.path.exists(LICENCE), "the typeface's licence is beside it")

dirs = sorted(d for d in os.listdir('.') if re.match(r'resources-(round|semiround|rectangle|semioctagon)-\d+x\d+$', d))
want_dirs = sorted(f"resources-{s}-{w}x{h}" for w, h, s in targets)
ok(dirs == want_dirs, f"the resources-<family> directories are exactly the targets ({', '.join(want_dirs)})"
   + ("" if dirs == want_dirs else f": found {dirs}"))

bad = 0
for w, h, shape in targets:
    d = f"resources-{shape}-{w}x{h}/fonts"
    if not os.path.exists(f'{d}/fonts.xml'):
        ok(False, f"{d}/fonts.xml is missing")
        bad += 1
        continue
    text = read(f'{d}/fonts.xml')
    want = [dict(e, filename=f"{refsize[e['id']][0]}-{size_at(e['id'], w, h)}.fnt") for e in base_fonts if e['id'] in refsize]
    if not scaler_shape(text) or font_elements(text) != want:
        ok(False, f"{d}/fonts.xml is not the scaler's for {w}x{h}")
        bad += 1
    for e in want:
        if not all(os.path.exists(f"{d}/{e['filename'][:-4]}.{x}") for x in ('fnt', 'png')):
            ok(False, f"{d}: {e['filename']} or its .png is missing")
            bad += 1
if not bad:
    ok(True, "every target's fonts.xml is the scaler's, each font at round(reference x k), and its files are there")

orphans = []
for d in ['resources/fonts'] + [f"{x}/fonts" for x in dirs]:
    if os.path.exists(f'{d}/fonts.xml'):
        keep = set(dict(FONT_RE.findall(read(f'{d}/fonts.xml'))).values())
        keep |= {f[:-4] + '.png' for f in keep}
        orphans += [f"{d}/{f}" for f in os.listdir(d) if f.endswith(('.fnt', '.png')) and f not in keep]
ok(not orphans, "no bitmap that no fonts.xml declares" + (f" (found {orphans[:3]})" if orphans else ""))

# The scaler does not refresh resources/fonts/, which the compiler reads for a product with no
# directory of its own: those copies must be the reference resolution's, byte for byte.
refdir = f"resources-{ref['shape']}-{rw}x{rh}/fonts"
same = all(os.path.exists(f'resources/fonts/{s}-{n}.{x}') and os.path.exists(f'{refdir}/{s}-{n}.{x}')
           and sha(f'resources/fonts/{s}-{n}.{x}') == sha(f'{refdir}/{s}-{n}.{x}')
           for s, n in refsize.values() for x in ('fnt', 'png'))
ok(same, f"resources/fonts/'s bitmaps are {refdir}'s, byte for byte")

# A product whose family has no fonts directory compiles with resources/fonts/'s copies, the
# reference's sizes, far too large on a smaller screen (the fenix 7X at 280 px would draw text about
# half as large again as it should), and nothing else would say so. As Climber Time's.
dev_dir = os.environ.get('CIQ_DEVICES') or next(
    (p for p in map(os.path.expanduser, DEVICE_DIRS) if os.path.isdir(p)), None)
products = re.findall(r'<iq:product id="([^"]+)"', read('manifest.xml'))
if dev_dir is None:
    print(f"  SKIP  every product has a font family: no device definitions (looked in "
          f"{', '.join(DEVICE_DIRS)}; set CIQ_DEVICES)")
else:
    families, missing = {}, []
    for p in products:
        f = os.path.join(dev_dir, p, 'compiler.json')
        if os.path.exists(f):
            families.setdefault(json.loads(read(f))['deviceFamily'], []).append(p)
        else:
            missing.append(p)
    ok(not missing, f"every product in manifest.xml has a device definition in {dev_dir}"
       + (f" (missing {missing})" if missing else ""))
    want_fam = {f"{s}-{w}x{h}" for w, h, s in targets}
    ok(set(families) == want_fam,
       f"the {len(products)} product(s)' families are exactly resolutions.json's targets"
       + ("" if set(families) == want_fam else
          f" (without fonts: {sorted(set(families) - want_fam)}, no product: {sorted(want_fam - set(families))})"))

# The typeface and every bitmap, by the hashes make fonts records: a changed TTF, or a bitmap
# copied over another of the same name, passes every other check.
hashed = sorted([f'resources/fonts/{f}.ttf' for f in FACES.values()] + [LICENCE] +
                [f'{d}/{f}' for d in ['resources/fonts'] + [f"{x}/fonts" for x in dirs]
                 if os.path.isdir(d) for f in os.listdir(d) if f.endswith(('.fnt', '.png'))])
now = {p: sha(p) for p in hashed if os.path.exists(p)}
if WRITE:
    with open(HASHES, 'w', encoding='utf-8') as f:
        f.writelines(f"{h}  {p}\n" for p, h in sorted(now.items()))
    print(f"  wrote {HASHES}")
recorded = {}
if os.path.exists(HASHES):
    for line in read(HASHES).splitlines():
        h, p = line.split(None, 1)
        recorded[p] = h
changed = sorted(p for p in set(now) | set(recorded) if now.get(p) != recorded.get(p))
ok(not changed, f"the typeface, its licence and the {len(hashed) - 3} bitmaps match {HASHES} (SHA-256)"
   + (f" (differ: {changed[:4]}; make fonts records them)" if changed else ""))

# ---------------------------------------------------------------------- glyphs
print("\nGLYPHS")
charsets = {c['fontId']: c['fontCharset'] for c in json.loads(read('resources/fonts/charsets.json'))}
for fid in want_ids:
    ok(charsets.get(fid) is not None and sorted(charsets[fid]) == sorted(CHARSETS[fid]),
       f"charsets.json {fid} holds exactly its {len(CHARSETS[fid])} glyphs")
bad = 0
for d in dirs:
    w, h = map(int, d.rsplit('-', 1)[1].split('x'))
    for fid, (stem, _) in refsize.items():
        size = size_at(fid, w, h)
        path = f"{d}/fonts/{stem}-{size}.fnt"
        if not os.path.exists(path):
            continue
        line, base, adv = fnt(path)
        if sorted(adv) != sorted(CHARSETS[fid]):
            ok(False, f"{path}: holds {len(adv)} glyphs, not its charset's {len(CHARSETS[fid])}")
            bad += 1
        weight = 'Bold' if fid.startswith('Bold') else 'SemiBold'
        digits = {adv.get(c) for c in '0123456789'}
        if len(digits) != 1 or abs(digits.pop() - FIGURE[weight] / UPM * size) > 1:
            ok(False, f"{path}: the digits are not one tabular advance of {FIGURE[weight]} units")
            bad += 1
        if line != math.ceil(size * (ASC + DESC) / UPM) or base != math.ceil(size * ASC / UPM):
            ok(False, f"{path}: lineHeight {line} and base {base} are not 1.2 and 1 em at size {size}")
            bad += 1
if not bad:
    ok(True, "every bitmap holds its charset, its digits one tabular advance, and its line 1.2 em and base 1 em")
spilt = [f"{d}/fonts/{refsize[fid][0]}-{size_at(fid, *map(int, d.rsplit('-', 1)[1].split('x')))}.fnt"
         for d in dirs for fid in refsize]
spilt = {p.rsplit('/', 1)[1]: spills(p) for p in spilt if os.path.exists(p)}
spilt = {p: c for p, c in spilt.items() if c}
ok(not spilt, "no glyph's next three columns in the atlas hold ink (the Makefile's FONT_PADDING)"
   + (f" (in {spilt})" if spilt else ""))

# Every literal the code measures must be in a text font: a missing glyph is measured at a fallback
# width without a word (playbook, fonts.md).
source = ''.join(read(f'source/{f}') for f in sorted(os.listdir('source')) if f.endswith('.mc'))
def literals(text):
    """The string literals in Monkey C text, without comments and format patterns."""
    text = re.sub(r'//[^\n]*', '', text)
    text = re.sub(r'\.format\("[^"]*"\)', '', text)
    return re.findall(r'"([^"]*)"', text)


measured = set(''.join(''.join(literals(line.split('d.width(', 1)[1]))
                       for line in source.splitlines() if 'd.width(' in line))
measured |= set(''.join(re.findall(r'"([^"]*)"', re.search(r'function fitIn.*?\n    }', source, re.S).group(0))))
ok(measured <= set(TEXT), f"every literal the pages measure is a text glyph ({''.join(sorted(measured))!r})")
drawn = set(''.join(literals(source)))
ok(drawn <= set(TEXT), "every string literal in source/ is in the text fonts"
   + (f" (not {''.join(sorted(drawn - set(TEXT)))!r})" if drawn - set(TEXT) else ""))

# ---------------------------------------------------------------------- Draw.mc
print("\nDRAW")
draw = read('source/Draw.mc')
for weight, const, fn in (('SemiBold', 'SEMI', 'semi'), ('Bold', 'BOLD', 'bold')):
    m = re.search(rf'const {const} = \[([^\]]*)\]', draw)
    fracs = [float(v) for v in m.group(1).split(',')] if m else []
    sizes = [refsize[i][1] for i in IDS[weight] if i in refsize]
    ok(len(fracs) == len(sizes) and all(abs(f - s / rw) < 0.00005 for f, s in zip(fracs, sizes)),
       f"Fonts.{const} is fonts.xml's {weight} sizes over the reference width, {rw}, to four places")
    m = re.search(rf'function {fn}\(.*?var ids = \[(.*?)\]', draw, re.S)
    ids = re.findall(r'Rez\.Fonts\.(\w+)', m.group(1)) if m else []
    ok(ids == IDS[weight], f"Fonts.{fn} loads the {weight} ids in Fonts.{const}'s order")


def num(v):
    return f"{v:g}"


def nearest(px, sizes):
    """Fonts.nearest: the nearest size, the larger on a tie."""
    best = 0
    for i in range(1, len(sizes)):
        if abs(sizes[i] - px) <= abs(sizes[best] - px) + 1e-4 * rw:
            best = i
    return best


# What the code asks for: every share passed to d.semi or d.bold as a number, or as a constant the
# source declares (`const NAME = 0.1234;`), maps to a font. A share times a variable (a widget drawn
# at size k) is not evaluated here.
consts = {n: float(v) for n, v in re.findall(r'const (\w+) = (0\.\d+);', source)}
asked, unknown = {'SemiBold': set(), 'Bold': set()}, set()
for fn, arg in re.findall(r'\b(?:d|Fonts)\.(semi|bold)\(([^()]*)\)', source):
    arg = arg.strip()
    v = float(arg) if re.fullmatch(r'0\.\d+', arg) else consts.get(arg)
    if v is None:
        unknown.add(arg)
    else:
        asked['SemiBold' if fn == 'semi' else 'Bold'].add(round(v * rw, 1))
for weight in IDS:
    sizes = [refsize[i][1] for i in IDS[weight]]
    out = sorted(px for px in asked[weight] if not sizes[0] * 0.8 <= px <= sizes[-1] * 1.2)
    ok(not out, f"every {weight} size the code names ({len(asked[weight])}) lies within the fonts' range"
       + (f" (outside: {out})" if out else ""))
print(f"        named in source, px at {rw}: " + '; '.join(
    f"{w} " + ', '.join(f"{px:g}->{IDS[w][nearest(px, [refsize[i][1] for i in IDS[w]])]}" for px in sorted(asked[w]))
    for w in asked) + (f"; not evaluated: {', '.join(sorted(unknown))}" if unknown else ''))

# The restricted fonts (numbers, grades) draw only what their charset holds: every string literal
# drawn in one, by a call that names its size, and BOX_NAME, which the grade fonts draw.
restricted = {i for i in want_ids if CHARSETS[i] != TEXT}
bad = []
for line in source.splitlines():
    m = re.search(r'\b(?:d|Fonts)\.(semi|bold)\(([^()]*)\)', line)
    if not m or not re.search(r'\.(text\w*|width)\(', line):
        continue
    arg = m.group(2).strip()
    v = float(arg) if re.fullmatch(r'0\.\d+', arg) else consts.get(arg)
    if v is None:
        continue
    weight = 'SemiBold' if m.group(1) == 'semi' else 'Bold'
    fid = IDS[weight][nearest(v * rw, [refsize[i][1] for i in IDS[weight]])]
    if fid in restricted:
        bad += [(fid, t) for t in literals(line[m.end():]) if not set(t) <= set(CHARSETS[fid])]
box = re.search(r'const BOX_NAME = \[([^\]]*)\]', source)
box_glyphs = set(''.join(re.findall(r'"([^"]*)"', box.group(1)))) if box else set()
ok(bool(box) and box_glyphs <= set(GRADES), f"BOX_NAME, which the grade fonts draw, is grade glyphs ({''.join(sorted(box_glyphs))})")
ok(not bad, "every string literal drawn in a number or grade font is in its charset" + (f" (not {bad[:3]})" if bad else ""))

merged = {}
for weight, mocks in MOCK.items():
    sizes = [refsize[i][1] for i in IDS[weight]]
    for px in mocks:
        merged.setdefault(IDS[weight][nearest(px, sizes)], []).append(px)
ok(all(merged.get(i) for i in want_ids), "every font has a mock size merged into it")

# ---------------------------------------------------------------------- README
print("\nTABLES")
HEAD = '# Font sizes by resolution'


def resolution_table(text):
    lines = text.split(HEAD, 1)[1].splitlines() if HEAD in text else []
    out = []
    for line in lines:
        if line.startswith('|'):
            out.append(line)
        elif out:
            break
    return out


def size_table():
    rows = ["| Font | Share of the width | At 416 px | The mocks' sizes it draws (px at 416) | Glyphs |",
            "|:-|-:|-:|:-|:-|"]
    kinds = {TEXT: 'text', NUMBERS: 'numbers', GRADES: 'grades'}
    for fid in want_ids:
        rows.append(f"| `{fid}` | {refsize[fid][1] / rw * 100:.2f} % | {refsize[fid][1]} | "
                    f"{', '.join(num(v) for v in merged[fid])} | {kinds[CHARSETS[fid]]} |")
    return rows


table = resolution_table(read('fonts.md'))
want = {(w, h, s, fid): size_at(fid, w, h) for w, h, s in targets for fid in refsize}
got = {}
for line in table:
    m = re.match(r'^\|\s*(\d+)\s*x\s*(\d+)\s*\|\s*(\w+)\s*\|\s*([\w ]+?)\s*\|\s*([\w ]+?)\s*\|\s*(\d+)\s*\|$', line.strip())
    if m:
        got[(int(m.group(1)), int(m.group(2)), m.group(3), m.group(4).replace(' ', ''))] = int(m.group(6))
ok({(a, b, c, d.lower()): v for (a, b, c, d), v in got.items()} == {(a, b, c, d.lower()): v for (a, b, c, d), v in want.items()},
   "fonts.md: one row per target and font, at round(reference x k)")

PAGE = 'README.md'
page = read(PAGE)
blocks = {'fonts.md': (table, '<!-- fonts.md: start -->', '<!-- fonts.md: end -->'),
          'sizes': (size_table(), '<!-- font sizes: start -->', '<!-- font sizes: end -->')}
for name, (rows, start, end) in blocks.items():
    if WRITE and start in page and end in page:
        head, rest = page.split(start, 1)
        page = head + start + '\n' + '\n'.join(rows) + '\n' + end + rest.split(end, 1)[1]
    block = page.split(start, 1)[1].split(end, 1)[0].strip().splitlines() if start in page and end in page else None
    ok(block == rows, f"{PAGE}'s {name} table is current, line for line (make fonts writes it)")
if WRITE:
    with open(PAGE, 'w', encoding='utf-8') as f:
        f.write(page)
    print(f"  wrote the tables into {PAGE}")
prose = [' '.join(b.split()) for b in re.split(r'\n\s*\n', page) if 'reference resolution' in b.lower()]
ok(any(re.search(rf'\b{rw}\s*[x×]\s*{rh}\b', b) and 'resolutions.json' in b for b in prose),
   f"{PAGE} names the reference resolution, {rw}x{rh}, and resolutions.json, in one paragraph")

print()
if fail:
    print(f"{len(fail)} check(s) failed.")
    sys.exit(1)
print("Font configuration is consistent.")
