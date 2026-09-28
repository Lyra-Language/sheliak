#!/usr/bin/env python3
"""Expand Musashi's opcode table into which opcodes a 68000 has.

    tests/musashi_legal.py build/deps/musashi/m68k_in.c

Prints 65,536 characters, `1` for an opcode the 68000 column of the table allows and `0`
for the rest — lines A and F included as `0`, since they are exceptions of their own. Each
table row gives a bit pattern (`.` a free bit) and, when its low six bits are an effective
address, the addressing modes allowed there; the row counts if the 68000's mode column
is U or S. The reference legaltest checks `is_legal` against.

Musashi lists ILLEGAL (0x4AFC) as an opcode of its own; it is the illegal-instruction
exception by definition, so it counts as `0` here.
"""

import sys

# The allowed-ea column's letters, as (mode, register) fields.
EA = {
    "A": [(2, r) for r in range(8)],
    "+": [(3, r) for r in range(8)],
    "-": [(4, r) for r in range(8)],
    "D": [(5, r) for r in range(8)],
    "X": [(6, r) for r in range(8)],
    "W": [(7, 0)],
    "L": [(7, 1)],
    "d": [(7, 2)],
    "x": [(7, 3)],
    "I": [(7, 4)],
}


def expand(pattern):
    """Every value of a bit pattern whose `.` bits are free."""
    out = [0]
    for ch in pattern:
        bits = (0, 1) if ch == "." else (int(ch),)
        out = [o << 1 | b for o in out for b in bits]
    return out


def main():
    source = open(sys.argv[1]).read()
    table = source.split("M68KMAKE_TABLE_START")[1].split("M68KMAKE_TABLE_END")[0]
    legal = set()
    for line in table.splitlines():
        fields = line.split()
        if len(fields) < 12:
            continue
        name, pattern, allowed, mode_68000 = fields[0], fields[4], fields[5], fields[6]
        if len(pattern) != 16 or name in ("1010", "1111", "illegal") or mode_68000 not in ("U", "S"):
            continue
        if allowed.strip("."):
            assert pattern[10:] == "......", line
            for base in expand(pattern[:10]):
                for letter in allowed.replace(".", ""):
                    for mode, reg in EA[letter]:
                        legal.add(base << 6 | mode << 3 | reg)
        else:
            legal.update(expand(pattern))
    sys.stdout.write("".join("1" if op in legal else "0" for op in range(65536)))


main()
