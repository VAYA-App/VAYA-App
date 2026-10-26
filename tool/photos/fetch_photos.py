"""Download the picked Commons photos, crop them and write the credits.

Run from the repo root (needs Pillow):

    python3 tool/photos/fetch_photos.py

Reads tool/photos/picks.json:

    {"<place, province or category id>": {"file": "File:....jpg",
                                          "focus": [0.5, 0.4]}}

`focus` is optional: the point (fractions of width and height) the crop
keeps in view. Destinations become 16:9 heroes, everything else a 4:3 card.
Writes assets/photos/<id>.webp and assets/photos/credits.json, which the
app reads for the photo credits page (ADR 0006).
"""

import html
import io
import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
PICKS = Path(__file__).with_name("picks.json")
OUT = ROOT / "assets/photos"
PROVINCES = ROOT / "assets/data/provinces.json"

API = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = "VAYA-photo-tool/1.0 (https://github.com/VAYA-App/VAYA-App)"

HERO = (1280, 720)
CARD = (800, 600)
QUALITY = 76


def get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as res:
        return res.read()


def info(title: str, width: int) -> dict:
    params = {
        "action": "query",
        "format": "json",
        "titles": title,
        "prop": "imageinfo",
        "iiprop": "url|extmetadata",
        "iiurlwidth": width,
    }
    data = json.loads(get(f"{API}?{urllib.parse.urlencode(params)}"))
    page = next(iter(data["query"]["pages"].values()))
    return page["imageinfo"][0]


def plain(value: str) -> str:
    """Commons metadata is HTML; credits need plain text."""
    return " ".join(html.unescape(re.sub(r"<[^>]+>", " ", value)).split())


def crop(img: Image.Image, size: tuple[int, int], focus) -> Image.Image:
    return ImageOps.fit(
        img.convert("RGB"),
        size,
        Image.LANCZOS,
        centering=tuple(focus) if focus else (0.5, 0.5),
    )


def main() -> None:
    picks = json.loads(PICKS.read_text())
    provinces = json.loads(PROVINCES.read_text())
    provinces = provinces if isinstance(provinces, list) else provinces["provinces"]
    heroes = {p["id"] for p in provinces}
    OUT.mkdir(parents=True, exist_ok=True)

    credits = []
    for photo_id, pick in sorted(picks.items()):
        size = HERO if photo_id in heroes else CARD
        meta = info(pick["file"], size[0] * 2)
        ext = meta.get("extmetadata", {})
        img = Image.open(io.BytesIO(get(meta["thumburl"])))
        crop(img, size, pick.get("focus")).save(
            OUT / f"{photo_id}.webp", "WEBP", quality=QUALITY, method=6
        )
        credits.append({
            "id": photo_id,
            "title": pick["file"].removeprefix("File:").rsplit(".", 1)[0],
            "author": plain(ext.get("Artist", {}).get("value", "ไม่ระบุ")),
            "licence": ext.get("LicenseShortName", {}).get("value", ""),
            "licenceUrl": ext.get("LicenseUrl", {}).get("value"),
            "source": meta["descriptionurl"],
        })
        print("ok", photo_id, flush=True)
        time.sleep(0.5)  # stay polite to the Commons API

    (OUT / "credits.json").write_text(
        json.dumps({"photos": credits}, ensure_ascii=False, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
