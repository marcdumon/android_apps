#!/usr/bin/env python3
"""Render the launcher glyph: a white tick on transparency, drawn over the blue background
that ic_launcher.xml supplies. Run this after changing the shape, then rebuild."""

import pathlib

from PIL import Image, ImageDraw

SIZE: int = 432
GLYPH: str = '#ffffff'
OUT: pathlib.Path = pathlib.Path(__file__).parent / 'app/src/main/res/drawable-nodpi/app_icon.png'


def draw_tick() -> Image.Image:
    """A bold tick, centred, sized to survive the launcher's 25% inset and circular mask."""
    scale = 4
    px = SIZE * scale
    img = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    width = int(px * 0.11)
    points = [(px * 0.26, px * 0.52), (px * 0.44, px * 0.70), (px * 0.76, px * 0.31)]
    draw.line(points, fill=GLYPH, width=width, joint='curve')
    # Rounded ends: PIL leaves square caps, so cap each end with a circle.
    for x, y in (points[0], points[-1]):
        r = width / 2
        draw.ellipse([x - r, y - r, x + r, y + r], fill=GLYPH)

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    """Write the glyph into the drawable directory."""
    OUT.parent.mkdir(parents=True, exist_ok=True)
    draw_tick().save(OUT)
    print(f'{OUT.name}: {OUT.stat().st_size} bytes')


if __name__ == '__main__':
    main()
