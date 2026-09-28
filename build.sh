#!/usr/bin/env bash
#
# Build Sheliak's programs into build/.
#
#   ./build.sh              # build/cputest and build/legaltest (the 68000 test runners)
#
# Uses the sibling compiler, ../lyra/build/lyrac (run ../lyra/build.sh first), whose
# install layout puts `std/` and `bindings/` beside it. Override with $LYRAC.
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LYRAC="${LYRAC:-$ROOT/../lyra/build/lyrac}"

if [ ! -x "$LYRAC" ]; then
  printf 'lyrac not found at %s — run ../lyra/build.sh, or set LYRAC\n' "$LYRAC" >&2
  exit 1
fi

mkdir -p "$ROOT/build"
"$LYRAC" build -o "$ROOT/build/cputest" "$ROOT/src/cputest.lyra"
"$LYRAC" build -o "$ROOT/build/legaltest" "$ROOT/src/legaltest.lyra"
