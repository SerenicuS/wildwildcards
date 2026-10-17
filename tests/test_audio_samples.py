"""Validate generated PCM duration, headroom, fades and stereo separation."""
from pathlib import Path
import math
import struct
import wave

root = Path(__file__).resolve().parents[1] / "assets" / "audio"
ranges = {"reload": (0.1, 0.25), "shoot_left": (0.2, 0.45),
          "shoot_right": (0.2, 0.45), "empty": (0.05, 0.12),
          "shield": (0.1, 0.2), "impact": (0.1, 0.3),
          "victory": (0.4, 0.9), "defeat": (0.4, 0.9), "tick": (0.02, 0.08), "stamp": (0.1, 0.25)}
peaks = {}
for name, (low, high) in ranges.items():
    with wave.open(str(root / f"{name}.wav")) as wav:
        assert wav.getsampwidth() == 2 and wav.getframerate() == 22050
        duration = wav.getnframes() / wav.getframerate()
        assert low <= duration <= high, (name, duration)
        channels = wav.getnchannels()
        raw = wav.readframes(wav.getnframes())
        samples = struct.unpack(f"<{len(raw)//2}h", raw)
    peak = max(abs(v) for v in samples) / 32767
    rms = math.sqrt(sum(v*v for v in samples) / len(samples)) / 32767
    assert 0 < rms < 0.3 and peak <= 0.651, (name, peak, rms)
    assert max(abs(v) for v in samples[:channels] + samples[-channels:]) <= 1, name
    assert abs(sum(samples) / len(samples) / 32767) < 0.01, name
    if name.startswith("shoot_"):
        assert channels == 2
        left = sum(v*v for v in samples[0::2])
        right = sum(v*v for v in samples[1::2])
        assert (left > right) == (name == "shoot_left"), name
    peaks[name] = peak
    print(f"{name}: {duration:.3f}s, peak={peak:.3f}, RMS={rms:.3f}")
# Conservative coherent worst case: every pool voice at the loudest effect peak
# plus the one sting voice. Actual combinations are substantially quieter.
bound = 6 * max(peaks.values()) * 10**(-14/20) + max(peaks["victory"], peaks["defeat"]) * 10**(-15/20)
assert bound < 0.9, bound
assert sum(p.stat().st_size for p in root.glob("*.wav")) < 200000
print(f"All {len(ranges)} PCM assets valid; conservative default mix peak bound={bound:.3f}")
