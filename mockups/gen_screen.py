#!/usr/bin/env python3
"""Atlas Eclipticalis — main playing screen mockup (scan mode, star just triggered)."""

from PIL import Image, ImageDraw, ImageFont

W, H, S = 128, 64, 4
OUT = "/home/user/atlas-eclipticalis/mockups"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

def F(sz): return ImageFont.truetype(FONT, sz)

def g(lv):
    v = min(255, max(0, round(lv * 255 / 15)))
    return (v, v, v)

STAFF_Y = [14, 21, 28, 35, 42]

def in_staff(y): return STAFF_Y[0] <= y <= STAFF_Y[-1]

def mag_level(mag, sy):
    base = max(2, int(15 - (mag + 1.5) * 1.8))
    return min(15, base + 1) if in_staff(sy) else base

def draw_star(draw, x, y, mag, flash_frac=0.0):
    x, y = int(round(x)), int(round(y))
    if not (-2 <= x <= W+1 and -2 <= y <= H+1): return
    lv = mag_level(mag, y)

    # Flash ring
    if flash_frac > 0:
        fl = int(flash_frac * 13)
        RING = [(-2,0),(2,0),(0,-2),(0,2),
                (-2,-1),(2,-1),(-2,1),(2,1),
                (-1,-2),(1,-2),(-1,2),(1,2)]
        for dx, dy in RING:
            hx, hy = x+dx, y+dy
            if 0 <= hx < W and 0 <= hy < H:
                draw.point((hx, hy), fill=g(fl))
        lv = 15

    # Halo for bright stars
    if mag < 2.2:
        for dx, dy in ((-1,0),(1,0),(0,-1),(0,1)):
            hx, hy = x+dx, y+dy
            if 0 <= hx < W and 0 <= hy < H:
                draw.point((hx, hy), fill=g(max(1, lv-9)))

    # Core pixel(s)
    if mag < 1.0:
        draw.rectangle([x, y, min(x+1,W-1), min(y+1,H-1)], fill=g(lv))
    else:
        if 0 <= x < W and 0 <= y < H:
            draw.point((x, y), fill=g(lv))

# Named/bright stars visible on screen
# (x, y, mag)  — Orion region panned so belt crosses the cursor zone
NAMED = [
    (22,  9, 0.4),   # Betelgeuse — top left, bright
    (48, 11, 1.6),   # Bellatrix
    (34, 22, 2.2),   # Mintaka   — belt left
    (44, 24, 1.7),   # Alnilam   — belt centre
    (54, 22, 1.8),   # Alnitak   — belt right, approaching cursor
    (64, 22, 1.85),  # star at cursor — flash!
    (17, 40, 0.1),   # Rigel     — bottom right, very bright
    (36, 40, 2.0),   # Saiph     — bottom left
    (90, 15, 1.3),   # Aldebaran-like (right half)
    (105, 28, 0.85), # bright star right
    (118, 44, 2.1),
    (78,  38, 1.9),
]

# Constellation lines (index pairs)
LINES = [(0,1),(0,2),(1,4),(2,3),(3,4),(4,5),(4,6),(2,7)]

# Background scatter: (x, y, mag)
BG = [
    ( 8, 4,3.8),(22, 9,4.2),(102, 3,3.6),(121,14,4.1),
    ( 4,29,4.5),(16,47,3.9),(119,41,4.2),(111,57,3.6),
    (36,56,4.5),(91,59,4.1),(101,33,4.5),( 21,58,4.3),
    (81,53,4.5),(28,37,4.8),(116,51,4.1),( 41, 4,4.6),
    (96,17,4.1),( 6,59,4.5),( 77, 6,4.3),( 31,21,4.9),
    (126,29,4.0),(86,39,4.7),(13,36,4.6),(106,23,4.3),
    (60, 3,4.4),(14,15,4.8),(122,58,4.2),( 50,57,4.6),
    (72,44,3.9),(55,52,4.3),(68, 8,4.1),( 93,54,4.5),
    (110,10,4.2),( 3,48,4.6),(70,57,4.4),( 25,52,4.1),
    (88, 6,4.3),(118,36,4.0),(44,48,4.5),( 65,35,4.8),
    (58,18,4.0),(38,31,4.4),(62,48,4.7),(107,50,4.2),
    ( 2,17,4.5),(11,25,4.3),(75,20,4.6),( 83,47,4.1),
]

img = Image.new('RGB', (W, H), (0,0,0))
draw = ImageDraw.Draw(img)

# Background stars
for x, y, m in BG:
    lv = max(1, int(15 - m * 2.0))
    ix, iy = int(x), int(y)
    if 0 <= ix < W and 0 <= iy < H:
        draw.point((ix, iy), fill=g(lv))

# Constellation lines (beneath stars)
for i, j in LINES:
    x1,y1 = int(NAMED[i][0]), int(NAMED[i][1])
    x2,y2 = int(NAMED[j][0]), int(NAMED[j][1])
    draw.line([(x1,y1),(x2,y2)], fill=g(3))

# Named stars (star at index 5 = at cursor, flashing)
for i, (x, y, m) in enumerate(NAMED):
    draw_star(draw, x, y, m, flash_frac=0.75 if i == 5 else 0.0)

# Staff lines
for sy in STAFF_Y:
    draw.line([(0,sy),(W-1,sy)], fill=g(4))

# Cursor line — bright (scan mode)
draw.line([(64,0),(64,H-1)], fill=g(15))

# HUD
F7 = F(7)

# Date top-left
draw.text((2, 1), "2000-01-15", fill=g(4), font=F7)

# Time top-right (right-aligned)
time_str = "21:47"
bb = draw.textbbox((0,0), time_str, font=F7)
tw = bb[2] - bb[0]
draw.text((W - tw - 2, 1), time_str, fill=g(4), font=F7)

# Lat / lon / density — bottom
draw.text((2, H-9), "48°N 2°E  80%", fill=g(4), font=F7)

# Save actual size and 4× scaled
img.save(f"{OUT}/screen_playing_actual.png")
big = img.resize((W*S, H*S), Image.NEAREST)
big.save(f"{OUT}/screen_playing.png")
print(f"screen_playing.png  ({W*S}x{H*S})")
