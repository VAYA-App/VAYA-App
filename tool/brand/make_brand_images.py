"""Build the app icon and splash sources in assets/brand/ from the mascot.

Run from the repo root (needs Pillow):

    python3 tool/brand/make_brand_images.py

Then regenerate the platform files:

    dart run flutter_launcher_icons
    dart run flutter_native_splash:create
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
WAVE = ROOT / "assets/mascot/3.0x/wave.webp"
OUT = ROOT / "assets/brand"

EMERALD = (0x00, 0x69, 0x48)
EMERALD_LIGHT = (0x0E, 0x7E, 0x58)

# Head, ears and scarf of the waving pose, as a square in wave.webp (720px).
HEAD_BOX = (90, 20, 650, 580)


def head(size: int) -> Image.Image:
    return (
        Image.open(WAVE)
        .convert("RGBA")
        .crop(HEAD_BOX)
        .resize((size, size), Image.LANCZOS)
    )


def icon() -> Image.Image:
    """Opaque 1024px icon for iOS and legacy Android: head on emerald."""
    img = Image.new("RGBA", (1024, 1024), EMERALD)
    ImageDraw.Draw(img).ellipse((132, 132, 892, 892), fill=EMERALD_LIGHT)
    # The crop cuts through the body, so that edge sits on the icon's edge.
    face = head(820)
    img.alpha_composite(face, (102, 1024 - 820))
    return img.convert("RGB")


def foreground() -> Image.Image:
    """Adaptive-icon foreground: head inside the 66% safe zone, body cut on
    the canvas edge where the launcher mask hides it."""
    img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    face = head(760)
    img.alpha_composite(face, (132, 1024 - 760))
    return img


def splash() -> Image.Image:
    """The whole waving mascot, for the launch screen."""
    return Image.open(WAVE).convert("RGBA")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    icon().save(OUT / "icon.png")
    foreground().save(OUT / "icon_foreground.png")
    splash().save(OUT / "splash.png")
    print("wrote", ", ".join(p.name for p in sorted(OUT.glob("*.png"))))
