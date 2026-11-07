#!/usr/bin/env python3
"""Builds sound effects from downloaded CC0 recordings.

  python3 tool/prepare_sfx.py /path/to/downloads

Each effect in RECIPES is a mix of one or more source clips (path under
the downloads folder, start offset, gain). Sources are decoded with
ffmpeg to 22.05 kHz mono, their leading silence is cut, they are mixed,
trimmed, faded, peak-normalised and written to assets/audio/sfx/<name>.wav.
A loop recipe takes a steady stretch of one recording and folds its
tail over its head so it repeats without a seam.

Effects not listed here keep the synthesised version from
tool/generate_sfx.py. Every source and its licence is recorded in
assets/audio/SFX_SOURCE.txt; only CC0 recordings are used. Needs numpy
and ffmpeg.
"""

import pathlib
import subprocess
import sys
import wave

import numpy as np

SR = 22050
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets/audio/sfx"

# name: (length s, peak dB, fade-out s, [(source, at s, gain, skip s)])
RECIPES = {
    "hit": (0.3, -4, 0.08, [
        ("100-CC0-wood-metal-SFX/wood_hit_04.ogg", 0.0, 1.0, 0),
        ("sfx_breaking_and_falling/bfh1_metal_hit_06.ogg", 0.005, 0.45, 0),
    ]),
    "damage": (0.6, -2, 0.15, [
        ("sfx_breaking_and_falling/bfh1_hit_06.ogg", 0.0, 1.0, 0),
        ("sfx_breaking_and_falling/bfh1_wood_breaking_03.ogg", 0.02, 0.8, 0),
        ("100-CC0-SFX_0/metal_03.ogg", 0.04, 0.6, 0),
    ]),
    "jam": (0.5, -5, 0.08, [
        ("sfx_breaking_and_falling/bfh1_metal_hit_02.ogg", 0.0, 0.9, 0),
        ("sfx_breaking_and_falling/bfh1_metal_hit_04.ogg", 0.13, 0.8, 0),
        ("100-CC0-SFX_0/switch_01.ogg", 0.27, 0.7, 0),
    ]),
    "explosion": (1.9, -1, 0.5, [
        ("25-CC0-bang-sfx/bang_09.ogg", 0.0, 1.0, 0),
        ("NenadSimic - Muffled Distant Explosion.wav", 0.0, 0.8, 0),
    ]),
    "flak": (0.9, -3, 0.25, [
        ("25-CC0-bang-sfx/bang_03.ogg", 0.0, 1.0, 0),
        ("NenadSimic - Muffled Distant Explosion.wav", 0.0, 0.35, 0),
    ]),
}

# name: (source, start s, length s, crossfade s, peak dB)
# The gun loop is eight rounds from the middle of a long burst, cut just
# before a round's onset at both ends so the rhythm carries on unbroken
# (rounds 0.0915 s apart, about 655 a minute).
LOOPS = {
    "gun": ("Prepared SFX Library/AK-47/C_27P.wav", 5.831, 0.727, 0.01, -3),
}


def decode(path: pathlib.Path) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
        capture_output=True,
        check=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768


def lead_trim(x: np.ndarray) -> np.ndarray:
    """Drop the silence before the sound starts (below -40 dB of peak)."""
    peak = np.max(np.abs(x)) or 1.0
    loud = np.nonzero(np.abs(x) > peak * 0.01)[0]
    return x[max(0, loud[0] - int(SR * 0.002)):] if len(loud) else x


def normalise(x: np.ndarray, peak_db: float) -> np.ndarray:
    return x / (np.max(np.abs(x)) or 1.0) * 10 ** (peak_db / 20)


def write(name: str, x: np.ndarray) -> None:
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f"  {name}: {len(x) / SR:.2f} s, {len(data) // 1024} KB")


def mix(src: pathlib.Path, length: float, peak_db: float, fade: float, parts) -> np.ndarray:
    out = np.zeros(int(SR * length))
    for rel, at, gain, skip in parts:
        clip = lead_trim(decode(src / rel)[int(SR * skip):])
        clip = clip / (np.max(np.abs(clip)) or 1.0) * gain
        i = int(SR * at)
        n = min(len(clip), len(out) - i)
        out[i:i + n] += clip[:n]
    nf = int(SR * fade)
    out[-nf:] *= np.linspace(1, 0, nf) ** 2
    out[: int(SR * 0.002)] *= np.linspace(0, 1, int(SR * 0.002))
    return normalise(soft_limit(out), peak_db)


def soft_limit(x: np.ndarray, drive: float = 2.2) -> np.ndarray:
    """Gentle tanh limiter: brings the body of a recording up to the
    loudness of the rest of the set without hard clipping its peaks."""
    x = x / (np.max(np.abs(x)) or 1.0)
    return np.tanh(drive * x) / np.tanh(drive)


def loop(src: pathlib.Path, rel: str, start: float, length: float, xfade: float, peak_db: float) -> np.ndarray:
    x = decode(src / rel)
    i, n, f = int(SR * start), int(SR * length), int(SR * xfade)
    seg = x[i:i + n + f]
    out = seg[:n].copy()
    # The stretch just after the loop end is faded in over the start, so
    # the sample after the last one is the recording's own next sample.
    out[:f] = seg[:f] * np.linspace(0, 1, f) + seg[n:n + f] * np.linspace(1, 0, f)
    return normalise(soft_limit(out, 1.8), peak_db)


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    src = pathlib.Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (length, peak, fade, parts) in RECIPES.items():
        write(name, mix(src, length, peak, fade, parts))
    for name, (rel, start, length, xfade, peak) in LOOPS.items():
        write(name, loop(src, rel, start, length, xfade, peak))
    return 0


if __name__ == "__main__":
    sys.exit(main())
