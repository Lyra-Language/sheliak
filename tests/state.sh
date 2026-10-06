#!/usr/bin/env bash
#
# Save states, held to the machine they were saved from (build/statetest): every VDP test
# ROM (src/vdproms.lyra) — and any ROMs given, which exercise far more of the machine than
# test ROMs that park — run, saved, loaded into a fresh machine that must equal the one
# saved, and run on in lockstep with it; then damaged and foreign states refused.
#
#   tests/state.sh                 the test ROMs (40 frames each side of the save — they
#                                  park within a few)
#   tests/state.sh game.bin …      and these (raw images) too, 300 frames each side
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly WORK="$ROOT/build/state"
mkdir -p "$WORK"
"$ROOT/build.sh" >/dev/null
"$ROOT/build/vdproms" "$WORK/roms" >/dev/null
"$ROOT/build/statetest" --frames 40 "$WORK"/roms/*.bin
if [ $# -gt 0 ]; then "$ROOT/build/statetest" "$@"; fi
