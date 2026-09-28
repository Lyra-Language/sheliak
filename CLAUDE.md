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
./build.sh                  # -> build/cputest, build/legaltest
tests/fetch.sh              # SingleStepTests 68000 suite -> build/deps/680x0 (~200 MB, once)
tests/cpu.sh                # every 68000 test file (~1M tests, ~17 s)
tests/cpu.sh MOVE.l DIVS    # just these
tests/legal.sh              # all 65,536 opcodes: legality against Musashi, illegal exceptions
tests/scenarios.sh          # interrupt, STOP and trace scenarios on a scripted bus
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
- **Test data is downloaded, never committed or shipped**: SingleStepTests declares no
  licence; `tests/fetch.sh` pins it to a commit under `build/`. Musashi's opcode table
  (MIT) is treated the same way by `tests/legal.sh`, though its licence would allow more.
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
- **Hot paths do not allocate** (`noalloc` where it can be said): the 68000 alone is ~7.6
  million cycles a second.

## Layout

Module paths resolve under `src/` (the entry file's directory), so entry points live there.

```
src/cputest.lyra     68000 test runner: one SingleStepTests file on stdin
src/legaltest.lyra   every opcode through the core, against a legality reference on stdin
src/scenariotest.lyra  interrupts, STOP and trace, scenario by scenario, on a scripted bus
src/m68k/            the 68000 (module m68k):
  cpu.lyra           Cpu, the Bus trait, step and decode, the prefetch, flags
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
tests/fetch.sh       download the pinned suite
tests/cpu.sh         run the suite, one line per instruction file
tests/legal.sh       fetch Musashi's table, expand it (musashi_legal.py), run legaltest
tests/scenarios.sh   run scenariotest
```

## Status

The 68000 passes **the whole suite**: all 124 files, 1,000,058 tests, address errors
included, every instruction the chip has (the two known-bad tests aside). Every one of the
65,536 opcodes is classified as Musashi's table does, and each illegal one takes exception
4, 10 (line A) or 11 (line F). Interrupts, STOP and trace pass their scenarios
(`tests/scenarios.sh`). **Nothing in the 68000 is left unbuilt** but the bus error, which
needs a bus that can raise one.

What the recorded suite cannot check rests on documentation: the illegal-instruction,
privilege-violation, trace and interrupt sequences on Motorola's tables and Yacht, with the
TRAP and TRAPV frames the suite does test; the divide-by-zero frame's PC on a single test. **The interrupt
has one open cycle count**: the idle after the acknowledge is 4 cycles (Motorola's 44 in
all) where Clock Signal takes 6 — to settle against hardware once the VDP raises real
interrupts.

`CPUTEST_FLAGS=--no-address-errors` skips tests that end in an address error, to get an
instruction's ordinary path right first.
