#!/usr/bin/env python3
"""Prepares the game's music from the files the music generator produced.

For each `role=path` pair it:
  1. trims silence at the start and the end (below -50 dB),
  2. normalises loudness to -16 LUFS (two-pass loudnorm, true peak -1.5 dB),
  3. encodes 128 kbit/s constant-bitrate MP3, 44.1 kHz stereo, no tags,
and writes assets/audio/music/<role>.mp3. MP3 plays on iOS, Android and
every browser; constant bitrate keeps the duration exact for the
crossfade in lib/audio/music.dart.

Prints the durations to paste into the MusicTrack enum.

Needs ffmpeg with libmp3lame. Usage:
  python3 tool/prepare_music.py menu=/path/a.mp3 dogfight=/path/b.mp3 ...
Record where each file came from in assets/audio/MUSIC_SOURCE.txt.
"""

import argparse
import json
import pathlib
import subprocess
import sys

TARGET_LUFS = -16.0
TRUE_PEAK = -1.5
TRIM = (
    "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05,"
    "areverse,"
    "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.3,"
    "areverse"
)


def run(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, text=True, check=True)


def measure(src: pathlib.Path) -> dict:
    out = run([
        "ffmpeg", "-hide_banner", "-nostats", "-i", str(src),
        "-af", f"{TRIM},loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA=11:print_format=json",
        "-f", "null", "-",
    ]).stderr
    start = out.rindex("{")
    return json.loads(out[start:out.index("}", start) + 1])


def encode(src: pathlib.Path, dst: pathlib.Path, m: dict) -> None:
    norm = (
        f"loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA=11"
        f":measured_I={m['input_i']}:measured_TP={m['input_tp']}"
        f":measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}"
        f":offset={m['target_offset']}:linear=true"
    )
    run([
        "ffmpeg", "-hide_banner", "-y", "-i", str(src),
        "-af", f"{TRIM},{norm}",
        "-ar", "44100", "-ac", "2",
        "-c:a", "libmp3lame", "-b:a", "128k",
        "-map_metadata", "-1", "-id3v2_version", "0", "-write_xing", "1",
        str(dst),
    ])


def duration(path: pathlib.Path) -> float:
    out = run([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "csv=p=0", str(path),
    ]).stdout
    return float(out.strip())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("pairs", nargs="+", help="role=path")
    parser.add_argument("--out", default="assets/audio/music")
    args = parser.parse_args()

    out_dir = pathlib.Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    for pair in args.pairs:
        role, _, path = pair.partition("=")
        src = pathlib.Path(path)
        if not role or not src.is_file():
            print(f"bad pair: {pair}", file=sys.stderr)
            return 2
        dst = out_dir / f"{role}.mp3"
        encode(src, dst, measure(src))
        print(f"  {role}: {duration(dst):.2f} s, {dst.stat().st_size / 1e6:.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
