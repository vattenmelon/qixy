#!/usr/bin/env python3
"""Add credit text to title.png in the black rectangle area using a futuristic font."""

from PIL import Image, ImageDraw, ImageFont

def main():
    img = Image.open('title.png').convert('RGBA')
    draw = ImageDraw.Draw(img)
    w, h = img.size  # 923x530

    # The black rectangle area is roughly the bottom portion, y=340 to y=530
    # We'll place text centered in this area

    # Use Futura Bold for a futuristic look
    try:
        font_large = ImageFont.truetype('/System/Library/Fonts/Supplemental/Futura.ttc', 36, index=1)  # Bold
        font_small = ImageFont.truetype('/System/Library/Fonts/Supplemental/Futura.ttc', 28, index=1)  # Bold
    except Exception:
        # Fallback to Avenir Next Condensed Bold
        font_large = ImageFont.truetype('/System/Library/Fonts/Avenir Next Condensed.ttc', 36, index=3)
        font_small = ImageFont.truetype('/System/Library/Fonts/Avenir Next Condensed.ttc', 28, index=3)

    # Color: bright cyan/light blue for futuristic look
    text_color = (0x00, 0xBB, 0xFF, 255)  # Bright blue
    text_color2 = (0xAA, 0xFF, 0xEE, 255)  # Cyan

    # Text lines
    line1 = "CODED BY CLAUDE"
    line2 = "PUBLISHED BY"
    line3 = "ERLING REIZER AS"

    center_x = w // 2

    # Place "CODED BY CLAUDE"
    bbox1 = draw.textbbox((0, 0), line1, font=font_large)
    tw1 = bbox1[2] - bbox1[0]
    y1 = 370
    draw.text((center_x - tw1 // 2, y1), line1, fill=text_color, font=font_large)

    # Place "PUBLISHED BY"
    bbox2 = draw.textbbox((0, 0), line2, font=font_small)
    tw2 = bbox2[2] - bbox2[0]
    y2 = 430
    draw.text((center_x - tw2 // 2, y2), line2, fill=text_color2, font=font_small)

    # Place "ERLING REIZER AS"
    bbox3 = draw.textbbox((0, 0), line3, font=font_small)
    tw3 = bbox3[2] - bbox3[0]
    y3 = 468
    draw.text((center_x - tw3 // 2, y3), line3, fill=text_color2, font=font_small)

    img.save('title.png')
    print(f"Added text to title.png ({w}x{h})")

if __name__ == '__main__':
    main()
