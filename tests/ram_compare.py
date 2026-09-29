#!/usr/bin/env python3
"""Compare the start of work RAM that a VDP test ROM leaves, Sheliak's against BlastEm's.

    tests/ram_compare.py SHELIAK_RAM BLASTEM_RAM [HSLACK]

Every byte must match, except, when HSLACK is given, the timing ROMs' H counter table
(FF0080 on, src/vdproms.lyra): there each H value may differ by up to HSLACK slots. H counts
the slots of a 40-cell line out of order (0-182, then 229-255), so values are compared as
positions in the line, and wrap from one line into the next. Prints each difference.
"""

import sys

H_TABLE = 0x80
SLOTS = 210


def position(h):
    return h if h <= 182 else h - 46


def main():
    sheliak = open(sys.argv[1], "rb").read()
    blastem = open(sys.argv[2], "rb").read()
    slack = int(sys.argv[3]) if len(sys.argv) > 3 else -1
    if len(sheliak) != len(blastem):
        print(f"RAM dumps differ in length: {len(sheliak)} and {len(blastem)}")
        return 1
    worst = 0
    bad = 0
    for at, (s, b) in enumerate(zip(sheliak, blastem)):
        if slack >= 0 and at >= H_TABLE:
            d = (position(s) - position(b)) % SLOTS
            d = min(d, SLOTS - d)
            worst = max(worst, d)
            ok = d <= slack
        else:
            ok = s == b
        if not ok:
            bad += 1
            print(f"FF{at:04X}: Sheliak {s:02X}, BlastEm {b:02X}")
    if slack >= 0:
        print(f"H counters within {worst} slots (slack {slack})")
    return 1 if bad else 0


sys.exit(main())
