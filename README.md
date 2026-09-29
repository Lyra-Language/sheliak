# Sheliak

A Sega Genesis / Mega Drive emulator written in [Lyra](https://github.com/Lyra-Language/lyra),
aiming to run any cartridge ROM, playable — and the emulator behind Vega, a studio for
making games for retro consoles.

**Accuracy is checked, not eyeballed.** Every chip is held to an independent reference:

- the **68000** to the whole SingleStepTests suite — 1,000,058 recorded instructions, every
  bus transaction compared;
- the **Z80** to its SingleStepTests suite — 1,604,000 instructions, compared T-state by
  T-state;
- the **VDP** to BlastEm, through test ROMs whose memories, registers, timing and frames must
  match — the picture pixel for pixel, mid-line changes included;
- the **YM2612** to Nuked-OPN2, a transcription of the decapped chip, sample for sample and
  bit for bit; the **PSG** to BlastEm's, tick for tick.

## Playing

Sheliak lives in the Lyra workspace beside the compiler (SDL3 is needed for the window):

```bash
../lyra/build.sh          # builds lyrac with std/ beside it
./build.sh                # builds build/sheliak and the test tools
build/sheliak game.bin    # plays a raw ROM image
```

Keys (pad 1): arrows; Z, X, C for A, B, C and A, S, D for X, Y, Z; Return for Start, Q for
Mode; F full screen; Escape quits. Gamepads are pads 1 and 2. The pads are 6-button;
`--pads 3` gives the original 3-button pad, which a few early games need.

On macOS the menu bar opens another ROM (⌘O; started with none, Sheliak asks for one),
pauses (⌘P) and resets (⌘R), and sets the pads, the window's size (⌘1–⌘5), full screen
(⌃⌘F), the volume and mute (⇧⌘M), and the look: sharp pixels, scanlines, or a CRT's
scanlines, aperture grille and curve, drawn by a shader on the GPU. Sheliak remembers them
(`~/Library/Application Support/Sheliak/preferences`).

A ROM may be a raw image, an SMD one or an MGD one (the Multi Game Doctor's, often `.md`),
whatever its extension. A split SMD image is found from its first part by the names of the
rest (`game.1`, `game.2`, …; `sf2md1.smd`, `sf2md2.smd`, …; `sf2a.smd`, `sf2b.smd`, …), or
its parts can be given in order: `build/sheliak part1 part2 …`. Any of these may be in a
zip, 7z or RAR 5 archive (`game.zip`, `game.smd.7z`, `game.rar`). A cartridge with save RAM
keeps it in a `.srm` file beside the ROM.

## Testing

The references are downloaded and built on first use, pinned, under `build/deps/` — none
is part of this repository:

```bash
tests/cpu.sh      # the 68000 against SingleStepTests
tests/z80.sh      # the Z80 against SingleStepTests
tests/vdp.sh      # the VDP (and the pads, cartridge hardware and Z80 in the machine)
                  # against BlastEm; needs SDL2, a C compiler and make
tests/ym.sh       # the YM2612 against Nuked-OPN2
tests/psg.sh      # the PSG against BlastEm's
tests/sound.sh    # the sound path end to end
```

`CLAUDE.md` is the working guide: the rules the code keeps, the layout, and the status of
each chip.

## Licence

Sheliak is MIT-licensed — see `LICENSE`. Three files in `tests/` are the exception, each
marked with its own licence because it exists to work with another project's code:
`tests/blastem_patches.py` and `tests/oracles/psg_blastem.c` (GPL-3.0-or-later, for BlastEm)
and `tests/oracles/ym_nuked.c` (LGPL-2.1-or-later, for Nuked-OPN2). Those projects are
downloaded and built only to test against; nothing of theirs is included here, and nothing
of theirs is linked into Sheliak.

Contributions are not being accepted yet.

Sega, Genesis and Mega Drive are trademarks of Sega Corporation. Sheliak is not affiliated
with or endorsed by Sega.
