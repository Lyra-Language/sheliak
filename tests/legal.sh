#!/usr/bin/env bash
#
# Check the 68000's opcode legality and illegal-instruction exceptions on all 65,536
# opcodes, against Musashi's opcode table (src/legaltest.lyra says what is checked).
#
#   tests/legal.sh
#
# The table is **downloaded, never committed or shipped**, like the SingleStepTests suite:
# one file, pinned to a commit, fetched once into build/deps/musashi/. Needs python3.
set -euo pipefail

readonly COMMIT="313ebf1bd9f4d0d93341eb5ce21fd8a119e9dbdd"
readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DEST="$ROOT/build/deps/musashi"

if ! { [ -f "$DEST/COMMIT" ] && [ "$(cat "$DEST/COMMIT")" = "$COMMIT" ]; }; then
  rm -rf "$DEST"
  mkdir -p "$DEST"
  curl -fsSL --retry 2 -o "$DEST/m68k_in.c" \
    "https://raw.githubusercontent.com/kstenerud/Musashi/$COMMIT/m68k_in.c"
  printf '%s' "$COMMIT" >"$DEST/COMMIT"
fi

"$ROOT/build.sh"
python3 "$ROOT/tests/musashi_legal.py" "$DEST/m68k_in.c" | "$ROOT/build/legaltest"
