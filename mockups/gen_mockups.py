#!/usr/bin/env python3
"""Atlas Eclipticalis — startup screen mockups, 128×64 norns resolution, 4× scaled."""

from PIL import Image, ImageDraw, ImageFont
import os

W, H, S = 128, 64, 4
OUT = os.path.dirname(os.path.abspath(__file__))

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

def F(size): return ImageFont.truetype(FONT, size)
F9  = F(9)
F7  = F(7)
F6  = F(6)

def g(lv):
    v = min(255, max(0, int(lv * 255 / 15)))
    return (v, v, v)

# ── star renderer ─────────────────────────────────────────────────────────
def star(draw, x, y, mag, boost=0):
    x, y = int(round(x)), int(round(y))
    if not (0 <= x < W and 0 <= y < H):
        return
    lv = min(15, max(2, int(15 - mag * 2.0) + boost))
    draw.point((x, y), fill=g(lv))
    if lv >= 9:
        for dx, dy in ((-1,0),(1,0),(0,-1),(0,1)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < W and 0 <= ny < H:
                draw.point((nx, ny), fill=g(max(1, lv - 9)))
    if lv == 15 or (boost >= 3 and mag < 1.2):
        for dx, dy in ((1,0),(0,1),(1,1)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < W and 0 <= ny < H:
                draw.point((nx, ny), fill=g(lv))

def cline(draw, stars, i, j, lv=3):
    x1,y1 = stars[i][0], stars[i][1]
    x2,y2 = stars[j][0], stars[j][1]
    draw.line([(int(x1),int(y1)),(int(x2),int(y2))], fill=g(lv))

def draw_constellation(draw, stars, lines, dx=0, dy=0, boost=3, line_lv=3):
    sh = [(x+dx, y+dy, m) for x,y,m in stars]
    for i,j in lines:
        cline(draw, sh, i, j, lv=line_lv)
    for x,y,m in sh:
        star(draw, x, y, m, boost=boost)

# ── Orion (7 stars, centred ~x=60) ───────────────────────────────────────
ORI = [
    (48, 10, 0.4),   # 0 Betelgeuse  – bright, top-left
    (71, 12, 1.6),   # 1 Bellatrix   – top-right
    (54, 22, 2.2),   # 2 Mintaka     – belt left
    (60, 24, 1.7),   # 3 Alnilam     – belt mid
    (67, 22, 1.8),   # 4 Alnitak     – belt right
    (73, 35, 0.1),   # 5 Rigel       – brightest, bottom-right
    (50, 35, 2.0),   # 6 Saiph       – bottom-left
]
ORI_L = [(0,1),(0,2),(1,4),(2,3),(3,4),(4,5),(2,6)]

# ── background scatter ────────────────────────────────────────────────────
BG = [
    ( 8,  4, 3.8),( 22,  9, 4.2),(102,  3, 3.6),(121, 14, 4.1),
    (  4, 29, 4.5),( 16, 47, 3.9),(119, 41, 4.2),(111, 57, 3.6),
    ( 36, 56, 4.5),( 91, 59, 4.1),(101, 33, 4.5),( 21, 58, 4.3),
    ( 81, 53, 4.5),( 28, 37, 4.8),(116, 51, 4.1),( 41,  4, 4.6),
    ( 96, 17, 4.1),(  6, 59, 4.5),( 77,  6, 4.3),( 31, 21, 4.9),
    (126, 29, 4.0),( 86, 39, 4.7),( 13, 36, 4.6),(106, 23, 4.3),
    ( 60,  3, 4.4),( 14, 15, 4.8),(122, 58, 4.2),( 50, 57, 4.6),
]

def scatter(draw):
    for x,y,m in BG:
        star(draw, x, y, m, boost=0)

def new(): return Image.new('RGB', (W, H), (0,0,0))

def cx(draw, txt, y, f, lv=15):
    bb = draw.textbbox((0,0), txt, font=f)
    x = max(0, (W - (bb[2]-bb[0])) // 2)
    draw.text((x, y), txt, fill=g(lv), font=f)

def tx(draw, txt, x, y, f, lv=15):
    draw.text((x, y), txt, fill=g(lv), font=f)

# ─────────────────────────────────────────────────────────────────────────
# A  "Constellation First"
#    Orion fills upper 2/3 · thin rule · title · dim subtitle
# ─────────────────────────────────────────────────────────────────────────
def mkA():
    img = new(); d = ImageDraw.Draw(img)
    scatter(d)
    draw_constellation(d, ORI, ORI_L, dx=0, dy=0)
    d.line([(18,42),(110,42)], fill=g(3))
    cx(d, "ATLAS ECLIPTICALIS", 44, F9, 15)
    cx(d, "an astronomical music box", 54, F6, 4)
    cx(d, "for norns  ·  John Cage", 61, F6, 3)
    return img

# ─────────────────────────────────────────────────────────────────────────
# B  "Title First"
#    Bold title at top · subtitle · rule · Orion in lower zone
# ─────────────────────────────────────────────────────────────────────────
def mkB():
    img = new(); d = ImageDraw.Draw(img)
    scatter(d)
    cx(d, "ATLAS ECLIPTICALIS", 1, F9, 15)
    cx(d, "an astronomical music box", 11, F6, 4)
    cx(d, "for norns  ·  John Cage", 18, F6, 3)
    d.line([(0,26),(127,26)], fill=g(4))
    draw_constellation(d, ORI, ORI_L, dx=0, dy=16)
    return img

# ─────────────────────────────────────────────────────────────────────────
# C  "Score"
#    Title top · 5 staff lines · Orion mapped onto staff · subtitle below
# ─────────────────────────────────────────────────────────────────────────
def mkC():
    img = new(); d = ImageDraw.Draw(img)
    scatter(d)
    cx(d, "ATLAS ECLIPTICALIS", 0, F9, 15)
    STAFF = [14, 20, 26, 32, 38]
    for sy in STAFF:
        d.line([(0,sy),(127,sy)], fill=g(4))
    # remap Orion y into staff zone 12..40
    def ry(y): return 12 + (y - 10) / (35 - 10) * (40 - 12)
    ori2 = [(x, ry(y), m) for x,y,m in ORI]
    for i,j in ORI_L:
        cline(d, ori2, i, j, lv=3)
    for x,y,m in ori2:
        star(d, x, y, m, boost=3)
    d.line([(0,42),(127,42)], fill=g(3))
    cx(d, "an astronomical music box for norns", 44, F6, 4)
    cx(d, "inspired by John Cage", 52, F6, 3)
    return img

# ─────────────────────────────────────────────────────────────────────────
# D  "Split"
#    Orion left · vertical rule · title stacked right
# ─────────────────────────────────────────────────────────────────────────
def mkD():
    img = new(); d = ImageDraw.Draw(img)
    scatter(d)
    # Orion in left half (shift left so it sits in x 0..60)
    draw_constellation(d, ORI, ORI_L, dx=-22, dy=8)
    d.line([(63,2),(63,62)], fill=g(3))
    tx(d, "ATLAS",        66,  4, F9, 15)
    tx(d, "ECLIPTICALIS", 66, 15, F7, 10)
    d.line([(66,26),(126,26)], fill=g(3))
    tx(d, "an astronomical", 66, 28, F6, 4)
    tx(d, "music box",       66, 35, F6, 4)
    tx(d, "for norns",       66, 42, F6, 3)
    tx(d, "· John Cage",     66, 49, F6, 3)
    return img

# ── render & save ─────────────────────────────────────────────────────────
for name, fn in (('A',mkA),('B',mkB),('C',mkC),('D',mkD)):
    img = fn()
    # actual size
    img.save(f"{OUT}/startup_{name}_actual.png")
    # 4× nearest-neighbour (sharp pixels)
    big = img.resize((W*S, H*S), Image.NEAREST)
    big.save(f"{OUT}/startup_{name}.png")
    print(f"startup_{name}.png  ({W*S}x{H*S})")
