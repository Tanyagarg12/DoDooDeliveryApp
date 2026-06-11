"""
Generates DoDoo Rider launcher icons (teal background, white delivery scooter).
Run from the android/ directory:  python generate_icons.py
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw

TEAL = (15, 118, 110)
WHITE = (255, 255, 255)

SIZES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

RES = Path(__file__).parent / "app" / "src" / "main" / "res"


def draw_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Circular teal background
    d.ellipse([0, 0, size - 1, size - 1], fill=TEAL)

    s = size / 96  # scale factor (design at 96px)

    def pt(x, y):
        return (x * s, y * s)

    def ptl(points):
        return [pt(x, y) for x, y in points]

    # --- Rider head (circle) ---
    hx, hy, hr = 48, 20, 8
    d.ellipse(
        [pt(hx - hr, hy - hr), pt(hx + hr, hy + hr)],
        fill=WHITE,
    )

    # --- Helmet (arc above head) ---
    d.pieslice(
        [pt(hx - hr - 1, hy - hr - 2), pt(hx + hr + 1, hy + hr)],
        start=200,
        end=340,
        fill=WHITE,
    )

    # --- Scooter body (simplified polygon) ---
    body = ptl([
        (20, 58), (20, 50), (52, 45), (68, 45),
        (72, 50), (78, 50), (83, 58), (80, 66),
        (62, 66), (60, 62), (38, 62), (36, 66),
        (24, 66),
    ])
    d.polygon(body, fill=WHITE)

    # --- Cargo box on back ---
    box = ptl([(20, 45), (20, 36), (48, 36), (48, 45)])
    d.polygon(box, fill=WHITE)

    # --- Rear wheel ---
    def circle(cx, cy, r, fill):
        d.ellipse([pt(cx - r, cy - r), pt(cx + r, cy + r)], fill=fill)

    circle(30, 68, 10, WHITE)
    circle(30, 68, 5, TEAL)

    # --- Front wheel ---
    circle(74, 68, 10, WHITE)
    circle(74, 68, 5, TEAL)

    # --- Handlebar ---
    d.line([pt(58, 45), pt(62, 38), pt(70, 38)], fill=WHITE, width=max(2, int(3 * s)))

    return img


for folder, size in SIZES.items():
    out_dir = RES / folder
    out_dir.mkdir(parents=True, exist_ok=True)
    icon = draw_icon(size)
    out_path = out_dir / "ic_launcher.png"
    icon.save(out_path, "PNG")
    print(f"  wrote {out_path.relative_to(RES.parent.parent.parent.parent)}")

print("Done.")
