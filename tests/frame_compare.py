#!/usr/bin/env python3
"""Compare Sheliak's rendered frame with BlastEm's screenshot.

    tests/frame_compare.py SHELIAK_FRAME.bin BLASTEM_FRAME.ppm

Sheliak's frame is the VDP's output: a header of width and height (two big-endian u16s),
then per pixel a big-endian u16 — the CRAM colour `----bbb-ggg-rrr-` and the intensity in
bits 13-12 (0 normal, 1 shadow, 2 highlight). It is turned into light through the DAC's 15
measured levels (normal c -> level 2c, shadow c, highlight c + 7), which BlastEm uses too,
and compared with the screenshot pixel for pixel. Prints a verdict line; exits 1 on a
difference, naming the first few.
"""

import sys

LEVELS = [0, 27, 49, 71, 87, 103, 119, 130, 146, 157, 174, 190, 206, 228, 255]


def light(pixel):
    intensity = (pixel >> 12) & 3
    out = []
    for shift in (1, 5, 9):  # red, green, blue
        c = (pixel >> shift) & 7
        out.append(LEVELS[c + 7] if intensity == 2 else LEVELS[c] if intensity == 1 else LEVELS[2 * c])
    return tuple(out)


def read_ppm(path):
    data = open(path, "rb").read()
    fields, pos = [], 0
    while len(fields) < 4:
        while data[pos:pos + 1].isspace():
            pos += 1
        if data[pos:pos + 1] == b"#":
            while data[pos:pos + 1] != b"\n":
                pos += 1
            continue
        start = pos
        while not data[pos:pos + 1].isspace():
            pos += 1
        fields.append(data[start:pos])
    assert fields[0] == b"P6", "not a binary PPM"
    width, height = int(fields[1]), int(fields[2])
    pixels = data[pos + 1:]
    return width, height, [tuple(pixels[i:i + 3]) for i in range(0, width * height * 3, 3)]


ours = open(sys.argv[1], "rb").read()
width, height = int.from_bytes(ours[0:2], "big"), int.from_bytes(ours[2:4], "big")
sheliak = [light(int.from_bytes(ours[i:i + 2], "big")) for i in range(4, 4 + width * height * 2, 2)]
bwidth, bheight, blastem = read_ppm(sys.argv[2])
if (bwidth, bheight) != (width, height):
    print(f"size differs: BlastEm {bwidth}x{bheight}, Sheliak {width}x{height}")
    sys.exit(1)
wrong = [i for i in range(width * height) if sheliak[i] != blastem[i]]
if not wrong:
    sys.exit(0)
print(f"{len(wrong)} of {width * height} pixels differ")
for i in wrong[:6]:
    print(f"  ({i % width}, {i // width}): BlastEm {blastem[i]}, Sheliak {sheliak[i]}")
sys.exit(1)
