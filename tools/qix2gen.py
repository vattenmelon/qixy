#!/usr/bin/env python3
"""Generate the 2-frame multicolor 'plasma star' sprite for QIX2.

Frame 0: 4-pointed star, points along the axes (+)
Frame 1: same star rotated 45 degrees (x)

Multicolor bit pairs: 01 = MC0 orange rim, 10 = body colour (green/white
flash), 11 = MC1 white-hot core.  12 MC pixels x 21 rows, 3 bytes/row.
"""
import math

W, H = 12, 21          # multicolor pixels per row, rows
CX, CY = 5.5, 10.0     # centre in (col,row) coords
P = 0.65               # arm concavity (0.5 = needle-thin, 1.0 = diamond)

def star(dx, dy, ax, ay):
    """Concave 4-point star field value; <=1.0 is inside."""
    u, v = abs(dx) / ax, abs(dy) / ay
    return u ** P + v ** P

def classify(col, row, rot):
    # twinkle: frame 0 stretches tall, frame 1 stretches wide
    ax, ay = (12.0, 6.5) if rot else (7.5, 10.5)
    # supersample each MC pixel 4x2 in hw space for smoother edges
    best = 99.0
    for sx in (0.25, 0.75):
        for sy in (0.25, 0.75):
            dx = ((col + sx) - (CX + 0.5)) * 2.0
            dy = (row + sy) - (CY + 0.5)
            best = min(best, star(dx, dy, ax, ay))
    if best > 1.0:
        return 0            # transparent
    if best <= 0.48:
        return 3            # 11 white-hot core
    if best <= 0.78:
        return 2            # 10 flashing body
    return 1                # 01 orange rim (tips)

CHARS = {0: '.', 1: 'r', 2: 'B', 3: 'W'}

for rot in (0, 1):
    print(f"--- frame {rot} ({'x' if rot else '+'}) ---")
    frame = []
    for row in range(H):
        pix = [classify(c, row, rot) for c in range(W)]
        print(''.join(CHARS[p] for p in pix))
        rowbytes = []
        for b in range(3):
            v = 0
            for p in pix[b * 4:(b + 1) * 4]:
                v = (v << 2) | p
            rowbytes.append(v)
        frame.extend(rowbytes)
    frame.append(0)  # pad byte -> 64
    print("bytes:")
    for i in range(0, 64, 16):
        print("        !byte " + ",".join(str(b) for b in frame[i:i + 16]))
