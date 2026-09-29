#!/usr/bin/env python3
"""A random YM2612 script for tests/ym.sh: every register the chip has, written between runs
of samples, with the status read now and then.

    tests/ym_script.py SEED

Writes are spaced as software spaces them — address, a couple of cycles, data, then a wait
that is usually the 32-cycle busy time and sometimes shorter, which the chip handles in its
own way (a data byte arriving while the last is still held). The LSI test registers (21,
2C) are never written; Sheliak does not model them.
"""
import random
import sys

rng = random.Random(int(sys.argv[1]))
out = []


def write(bank, address, data, wait=None):
    out.append(f"w {bank * 2} {address:x}")
    out.append(f"c {rng.choice([1, 2, 2, 3])}")
    out.append(f"w {bank * 2 + 1} {data:x}")
    if rng.random() < 0.1:
        # The status read while the write still busies the chip.
        out.append(f"c {rng.randrange(1, 40)}")
        out.append("r 0")
    out.append(f"c {wait if wait is not None else rng.choice([32, 32, 32, 40, 24, 13, 7])}")


def operator(bank, ch, op):
    base = ch + [0, 8, 4, 12][op]
    write(bank, 0x30 + base, rng.randrange(256))
    write(bank, 0x40 + base, rng.choice([0, 0, rng.randrange(40), rng.randrange(128)]))
    write(bank, 0x50 + base, rng.randrange(256))
    write(bank, 0x60 + base, rng.randrange(256))
    write(bank, 0x70 + base, rng.randrange(32))
    write(bank, 0x80 + base, rng.randrange(256))
    write(bank, 0x90 + base, rng.choice([0, 0, 0, rng.randrange(16)]))


def channel(bank, ch):
    for op in range(4):
        operator(bank, ch, op)
    write(bank, 0xB0 + ch, rng.randrange(64))
    write(bank, 0xB4 + ch, rng.randrange(256))
    frequency(bank, ch)


def frequency(bank, ch):
    write(bank, 0xA4 + ch, rng.randrange(64))
    write(bank, 0xA0 + ch, rng.randrange(256))


def key(ch, ops):
    write(0, 0x28, ops << 4 | (ch % 3) | (4 if ch >= 3 else 0))


write(0, 0x22, rng.choice([0, 0, 8 | rng.randrange(8)]))
write(0, 0x27, 0)
channels = rng.sample(range(6), rng.randrange(1, 7))
for ch in channels:
    channel(ch // 3, ch % 3)
for _ in range(rng.randrange(6, 16)):
    event = rng.random()
    if event < 0.35:
        ch = rng.choice(channels)
        key(ch, rng.choice([15, 15, rng.randrange(16)]))
    elif event < 0.5:
        ch = rng.choice(channels)
        key(ch, 0)
    elif event < 0.6:
        ch = rng.choice(channels)
        frequency(ch // 3, ch % 3)
    elif event < 0.65:
        ch = rng.choice(channels)
        operator(ch // 3, ch % 3, rng.randrange(4))
    elif event < 0.7:
        write(0, 0x22, 8 | rng.randrange(8))
    elif event < 0.75:
        # Channel 3's special mode, its per-operator frequencies, perhaps CSM with timer A.
        for i in range(3):
            write(0, 0xAC + i, rng.randrange(64))
            write(0, 0xA8 + i, rng.randrange(256))
        write(0, 0x24, rng.randrange(256))
        write(0, 0x25, rng.randrange(4))
        write(0, 0x27, rng.choice([0x40, 0x80 | 0x15]))
    elif event < 0.82:
        # The timers: periods, load, enable, reset, and the flags read back.
        write(0, 0x24, rng.randrange(256))
        write(0, 0x25, rng.randrange(4))
        write(0, 0x26, rng.randrange(256))
        write(0, 0x27, rng.randrange(64))
        out.append(f"s {rng.randrange(1, 200)}")
        out.append("r 0")
        write(0, 0x27, 0x30 | rng.randrange(16))
    elif event < 0.9:
        # The DAC: on, a few samples written, maybe off again.
        write(0, 0x2B, 0x80)
        for _ in range(rng.randrange(4, 20)):
            write(0, 0x2A, rng.randrange(256), wait=rng.choice([24, 48, 100]))
        if rng.random() < 0.5:
            write(0, 0x2B, 0)
    out.append(f"s {rng.randrange(20, 400)}")
    out.append(f"r {rng.choice([0, 0, 1, 2])}")
print("\n".join(out))
