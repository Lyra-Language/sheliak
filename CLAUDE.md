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
  licence; `tests/fetch.sh` pins it to a commit under `build/`.
- **Hot paths do not allocate** (`noalloc` where it can be said): the 68000 alone is ~7.6
  million cycles a second.

## Layout

Module paths resolve under `src/` (the entry file's directory), so entry points live there.

```
src/cputest.lyra     68000 test runner: one SingleStepTests file on stdin
src/m68k/            the 68000 (module m68k):
  cpu.lyra           Cpu, the Bus trait, step and decode, the prefetch, flags
  access.lyra        fault-aware accesses; the address error exception
  ea.lyra            effective addresses: locate, read_operand, write_operand
  move.lyra          MOVE, MOVEA (with the -(An) and (xxx).L destination orders)
  alu.lyra           results and condition codes per operation and size (no bus)
  arith.lyra         ADD/SUB/AND/OR/EOR/CMP in every form: register, memory, address
                     register, extended, CMPM, immediate (group 0), quick (group 5)
  shift.lyra         ASx/LSx/ROXx/ROx, register and memory forms, a bit at a time
  flow.lyra          Bcc/BRA/BSR, DBcc, Scc, JMP, JSR, RTS, RTR, LEA, PEA; the queue refill
  exception.lyra     TRAP, TRAPV, CHK, RTE, SR/CCR moves and immediates, MOVE USP, RESET;
                     the 6-byte group 1/2 frame, set_sr (stack switch on S)
tests/fetch.sh       download the pinned suite
tests/cpu.sh         run the suite, one line per instruction file
```

## Status

The 68000 passes every test in 87 of the suite's 125 files (701,653 tests, address errors
included): NOP, MOVEQ, MOVE, MOVEA, ADD/SUB/AND/OR/EOR/CMP with their A, X, M, I and Q
forms, all shifts and rotates, control flow (Bcc, BSR, DBcc, Scc, JMP, JSR, RTS, RTR, LEA,
PEA), and the exception group (TRAP, TRAPV, CHK, RTE, SR/CCR moves and immediates, MOVE
USP, RESET).

Not yet: interrupts (the IPL input and autovectored acknowledge — wanted with the VDP),
trace (the T bit), and the illegal-instruction and line A/F exceptions, which wait for
`Unimplemented` to mean only a genuinely illegal opcode. Every other opcode answers `Unimplemented`, which the runner counts apart from
failures. `CPUTEST_FLAGS=--no-address-errors` skips tests that end in one, to get an
instruction's ordinary path right first.
