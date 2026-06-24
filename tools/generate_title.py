#!/usr/bin/env python3
"""
Generate a dramatic QIXY title screen with rocket ships and explosions.
Output: 320x200 PNG optimized for C64 multicolor bitmap conversion.
"""

from PIL import Image, ImageDraw, ImageFont
import math
import random

# C64 palette
C64 = {
    'black':       (0x00, 0x00, 0x00),
    'white':       (0xFF, 0xFF, 0xFF),
    'red':         (0x88, 0x00, 0x00),
    'cyan':        (0xAA, 0xFF, 0xEE),
    'purple':      (0xCC, 0x44, 0xCC),
    'green':       (0x00, 0xCC, 0x55),
    'blue':        (0x00, 0x00, 0xAA),
    'yellow':      (0xEE, 0xEE, 0x77),
    'orange':      (0xDD, 0x88, 0x55),
    'brown':       (0x66, 0x44, 0x00),
    'pink':        (0xFF, 0x77, 0x77),
    'darkgrey':    (0x33, 0x33, 0x33),
    'grey':        (0x77, 0x77, 0x77),
    'lightgreen':  (0xAA, 0xFF, 0x66),
    'lightblue':   (0x00, 0x88, 0xFF),
    'lightgrey':   (0xBB, 0xBB, 0xBB),
}

WIDTH, HEIGHT = 320, 200

def draw_star_field(draw, count=60):
    """Draw random stars on black background."""
    random.seed(42)
    for _ in range(count):
        x = random.randint(0, WIDTH - 1)
        y = random.randint(0, HEIGHT - 1)
        brightness = random.choice(['white', 'lightgrey', 'grey', 'lightblue'])
        draw.point((x, y), fill=C64[brightness])
        # Some stars are 2px wide for multicolor mode visibility
        if random.random() > 0.6:
            draw.point((x + 1, y), fill=C64[brightness])

def draw_explosion(draw, cx, cy, radius, seed=0):
    """Draw a starburst explosion."""
    random.seed(seed)
    colors = [C64['yellow'], C64['orange'], C64['red'], C64['white'], C64['pink']]

    # Inner bright core
    core_r = radius // 3
    for y in range(-core_r, core_r + 1):
        for x in range(-core_r, core_r + 1):
            if x*x + y*y <= core_r*core_r:
                px, py = cx + x, cy + y
                if 0 <= px < WIDTH and 0 <= py < HEIGHT:
                    draw.point((px, py), fill=C64['white'])

    # Mid ring - yellow/orange
    mid_r = radius * 2 // 3
    for y in range(-mid_r, mid_r + 1):
        for x in range(-mid_r, mid_r + 1):
            dist = math.sqrt(x*x + y*y)
            if core_r < dist <= mid_r:
                px, py = cx + x, cy + y
                if 0 <= px < WIDTH and 0 <= py < HEIGHT:
                    c = C64['yellow'] if dist < (core_r + mid_r) / 2 else C64['orange']
                    draw.point((px, py), fill=c)

    # Outer ring - red/orange
    for y in range(-radius, radius + 1):
        for x in range(-radius, radius + 1):
            dist = math.sqrt(x*x + y*y)
            if mid_r < dist <= radius:
                px, py = cx + x, cy + y
                if 0 <= px < WIDTH and 0 <= py < HEIGHT:
                    draw.point((px, py), fill=C64['red'])

    # Radiating spikes
    num_spikes = random.randint(8, 14)
    for i in range(num_spikes):
        angle = random.uniform(0, 2 * math.pi)
        spike_len = radius + random.randint(radius // 2, radius * 2)
        for t in range(spike_len):
            frac = t / spike_len
            px = int(cx + math.cos(angle) * t)
            py = int(cy + math.sin(angle) * t)
            if 0 <= px < WIDTH and 0 <= py < HEIGHT:
                if frac < 0.3:
                    c = C64['white']
                elif frac < 0.5:
                    c = C64['yellow']
                elif frac < 0.7:
                    c = C64['orange']
                else:
                    c = C64['red']
                draw.point((px, py), fill=c)
                # Thicken spikes near center
                if frac < 0.5:
                    dx = int(math.sin(angle))
                    dy = int(-math.cos(angle))
                    px2, py2 = px + dx, py + dy
                    if 0 <= px2 < WIDTH and 0 <= py2 < HEIGHT:
                        draw.point((px2, py2), fill=c)


def draw_rocket(draw, x, y, direction=1, size=1.0):
    """
    Draw a rocket ship. direction: 1=going up-right, -1=going up-left.
    The rocket points upward/diagonal.
    """
    # Rocket body (elongated vertical shape)
    bw = int(8 * size)  # body width
    bh = int(30 * size)  # body height

    # Slight tilt
    tilt = direction * 0.2

    # Body - lightgrey/white
    for t in range(bh):
        frac = t / bh
        # Width tapers at nose
        if frac < 0.2:
            w = int(bw * frac / 0.2)
        elif frac > 0.8:
            w = int(bw * (1.0 - frac) / 0.2)
        else:
            w = bw

        px = x + int(t * tilt)
        py = y - bh + t

        for dx in range(-w // 2, w // 2 + 1):
            ppx = px + dx
            if 0 <= ppx < WIDTH and 0 <= py < HEIGHT:
                if frac < 0.15:
                    c = C64['red']  # Nose cone
                elif abs(dx) <= 1:
                    c = C64['white']  # Center stripe
                else:
                    c = C64['lightgrey']
                draw.point((ppx, py), fill=c)

    # Nose tip
    for dy in range(-3, 0):
        nx = x + int((bh + dy) * -tilt)
        ny = y - bh + dy
        if 0 <= nx < WIDTH and 0 <= ny < HEIGHT:
            draw.point((nx, ny), fill=C64['red'])

    # Fins
    fin_h = int(10 * size)
    fin_w = int(6 * size)
    fin_y = y - int(5 * size)

    # Left fin
    for t in range(fin_h):
        frac = t / fin_h
        fw = int(fin_w * (1.0 - frac))
        py_f = fin_y - t
        for dx in range(fw):
            ppx = x - bw // 2 - dx
            if 0 <= ppx < WIDTH and 0 <= py_f < HEIGHT:
                draw.point((ppx, py_f), fill=C64['red'])

    # Right fin
    for t in range(fin_h):
        frac = t / fin_h
        fw = int(fin_w * (1.0 - frac))
        py_f = fin_y - t
        for dx in range(fw):
            ppx = x + bw // 2 + dx
            if 0 <= ppx < WIDTH and 0 <= py_f < HEIGHT:
                draw.point((ppx, py_f), fill=C64['red'])

    # Engine exhaust / flame
    flame_h = int(20 * size)
    for t in range(flame_h):
        frac = t / flame_h
        fw = int((4 + t * 0.8) * size)
        py_f = y + t
        for dx in range(-fw, fw + 1):
            ppx = x + dx + int(math.sin(t * 0.5 + random.random()) * 2)
            if 0 <= ppx < WIDTH and 0 <= py_f < HEIGHT:
                if frac < 0.3:
                    c = C64['white']
                elif frac < 0.5:
                    c = C64['yellow']
                elif frac < 0.75:
                    c = C64['orange']
                else:
                    c = C64['red']
                draw.point((ppx, py_f), fill=c)


# C64-style block font - 5x5 grid per character
BLOCK_FONT = {
    'Q': [
        "01110",
        "10001",
        "10001",
        "10011",
        "01111",
    ],
    'I': [
        "11111",
        "00100",
        "00100",
        "00100",
        "11111",
    ],
    'X': [
        "10001",
        "01010",
        "00100",
        "01010",
        "10001",
    ],
    'Y': [
        "10001",
        "01010",
        "00100",
        "00100",
        "00100",
    ],
    'A': [
        "01110",
        "10001",
        "11111",
        "10001",
        "10001",
    ],
    'B': [
        "11110",
        "10001",
        "11110",
        "10001",
        "11110",
    ],
    'C': [
        "01111",
        "10000",
        "10000",
        "10000",
        "01111",
    ],
    'D': [
        "11110",
        "10001",
        "10001",
        "10001",
        "11110",
    ],
    'E': [
        "11111",
        "10000",
        "11110",
        "10000",
        "11111",
    ],
    'F': [
        "11111",
        "10000",
        "11110",
        "10000",
        "10000",
    ],
    'G': [
        "01111",
        "10000",
        "10011",
        "10001",
        "01111",
    ],
    'H': [
        "10001",
        "10001",
        "11111",
        "10001",
        "10001",
    ],
    'K': [
        "10010",
        "10100",
        "11000",
        "10100",
        "10010",
    ],
    'L': [
        "10000",
        "10000",
        "10000",
        "10000",
        "11111",
    ],
    'M': [
        "10001",
        "11011",
        "10101",
        "10001",
        "10001",
    ],
    'N': [
        "10001",
        "11001",
        "10101",
        "10011",
        "10001",
    ],
    'O': [
        "01110",
        "10001",
        "10001",
        "10001",
        "01110",
    ],
    'P': [
        "11110",
        "10001",
        "11110",
        "10000",
        "10000",
    ],
    'R': [
        "11110",
        "10001",
        "11110",
        "10010",
        "10001",
    ],
    'S': [
        "01111",
        "10000",
        "01110",
        "00001",
        "11110",
    ],
    'T': [
        "11111",
        "00100",
        "00100",
        "00100",
        "00100",
    ],
    'U': [
        "10001",
        "10001",
        "10001",
        "10001",
        "01110",
    ],
    'V': [
        "10001",
        "10001",
        "10001",
        "01010",
        "00100",
    ],
    'W': [
        "10001",
        "10001",
        "10101",
        "11011",
        "10001",
    ],
    'Z': [
        "11111",
        "00010",
        "00100",
        "01000",
        "11111",
    ],
    ' ': [
        "00000",
        "00000",
        "00000",
        "00000",
        "00000",
    ],
    '.': [
        "00000",
        "00000",
        "00000",
        "00000",
        "00100",
    ],
    '-': [
        "00000",
        "00000",
        "11111",
        "00000",
        "00000",
    ],
    'J': [
        "00111",
        "00010",
        "00010",
        "10010",
        "01100",
    ],
}


def draw_text(draw, text, x, y, color, scale=2):
    """Draw text using block font. Each char is 5*scale wide + 1*scale gap."""
    char_w = 6 * scale  # 5 pixels + 1 gap
    for i, ch in enumerate(text.upper()):
        glyph = BLOCK_FONT.get(ch)
        if glyph is None:
            continue
        cx = x + i * char_w
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == '1':
                    for sy in range(scale):
                        for sx in range(scale):
                            px = cx + gx * scale + sx
                            py = y + gy * scale + sy
                            if 0 <= px < WIDTH and 0 <= py < HEIGHT:
                                draw.point((px, py), fill=color)


def text_width(text, scale=2):
    """Get pixel width of text."""
    return len(text) * 6 * scale


def draw_title_qixy(draw):
    """Draw large QIXY title with glow effect."""
    scale = 6
    text = "QIXY"
    tw = text_width(text, scale)
    tx = (WIDTH - tw) // 2
    ty = 30

    # Glow/outline in dark color
    for ox in range(-2, 3):
        for oy in range(-2, 3):
            if ox == 0 and oy == 0:
                continue
            draw_text(draw, text, tx + ox, ty + oy, C64['blue'], scale)

    # Main title in cyan
    draw_text(draw, text, tx, ty, C64['cyan'], scale)

    # Inner highlight
    draw_text(draw, text, tx + 1, ty + 1, C64['white'], scale - 1)


def draw_scanlines(draw):
    """Subtle horizontal lines for CRT effect."""
    for y in range(0, HEIGHT, 4):
        for x in range(0, WIDTH, 2):
            px = draw._image.getpixel((x, y))
            if px != C64['black']:
                # Slightly darken
                pass  # Skip for C64 color simplicity


def main():
    random.seed(2026)
    img = Image.new('RGB', (WIDTH, HEIGHT), C64['black'])
    draw = ImageDraw.Draw(img)

    # 1. Star field background
    draw_star_field(draw, count=80)

    # 2. Explosions - dramatic backdrop (keep away from center text area)
    draw_explosion(draw, 35, 50, 25, seed=10)     # Top-left explosion
    draw_explosion(draw, 285, 40, 30, seed=20)    # Top-right explosion
    draw_explosion(draw, 30, 165, 18, seed=30)    # Bottom-left corner
    draw_explosion(draw, 290, 165, 20, seed=40)   # Bottom-right corner

    # Small accent explosions on edges
    draw_explosion(draw, 15, 105, 10, seed=60)
    draw_explosion(draw, 305, 100, 10, seed=70)

    # 3. Rocket ships - flanking the title, at the edges
    random.seed(100)
    draw_rocket(draw, 38, 138, direction=-1, size=1.1)     # Left rocket
    draw_rocket(draw, 282, 133, direction=1, size=1.1)      # Right rocket
    # Smaller background rockets at far edges
    draw_rocket(draw, 10, 188, direction=-1, size=0.7)
    draw_rocket(draw, 310, 183, direction=1, size=0.7)

    # 4. Large QIXY title
    draw_title_qixy(draw)

    # 5. Credit text
    # "CODED BY CLAUDE"
    t1 = "CODED BY CLAUDE"
    tw1 = text_width(t1, 2)
    draw_text(draw, t1, (WIDTH - tw1) // 2, 110, C64['yellow'], 2)

    # "PUBLISHED BY ERLING REIZER AS"
    # Use smaller scale to fit
    t2 = "PUBLISHED BY"
    tw2 = text_width(t2, 2)
    draw_text(draw, t2, (WIDTH - tw2) // 2, 130, C64['lightgreen'], 2)

    t3 = "ERLING REIZER AS"
    tw3 = text_width(t3, 2)
    draw_text(draw, t3, (WIDTH - tw3) // 2, 146, C64['lightgreen'], 2)

    # "PRESS FIRE TO START" at bottom
    t4 = "PRESS FIRE TO START"
    tw4 = text_width(t4, 1)
    draw_text(draw, t4, (WIDTH - tw4) // 2, 182, C64['white'], 1)

    # Save
    output_path = '/Users/erlingreizer/src/qixy/tools/title_new.png'
    img.save(output_path)
    print(f"Saved: {output_path}")
    print(f"Size: {WIDTH}x{HEIGHT}")


if __name__ == "__main__":
    main()
