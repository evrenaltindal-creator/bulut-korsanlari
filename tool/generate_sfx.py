#!/usr/bin/env python3
"""Synthesises the game's sound effects; no recordings, no licences.

  python3 tool/generate_sfx.py

Writes assets/audio/sfx/<name>.wav (22.05 kHz, 16-bit, mono). Loops
(gun, engine) are built from whole cycles so they repeat without a
click. Output is deterministic (fixed seed). Needs numpy.
"""

import pathlib
import wave

import numpy as np

SR = 22050
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets/audio/sfx"
rng = np.random.default_rng(1918)


def t(seconds: float) -> np.ndarray:
    return np.arange(int(SR * seconds)) / SR


def noise(n: int) -> np.ndarray:
    return rng.uniform(-1, 1, n)


def lowpass(x: np.ndarray, cutoff) -> np.ndarray:
    """One-pole low-pass; cutoff may be an array (a sweep)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def env(n: int, attack: float, decay: float) -> np.ndarray:
    """Fast attack, exponential decay (seconds)."""
    tt = np.arange(n) / SR
    a = np.clip(tt / max(attack, 1e-4), 0, 1)
    return a * np.exp(-tt / decay)


def normalise(x: np.ndarray, peak_db: float) -> np.ndarray:
    peak = np.max(np.abs(x)) or 1.0
    return x / peak * 10 ** (peak_db / 20)


def fade(x: np.ndarray, start: float = 0.003, end: float = 0.02) -> np.ndarray:
    n0, n1 = int(SR * start), int(SR * end)
    x = x.copy()
    if n0:
        x[:n0] *= np.linspace(0, 1, n0)
    if n1:
        x[-n1:] *= np.linspace(1, 0, n1)
    return x


def write(name: str, x: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f"  {name}: {len(x) / SR:.2f} s, {len(data) // 1024} KB")


def gun_shot(n: int) -> np.ndarray:
    tt = np.arange(n) / SR
    crack = highpass(noise(n), 900) * env(n, 0.0005, 0.012)
    body = lowpass(noise(n), 1600) * env(n, 0.001, 0.03) * 0.8
    thump = np.sin(2 * np.pi * 95 * tt) * env(n, 0.001, 0.035) * 0.9
    return crack + body + thump


def gun_loop() -> np.ndarray:
    """Ten rounds a second, one second long: loops seamlessly."""
    step = int(SR * 0.1)
    out = np.zeros(step * 10)
    for k in range(10):
        shot = gun_shot(step) * (0.85 + 0.3 * rng.random())
        out[k * step:(k + 1) * step] += shot
    return normalise(out, -3)


def engine_loop() -> np.ndarray:
    """Radial engine drone, two seconds; every partial completes whole
    cycles in the loop so it repeats without a seam."""
    tt = t(2.0)
    f0 = 55.0
    x = np.zeros_like(tt)
    for h, amp in ((1, 1.0), (2, 0.6), (3, 0.45), (4, 0.25), (6, 0.12)):
        x += amp * np.sin(2 * np.pi * f0 * h * tt + h)
    blade = 0.65 + 0.35 * np.sin(2 * np.pi * 27.5 * tt)  # propeller beat
    # Noise that loops: render a little extra and fold it back over the
    # start, so the sample after the last one is the natural next one.
    n = int(SR * 0.25)
    extra = lowpass(noise(len(tt) + n), 700) * 0.6
    hiss = extra[: len(tt)].copy()
    hiss[:n] = extra[:n] * np.linspace(0, 1, n) + extra[len(tt):] * np.linspace(1, 0, n)
    out = x * blade + hiss
    return normalise(out, -6)


def explosion(seconds: float = 1.7, deep: float = 1.0) -> np.ndarray:
    n = int(SR * seconds)
    tt = np.arange(n) / SR
    sweep = 3000 * np.exp(-tt / 0.18) + 120
    rumble = lowpass(noise(n), sweep) * env(n, 0.003, 0.45)
    boom = np.sin(2 * np.pi * (55 * deep) * tt * (1 - 0.3 * tt)) * env(n, 0.005, 0.35) * 1.2
    crack = highpass(noise(n), 1500) * env(n, 0.0005, 0.03) * 0.8
    crackle = np.zeros(n)
    for _ in range(40):
        i = int(rng.uniform(0.08, seconds * 0.8) * SR)
        m = min(int(SR * 0.006), n - i)
        crackle[i:i + m] += noise(m) * env(m, 0.0002, 0.002) * rng.uniform(0.2, 0.6)
    crackle *= np.exp(-tt / 0.5)
    return normalise(fade(rumble + boom + crack + crackle, end=0.2), -1)


def hit() -> np.ndarray:
    n = int(SR * 0.14)
    tt = np.arange(n) / SR
    tick = highpass(noise(n), 2500) * env(n, 0.0003, 0.008)
    ring = np.sin(2 * np.pi * 1850 * tt) * env(n, 0.0005, 0.03) * 0.5
    thud = np.sin(2 * np.pi * 240 * tt) * env(n, 0.001, 0.025) * 0.6
    return normalise(fade(tick + ring + thud), -4)


def damage() -> np.ndarray:
    n = int(SR * 0.35)
    tt = np.arange(n) / SR
    thud = np.sin(2 * np.pi * (130 - 70 * tt / 0.35) * tt) * env(n, 0.002, 0.08)
    splinter = lowpass(noise(n), 2500) * env(n, 0.001, 0.05) * 0.9
    rattle = np.zeros(n)
    for k in range(5):
        i = int(SR * (0.03 + 0.035 * k))
        m = int(SR * 0.012)
        rattle[i:i + m] += highpass(noise(m), 1200) * env(m, 0.0003, 0.004) * 0.5
    return normalise(fade(thud + splinter + rattle), -2)


def flak() -> np.ndarray:
    n = int(SR * 0.7)
    tt = np.arange(n) / SR
    whump = lowpass(noise(n), 450) * env(n, 0.004, 0.16) * 1.4
    low = np.sin(2 * np.pi * 68 * tt) * env(n, 0.004, 0.12)
    pop = highpass(noise(n), 1800) * env(n, 0.0004, 0.006) * 0.35
    return normalise(fade(whump + low + pop, end=0.1), -3)


def bomb_drop() -> np.ndarray:
    """Release clunk, then a whistle falling for the bomb's 1.7 s drop."""
    n = int(SR * 1.7)
    tt = np.arange(n) / SR
    freq = 1500 - 850 * (tt / 1.7) ** 1.4 + 18 * np.sin(2 * np.pi * 6 * tt)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    whistle = np.sin(phase) * np.clip(tt / 0.4, 0, 1) * (0.35 + 0.45 * tt / 1.7)
    clunk_n = int(SR * 0.08)
    clunk = np.zeros(n)
    clunk[:clunk_n] = (np.sin(2 * np.pi * 300 * tt[:clunk_n]) + highpass(noise(clunk_n), 1500) * 0.5) * env(
        clunk_n, 0.0005, 0.02
    )
    return normalise(fade(whistle * 0.8 + clunk, end=0.05), -5)


def jam() -> np.ndarray:
    n = int(SR * 0.4)
    tt = np.arange(n) / SR
    out = np.zeros(n)
    for start, f in ((0.0, 930), (0.13, 1310)):
        i = int(SR * start)
        m = n - i
        ring = np.sin(2 * np.pi * f * tt[:m]) * env(m, 0.0005, 0.05)
        click = highpass(noise(m), 2000) * env(m, 0.0003, 0.004)
        out[i:] += ring * 0.7 + click
    return normalise(fade(out), -5)


def warning() -> np.ndarray:
    """Two-tone cockpit buzzer."""
    tt = t(0.5)
    tone = np.where(tt < 0.25, np.sign(np.sin(2 * np.pi * 740 * tt)), np.sign(np.sin(2 * np.pi * 554 * tt)))
    shaped = lowpass(tone, 2500) * (np.sin(np.pi * np.clip(tt / 0.5, 0, 1)) ** 0.3)
    return normalise(fade(shaped, end=0.03), -14)


def main() -> None:
    write("gun", gun_loop())
    write("engine", engine_loop())
    write("explosion", explosion())
    write("hit", hit())
    write("damage", damage())
    write("flak", flak())
    write("bomb", bomb_drop())
    write("jam", jam())
    write("warning", warning())


if __name__ == "__main__":
    main()
