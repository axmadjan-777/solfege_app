#!/usr/bin/env python3
"""Decode the complete C4–G5 MP3 set and check duration, signal and pitch.

Requires ffmpeg on PATH; uses only Python's standard library. This is an
explicit media acceptance check, not a substitute for hearing the browser.
"""

import array
import cmath
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent
NAMES = ("C", "Cs", "D", "Eb", "E", "F", "Fs", "G", "Gs", "A", "Bb", "B")
RATE = 11025


def spectrum(samples):
    size = 1
    while size * 2 <= len(samples):
        size *= 2
    start = (len(samples) - size) // 2
    values = [complex(samples[start + i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1))))
              for i in range(size)]
    j = 0
    for i in range(1, size):
        bit = size >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j ^= bit
        if i < j:
            values[i], values[j] = values[j], values[i]
    length = 2
    while length <= size:
        root = cmath.exp(-2j * math.pi / length)
        for start in range(0, size, length):
            factor = 1
            for i in range(length // 2):
                even = values[start + i]
                odd = values[start + i + length // 2] * factor
                values[start + i] = even + odd
                values[start + i + length // 2] = even - odd
                factor *= root
        length *= 2
    magnitudes = [abs(value) for value in values[:size // 2]]
    peak = max(range(2, len(magnitudes) - 1), key=magnitudes.__getitem__)
    left, center, right = [math.log(max(magnitudes[i], 1e-12))
                           for i in (peak - 1, peak, peak + 1)]
    offset = 0.5 * (left - right) / (left - 2 * center + right)
    return (peak + offset) * RATE / size


def verify():
    results = []
    expected_paths = set()
    for midi in range(60, 80):
        name = f"{NAMES[midi % 12]}{midi // 12 - 1}.mp3"
        path = ROOT / "assets" / "audio" / name
        expected_paths.add(path.name)
        raw = subprocess.check_output([
            "ffmpeg", "-v", "error", "-i", str(path), "-f", "s16le",
            "-acodec", "pcm_s16le", "-ac", "1", "-ar", str(RATE), "pipe:1",
        ])
        samples = array.array("h", raw)
        if sys.byteorder != "little":
            samples.byteswap()
        duration = len(samples) / RATE
        rms = math.sqrt(sum(value * value for value in samples) / len(samples)) / 32768
        assert 0.15 <= duration <= 2, (name, "duration", duration)
        assert rms > 0.01, (name, "silent/quiet", rms)
        frequency = spectrum(samples)
        expected = 440 * 2 ** ((midi - 69) / 12)
        cents = 1200 * math.log2(frequency / expected)
        assert abs(cents) < 15, (name, "wrong pitch", frequency, expected, cents)
        results.append({"file": name, "midi": midi, "seconds": round(duration, 4),
                        "frequency_hz": round(frequency, 3), "error_cents": round(cents, 3),
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    actual = {path.name for path in (ROOT / "assets" / "audio").glob("*.mp3")}
    assert actual == expected_paths, {"missing": sorted(expected_paths - actual),
                                      "unexpected": sorted(actual - expected_paths)}
    return results


if __name__ == "__main__":
    print(json.dumps(verify(), ensure_ascii=False, indent=2))
