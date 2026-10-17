"""Generate Wild Wild Cards' original PCM effects using only Python's stdlib.

Run from any folder: python tools/generate_audio.py
Deterministic synthesis; no downloaded samples or runtime Python dependency.
"""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RNG = random.Random(12491)


def noise(count, cutoff):
    alpha = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    value = 0.0
    result = []
    for _ in range(count):
        value += alpha * (RNG.uniform(-1, 1) - value)
        result.append(value)
    return result


def envelope(t, duration, decay, attack=0.002):
    return min(t / attack, 1) * math.exp(-t / decay) * min((duration - t) / 0.015, 1)


def metallic(duration, hits, tones, decay):
    count = round(duration * RATE)
    hiss = noise(count, 4800)
    result = []
    for i in range(count):
        t = i / RATE
        value = 0.0
        for start, strength in hits:
            age = t - start
            if age >= 0:
                ring = sum(math.sin(math.tau * freq * age) / (j + 1) for j, freq in enumerate(tones))
                value += strength * envelope(age, duration - start, decay) * (0.65 * hiss[i] + 0.24 * ring)
        result.append(value)
    return result


def gunshot(duration, variant):
    count = round(duration * RATE)
    crack = noise(count, 5800)
    body = noise(count, 850)
    result = []
    for i in range(count):
        t = i / RATE
        low = math.sin(math.tau * ((108 + variant * 5) * t - 45 * t * t))
        value = (0.85 * crack[i] * math.exp(-t / 0.018)
                 + 0.5 * body[i] * math.exp(-t / 0.072)
                 + 0.26 * low * math.exp(-t / 0.048))
        result.append(value * min(t / 0.001, 1) * min((duration - t) / 0.025, 1))
    return result


def sting(notes, duration):
    # Plucked, slightly inharmonic strings with a quiet open-fifth undertone.
    count = round(duration * RATE)
    result = []
    for i in range(count):
        t = i / RATE
        value = 0.0
        for start, freq in notes:
            age = t - start
            if age >= 0:
                pluck = sum(math.sin(math.tau * freq * h * age * (1 + 0.0005 * h))
                            * math.exp(-age * h * 2.5) / (h * h) for h in range(1, 6))
                value += pluck * envelope(age, duration - start, 0.2, 0.004)
        result.append(value)
    return result


def save(name, values, peak, pan=None):
    # Remove DC, normalize once offline and taper both ends to avoid clicks.
    mean = sum(values) / len(values)
    values = [v - mean for v in values]
    for i in range(len(values)):
        values[i] *= min(i / 44, (len(values) - 1 - i) / 110, 1)
    scale = peak / max(abs(v) for v in values)
    samples = []
    for value in values:
        value *= scale
        if pan is None:
            samples.append(round(value * 32767))
        else:
            samples.extend(round(value * gain * 32767) for gain in pan)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as output:
        output.setnchannels(1 if pan is None else 2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(struct.pack(f"<{len(samples)}h", *samples))


def stamp():
    # Dry paper slap over a short wooden thump. Independent seed keeps all
    # existing combat samples byte-identical when regenerating the library.
    rng = random.Random(3301)
    values = []
    for i in range(round(0.19 * RATE)):
        t = i / RATE
        value = (0.65 * math.sin(math.tau * 115 * t) * math.exp(-t / 0.032)
                 + 0.55 * rng.uniform(-1, 1) * math.exp(-t / 0.012))
        values.append(value)
    save("stamp", values, 0.55)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    save("reload", metallic(0.19, [(0, 1), (0.073, 0.7)], [1250, 2380, 3650], 0.024), 0.50)
    save("shoot_left", gunshot(0.34, 0), 0.65, (0.93, 0.37))
    save("shoot_right", gunshot(0.32, 1), 0.65, (0.37, 0.93))
    save("empty", metallic(0.085, [(0, 1)], [1750, 3100], 0.009), 0.45)
    save("shield", metallic(0.17, [(0, 1)], [620, 1245, 1870], 0.044), 0.45)
    save("impact", metallic(0.21, [(0.018, 1)], [2170, 3480, 4710], 0.035), 0.50)
    save("victory", sting([(0, 220), (0, 330), (0.15, 440), (0.30, 554.37), (0.43, 659.25)], 0.82), 0.55)
    save("defeat", sting([(0, 329.63), (0.16, 293.66), (0.32, 246.94), (0.46, 164.81)], 0.84), 0.55)
    save("tick", metallic(0.04, [(0, 1)], [900], 0.006), 0.25)
    stamp()
    total = sum(path.stat().st_size for path in OUT.glob("*.wav"))
    print(f"Generated 10 original 16-bit PCM WAV effects at {RATE} Hz ({total:,} bytes)")


if __name__ == "__main__":
    import sys
    stamp() if "--stamp-only" in sys.argv else main()
