#!/usr/bin/env python3
"""
Convert an image to a C64 hires bitmap for use as the LEVEL 4 gameplay
background.

Unlike convert_hires.py (which emits a full 40x25 / 8000-byte screen, like the
level 2 background), this script emits ONLY the playfield interior so the data
fits in the small amount of free RAM left below the $C000 runtime buffers.

Interior playfield = columns FIELD_LEFT+1..FIELD_RIGHT-1 (2..37, 36 cells wide)
                     rows    FIELD_TOP+1..FIELD_BOTTOM-1 (4..22, 19 cells tall)

Output (packed row-major over the interior rectangle, stride = 36 cells):
    LEVEL4_BITMAP : 36*19*8 = 5472 bytes  (copied into $4000 interior at runtime)
    LEVEL4_SCREEN : 36*19   =  684 bytes  (hires colour nibbles per cell)

Usage:
    python convert_level4_bg.py input.jpg [output.asm]
"""

import sys
import os
from pathlib import Path

# Interior dimensions in character cells (must match the OVERLAY_LEVEL4_BG loop)
COLS = 36   # FIELD_LEFT+1 .. FIELD_RIGHT-1  (2..37)
ROWS = 19   # FIELD_TOP+1  .. FIELD_BOTTOM-1 (4..22)
PX_W = COLS * 8   # 288
PX_H = ROWS * 8   # 152

# C64 color palette (RGB values) - same ordering as convert_hires.py
C64_PALETTE = [
    (0x00, 0x00, 0x00),  # 0  Black
    (0xFF, 0xFF, 0xFF),  # 1  White
    (0x88, 0x00, 0x00),  # 2  Red
    (0xAA, 0xFF, 0xEE),  # 3  Cyan
    (0xCC, 0x44, 0xCC),  # 4  Purple
    (0x00, 0xCC, 0x55),  # 5  Green
    (0x00, 0x00, 0xAA),  # 6  Blue
    (0xEE, 0xEE, 0x77),  # 7  Yellow
    (0xDD, 0x88, 0x55),  # 8  Orange
    (0x66, 0x44, 0x00),  # 9  Brown
    (0xFF, 0x77, 0x77),  # 10 Pink
    (0x33, 0x33, 0x33),  # 11 Dark Grey
    (0x77, 0x77, 0x77),  # 12 Grey
    (0xAA, 0xFF, 0x66),  # 13 Light Green
    (0x00, 0x88, 0xFF),  # 14 Light Blue
    (0xBB, 0xBB, 0xBB),  # 15 Light Grey
]


def color_distance(c1, c2):
    return sum((a - b) ** 2 for a, b in zip(c1, c2))


def find_nearest_c64_color(rgb):
    min_dist = float('inf')
    best_idx = 0
    for idx, pal_color in enumerate(C64_PALETTE):
        dist = color_distance(rgb, pal_color)
        if dist < min_dist:
            min_dist = dist
            best_idx = idx
    return best_idx


def load_image(filename):
    """Load image and return PX_W x PX_H array of C64 color indices."""
    try:
        from PIL import Image
    except ImportError:
        print("Error: PIL/Pillow not installed. Run: pip install Pillow")
        sys.exit(1)

    img = Image.open(filename).convert('RGB')
    # Crop to the interior aspect ratio (cover) before resizing so faces are
    # not squashed, then resize to the exact interior pixel size.
    target_ar = PX_W / PX_H
    w, h = img.size
    src_ar = w / h
    if src_ar > target_ar:
        # too wide: crop width
        new_w = int(h * target_ar)
        left = (w - new_w) // 2
        img = img.crop((left, 0, left + new_w, h))
    else:
        # too tall: crop height
        new_h = int(w / target_ar)
        top = (h - new_h) // 2
        img = img.crop((0, top, w, top + new_h))
    img = img.resize((PX_W, PX_H), Image.Resampling.LANCZOS)

    pixels = []
    for y in range(PX_H):
        row = []
        for x in range(PX_W):
            row.append(find_nearest_c64_color(img.getpixel((x, y))))
        pixels.append(row)
    return pixels


def convert_to_hires_bitmap(pixels):
    """Convert interior pixels to packed hires bitmap + screen RAM nibbles."""
    bitmap_data = bytearray(COLS * ROWS * 8)
    screen_ram = bytearray(COLS * ROWS)

    cell_idx = 0
    for char_row in range(ROWS):
        for char_col in range(COLS):
            cell_pixels = []
            for y in range(8):
                for x in range(8):
                    cell_pixels.append(pixels[char_row * 8 + y][char_col * 8 + x])

            color_counts = {}
            for c in cell_pixels:
                color_counts[c] = color_counts.get(c, 0) + 1
            sorted_colors = sorted(color_counts.keys(), key=lambda c: -color_counts[c])

            bg_color = sorted_colors[0]
            fg_color = sorted_colors[1] if len(sorted_colors) > 1 else bg_color
            screen_ram[cell_idx] = (fg_color << 4) | bg_color

            for y in range(8):
                byte_val = 0
                for x in range(8):
                    pc = cell_pixels[y * 8 + x]
                    if pc == fg_color:
                        bit = 1
                    elif pc == bg_color:
                        bit = 0
                    else:
                        dist_fg = color_distance(C64_PALETTE[pc], C64_PALETTE[fg_color])
                        dist_bg = color_distance(C64_PALETTE[pc], C64_PALETTE[bg_color])
                        bit = 1 if dist_fg <= dist_bg else 0
                    byte_val = (byte_val << 1) | bit
                bitmap_data[cell_idx * 8 + y] = byte_val

            cell_idx += 1

    return bitmap_data, screen_ram


def write_asm_output(bitmap_data, screen_ram, output_path):
    with open(output_path, 'w') as f:
        f.write("; ============================================================================\n")
        f.write("; Level 4 Background - Hires Bitmap Data (interior only)\n")
        f.write("; Generated by convert_level4_bg.py\n")
        f.write("; ============================================================================\n")
        f.write(f"; Packed interior: {COLS} cols x {ROWS} rows\n")
        f.write(f"; LEVEL4_BITMAP = {len(bitmap_data)} bytes, LEVEL4_SCREEN = {len(screen_ram)} bytes\n")
        f.write("; Copied into the GAMEPLAY_BITMAP/SCREEN interior by OVERLAY_LEVEL4_BG.\n")
        f.write("; ============================================================================\n\n")

        f.write("LEVEL4_BITMAP:\n")
        for i in range(0, len(bitmap_data), 16):
            chunk = bitmap_data[i:i + 16]
            f.write("        !byte " + ", ".join(f"${b:02X}" for b in chunk) + "\n")

        f.write("\nLEVEL4_SCREEN:\n")
        for i in range(0, len(screen_ram), 16):
            chunk = screen_ram[i:i + 16]
            f.write("        !byte " + ", ".join(f"${b:02X}" for b in chunk) + "\n")

        f.write("\n; End of level 4 background data\n")


def main():
    if len(sys.argv) < 2:
        print("Usage: python convert_level4_bg.py input.jpg [output.asm]")
        sys.exit(1)

    input_file = sys.argv[1]
    if not os.path.exists(input_file):
        print(f"Error: File not found: {input_file}")
        sys.exit(1)

    script_dir = Path(__file__).parent
    output_path = (script_dir.parent / "level4_bg.asm") if len(sys.argv) < 3 else Path(sys.argv[2])

    print(f"Loading image: {input_file}")
    pixels = load_image(input_file)
    print(f"Converting interior {COLS}x{ROWS} cells ({PX_W}x{PX_H}px)...")
    bitmap_data, screen_ram = convert_to_hires_bitmap(pixels)
    print(f"Bitmap data: {len(bitmap_data)} bytes")
    print(f"Screen RAM:  {len(screen_ram)} bytes")
    print(f"Writing output: {output_path}")
    write_asm_output(bitmap_data, screen_ram, output_path)
    print("Done!")


if __name__ == "__main__":
    main()
