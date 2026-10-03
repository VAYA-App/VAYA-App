"""Turns mascot renders into transparent, consistently framed app assets.

Canva's free plan cannot export transparent PNGs, so each pose is exported
twice: once on a white page and once on a black page. The difference between
the two gives the exact alpha of every pixel (difference matting).

Usage (see docs/MASCOT.md):
    python3 tool/mascot/matte.py <white_dir> <black_dir>

Both folders hold one PNG per pose with the same file names, e.g.
white/wave.png and black/wave.png. Output goes to assets/mascot/ as WebP in
1x, 2.0x and 3.0x, plus an `avatar` cropped from the `wave` pose.

Requires Pillow and NumPy.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / 'assets' / 'mascot'

# Logical size (dp) of each asset at 1x.
POSE_SIZE = 240
AVATAR_SIZE = 96

# Avatar = head and shoulders of the wave pose, as fractions of the framed
# pose image (left, top, size).
AVATAR_BOX = (0.166, 0.0, 0.694)

PADDING = 16


def matte(white: Path, black: Path) -> np.ndarray:
    w = np.asarray(Image.open(white).convert('RGB')).astype(np.float32)
    b = np.asarray(Image.open(black).convert('RGB')).astype(np.float32)
    alpha = np.clip(1.0 - (w - b).mean(axis=2) / 255.0, 0, 1)
    alpha[alpha < 0.02] = 0
    colour = np.where(alpha[..., None] > 0, b / np.maximum(alpha[..., None], 1e-6), 0)
    return np.dstack([np.clip(colour, 0, 255), alpha * 255]).round().astype(np.uint8)


def shared_frame(images: dict[str, np.ndarray]) -> tuple[int, int, int]:
    """One square crop that fits every pose, so the elephant keeps the same
    scale whichever pose is shown."""
    ys, xs = [], []
    for rgba in images.values():
        yy, xx = np.where(rgba[..., 3] > 8)
        ys += [yy.min(), yy.max()]
        xs += [xx.min(), xx.max()]
    y0, y1, x0, x1 = min(ys), max(ys), min(xs), max(xs)
    side = max(y1 - y0, x1 - x0) + 2 * PADDING
    return max(0, (y0 + y1) // 2 - side // 2), max(0, (x0 + x1) // 2 - side // 2), side


def save_variants(image: Image.Image, name: str, size: int) -> None:
    for scale, folder in ((1, OUT), (2, OUT / '2.0x'), (3, OUT / '3.0x')):
        folder.mkdir(parents=True, exist_ok=True)
        px = size * scale
        image.resize((px, px), Image.LANCZOS).save(folder / f'{name}.webp', 'WEBP', quality=90, method=6)


def main(white_dir: str, black_dir: str) -> None:
    names = sorted(p.stem for p in Path(white_dir).glob('*.png'))
    images = {n: matte(Path(white_dir) / f'{n}.png', Path(black_dir) / f'{n}.png') for n in names}
    top, left, side = shared_frame(images)
    framed = {}
    for name, rgba in images.items():
        framed[name] = Image.fromarray(rgba, 'RGBA').crop((left, top, left + side, top + side))
        save_variants(framed[name], name, POSE_SIZE)
        print(f'{name}: {side}px frame')
    if 'wave' in framed:
        l, t, s = (round(v * side) for v in AVATAR_BOX)
        save_variants(framed['wave'].crop((l, t, l + s, t + s)), 'avatar', AVATAR_SIZE)
        print('avatar: from wave')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
