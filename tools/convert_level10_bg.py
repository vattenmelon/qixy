#!/usr/bin/env python3
"""
Convert an image to a high-quality C64 HIRES bitmap for the LEVEL 10 gameplay
background, RLE-compressed so it fits in the small amount of free RAM left.

Gameplay runs in hires bitmap mode (2 freely-chosen colours per 8x8 cell), so we
stay in hires to avoid breaking trail/fill rendering. Quality is maximised by:
  * fit+pad (letterbox on black) so the whole figure stays visible, and because
    the source background is black it blends seamlessly with the playfield;
  * choosing, per cell, the TWO palette colours that minimise total squared
    error (brute force over all 120 pairs);
  * Floyd-Steinberg dithering *within* each cell between its two chosen colours
    to convey intermediate shades.

Interior playfield = 36 cols x 19 rows (see OVERLAY_LEVEL4_BG), packed row-major.
Raw = 36*19*8 bitmap (5472) + 36*19 screen (684) = 6156 bytes, then RLE-packed.

Usage:
    python convert_level10_bg.py input.jpg [output.asm]
"""

import sys, os
from pathlib import Path

COLS, ROWS = 36, 19
PX_W, PX_H = COLS * 8, ROWS * 8   # 288 x 152

C64_PALETTE = [
    (0x00, 0x00, 0x00), (0xFF, 0xFF, 0xFF), (0x88, 0x00, 0x00), (0xAA, 0xFF, 0xEE),
    (0xCC, 0x44, 0xCC), (0x00, 0xCC, 0x55), (0x00, 0x00, 0xAA), (0xEE, 0xEE, 0x77),
    (0xDD, 0x88, 0x55), (0x66, 0x44, 0x00), (0xFF, 0x77, 0x77), (0x33, 0x33, 0x33),
    (0x77, 0x77, 0x77), (0xAA, 0xFF, 0x66), (0x00, 0x88, 0xFF), (0xBB, 0xBB, 0xBB),
]


def dist(c1, c2):
    return (c1[0]-c2[0])**2 + (c1[1]-c2[1])**2 + (c1[2]-c2[2])**2


def load_fit_pad(filename):
    from PIL import Image
    img = Image.open(filename).convert('RGB')
    w, h = img.size
    scale = min(PX_W / w, PX_H / h)
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new('RGB', (PX_W, PX_H), (0, 0, 0))   # black letterbox
    canvas.paste(img, ((PX_W - nw) // 2, (PX_H - nh) // 2))
    px = [[canvas.getpixel((x, y)) for x in range(PX_W)] for y in range(PX_H)]
    return px


def best_pair(cell_rgb):
    """Pick the two palette indices minimising total squared error for the cell."""
    # Candidate colours = palette entries that are nearest to at least one pixel,
    # plus the overall set; brute force over all pairs of the 16 palette colours.
    best = None
    best_err = None
    for a in range(16):
        ca = C64_PALETTE[a]
        for b in range(a, 16):
            cb = C64_PALETTE[b]
            err = 0
            for rgb in cell_rgb:
                da, db = dist(rgb, ca), dist(rgb, cb)
                err += da if da < db else db
            if best_err is None or err < best_err:
                best_err = err
                best = (a, b)
    return best


def dither_cell(cell_rgb, fg, bg):
    """Floyd-Steinberg dither the 8x8 cell between two palette colours.

    Returns list of 64 bits (1 = fg, 0 = bg)."""
    cfg, cbg = C64_PALETTE[fg], C64_PALETTE[bg]
    # working buffer of floats
    buf = [[float(cell_rgb[y*8+x][i]) for i in range(3)] for y in range(8) for x in range(8)]
    buf = [list(cell_rgb[i]) for i in range(64)]
    buf = [[float(v) for v in cell_rgb[i]] for i in range(64)]
    bits = [0]*64
    for y in range(8):
        for x in range(8):
            idx = y*8+x
            old = buf[idx]
            d_fg = dist(old, cfg)
            d_bg = dist(old, cbg)
            if d_fg <= d_bg:
                bits[idx] = 1
                chosen = cfg
            else:
                bits[idx] = 0
                chosen = cbg
            err = [old[i]-chosen[i] for i in range(3)]
            # distribute error (FS) within the cell
            for dx, dy, w in ((1,0,7),(-1,1,3),(0,1,5),(1,1,1)):
                nx, ny = x+dx, y+dy
                if 0 <= nx < 8 and 0 <= ny < 8:
                    nidx = ny*8+nx
                    for i in range(3):
                        buf[nidx][i] += err[i]*w/16.0
    return bits


def convert(px):
    bitmap = bytearray(COLS*ROWS*8)
    screen = bytearray(COLS*ROWS)
    cell = 0
    for cr in range(ROWS):
        for cc in range(COLS):
            cell_rgb = [px[cr*8+y][cc*8+x] for y in range(8) for x in range(8)]
            fg, bg = best_pair(cell_rgb)
            screen[cell] = (fg << 4) | bg
            bits = dither_cell(cell_rgb, fg, bg)
            for y in range(8):
                byte = 0
                for x in range(8):
                    byte = (byte << 1) | bits[y*8+x]
                bitmap[cell*8+y] = byte
            cell += 1
    return bitmap, screen


def rle_compress(data):
    """Simple RLE. Control byte:
        $80|n (n=1..127): run -> next byte repeated n times
        $00|n (n=1..127): literal -> next n bytes copied verbatim
        $00 terminates.
    """
    out = bytearray()
    i, n = 0, len(data)
    while i < n:
        # count run length of identical bytes
        run = 1
        while i+run < n and data[i+run] == data[i] and run < 127:
            run += 1
        if run >= 3:
            out.append(0x80 | run)
            out.append(data[i])
            i += run
        else:
            # gather a literal block until a run of >=3 appears
            start = i
            lit = 0
            while i < n and lit < 127:
                r = 1
                while i+r < n and data[i+r] == data[i] and r < 3:
                    r += 1
                if r >= 3:
                    break
                i += 1
                lit += 1
            out.append(lit)            # high bit clear
            out.extend(data[start:start+lit])
    out.append(0x00)                   # terminator
    return out


def emit(f, label, data):
    f.write(f"{label}:\n")
    for i in range(0, len(data), 16):
        f.write("        !byte " + ", ".join(f"${b:02X}" for b in data[i:i+16]) + "\n")


def main():
    if len(sys.argv) < 2:
        print("Usage: python convert_level10_bg.py input.jpg [output.asm]")
        sys.exit(1)
    inp = sys.argv[1]
    if not os.path.exists(inp):
        print("Not found:", inp); sys.exit(1)
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).parent.parent / "level10_bg.asm"

    print("Loading + fit/pad:", inp)
    px = load_fit_pad(inp)
    print("Converting (optimal 2-colour per cell + in-cell dither)...")
    bitmap, screen = convert(px)
    raw = bytes(bitmap) + bytes(screen)
    print(f"Raw: {len(raw)} bytes ({len(bitmap)} bitmap + {len(screen)} screen)")
    comp = rle_compress(raw)
    print(f"RLE compressed: {len(comp)} bytes  ({100*len(comp)//len(raw)}% of raw)")

    with open(out, 'w') as f:
        f.write("; Level 10 background - hires, RLE-compressed (interior 36x19)\n")
        f.write("; Generated by convert_level10_bg.py\n")
        f.write(f"; Decompresses to {len(bitmap)} bitmap + {len(screen)} screen bytes.\n")
        f.write(f"; Compressed stream = {len(comp)} bytes.\n\n")
        emit(f, "LEVEL10_RLE", comp)
        f.write("\n; End of level 10 background data\n")
    print("Wrote", out)


if __name__ == "__main__":
    main()
