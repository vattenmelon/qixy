#!/usr/bin/env python3
"""
Convert PNG image to C64 multicolor bitmap format for QIXY title screen.

Usage:
    python convert_title.py [input.png]

If no input file is provided, generates a sample QIXY title screen.

Output: title_data.asm with ACME assembly directives.
"""

import sys
import os
from pathlib import Path

# C64 color palette (RGB values)
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
    """Calculate squared Euclidean distance between two RGB colors."""
    return sum((a - b) ** 2 for a, b in zip(c1, c2))

def find_nearest_c64_color(rgb):
    """Find the nearest C64 palette color index for an RGB color."""
    min_dist = float('inf')
    best_idx = 0
    for idx, pal_color in enumerate(C64_PALETTE):
        dist = color_distance(rgb, pal_color)
        if dist < min_dist:
            min_dist = dist
            best_idx = idx
    return best_idx

def load_png(filename):
    """Load PNG and return 320x200 indexed color array."""
    try:
        from PIL import Image
    except ImportError:
        print("Error: PIL/Pillow not installed. Run: pip install Pillow")
        sys.exit(1)

    img = Image.open(filename).convert('RGB')

    # Resize to 320x200 if needed
    if img.size != (320, 200):
        img = img.resize((320, 200), Image.Resampling.LANCZOS)

    # Convert to C64 color indices
    pixels = []
    for y in range(200):
        row = []
        for x in range(320):
            rgb = img.getpixel((x, y))
            row.append(find_nearest_c64_color(rgb))
        pixels.append(row)

    return pixels

def generate_sample_title():
    """Generate a sample QIXY title screen (320x200 C64 color indices)."""
    pixels = [[0 for _ in range(320)] for _ in range(200)]

    # Background: dark blue gradient effect
    for y in range(200):
        for x in range(320):
            if y < 20 or y >= 180:
                pixels[y][x] = 6  # Blue border
            elif y < 40 or y >= 160:
                pixels[y][x] = 14  # Light blue
            else:
                pixels[y][x] = 0  # Black background

    # Draw "QIXY" in large block letters (each letter ~60 pixels wide, ~60 pixels tall)
    # Letters start at y=50, centered horizontally

    # Simple block font for QIXY
    def draw_rect(x1, y1, x2, y2, color):
        for y in range(max(0, y1), min(200, y2)):
            for x in range(max(0, x1), min(320, x2)):
                pixels[y][x] = color

    letter_width = 50
    letter_height = 60
    letter_spacing = 10
    total_width = 4 * letter_width + 3 * letter_spacing
    start_x = (320 - total_width) // 2
    start_y = 50
    thickness = 12

    # Q - circle with tail
    qx = start_x
    # Draw Q as a square O with a diagonal tail
    draw_rect(qx, start_y, qx + letter_width, start_y + thickness, 3)  # Top
    draw_rect(qx, start_y + letter_height - thickness, qx + letter_width, start_y + letter_height, 3)  # Bottom
    draw_rect(qx, start_y, qx + thickness, start_y + letter_height, 3)  # Left
    draw_rect(qx + letter_width - thickness, start_y, qx + letter_width, start_y + letter_height, 3)  # Right
    # Q tail
    draw_rect(qx + letter_width - 20, start_y + letter_height - 15, qx + letter_width + 5, start_y + letter_height + 10, 3)

    # I - simple vertical bar with serifs
    ix = start_x + letter_width + letter_spacing
    draw_rect(ix, start_y, ix + letter_width, start_y + thickness, 7)  # Top serif
    draw_rect(ix, start_y + letter_height - thickness, ix + letter_width, start_y + letter_height, 7)  # Bottom serif
    draw_rect(ix + (letter_width - thickness) // 2, start_y, ix + (letter_width + thickness) // 2, start_y + letter_height, 7)  # Vertical

    # X - two diagonal bars (simplified as crossed rectangles)
    xx = start_x + 2 * (letter_width + letter_spacing)
    # Draw X as two crossing diagonals - simplified to tilted rectangles
    for i in range(letter_height):
        x_offset = int(i * letter_width / letter_height)
        # Left to right diagonal
        draw_rect(xx + x_offset, start_y + i, xx + x_offset + thickness, start_y + i + 1, 2)
        # Right to left diagonal
        draw_rect(xx + letter_width - x_offset - thickness, start_y + i, xx + letter_width - x_offset, start_y + i + 1, 2)

    # Y - V with a stem
    yx = start_x + 3 * (letter_width + letter_spacing)
    mid_y = start_y + letter_height // 2
    # Top left diagonal
    for i in range(letter_height // 2):
        x_offset = int(i * (letter_width // 2 - thickness // 2) / (letter_height // 2))
        draw_rect(yx + x_offset, start_y + i, yx + x_offset + thickness, start_y + i + 1, 4)
    # Top right diagonal
    for i in range(letter_height // 2):
        x_offset = int(i * (letter_width // 2 - thickness // 2) / (letter_height // 2))
        draw_rect(yx + letter_width - x_offset - thickness, start_y + i, yx + letter_width - x_offset, start_y + i + 1, 4)
    # Stem
    draw_rect(yx + (letter_width - thickness) // 2, mid_y, yx + (letter_width + thickness) // 2, start_y + letter_height, 4)

    # Subtitle "A QIX CLONE FOR C64" at y=130
    subtitle_y = 130
    subtitle_colors = [14, 3, 7, 13, 5]  # Gradient colors
    for x in range(40, 280):
        color_idx = (x - 40) * len(subtitle_colors) // 240
        pixels[subtitle_y][x] = subtitle_colors[color_idx]
        pixels[subtitle_y + 1][x] = subtitle_colors[color_idx]

    # "PRESS FIRE TO START" flashing area at y=160
    for x in range(80, 240):
        pixels[160][x] = 1  # White
        pixels[161][x] = 1

    return pixels

def convert_to_multicolor_bitmap(pixels):
    """
    Convert 320x200 indexed pixels to C64 multicolor bitmap format.

    Returns:
        tuple: (bitmap_data, screen_ram, color_ram, background_color)
        - bitmap_data: 8000 bytes
        - screen_ram: 1000 bytes (upper/lower nybbles for 2 colors per cell)
        - color_ram: 1000 bytes
        - background_color: single byte
    """
    bitmap_data = bytearray(8000)
    screen_ram = bytearray(1000)
    color_ram = bytearray(1000)

    # Find most common color as background
    color_counts = [0] * 16
    for row in pixels:
        for c in row:
            color_counts[c] += 1
    background_color = color_counts.index(max(color_counts))

    # Process each 4x8 character cell
    cell_idx = 0
    for char_row in range(25):  # 25 character rows
        for char_col in range(40):  # 40 character columns
            # Get all pixels in this 4x8 cell
            # Note: multicolor mode uses 4-pixel wide cells (2 bits per pixel)
            # So we process 8 horizontal pixels as 4 multicolor pixels
            cell_pixels = []
            for y in range(8):
                py = char_row * 8 + y
                for x in range(4):  # 4 multicolor pixels = 8 hires pixels
                    px = char_col * 8 + x * 2
                    if py < 200 and px < 320:
                        # Take the average/dominant of the 2 hires pixels
                        c1 = pixels[py][px]
                        c2 = pixels[py][min(px + 1, 319)]
                        # Pick the most common one, or the first if tie
                        cell_pixels.append(c1 if c1 == c2 else c1)
                    else:
                        cell_pixels.append(background_color)

            # Find the 4 most common colors in this cell
            cell_colors = {}
            for c in cell_pixels:
                cell_colors[c] = cell_colors.get(c, 0) + 1

            sorted_colors = sorted(cell_colors.keys(), key=lambda x: -cell_colors[x])

            # Map: %00=bg, %01=screen upper, %10=screen lower, %11=color RAM
            color_map = {background_color: 0}
            screen_upper = background_color
            screen_lower = background_color
            colorram_color = background_color

            color_slot = 1
            for c in sorted_colors:
                if c == background_color:
                    continue
                if color_slot == 1:
                    screen_upper = c
                    color_map[c] = 1
                elif color_slot == 2:
                    screen_lower = c
                    color_map[c] = 2
                elif color_slot == 3:
                    colorram_color = c
                    color_map[c] = 3
                else:
                    break  # Can only have 4 colors per cell
                color_slot += 1

            # Set screen RAM and color RAM for this cell
            screen_ram[cell_idx] = (screen_upper << 4) | screen_lower
            color_ram[cell_idx] = colorram_color

            # Convert cell pixels to bitmap bytes
            for y in range(8):
                byte_val = 0
                for x in range(4):
                    pixel_idx = y * 4 + x
                    pixel_color = cell_pixels[pixel_idx]
                    # Map to 2-bit value
                    if pixel_color in color_map:
                        bits = color_map[pixel_color]
                    else:
                        # Find nearest mapped color
                        bits = 0
                        min_dist = float('inf')
                        for mapped_color, mapped_bits in color_map.items():
                            dist = color_distance(C64_PALETTE[pixel_color], C64_PALETTE[mapped_color])
                            if dist < min_dist:
                                min_dist = dist
                                bits = mapped_bits
                    byte_val = (byte_val << 2) | bits

                # Bitmap is stored in a special order:
                # Each 8x8 character cell is stored sequentially (8 bytes per cell)
                # Cells are stored row by row (40 cells per row, 25 rows)
                bitmap_offset = cell_idx * 8 + y
                bitmap_data[bitmap_offset] = byte_val

            cell_idx += 1

    return bitmap_data, screen_ram, color_ram, background_color

def write_asm_output(bitmap_data, screen_ram, color_ram, bg_color, output_path):
    """Write ACME assembly output file."""
    with open(output_path, 'w') as f:
        f.write("; ============================================================================\n")
        f.write("; QIXY Title Screen - Multicolor Bitmap Data\n")
        f.write("; Generated by convert_title.py\n")
        f.write("; ============================================================================\n")
        f.write("; Memory layout (VIC Bank 1: $4000-$7FFF):\n")
        f.write(";   Screen RAM:   $5C00-$5FE7 (1000 bytes) - bank offset $1C00\n")
        f.write(";   Bitmap data:  $6000-$7F3F (8000 bytes) - bank offset $2000\n")
        f.write(";   Color RAM:    Copied to $D800 at runtime\n")
        f.write("; VIC-II $D018 = $78 (screen at $1C00, bitmap at $2000)\n")
        f.write("; ============================================================================\n\n")

        f.write(f"TITLE_BG_COLOR = ${bg_color:02X}\n\n")

        # Screen RAM at $5C00 (for VIC bank 1 with screen at offset $1C00)
        f.write("; Screen RAM for title (1000 bytes)\n")
        f.write("* = $5C00\n")
        f.write("TITLE_SCREEN:\n")
        for i in range(0, len(screen_ram), 16):
            chunk = screen_ram[i:i+16]
            hex_bytes = ", ".join(f"${b:02X}" for b in chunk)
            f.write(f"        !byte {hex_bytes}\n")

        # Bitmap data at $6000 (bank offset $2000)
        f.write("\n; Bitmap data (8000 bytes)\n")
        f.write("* = $6000\n")
        f.write("TITLE_BITMAP:\n")
        for i in range(0, len(bitmap_data), 16):
            chunk = bitmap_data[i:i+16]
            hex_bytes = ", ".join(f"${b:02X}" for b in chunk)
            f.write(f"        !byte {hex_bytes}\n")

        # Color RAM data (stored after bitmap, copied to $D800 at runtime)
        f.write("\n; Color RAM data for title (1000 bytes) - copy to $D800\n")
        f.write("TITLE_COLORS:\n")
        for i in range(0, len(color_ram), 16):
            chunk = color_ram[i:i+16]
            hex_bytes = ", ".join(f"${b:02X}" for b in chunk)
            f.write(f"        !byte {hex_bytes}\n")

        f.write("\n; End of title data\n")

def main():
    script_dir = Path(__file__).parent
    output_path = script_dir.parent / "title_data.asm"

    if len(sys.argv) > 1:
        input_file = sys.argv[1]
        if not os.path.exists(input_file):
            print(f"Error: File not found: {input_file}")
            sys.exit(1)
        print(f"Loading PNG: {input_file}")
        pixels = load_png(input_file)
    else:
        print("No input file specified, generating sample title screen...")
        pixels = generate_sample_title()

    print("Converting to C64 multicolor bitmap format...")
    bitmap_data, screen_ram, color_ram, bg_color = convert_to_multicolor_bitmap(pixels)

    print(f"Background color: {bg_color} ({['Black', 'White', 'Red', 'Cyan', 'Purple', 'Green', 'Blue', 'Yellow', 'Orange', 'Brown', 'Pink', 'Dark Grey', 'Grey', 'Light Green', 'Light Blue', 'Light Grey'][bg_color]})")
    print(f"Bitmap data: {len(bitmap_data)} bytes")
    print(f"Screen RAM: {len(screen_ram)} bytes")
    print(f"Color RAM: {len(color_ram)} bytes")

    print(f"Writing output: {output_path}")
    write_asm_output(bitmap_data, screen_ram, color_ram, bg_color, output_path)

    print("Done!")

if __name__ == "__main__":
    main()
