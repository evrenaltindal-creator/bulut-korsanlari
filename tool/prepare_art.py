#!/usr/bin/env python3
"""Prepares the story illustrations from the image generator's files.

Reads a folder of generated images named <key>_<anything>.jpg|png
(chapter1..3, m1..m9, selvi, kerem, surmeli, kuzgun) and writes:
  assets/images/chapters/chapterN.jpg   1280x720
  assets/images/missions/mN.jpg         1280x720
  assets/images/portraits/<name>.jpg    640x640 (centre square crop)
as progressive JPEG without metadata. TRIM lists painted paper borders
to cut off before cropping, as fractions (left, top, right, bottom).

Needs Pillow. Usage:
  python3 tool/prepare_art.py /path/to/generated/folder
Record where the images came from in assets/images/IMAGE_SOURCE.txt.
"""

import pathlib
import sys

from PIL import Image

OUT = pathlib.Path("assets/images")
WIDE = (1280, 720)
SQUARE = 640
PORTRAITS = {"selvi", "kerem", "surmeli", "kuzgun"}
TRIM = {"chapter2": (0.03, 0.055, 0.975, 0.94)}


def crop_to(img: Image.Image, ratio: float) -> Image.Image:
    w, h = img.size
    if w / h > ratio:
        nw = round(h * ratio)
        left = (w - nw) // 2
        return img.crop((left, 0, left + nw, h))
    nh = round(w / ratio)
    top = (h - nh) // 2
    return img.crop((0, top, w, top + nh))


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    src = pathlib.Path(sys.argv[1])
    seen = set()
    for path in sorted(src.iterdir()):
        if path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
            continue
        key = path.stem.split("_")[0]
        img = Image.open(path).convert("RGB")
        if key in TRIM:
            l, t, r, b = TRIM[key]
            w, h = img.size
            img = img.crop((round(l * w), round(t * h), round(r * w), round(b * h)))
        if key in PORTRAITS:
            img = crop_to(img, 1).resize((SQUARE, SQUARE), Image.LANCZOS)
            dst = OUT / "portraits" / f"{key}.jpg"
        elif key.startswith("chapter"):
            img = crop_to(img, WIDE[0] / WIDE[1]).resize(WIDE, Image.LANCZOS)
            dst = OUT / "chapters" / f"{key}.jpg"
        elif key.startswith("m") and key[1:].isdigit():
            img = crop_to(img, WIDE[0] / WIDE[1]).resize(WIDE, Image.LANCZOS)
            dst = OUT / "missions" / f"{key}.jpg"
        else:
            print(f"skipping {path.name}: unknown name")
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        img.save(dst, "JPEG", quality=82, optimize=True, progressive=True)
        seen.add(key)
        print(f"  {key}: {dst} ({dst.stat().st_size // 1024} KB)")
    print(f"{len(seen)} images")
    return 0


if __name__ == "__main__":
    sys.exit(main())
