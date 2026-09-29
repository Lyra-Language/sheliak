# Sheliak — Project Context

Sheliak is a Sega Genesis / Mega Drive emulator written in Lyra, built for Vega (the
retro-console studio in `../vega`) to run and debug what it makes — and to run **any
existing cartridge ROM, playable**. Master System and Game Gear follow, reusing its Z80 and
SN76489. **Open source, MIT** (`LICENSE`); Vega, which uses it, is closed and sold, so
nothing copyleft or non-commercial is linked in — and nothing of BlastEm's or Nuked-OPN2's
is ever copied in, which a public repository makes everyone's to check. The three `tests/`
files that work with those projects' code carry their own licences (GPL-3.0-or-later,
LGPL-2.1-or-later), with SPDX headers; keep new ones like them marked the same way.
Contributions are not being accepted yet. Lives in the Lyra workspace beside `lyra/`; the
workspace's `CLAUDE.md` rules apply here too. Never "Sega", "Genesis" or "Mega Drive" in a
product name.

## Commands

```bash
../lyra/build.sh            # the compiler, with std/ beside it
./build.sh                  # -> build/: sheliak, cputest, legaltest, scenariotest, vdproms,
                            #    vdpcheck, padtest, romtest
build/sheliak ROM           # play: arrows, Z/X/C = A/B/C, A/S/D = X/Y/Z, Return = Start,
                            #    Q = Mode, F = full screen, Escape; gamepads on ports 1 and 2;
                            #    --pads 3 for 3-button pads
SDL_VIDEODRIVER=dummy build/sheliak ROM --frames 600 --screenshot out.bmp   # headless
                            #    (--wav FILE: the sound; --save: use the .srm too)
tests/fetch.sh              # SingleStepTests 68000 suite -> build/deps/680x0 (~200 MB, once)
tests/cpu.sh                # every 68000 test file (~1M tests, ~17 s)
tests/cpu.sh MOVE.l DIVS    # just these
tests/legal.sh              # all 65,536 opcodes: legality against Musashi, illegal exceptions
tests/fetch_z80.sh          # SingleStepTests Z80 suite -> build/deps/z80 (~1.3 GB, once)
tests/z80.sh                # every Z80 test file (1,604 files, 1.6M tests, ~85 s)
tests/z80.sh 00 "dd cb __ 06"   # just these
build/z80scenarios          # the Z80's interrupts, HALT, EI, RETN
tests/psg.sh                # the PSG against BlastEm's, tick by tick (random scripts)
tests/ym.sh                 # the YM2612 against Nuked-OPN2, sample by sample, bit for bit
tests/sound.sh              # a note from each chip through the front end, its pitch measured
tests/scenarios.sh          # interrupt, STOP and trace scenarios on a scripted bus
tests/vdp.sh                # VDP test ROMs on Sheliak and BlastEm, compared (needs SDL2)
tests/vdp.sh fill copy      # just these
build/padtest               # the pads, buttons held, through the bus
build/romtest               # ROM files read: raw, SMD, split SMD, MGD, zipped; part names
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
  bus arbitration); the CPU keeps no clock. TAS's write-back is the bus's too: the
  read-modify-write is its own `Bus` method, so the Genesis bus can drop the write, as the
  console does.
- **VDP by access slot** (FIFO, DMA, mid-line effects), Z80/68000 bus sharing, cartridge
  hardware (SRAM, EEPROM, the SSF2 mapper), regions, TMSS, 3- and 6-button pads.
- **Out of scope unless decided otherwise**: Sega CD, 32X; the SVP (Virtua Racing) is late.

## Rules

- **A chip is a module; a console is a composition** (`../vega/CLAUDE.md`'s rule): the Z80
  and SN76489 written here are the Master System's and Game Gear's too.
- **Every chip is tested headlessly.** Per-instruction suites for CPUs; a headless runner
  (ROM → frames and audio dumped) for the whole machine. Nothing is verified by eye alone.
- **An address error is state, not control flow** (`src/m68k/access.lyra`): every access
  goes through `cpu_read_word` and friends, which record the fault and then do nothing, so
  the instruction runs to its end off the bus and `step` runs exception 3. Code that writes
  a register or the flags directly checks `cpu.faulted` first. What the chip has already
  changed when it faults stays changed — a source's (An)+/-(An) is applied during address
  calculation, MOVE's destination (An)+ only after its write — and the tests are the
  authority on which is which.
- **The frame gets the faulting opcode**, passed to `address_error` by `step`: an
  instruction that prefetched before faulting has the next opcode in IRD.
- **The frame's PC is the chip's internal PC, four bytes ahead of the word being fetched**
  — `cpu.pc` reads at `pc + 4`, so a refill from an odd target sets `pc = target - 4` first
  (`jump_to`). The status word's I/N bit is set for an instruction-fetch fault, clear for a
  data access.
- **Hardware arithmetic wraps**: Lyra traps on overflow, so register arithmetic is
  `wrapping_*`, and conversions (`u8(x)` truncates, `i8(u8)` reinterprets) are explicit.
- **A test is only skipped with an upstream report behind it**: `KNOWN_BAD` in
  `src/cputest.lyra` names each one and the issue that says its data is wrong, and the
  runner counts them apart. Two so far (ASL.b 1583 and 1761, SingleStepTests issue #4).
- **The suite runs every test in supervisor mode**, so the privilege violation is untested
  there: it follows Motorola's documentation and the frame TRAP's tests confirm, and is to
  be checked against real software.
- **Test data is downloaded, never committed or shipped**: SingleStepTests' 68000 suite
  declares no licence; `tests/fetch.sh` pins it to a commit under `build/`. The Z80 suite
  (MIT) is treated the same way by `tests/fetch_z80.sh`, and Musashi's opcode table (MIT) by
  `tests/legal.sh`, though their licences would allow more.
- **The Z80 is checked T-state by T-state**, as the 68000 is by transaction: every register
  (the undocumented WZ, Q, P, EI and R included), RAM, and each memory and I/O access with
  the T-state it came at. Its interrupts, which the suite never raises, are scenarios on
  Zilog's documented timings (`src/z80scenarios.lyra`).
- **The Z80 runs on the 68000's bus** (`src/genesis/sound.lyra`): caught up at every 68000
  bus cycle, a T-state every 15 master clocks. Its bus is granted only out of reset
  (BlastEm's model; Sega's start-up sequence releases the reset first). Two BlastEm
  approximations the `z80_run` ROM sidesteps: it ends the Z80's /INT pulse only when it
  next synchronises (so a handler re-enabling interrupts within the ~171 T-state pulse is
  taken again a number of times that depends on that), and it schedules the first frame's
  interrupt from the VDP's power-on mode 4 (an extra one near line 192).
- **Legality is decided once, before decoding**: `is_legal` (`src/m68k/legal.lyra`) says
  whether the 68000 has an opcode, and `step` takes the illegal-instruction (or line A/F)
  exception for any it does not. The decoder may therefore match by bit pattern alone —
  it never sees an operand the instruction refuses. `tests/legal.sh` holds `is_legal` to
  Musashi's table on every opcode and checks that every legal one decodes.
- **The IPL pins are sampled at every instruction fetch**, not at the instruction boundary
  (Clock Signal's model): an interrupt raised after an instruction's last fetch is taken
  only after the next instruction. Level 7 is taken on its rise, once. The acknowledge
  cycle is the bus's (`acknowledge_interrupt`), timing and vector both — the Genesis
  autovectors, synchronised to the E clock.
- **Trace follows the T bit as an instruction starts**: exception 9 after it, inside its
  `step` — so a pending interrupt is taken at the next step, after the trace, as Motorola
  ranks them. Not after an illegal opcode or a privilege violation (`Cpu.untraced`); after
  TRAP, TRAPV, CHK or divide-by-zero it follows that exception, into its handler.
- **BlastEm is the VDP's oracle, as SingleStepTests is the 68000's** (`tests/vdp.sh`):
  test ROMs run on both to a parking loop, and the VDP's memories, registers, address and
  code registers and the start of work RAM must match byte for byte — and the frame, pixel
  for pixel: Sheliak renders the VDP's output (a CRAM colour and an intensity per pixel),
  `tests/frame_compare.py` turns it into light through the DAC's 15 levels, and BlastEm's
  screenshot must be the same image. BlastEm is GPLv3, so
  it is **downloaded, built and run as a separate program** — pinned, under `build/deps/`,
  never linked, committed or shipped. Its source may be read to understand what the
  hardware does, never copied. Where it and the classic documents (genvdp.txt) disagree,
  it is the authority, and the decision is recorded where the code makes it — unless BlastEm
  itself looks wrong, when Sheliak does not copy it and the test sidesteps the case, the
  reason written beside it (the one so far: `draw_shadow_blank` in `src/vdproms.lyra`).
- **BlastEm is patched only outside what it emulates** (`tests/blastem_patches.py`): a line
  the no-OpenGL build cannot compile, its no-OpenGL screenshot path (which read the wrong
  rows), and a `screenshot` debugger command. It runs on SDL's dummy drivers, off-screen,
  with a scratch HOME holding a config that crops the border.
- **The test ROMs are ours**, written by `src/vdproms.lyra` with a hand-encoded handful of
  68000 instructions, so the harness needs no assembler. Each sets every register first (as
  a game's start-up does, so neither emulator's power-on values matter), waits for each DMA
  to finish before touching the VDP again (as a program must), and parks in `bra.s *`.
- **The VDP's memories are compared settled**: both emulators run two frames past the
  parking loop, so the FIFO drains and any DMA completes, and the last frame drawn is
  compared; how long anything took is for the timing ROMs to record, in work RAM.
- **Timing is compared by what a program sees** (the timing ROMs in `src/vdproms.lyra`):
  the V counter at an interrupt or a blanking edge must match exactly; the H counter within
  a slack the ROM names (`.hslack`, `tests/ram_compare.py`) — 8 slots for an interrupt's
  arrival, as BlastEm's 68000 enters one ~10 cycles faster than Motorola's 44 and polls in
  STOP every 4, and 16 for an edge a loop polls for, one loop's length. So an H position
  off by less than a loop goes unseen: the harness is proven on larger mutations only.
  Each ROM measures from a V-blank edge or an interrupt taken in STOP, never from power-on,
  and drains anything pending first — the emulators' power-on beam and H interrupt counter
  (BlastEm FF, Sheliak 0) are not the hardware's, nor each other's. A handler sets all it
  depends on (a DMA's source too), since a drain may run it once more beforehand. **The
  FIFO's two-slot latency is below the slack** and unchecked; the slot maps, a VRAM word's
  two slots and DMA's pace are (each mutation fails the access-slot ROMs).
- **A mid-line change is compared through the FIFO** (`mid_*` in `src/vdproms.lyra`): the
  ROM fills it first, so each change lands in the external slot the VDP gives it and the
  frames can be compared pixel for pixel. A register written mid-line lands where the
  68000 happens to be, which the emulators do not agree on to the pixel, and is untested.
- **Where BlastEm's 68000 and Sheliak's differ, the ROM sidesteps it**: BlastEm takes an
  interrupt one instruction after the mask is lowered, Sheliak (Clock Signal's model) at
  once; `wait_for_interrupts` unmasks across a `nop`. Its status register's top six bits
  are its prefetch word, Sheliak's the last word on the bus; the ROMs store only the low
  byte.
- **Hot paths do not allocate** (`noalloc` where it can be said): the 68000 alone is ~7.6
  million cycles a second.
- **A large struct is read through `ref`, never a bare parameter**: a bare parameter is a
  copy, and the bus, the VDP and the YM2612 are kilobytes. Passing them bare cost the
  emulator two thirds of its time (a frame 14 ms, then 4.7 ms with `ref`).
- **The YM2612's oracle is Nuked-OPN2** (LGPL-2.1, `tests/ym.sh`), a transcription of the
  decapped die, downloaded pinned and built into a separate harness
  (`tests/oracles/ym_nuked.c`) — never linked, and read for behaviour, never copied: Sheliak's
  YM2612 is its own structure, its ROMs generated from their formulas (and checked equal to
  the chip's). It must match Nuked's output sample for sample, bit for bit, on random
  scripts of every register (the LSI test registers aside). The chip type is the YM2612
  (the ladder effect), status read on port 0.
- **The PSG's oracle is BlastEm's `psg.c`**, built into `tests/oracles/psg_blastem.c` from the
  pinned BlastEm tree: its state compared tick by tick. Where SMS Power's hardware tests
  and BlastEm part (a data byte to a latched volume or noise register), Sheliak follows the
  hardware and the scripts avoid the case.
- **The cartridge is recognised by its header, as BlastEm recognises it** (romdb.c's
  heuristics): save RAM by "RA" at 1B0, mapped for good past the ROM or through the Sega
  mapper's A130F1 over a ROM of more than 2 MB; the SSF2 mapper by a file of more than 4 MB
  whose header says no more than 4 MB. `tests/vdp.sh`'s cartridge ROMs hold both, and ROM
  mirroring, to BlastEm — clearing BlastEm's saves (kept in its scratch home) before each
  run. A save file is a byte per byte of save RAM, BlastEm's `save.sram` format.
- **A ROM file is read by its contents, never its name**: an SMD image by the copier's
  header as BlastEm recognises it (system.c's `is_smd_format`), anything else raw.
  `build/romtest` holds the reading to an SMD writer of its own, and BlastEm reads such a
  file as the raw image it was made from. **An MGD image has no header**, so it is known
  by content: "SEGA" at 100 only once put back in address order (the other order reads
  "ESAG"). A file reading "SEGA" neither way stays raw. **A split SMD image has no reference** (BlastEm
  refuses them): its parts are joined by the format alone — byte 2 set in all but the last
  — and refused unless the result begins "SEGA", so a later part given first is caught.
  Only a part's *name* is guessed, never its contents: a guess that finds nothing is an
  error asking for the parts in order, never a shorter ROM.
- **A zip or 7z is read by Lyra's `std.zip` and `std.sevenzip`**, whose decompressors
  (`std.compress`) are held to Go's DEFLATE, liblzma and 7-Zip's own archives in the
  compiler's tests. The ROM in either is chosen one way (`roms_in_archive`): the one file
  with a ROM's extension (or the one file), or a split image's parts chained by name; an
  archive of several ROMs is refused, naming them, rather than one picked. An archived
  ROM's save file drops both extensions.
- **The mix is not checked against hardware**: the resampling, the PSG/FM balance, the
  Model 1 low-pass (3,390 Hz, BlastEm's default) and the DC block are `genesis/audio.lyra`'s
  choices; `tests/sound.sh` checks only that notes come out at their pitch.

## Layout

Module paths resolve under `src/` (the entry file's directory), so entry points live there.

```
src/sheliak.lyra     the emulator in an SDL window: frames paced to 59.92 Hz, the picture
                     through the DAC's levels, keyboard and gamepads as pads 1 and 2
src/padtest.lyra     the controller ports with buttons held, read through the bus
src/romtest.lyra     ROM files as dumped (raw, SMD, split SMD, MGD) read back as images;
                     the names a split image's next part is looked for by; a zip's ROM
src/psgtest.lyra     the PSG on a script, its state printed per tick
src/ymtest.lyra      the YM2612 on a script, its output printed per sample
src/cputest.lyra     68000 test runner: one SingleStepTests file on stdin
src/z80test.lyra     Z80 test runner: one SingleStepTests file on stdin
src/z80scenarios.lyra  the Z80's interrupts, scenario by scenario, on a scripted bus
src/legaltest.lyra   every opcode through the core, against a legality reference on stdin
src/scenariotest.lyra  interrupts, STOP and trace, scenario by scenario, on a scripted bus
src/m68k/            the 68000 (module m68k):
  cpu.lyra           Cpu, the Bus trait, reset, step and decode, the prefetch, flags
  legal.lyra         is_legal: which opcodes the 68000 has
  access.lyra        fault-aware accesses; the address error exception
  ea.lyra            effective addresses: locate, read_operand, write_operand
  move.lyra          MOVE, MOVEA (with the -(An) and (xxx).L destination orders)
  alu.lyra           results and condition codes per operation and size (no bus)
  arith.lyra         ADD/SUB/AND/OR/EOR/CMP in every form: register, memory, address
                     register, extended, CMPM, immediate (group 0), quick (group 5)
  shift.lyra         ASx/LSx/ROXx/ROx, register and memory forms, a bit at a time
  flow.lyra          Bcc/BRA/BSR, DBcc, Scc, JMP, JSR, RTS, RTR, LEA, PEA, LINK, UNLK;
                     the queue refill
  exception.lyra     TRAP, TRAPV, CHK, RTE, SR/CCR moves and immediates, MOVE USP, RESET,
                     STOP; illegal instruction, line A/F, privilege violation, trace,
                     interrupts; the 6-byte group 1/2 frame, set_sr (stack switch on S)
  muldiv.lyra        MULU, MULS, DIVU, DIVS; data-dependent timing (Cwik's division model)
  bcd.lyra           ABCD, SBCD, NBCD, with the chip's undocumented N and V
  bits.lyra          BTST, BCHG, BCLR, BSET, dynamic and static
  registers.lyra     SWAP, EXT, EXG
  unary.lyra         NEGX, CLR, NEG, NOT, TST (CLR reads before it writes), TAS
  movem.lyra         MOVEM (with the extra read), MOVEP
src/z80/             the Z80 (module z80):
  cpu.lyra           Z80Cpu, the Z80Bus trait, step, interrupts (IM 0/1/2, NMI, HALT),
                     registers and the unprefixed instructions, decoded by x/y/z/p/q
  prefixed.lyra      CB, DD CB / FD CB, ED (block instructions and their repeat flags)
  alu.lyra           arithmetic and the flags, bits 5 and 3 included
src/psg/psg.lyra     the SN76489 (module psg): tone and noise channels, the Sega LFSR
src/ym2612/ym2612.lyra  the YM2612 (module ym2612), cycle by cycle: the register file,
                     phase and envelope generators, SSG-EG, LFO, operators and algorithms,
                     channel accumulation, the multiplexed 9-bit DAC and its ladder, timers
src/vdp/             the VDP (module vdp):
  vdp.lyra           memories, registers, the control and data ports, status, DMA's start
  slots.lyra         the access slots: which slots are the 68000's, the FIFO, reads fetched
                     ahead, fill, copy and 68000 → VDP transfers a slot at a time
  beam.lyra          the beam on the master clock: access slots, lines, V-blank and
                     H-blank, the HV counter and its latch, the H and V interrupts; draws
                     each line as the beam reaches it
  render.lyra        mode 5, drawn slot by slot: each block fetched, each pixel composed and
                     coloured as it goes out, the CRAM dot; the plane fetch pipeline (fine
                     scroll, column scroll, the window and its edge bug), sprites and their
                     limits, priority, shadow/highlight
src/genesis/         the machine (module genesis):
  machine.lyra       power on, and run a frame
  cartridge.lyra     the ROM file read (raw, SMD, split SMD, MGD, zip, 7z); the ROM
                     (mirrored), save RAM, the Sega SRAM and SSF2 mappers, the header they
                     are recognised by
  sound.lyra         the Z80's side: its RAM, the bank window onto the cartridge, its clock
                     and /INT (from the VDP); the YM2612 and PSG, clocked, their samples
  audio.lyra         the analog stage: both chips resampled by area, mixed, filtered
  io.lyra            the I/O chip: 3- and 6-button pads (TH-multiplexed; the 6-button's
                     edge count, timeout and power-on rise); the Z80's RAM and bus request
                     as the 68000 sees them
  bus.lyra           the 68000's memory map: ROM, work RAM, the VDP ports, I/O, Z80, TMSS;
                     the master clock, refresh, the interrupt pins and E-clock acknowledge;
                     the 68000 held by the VDP, and fed to it during a transfer
src/vdproms.lyra     writes the VDP test ROMs (and each one's parking address)
src/vdpcheck.lyra    runs one test ROM on Sheliak and dumps the VDP for comparison
tests/fetch.sh       download the pinned 68000 suite
tests/fetch_z80.sh   download the pinned Z80 suite
tests/z80.sh         run it, one line per opcode file
tests/cpu.sh         run the suite, one line per instruction file
tests/legal.sh       fetch Musashi's table, expand it (musashi_legal.py), run legaltest
tests/scenarios.sh   run scenariotest
tests/vdp.sh         fetch and build BlastEm (pinned), run every VDP test ROM on both, compare
tests/blastem_patches.py  the oracle's three patches (none to anything it emulates)
tests/frame_compare.py    Sheliak's VDP output against BlastEm's screenshot, pixel for pixel
tests/ram_compare.py      work RAM, exact but for a timing ROM's H counters, within its slack
tests/oracles/       the C harnesses around the sound oracles (Nuked-OPN2, BlastEm's PSG)
tests/psg.sh, psg_script.py  the PSG against BlastEm's
tests/ym.sh, ym_script.py    the YM2612 against Nuked-OPN2
tests/sound.sh, wav_pitch.py the sound path end to end
```

## Status

The 68000 passes **the whole suite**: all 124 files, 1,000,058 tests, address errors
included, every instruction the chip has (the two known-bad tests aside). Every one of the
65,536 opcodes is classified as Musashi's table does, and each illegal one takes exception
4, 10 (line A) or 11 (line F). Interrupts, STOP and trace pass their scenarios
(`tests/scenarios.sh`). **Nothing in the 68000 is left unbuilt** but the bus error, which
needs a bus that can raise one.

What the recorded suite cannot check rests on documentation: the illegal-instruction,
privilege-violation, trace, interrupt and reset sequences on Motorola's tables and Yacht,
with the TRAP and TRAPV frames the suite does test; the divide-by-zero frame's PC on a
single test. **The interrupt has one open cycle count**: the idle after the acknowledge is
4 cycles (Motorola's 44 in all) where Clock Signal takes 6 — to settle against hardware
once the VDP raises real interrupts.

`CPUTEST_FLAGS=--no-address-errors` skips tests that end in an address error, to get an
instruction's ordinary path right first.

**The VDP has its programming interface, renders, and runs on the master clock**
(`tests/vdp.sh`, 39 ROMs matching BlastEm): VRAM, CRAM, VSRAM, the registers, the command
words, the data port, DMA; mode 5 frames pixel for pixel — planes A and B at every size and
scroll mode, the window (left, right, below), sprites (sizes, flips, links, both limits,
masking), priority, shadow/highlight, 32- and 40-cell widths, the blanked left column; and
the beam — access slots and lines (NTSC), the V-blank and H-blank flags, the HV counter and
its latch, the H and V interrupts through the 68000's pins, the E-clock acknowledge, DRAM
refresh, each line drawn as the beam reaches it; and **the access slots** — the FIFO and
its waiting, reads fetched ahead, fill and copy a byte a slot, 68000 → VDP transfers paced
by the slots with the 68000 held; and **mid-line changes** — the picture drawn slot by
slot, each block fetched and each pixel coloured when the VDP does it, the CRAM dot
included. Not yet: the corners — interlace (and the odd-frame bit), 128 KB VRAM mode, the
8-bit VRAM read, mode 4, the SAT cache, PAL — and, within a line, BlastEm's finer points:
the sprite pipeline spread over the line before (Sheliak takes the sprites at one slot),
and the display switched on or off mid-line (Sheliak stops fetching and draws the
backdrop).

**The Z80 passes the whole SingleStepTests suite** — all 1,604 files, 1,604,000 tests, at
T-state resolution, undocumented flags, WZ and the 2018 block-repeat flags included — and
its interrupt scenarios; it runs in the Genesis (`z80_run` matches BlastEm: a program
loaded by the 68000, the bank window, V-blank interrupts frame by frame). **Not yet**: its
reach into the 68000's RAM and I/O through the window (FF, dropped), the 68000's stall when
it does, and the VDP at 7F00.

**The sound chips are built** — the YM2612 matching Nuked-OPN2 bit for bit on random scripts
of every register (algorithms, feedback, envelopes and SSG-EG, detune, the LFO, channel 3's
special and CSM modes, the DAC and its ladder, the timers and busy flag), the PSG matching
BlastEm's tick for tick — both on the bus (68000 and Z80), and the front end plays them:
mixed, filtered, resampled to 48 kHz through SDL, or written to a WAV (`--wav`). A frame,
sound and all, takes ~4.7 ms. **Not yet**: the YM2612's test registers; a mix checked
against a real console.

**The front end runs a cartridge in a window** (`build/sheliak`), and `tests/vdp.sh` holds
its picture to BlastEm's too: the texels it sends the window (`--ppm`), byte for byte against
the screenshot, so its colour conversion is checked, not only the VDP's output. Raw, SMD, split
SMD and MGD ROM images, zipped, 7-zipped or not, two 6-button pads (3 with `--pads 3`; the protocol matched against BlastEm
with nothing held, `pads` and `pads6`; with buttons held, `build/padtest`), frames paced to
the console's 59.92 Hz whatever the display's rate, ~4.7 ms a frame with sound on an M-series Mac. **Cartridges**: the ROM mirrored at its
size, save RAM (odd, even or both buses; past the ROM or through the Sega mapper, with
write-protect), the SSF2 bank mapper, and save files beside the ROM. **Not yet**: serial
EEPROM saves (the cartridges that carry one are known only by a database), lock-on and
unlicensed mappers, the Z80's bank window through the mapper, regions other
than US NTSC.

**Open**: the VDP's registers at power-on (the ROMs set every one; BlastEm starts register
10 at FF, uncited), and the beam's position and the H interrupt counter with them (Sheliak
starts at the top of an active frame, counter 0). Whether the 68000 takes an interrupt
straight after the mask is lowered or one instruction later (see Rules). The status
register's open-bus bits. The partial left block's column scroll follows BlastEm's model-1 AND;
MD2 VA4 and later differ. In shadow/highlight mode with the left column blanked, BlastEm
draws pixels 8–15 from the planes' pixels 0–7, which Sheliak does not (see Rules).