# Sheliak — Project Context

Sheliak is a Sega Genesis / Mega Drive emulator written in Lyra, built for Vega (the
retro-console studio in `../vega`) to run and debug what it makes — and to run **any
existing cartridge ROM, playable**. Master System and Game Gear follow, reusing its Z80 and
SN76489. **Private and proprietary** (`LICENSE`); Vega is sold, so nothing copyleft or
non-commercial is linked in. Lives in the Lyra workspace beside `lyra/`; the workspace's
`CLAUDE.md` rules apply here too. Never "Sega", "Genesis" or "Mega Drive" in a product name.

## Commands

```bash
../lyra/build.sh            # the compiler, with std/ beside it
./build.sh                  # -> build/cputest
tests/fetch.sh              # SingleStepTests 68000 suite -> build/deps/680x0 (~200 MB, once)
tests/cpu.sh                # every 68000 test file (~1M tests, ~17 s)
tests/cpu.sh MOVE.l DIVS    # just these
```

## Accuracy Target

**Commercial compatibility**: every cartridge ROM runs and is playable. That rules out
frame-at-a-time shortcuts from the start:

- **One master clock** (≈53.69 MHz NTSC, 53.20 PAL); every chip is advanced in lockstep by
  a scheduler, and games depend on how the 68000, Z80, VDP and YM2612 interleave.
- **68000 at bus-cycle level** (`src/m68k/`): each instruction is the exact sequence of word
  and byte accesses and idle cycles the chip makes, with the **prefetch queue** (IRD, IRC)
  modelled and exceptions (address error, bus error, traps) writing their stack frames in
  the hardware's order. Checked against SingleStepTests, which record every transaction.
- **Time lives in the bus**: an access costs 4 cycles plus the bus's wait states (VDP, Z80
  bus arbitration); the CPU keeps no clock.
- **VDP by access slot** (FIFO, DMA, mid-line effects), Z80/68000 bus sharing, cartridge
  hardware (SRAM, EEPROM, the SSF2 mapper), regions, TMSS, 3- and 6-button pads.
- **Out of scope unless decided otherwise**: Sega CD, 32X; the SVP (Virtua Racing) is late.

## Rules

- **A chip is a module; a console is a composition** (`../vega/CLAUDE.md`'s rule): the Z80
  and SN76489 written here are the Master System's and Game Gear's too.
- **Every chip is tested headlessly.** Per-instruction suites for CPUs; a headless runner
  (ROM → frames and audio dumped) for the whole machine. Nothing is verified by eye alone.
- **Hardware arithmetic wraps**: Lyra traps on overflow, so register arithmetic is
  `wrapping_*`, and conversions (`u8(x)` truncates, `i8(u8)` reinterprets) are explicit.
- **Test data is downloaded, never committed or shipped**: SingleStepTests declares no
  licence; `tests/fetch.sh` pins it to a commit under `build/`.
- **Hot paths do not allocate** (`noalloc` where it can be said): the 68000 alone is ~7.6
  million cycles a second.

## Layout

Module paths resolve under `src/` (the entry file's directory), so entry points live there.

```
src/cputest.lyra     68000 test runner: one SingleStepTests file on stdin
src/m68k/            the 68000 (module m68k): Cpu, the Bus trait, step
tests/fetch.sh       download the pinned suite
tests/cpu.sh         run the suite, one line per instruction file
```

## Status

The 68000 core runs NOP and MOVEQ; every other opcode answers `Unimplemented`, which the
runner counts apart from failures.
