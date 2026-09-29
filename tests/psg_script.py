#!/usr/bin/env python3
"""A random PSG script for tests/psg.sh: writes of every kind between runs of ticks.

    tests/psg_script.py SEED

The noise register is written first, as the two emulators' power-on shift registers differ
(0 in BlastEm), and a data byte is never written while a volume or the noise register is
latched — the hardware writes its low bits then, BlastEm ignores it (src/psg/psg.lyra).
"""
import random
import sys

rng = random.Random(int(sys.argv[1]))
print("w e4")
latched_tone = False
for _ in range(400):
    kind = rng.random()
    if kind < 0.45:
        channel = rng.randrange(4)
        volume = rng.random() < 0.4
        value = 0x80 | channel << 5 | (0x10 if volume else 0) | rng.randrange(16)
        latched_tone = not volume and channel < 3
        print(f"w {value:x}")
    elif kind < 0.6 and latched_tone:
        # Short periods now and then, so the flips come thick and fast.
        print(f"w {rng.choice([0, 0, 1, rng.randrange(64)]):x}")
    else:
        print(f"t {rng.randrange(1, 200):x}")
