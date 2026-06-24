#!/usr/bin/env python3
"""Add credit text to title_320x200.png using thick pixel-drawn block letters
that survive C64 multicolor bitmap conversion (effective 160x200 resolution)."""

from PIL import Image, ImageDraw

# Simple 5x5 block font - each letter is a list of (x,y) pixel positions
# Designed to be 2px wide strokes minimum for C64 multicolor readability
BLOCK_FONT = {
    'A': [
        "..XX..",
        ".X..X.",
        ".XXXX.",
        ".X..X.",
        ".X..X.",
    ],
    'B': [
        ".XXX..",
        ".X..X.",
        ".XXX..",
        ".X..X.",
        ".XXX..",
    ],
    'C': [
        "..XXX.",
        ".X....",
        ".X....",
        ".X....",
        "..XXX.",
    ],
    'D': [
        ".XXX..",
        ".X..X.",
        ".X..X.",
        ".X..X.",
        ".XXX..",
    ],
    'E': [
        ".XXXX.",
        ".X....",
        ".XXX..",
        ".X....",
        ".XXXX.",
    ],
    'F': [
        ".XXXX.",
        ".X....",
        ".XXX..",
        ".X....",
        ".X....",
    ],
    'G': [
        "..XXX.",
        ".X....",
        ".X.XX.",
        ".X..X.",
        "..XXX.",
    ],
    'H': [
        ".X..X.",
        ".X..X.",
        ".XXXX.",
        ".X..X.",
        ".X..X.",
    ],
    'I': [
        ".XXX.",
        "..X..",
        "..X..",
        "..X..",
        ".XXX.",
    ],
    'K': [
        ".X..X.",
        ".X.X..",
        ".XX...",
        ".X.X..",
        ".X..X.",
    ],
    'L': [
        ".X....",
        ".X....",
        ".X....",
        ".X....",
        ".XXXX.",
    ],
    'N': [
        ".X..X.",
        ".XX.X.",
        ".X.XX.",
        ".X..X.",
        ".X..X.",
    ],
    'O': [
        "..XX..",
        ".X..X.",
        ".X..X.",
        ".X..X.",
        "..XX..",
    ],
    'P': [
        ".XXX..",
        ".X..X.",
        ".XXX..",
        ".X....",
        ".X....",
    ],
    'R': [
        ".XXX..",
        ".X..X.",
        ".XXX..",
        ".X.X..",
        ".X..X.",
    ],
    'S': [
        "..XXX.",
        ".X....",
        "..XX..",
        "....X.",
        ".XXX..",
    ],
    'T': [
        ".XXXXX.",
        "...X...",
        "...X...",
        "...X...",
        "...X...",
    ],
    'U': [
        ".X..X.",
        ".X..X.",
        ".X..X.",
        ".X..X.",
        "..XX..",
    ],
    'V': [
        ".X..X.",
        ".X..X.",
        ".X..X.",
        "..XX..",
        "..XX..",
    ],
    'W': [
        ".X...X.",
        ".X...X.",
        ".X.X.X.",
        ".XX.XX.",
        ".X...X.",
    ],
    'X': [
        ".X..X.",
        "..XX..",
        "..XX..",
        "..XX..",
        ".X..X.",
    ],
    'Y': [
        ".X..X.",
        ".X..X.",
        "..XX..",
        "..X...",
        "..X...",
    ],
    'Z': [
        ".XXXX.",
        "...X..",
        "..X...",
        ".X....",
        ".XXXX.",
    ],
    ' ': [
        "...",
        "...",
        "...",
        "...",
        "...",
    ],
    '.': [
        "..",
        "..",
        "..",
        "..",
        ".X",
    ],
}


def draw_block_text(draw, text, x, y, color, scale=2):
    """Draw text using block font. Scale=2 means each font pixel is 2x2 screen pixels."""
    cursor_x = x
    for ch in text:
        glyph = BLOCK_FONT.get(ch.upper())
        if glyph is None:
            cursor_x += 3 * scale  # unknown char = space
            continue
        for row_idx, row in enumerate(glyph):
            for col_idx, pixel in enumerate(row):
                if pixel == 'X':
                    px = cursor_x + col_idx * scale
                    py = y + row_idx * scale
                    draw.rectangle([px, py, px + scale - 1, py + scale - 1], fill=color)
        cursor_x += len(glyph[0]) * scale + scale  # char width + spacing


def text_width(text, scale=2):
    """Calculate the pixel width of block text."""
    total = 0
    for ch in text:
        glyph = BLOCK_FONT.get(ch.upper())
        if glyph is None:
            total += 3 * scale
        else:
            total += len(glyph[0]) * scale + scale
    return total - scale  # remove trailing space


def main():
    img = Image.open('title_320x200.png').convert('RGB')
    draw = ImageDraw.Draw(img)
    w, h = img.size  # 320x200

    white = (0xFF, 0xFF, 0xFF)
    cyan = (0xAA, 0xFF, 0xEE)
    gray = (0x77, 0x77, 0x77)  # C64 color 12 (Grey)

    center_x = w // 2

    line1 = "CODED BY"
    line2 = "CLAUDE"

    tw1 = text_width(line1, scale=2)
    tw2 = text_width(line2, scale=2)
    max_tw = max(tw1, tw2)

    # Calculate rectangle to fit both lines with padding
    padding_x = 8
    padding_y = 4
    text_height = 5 * 2  # 5 rows * scale 2
    line_spacing = 4
    total_text_height = 2 * text_height + line_spacing

    y_start = 150
    rect_x1 = center_x - max_tw // 2 - padding_x
    rect_y1 = y_start - padding_y
    rect_x2 = center_x + max_tw // 2 + padding_x
    rect_y2 = y_start + total_text_height + padding_y

    # Draw text lines centered
    draw_block_text(draw, line1, center_x - tw1 // 2, y_start, white, scale=2)
    draw_block_text(draw, line2, center_x - tw2 // 2, y_start + text_height + line_spacing, white, scale=2)

    output = 'title_320x200_credits.png'
    img.save(output)
    print(f"Added credits to {output} ({w}x{h})")
    print(f"Line 1 width: {tw1}px")


if __name__ == '__main__':
    main()
