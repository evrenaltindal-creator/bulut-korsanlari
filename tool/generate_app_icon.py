#!/usr/bin/env python3
"""Builds every app icon from one square source image.

  python3 tool/generate_app_icon.py assets/branding/app_icon_source.png \
      [--preview /some/where/icon_preview.png]

Writes:
  iOS      ios/Runner/Assets.xcassets/AppIcon.appiconset/*  (sizes read
           from Contents.json; no alpha channel, App Store rejects it)
  Android  mipmap-*/ic_launcher.png (square, for old launchers) and an
           adaptive icon (Android 8+): the picture as the background layer,
           a transparent foreground. Launchers crop the adaptive layer to
           roughly its middle two thirds, so keep the subject centred.
  Web      web/icons/Icon-192/512 (+ maskable) and web/favicon.png

--preview draws the icon the way phones show it (rounded square, circle,
small sizes) so a candidate can be judged before it is chosen.

The source must be square-ish and at least 1024 px; it is centre-cropped
to a square. Edit the source, never the generated files. Needs Pillow.
"""

import argparse
import json
import pathlib
import sys

from PIL import Image, ImageDraw, ImageStat

ROOT = pathlib.Path(__file__).resolve().parent.parent
IOS = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID = ROOT / "android/app/src/main/res"
WEB = ROOT / "web"

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

# Share of an Android adaptive layer the picture fills. Launchers show
# only the middle 72 of its 108 dp, so a full-size picture loses its
# edges; at this size the circle keeps nearly all of it.
ADAPTIVE_INSET = 0.68
# Web maskable icons promise only a centre circle of 80 percent.
MASKABLE_INSET = 0.84

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""


def load(path: pathlib.Path) -> Image.Image:
    img = Image.open(path)
    w, h = img.size
    if min(w, h) < 1024:
        sys.exit(f"{path}: {w}x{h} is too small; the source must be at least 1024 px")
    if abs(w - h) > 0.25 * max(w, h):
        sys.exit(f"{path}: {w}x{h} is not square enough to crop to an icon")
    side = min(w, h)
    left, top = (w - side) // 2, (h - side) // 2
    img = img.crop((left, top, left + side, top + side))
    if img.mode in ("RGBA", "LA", "P"):
        # Icons must be opaque: flatten any transparency onto the corner
        # colour rather than black.
        rgba = img.convert("RGBA")
        bg = Image.new("RGBA", rgba.size, rgba.getpixel((2, 2))[:3] + (255,))
        img = Image.alpha_composite(bg, rgba)
    return img.convert("RGB")


def sized(img: Image.Image, px: int) -> Image.Image:
    return img.resize((px, px), Image.LANCZOS)


def edge_colour(img: Image.Image) -> tuple:
    """Average colour of the outermost two percent, to pad with."""
    w = img.size[0]
    band = max(2, w // 50)
    mask = Image.new("L", img.size, 255)
    ImageDraw.Draw(mask).rectangle((band, band, w - band - 1, w - band - 1), fill=0)
    return tuple(round(c) for c in ImageStat.Stat(img, mask).mean[:3])


def inset(img: Image.Image, px: int, share: float) -> Image.Image:
    """The picture at [share] of a [px] square, padded with its edge colour."""
    canvas = Image.new("RGB", (px, px), edge_colour(img))
    inner = round(px * share)
    off = (px - inner) // 2
    canvas.paste(sized(img, inner), (off, off))
    return canvas


def ios(img: Image.Image) -> int:
    contents = json.loads((IOS / "Contents.json").read_text())
    n = 0
    for entry in contents["images"]:
        size = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        px = round(size * scale)
        sized(img, px).save(IOS / entry["filename"], optimize=True)
        n += 1
    return n


def android(img: Image.Image) -> int:
    n = 0
    for name, k in DENSITIES.items():
        folder = ANDROID / f"mipmap-{name}"
        folder.mkdir(exist_ok=True)
        sized(img, round(48 * k)).save(folder / "ic_launcher.png", optimize=True)
        layer = round(108 * k)
        inset(img, layer, ADAPTIVE_INSET).save(folder / "ic_launcher_background.png", optimize=True)
        Image.new("RGBA", (layer, layer), (0, 0, 0, 0)).save(folder / "ic_launcher_foreground.png")
        n += 3
    anydpi = ANDROID / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(ADAPTIVE_XML)
    return n + 1


def web(img: Image.Image) -> int:
    for px in (192, 512):
        sized(img, px).save(WEB / "icons" / f"Icon-{px}.png", optimize=True)
        inset(img, px, MASKABLE_INSET).save(WEB / "icons" / f"Icon-maskable-{px}.png", optimize=True)
    sized(img, 32).save(WEB / "favicon.png", optimize=True)
    return 5


def preview(img: Image.Image, out: pathlib.Path) -> None:
    """Home-screen sizes on a dark and a light wallpaper."""
    sheet = Image.new("RGB", (1000, 420), (30, 34, 44))
    light = Image.new("RGB", (1000, 210), (226, 222, 214))
    sheet.paste(light, (0, 210))
    for row, y0 in enumerate((20, 230)):
        x = 30
        for px, shape in ((180, "ios"), (120, "ios"), (60, "ios"), (180, "circle"), (96, "circle"), (40, "ios")):
            icon = sized(img, px * 2).resize((px, px), Image.LANCZOS)
            mask = Image.new("L", (px, px), 0)
            d = ImageDraw.Draw(mask)
            if shape == "ios":
                d.rounded_rectangle((0, 0, px - 1, px - 1), radius=round(px * 0.225), fill=255)
            else:
                # Android shows the middle 72 of the adaptive layer's 108 dp.
                layer = inset(img, round(px * 1.5), ADAPTIVE_INSET)
                off = (layer.size[0] - px) // 2
                icon = layer.crop((off, off, off + px, off + px))
                d.ellipse((0, 0, px - 1, px - 1), fill=255)
            sheet.paste(icon, (x, y0 + (180 - px) // 2), mask)
            x += px + 30
    sheet.save(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("source")
    ap.add_argument("--preview", help="write a preview sheet here and change nothing else")
    args = ap.parse_args()
    img = load(pathlib.Path(args.source))
    if args.preview:
        preview(img, pathlib.Path(args.preview))
        print(f"preview: {args.preview}")
        return 0
    print(f"iOS: {ios(img)} files, Android: {android(img)} files, web: {web(img)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
