#!/usr/bin/env python3
"""The strongest pitch in a 16-bit stereo WAV's left channel, from 1 s in, and its peak.

    tests/wav_pitch.py FILE.wav EXPECTED_HZ

Scans 100-1000 Hz by the power of a one-second window at each frequency (2 Hz steps, then
0.1 Hz about the best); exits 1 unless the strongest is within 0.5 Hz of EXPECTED_HZ and the
channel is not silent.
"""
import math
import struct
import sys

data = open(sys.argv[1], "rb").read()
want = float(sys.argv[2])
rate = struct.unpack_from("<I", data, 24)[0]
count = (len(data) - 44) // 4
left = [struct.unpack_from("<h", data, 44 + 4 * i)[0] for i in range(count)]
window = left[rate:2 * rate]


def power(f):
    re = sum(v * math.cos(2 * math.pi * f * i / rate) for i, v in enumerate(window))
    im = sum(v * math.sin(2 * math.pi * f * i / rate) for i, v in enumerate(window))
    return re * re + im * im


coarse = max(range(100, 1000, 2), key=power)
fine = max([coarse + k / 10 for k in range(-25, 26)], key=power)
peak = max(abs(v) for v in window)
ok = abs(fine - want) <= 0.5 and peak > 500
print(f"{sys.argv[1].split('/')[-1]}: {fine:.1f} Hz (want {want}), peak {peak}{'' if ok else '  <- wrong'}")
sys.exit(0 if ok else 1)
