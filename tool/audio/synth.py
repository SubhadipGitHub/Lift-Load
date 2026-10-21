#!/usr/bin/env python3
"""Synthesizes every Lift Load sound effect and venue music loop.

All audio is generated here from code (numpy), deterministically, so it
carries no licence and can be regenerated or retuned:

    python3 tool/audio/synth.py            # writes assets/sfx/*.mp3, assets/music/*.mp3

Needs numpy and ffmpeg (libmp3lame). MP3 because it plays on Android, Chrome
and iOS Safari alike.

Hidden-weight rule: every cue is a fixed sound. Nothing here depends on who
boards or how heavy they are; the creak follows the gauge zone only.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "assets", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "music")
rng = np.random.default_rng(7919)


# ── Building blocks ─────────────────────────────────────────────────────────

def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(SR * seconds)) / SR


def env(n: int, attack: float = 0.005, decay: float = 0.2, sustain: float = 0.0, release: float = 0.05) -> np.ndarray:
    """Attack, then exponential decay toward sustain, then a release ramp."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = sustain + (1 - sustain) * np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-4))
    r = np.clip((n / SR - t) / max(release, 1e-4), 0, 1)
    return a * d * r


def sine(freq, seconds: float, phase: float = 0.0) -> np.ndarray:
    t = t_axis(seconds)
    if np.isscalar(freq):
        return np.sin(2 * np.pi * freq * t + phase)
    # Swept frequency: integrate the instantaneous frequency.
    return np.sin(2 * np.pi * np.cumsum(freq) / SR + phase)


def noise(seconds: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(SR * seconds))


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def bell(freq: float, seconds: float, decay: float, partials=((1, 1), (2.76, 0.5), (5.4, 0.25), (8.93, 0.12))):
    n = int(SR * seconds)
    out = np.zeros(n)
    for ratio, amp in partials:
        out += amp * sine(freq * ratio, seconds) * env(n, 0.002, decay / ratio ** 0.5, 0, 0.05)
    return out


def pluck(freq: float, seconds: float, damping: float = 0.996) -> np.ndarray:
    """Karplus-Strong plucked string."""
    n = int(SR * seconds)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = damping * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out * env(n, 0.002, seconds, 0, 0.05)


def mix(n: int, *parts: tuple[np.ndarray, float]) -> np.ndarray:
    out = np.zeros(n)
    for sig, at in parts:
        start = int(at * SR)
        end = min(n, start + len(sig))
        if end > start:
            out[start:end] += sig[: end - start]
    return out


def normalize(x: np.ndarray, peak_db: float) -> np.ndarray:
    peak = np.max(np.abs(x)) or 1.0
    return x / peak * 10 ** (peak_db / 20)


def note(name: str) -> float:
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + 12 * (octave + 1) - 69) / 12)


# ── Sound effects ───────────────────────────────────────────────────────────

def sfx() -> dict[str, np.ndarray]:
    s: dict[str, np.ndarray] = {}

    n = int(SR * 0.05)
    s["tick"] = sine(1900, 0.05) * env(n, 0.001, 0.012)

    n = int(SR * 0.12)
    s["select"] = mix(n, (sine(880, 0.06) * env(int(SR * 0.06), 0.002, 0.03), 0),
                      (sine(1320, 0.06) * env(int(SR * 0.06), 0.002, 0.03), 0.05))

    n = int(SR * 0.16)
    s["seat"] = sine(np.linspace(150, 90, n), 0.16) * env(n, 0.002, 0.05) + 0.25 * lowpass(noise(0.16), 900) * env(n, 0.001, 0.03)

    step = sine(np.linspace(140, 100, int(SR * 0.07)), 0.07) * env(int(SR * 0.07), 0.002, 0.025) \
        + 0.2 * lowpass(noise(0.07), 1200) * env(int(SR * 0.07), 0.001, 0.015)
    s["board"] = mix(int(SR * 0.2), (step, 0), (step * 0.8, 0.09))

    n = int(SR * 0.42)
    whoosh = lowpass(noise(0.42), 1400) * np.sin(np.linspace(0, np.pi, n)) ** 2
    clunk = sine(np.linspace(110, 70, int(SR * 0.1)), 0.1) * env(int(SR * 0.1), 0.001, 0.03)
    s["door_close"] = mix(n, (0.6 * whoosh, 0), (clunk, 0.32))
    s["door_open"] = 0.6 * lowpass(noise(0.35), 1600) * np.sin(np.linspace(0, np.pi, int(SR * 0.35))) ** 2

    s["ding"] = bell(note("C6"), 1.3, 0.6)

    n = int(SR * 0.5)
    wobble = 260 + 60 * np.sin(np.linspace(0, 9 * np.pi, n)) + np.linspace(0, 120, n)
    saw = 2 * ((np.cumsum(wobble) / SR) % 1.0) - 1
    s["creak"] = lowpass(highpass(saw, 180), 900) * env(n, 0.03, 0.4, 0.3, 0.1)

    n = int(SR * 0.25)
    s["snap"] = highpass(noise(0.25), 2500) * env(n, 0.0005, 0.03) + 0.5 * bell(1700, 0.25, 0.08)

    n = int(SR * 1.3)
    rumble = lowpass(noise(1.3), 160) * env(n, 0.01, 0.5)
    thud = sine(np.linspace(90, 40, int(SR * 0.4)), 0.4) * env(int(SR * 0.4), 0.002, 0.15)
    clatter = sum(bell(f, 0.5, 0.12) * 0.25 for f in (1200, 1700, 2300))
    s["crash"] = mix(n, (rumble * 1.4, 0), (thud * 1.2, 0.05), (clatter, 0.12), (clatter * 0.6, 0.31))

    s["coin"] = mix(int(SR * 0.42), (bell(note("B5"), 0.2, 0.08, ((1, 1), (2, 0.3))), 0),
                    (bell(note("E6"), 0.35, 0.2, ((1, 1), (2, 0.3), (3, 0.1))), 0.07))

    sq = np.sign(sine(170, 0.1)) * env(int(SR * 0.1), 0.003, 0.05, 0.6, 0.02)
    s["refuse"] = lowpass(mix(int(SR * 0.26), (sq, 0), (sq, 0.14)), 1800)

    n = int(SR * 1.4)
    parts = []
    for i, nm in enumerate(["C5", "E5", "G5", "C6"]):
        f = note(nm)
        dur = 0.9 if nm == "C6" else 0.3
        m = int(SR * dur)
        sw = 2 * ((f * np.arange(m) / SR) % 1.0) - 1
        parts.append((lowpass(sw, 2800) * env(m, 0.01, dur * 0.8, 0.4, 0.1) * 0.6, i * 0.12))
    s["fanfare"] = mix(n, *parts)

    n = int(SR * 1.0)
    parts = []
    for i, nm in enumerate(["G4", "F#4", "F4"]):
        f = note(nm)
        dur = 0.5 if i == 2 else 0.25
        m = int(SR * dur)
        freq = np.full(m, f) * (np.linspace(1, 0.94, m) if i == 2 else 1)
        sw = 2 * ((np.cumsum(freq) / SR) % 1.0) - 1
        parts.append((lowpass(sw, 1500) * env(m, 0.01, dur, 0.5, 0.08) * 0.5, i * 0.24))
    s["fail"] = mix(n, *parts)

    s["chime"] = mix(int(SR * 0.9), (bell(note("E6"), 0.6, 0.3), 0), (bell(note("C6"), 0.7, 0.35), 0.18))

    s["clank"] = sum(bell(f, 0.32, 0.07, ((1, 1), (1.47, 0.6), (2.31, 0.4))) * 0.4 for f in (420, 640))

    n = int(SR * 0.06)
    s["ui"] = sine(np.linspace(600, 900, n), 0.06) * env(n, 0.002, 0.018)
    return s


# ── Music: one quiet, seamless loop per venue ───────────────────────────────

VENUES = {
    # name: (bpm, key root, progression as chord roots in semitones with quality, lead instrument)
    "society": (92, "F3", [(0, "maj7"), (9, "m7"), (2, "m7"), (7, "7")], "rhodes"),
    "office": (104, "A3", [(0, "m7"), (5, "m7"), (10, "7"), (3, "maj7")], "marimba"),
    "hospital": (76, "D3", [(0, "maj7"), (5, "maj7"), (9, "m7"), (7, "7")], "musicbox"),
    "mall": (112, "G3", [(0, "maj7"), (4, "m7"), (9, "m7"), (2, "7")], "guitar"),
    "hotel": (84, "E3", [(0, "maj7"), (9, "m7"), (5, "maj7"), (7, "7")], "strings"),
}

QUALITY = {"maj7": (0, 4, 7, 11), "m7": (0, 3, 7, 10), "7": (0, 4, 7, 10)}


def instrument(kind: str, freq: float, seconds: float) -> np.ndarray:
    n = int(SR * seconds)
    if kind == "rhodes":
        tone = sine(freq, seconds) + 0.35 * sine(freq * 2, seconds) + 0.08 * sine(freq * 3, seconds)
        trem = 1 + 0.15 * np.sin(2 * np.pi * 5 * t_axis(seconds))
        return tone * trem * env(n, 0.005, 0.9, 0.15, 0.2) * 0.5
    if kind == "marimba":
        return (sine(freq, seconds) + 0.25 * sine(freq * 4, seconds) * env(n, 0.001, 0.05)) * env(n, 0.002, 0.25) * 0.6
    if kind == "musicbox":
        return bell(freq * 2, seconds, 0.7, ((1, 1), (3, 0.2), (5.2, 0.08))) * 0.45
    if kind == "guitar":
        return pluck(freq, seconds, 0.994) * 0.7
    # strings: detuned saws, slow attack, soft
    out = np.zeros(n)
    for d in (-0.004, 0.0, 0.005):
        f = freq * (1 + d)
        out += 2 * ((f * np.arange(n) / SR) % 1.0) - 1
    return lowpass(out / 3, 1400) * env(n, 0.35, 2.0, 0.6, 0.4) * 0.5


def music_loop(name: str) -> np.ndarray:
    bpm, root, prog, lead = VENUES[name]
    beat = 60 / bpm
    bars = 8  # two passes of the four-chord loop
    total = int(SR * beat * 4 * bars)
    out = np.zeros(total + SR * 4)  # room for tails, folded back for a seamless loop
    base = note(root)
    loop_rng = np.random.default_rng(sum(ord(ch) for ch in name))
    for bar in range(bars):
        semis, quality = prog[bar % len(prog)]
        chord = [base * 2 ** ((semis + q) / 12) for q in QUALITY[quality]]
        t0 = bar * 4 * beat
        # Bass on beats 1 and 3.
        for b in (0, 2):
            f = base / 2 * 2 ** (semis / 12) * (1.5 if b == 2 and bar % 2 else 1)
            sig = (sine(f, beat * 1.6) + 0.2 * sine(f * 2, beat * 1.6)) * env(int(SR * beat * 1.6), 0.01, beat, 0.2, 0.1) * 0.55
            start = int((t0 + b * beat) * SR)
            out[start:start + len(sig)] += sig
        # Chord pad (soft, held).
        for f in chord:
            sig = instrument("strings" if lead == "strings" else "rhodes", f, beat * 4) * 0.35
            start = int(t0 * SR)
            out[start:start + len(sig)] += sig
        # Lead: a gentle arpeggio pattern, varied by bar.
        pattern = [0, 2, 1, 3, 2, 1, 3, 2] if bar % 2 == 0 else [3, 1, 2, 0, 1, 2, 3, 1]
        for i, idx in enumerate(pattern):
            if loop_rng.random() < 0.18:
                continue  # rests keep it airy
            f = chord[idx] * 2
            sig = instrument(lead, f, beat * 1.5) * 0.5
            start = int((t0 + i * beat / 2) * SR)
            out[start:start + len(sig)] += sig
        # Brushes on 2 and 4.
        for b in (1, 3):
            m = int(SR * 0.12)
            sig = highpass(rng.uniform(-1, 1, m), 3000) * env(m, 0.002, 0.04) * 0.12
            start = int((t0 + b * beat) * SR)
            out[start:start + m] += sig
    # Fold the tail past the loop end back onto the start, so it repeats without a seam.
    loop = out[:total].copy()
    tail = out[total:]
    loop[: len(tail)] += tail[: total]
    return loop


# ── Output ──────────────────────────────────────────────────────────────────

def write_mp3(samples: np.ndarray, path: str, bitrate: str) -> None:
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(
            ["ffmpeg", "-loglevel", "error", "-y", "-i", tmp.name, "-ac", "1", "-codec:a", "libmp3lame",
             "-b:a", bitrate, "-map_metadata", "-1", path],
            check=True,
        )
        os.unlink(tmp.name)


def main() -> int:
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    for name, sig in sfx().items():
        write_mp3(normalize(sig, -1.5), os.path.join(SFX_DIR, f"{name}.mp3"), "96k")
    for name in VENUES:
        write_mp3(normalize(music_loop(name), -4), os.path.join(MUSIC_DIR, f"{name}.mp3"), "64k")
    return 0


if __name__ == "__main__":
    sys.exit(main())
