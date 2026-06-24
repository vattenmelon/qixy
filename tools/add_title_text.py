#!/usr/bin/env python3
"""Add credit text to the QIXY title screen bitmap in title_data.asm.

Renders text into the black rectangle area of the title screen bitmap.
Uses double-width characters (2 cells per letter) for readability.
"""

import sys
import os

# Double-width font: 8 multicolor pixels wide x 7 rows tall (row 8 blank)
# Each character spans 2 character cells horizontally
# Each row value is 8 bits: MSB=leftmost pixel
FONT = {
    ' ': [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    'A': [0x3C, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x00],
    'B': [0x7C, 0x66, 0x7C, 0x66, 0x66, 0x7C, 0x00],
    'C': [0x3E, 0x60, 0x60, 0x60, 0x60, 0x3E, 0x00],
    'D': [0x7C, 0x66, 0x66, 0x66, 0x66, 0x7C, 0x00],
    'E': [0x7E, 0x60, 0x7C, 0x60, 0x60, 0x7E, 0x00],
    'F': [0x7E, 0x60, 0x7C, 0x60, 0x60, 0x60, 0x00],
    'G': [0x3E, 0x60, 0x60, 0x6E, 0x66, 0x3E, 0x00],
    'H': [0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00],
    'I': [0x3C, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00],
    'J': [0x1E, 0x06, 0x06, 0x06, 0x66, 0x3C, 0x00],
    'K': [0x66, 0x6C, 0x78, 0x6C, 0x66, 0x66, 0x00],
    'L': [0x60, 0x60, 0x60, 0x60, 0x60, 0x7E, 0x00],
    'M': [0x63, 0x77, 0x7F, 0x6B, 0x63, 0x63, 0x00],
    'N': [0x66, 0x76, 0x7E, 0x6E, 0x66, 0x66, 0x00],
    'O': [0x3C, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00],
    'P': [0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x00],
    'Q': [0x3C, 0x66, 0x66, 0x6E, 0x66, 0x3E, 0x00],
    'R': [0x7C, 0x66, 0x66, 0x7C, 0x66, 0x66, 0x00],
    'S': [0x3E, 0x60, 0x3C, 0x06, 0x06, 0x7C, 0x00],
    'T': [0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00],
    'U': [0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00],
    'V': [0x66, 0x66, 0x66, 0x66, 0x3C, 0x18, 0x00],
    'W': [0x63, 0x63, 0x6B, 0x7F, 0x77, 0x63, 0x00],
    'X': [0x66, 0x66, 0x3C, 0x3C, 0x66, 0x66, 0x00],
    'Y': [0x66, 0x66, 0x3C, 0x18, 0x18, 0x18, 0x00],
    'Z': [0x7E, 0x06, 0x0C, 0x30, 0x60, 0x7E, 0x00],
}

# Character width in cells (most are 2, space is 1)
CHAR_WIDTH = {ch: 1 if ch == ' ' else 2 for ch in FONT}


def row_to_mc_bytes(row_bits):
    """Convert an 8-bit row pattern to two multicolor bytes (left cell, right cell).

    In multicolor bitmap mode, each byte encodes 4 pixels (2 bits each).
    We use %01 for foreground pixels and %00 for background.
    Left cell = bits 7-4, right cell = bits 3-0.
    """
    left = 0
    right = 0
    for i in range(4):
        if row_bits & (0x80 >> i):
            left |= (1 << (6 - i * 2))  # %01
    for i in range(4):
        if row_bits & (0x08 >> i):
            right |= (1 << (6 - i * 2))  # %01
    return left, right


def parse_byte_lines(text, label):
    """Extract byte values from !byte lines after a label."""
    result = []
    found = False
    for line in text.split('\n'):
        if label + ':' in line:
            found = True
            continue
        if found:
            if line.strip().startswith('* =') or (line.strip() and not line.strip().startswith('!byte') and not line.strip().startswith(';')):
                if result:
                    break
                continue
            if '!byte' in line:
                byte_part = line.split('!byte')[1].strip()
                for b in byte_part.split(','):
                    b = b.strip()
                    if b.startswith('$'):
                        result.append(int(b[1:], 16))
                    elif b.startswith('0x'):
                        result.append(int(b, 16))
                    else:
                        result.append(int(b))
    return result


def format_bytes(data, bytes_per_line=16):
    """Format byte array as !byte lines."""
    lines = []
    for i in range(0, len(data), bytes_per_line):
        chunk = data[i:i + bytes_per_line]
        hex_vals = ', '.join(f'${b:02X}' for b in chunk)
        lines.append(f'        !byte {hex_vals}')
    return '\n'.join(lines)


def clear_cell(bitmap, screen, colors, col, row):
    """Clear a character cell in the bitmap (make it black)."""
    bmp_off = row * 320 + col * 8
    for y in range(8):
        bitmap[bmp_off + y] = 0
    screen[row * 40 + col] = 0
    colors[row * 40 + col] = 0


def render_text(bitmap, screen, colors, text, col, row, fg_color=1):
    """Render double-width text into bitmap at character position (col, row)."""
    cur_col = col
    for ch in text:
        if ch not in FONT:
            print(f"Warning: '{ch}' not in font, skipping")
            continue

        w = CHAR_WIDTH[ch]
        glyph = FONT[ch]

        if ch == ' ':
            # Space: just clear one cell
            if cur_col < 40:
                clear_cell(bitmap, screen, colors, cur_col, row)
            cur_col += 1
            continue

        # Clear and render 2 cells for this character
        for ci in range(2):
            c = cur_col + ci
            if c >= 40:
                break
            clear_cell(bitmap, screen, colors, c, row)
            # Set screen RAM upper nibble to fg color for %01 pixels
            screen[row * 40 + c] = fg_color << 4

        # Write bitmap data
        for y in range(7):
            left, right = row_to_mc_bytes(glyph[y])
            bmp_left = row * 320 + cur_col * 8 + y
            bmp_right = row * 320 + (cur_col + 1) * 8 + y
            if cur_col < 40:
                bitmap[bmp_left] = left
            if cur_col + 1 < 40:
                bitmap[bmp_right] = right

        # Row 7 is blank (already cleared)
        cur_col += 2


def text_width_cells(text):
    """Calculate width in character cells for a text string."""
    return sum(CHAR_WIDTH.get(ch, 2) for ch in text)


def main():
    # Find title_data.asm - check parent dir or current dir
    filename = os.path.join(os.path.dirname(__file__), '..', 'title_data.asm')
    if not os.path.exists(filename):
        filename = 'title_data.asm'
    if len(sys.argv) > 1:
        filename = sys.argv[1]

    with open(filename, 'r') as f:
        content = f.read()

    screen = parse_byte_lines(content, 'TITLE_SCREEN')
    bitmap = parse_byte_lines(content, 'TITLE_BITMAP')
    colors = parse_byte_lines(content, 'TITLE_COLORS')

    print(f"Screen RAM: {len(screen)} bytes")
    print(f"Bitmap: {len(bitmap)} bytes")
    print(f"Color RAM: {len(colors)} bytes")

    # Text layout with double-width characters:
    # "CODED BY CLAUDE" = 12 letters*2 + 2 spaces*1 = 26 cells
    # "PUBLISHED BY"    = 11 letters*2 + 1 space*1 = 23 cells
    # "ERLING REIZER AS" = 14 letters*2 + 2 spaces*1 = 30 cells

    # Clear rows that have baked-in text from the original PNG
    # The source image has "CODED BY CLAUDE" around rows 16-17
    # and "PUBLISHED BY ERLING REIZER" around rows 23-24
    clear_rows = [16, 17, 18, 23, 24]
    for row in clear_rows:
        for c in range(40):
            clear_cell(bitmap, screen, colors, c, row)
    print(f"Cleared rows {clear_rows} (original image text)")

    text_lines = [
        (17, "CODED BY CLAUDE", 1),     # White
        (21, "PUBLISHED BY", 14),       # Light blue
        (22, "ERLING REIZER AS", 14),   # Light blue
    ]

    for row, text, fg_color in text_lines:
        width = text_width_cells(text)
        col = (40 - width) // 2
        print(f"Placing '{text}' at row {row}, col {col} (width {width} cells)")

        # Clear full row for clean look
        for c in range(max(0, col - 1), min(40, col + width + 1)):
            clear_cell(bitmap, screen, colors, c, row)

        render_text(bitmap, screen, colors, text, col, row, fg_color)

    # Rebuild ASM
    bg_line = "TITLE_BG_COLOR = $00"
    for line in content.split('\n'):
        if 'TITLE_BG_COLOR' in line:
            bg_line = line.strip()
            break

    screen_data = format_bytes(screen)
    bitmap_data = format_bytes(bitmap)
    color_data = format_bytes(colors)

    new_content = f"""; ============================================================================
; QIXY Title Screen - Multicolor Bitmap Data
; Generated by convert_title.py
; ============================================================================
; Memory layout (VIC Bank 1: $4000-$7FFF):
;   Screen RAM:   $5C00-$5FE7 (1000 bytes) - bank offset $1C00
;   Bitmap data:  $6000-$7F3F (8000 bytes) - bank offset $2000
;   Color RAM:    Copied to $D800 at runtime
; VIC-II $D018 = $78 (screen at $1C00, bitmap at $2000)
; ============================================================================

{bg_line}

; Screen RAM for title (1000 bytes)
* = $5C00
TITLE_SCREEN:
{screen_data}

; Bitmap data (8000 bytes)
* = $6000
TITLE_BITMAP:
{bitmap_data}

; Color RAM data (1000 bytes)
TITLE_COLORS:
{color_data}
"""

    with open(filename, 'w') as f:
        f.write(new_content)

    print(f"\nUpdated {filename}")


if __name__ == '__main__':
    main()
