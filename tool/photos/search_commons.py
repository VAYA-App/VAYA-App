"""List Wikimedia Commons photo candidates for every Place and Destination.

Run from the repo root (standard library only):

    python3 tool/photos/search_commons.py candidates.json [id,id,...]

For each Place it searches Commons by name (plus any extra query in
tool/photos/queries.json) and keeps only photos whose licence allows use in
the app. Pick one file per id and put its title in tool/photos/picks.json,
then run fetch_photos.py.
"""

import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "assets/data"
QUERIES = Path(__file__).with_name("queries.json")

API = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = "VAYA-photo-tool/1.0 (https://github.com/VAYA-App/VAYA-App)"


def allowed(licence: str) -> bool:
    """Licences that let us ship the file in the app, with credit where
    needed: public domain, CC0, CC BY and CC BY-SA (never NC or ND)."""
    free = licence.startswith(("CC0", "Public domain", "PD", "CC BY"))
    return free and "NC" not in licence and "ND" not in licence


def search(query: str, limit: int = 8) -> list[dict]:
    params = {
        "action": "query",
        "format": "json",
        "generator": "search",
        "gsrnamespace": 6,
        "gsrlimit": limit,
        "gsrsearch": f"{query} filetype:bitmap",
        "prop": "imageinfo",
        "iiprop": "url|size|extmetadata",
        "iiurlwidth": 320,
    }
    req = urllib.request.Request(
        f"{API}?{urllib.parse.urlencode(params)}",
        headers={"User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(req, timeout=30) as res:
        pages = json.load(res).get("query", {}).get("pages", {})
    out = []
    for page in sorted(pages.values(), key=lambda p: p.get("index", 0)):
        info = page["imageinfo"][0]
        meta = info.get("extmetadata", {})
        licence = meta.get("LicenseShortName", {}).get("value", "")
        if not allowed(licence) or info["width"] < 800:
            continue
        out.append({
            "title": page["title"],
            "licence": licence,
            "size": [info["width"], info["height"]],
            "thumb": info.get("thumburl"),
        })
    return out


def targets() -> list[dict]:
    provinces = json.loads((DATA / "provinces.json").read_text())
    provinces = provinces if isinstance(provinces, list) else provinces["provinces"]
    items = []
    for p in provinces:
        items.append({"id": p["id"], "kind": "destination", "name": p["name"]})
        places = json.loads((DATA / f"places/{p['id']}.json").read_text())
        for place in places["places"]:
            items.append({
                "id": place["id"],
                "kind": place["category"],
                "name": place["name"],
                "province": p["name"],
            })
    for category in ("attraction", "restaurant", "accommodation"):
        items.append({"id": f"category-{category}", "kind": "category", "name": ""})
    return items


def main(out: Path, only: set[str] | None) -> None:
    extra = json.loads(QUERIES.read_text()) if QUERIES.exists() else {}
    result = {}
    for item in targets():
        if only and item["id"] not in only:
            continue
        queries = [q for q in [item["name"], *extra.get(item["id"], [])] if q]
        seen, found = set(), []
        for q in queries:
            for c in search(q):
                if c["title"] not in seen:
                    seen.add(c["title"])
                    found.append(c)
            time.sleep(0.5)  # stay polite to the Commons API
        result[item["id"]] = {**item, "candidates": found}
        print(f"{len(found):2d}  {item['id']}", flush=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main(Path(sys.argv[1]), set(sys.argv[2].split(",")) if len(sys.argv) > 2 else None)
