#!/usr/bin/env bash
#
# Check Sheliak's PSG against BlastEm's: random scripts of writes and ticks run on both, the
# state after every tick compared.
#
#   tests/psg.sh            # 50 scripts
#   tests/psg.sh 200        # more
#
# BlastEm's psg.c is compiled into tests/oracles/psg_blastem.c's harness from the pinned
# BlastEm tree tests/vdp.sh fetches (GPLv3: run as a separate program, never linked).
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BLASTEM_SRC="$(ls -d "$ROOT"/build/deps/blastem/blastem-*/ 2>/dev/null | head -1)"
readonly WORK="$ROOT/build/psg"
count="${1:-50}"

if [ -z "$BLASTEM_SRC" ]; then
  echo "psg: no BlastEm tree under build/deps — run tests/vdp.sh once to fetch it"
  exit 1
fi
mkdir -p "$ROOT/build/oracles" "$WORK"
cc -O1 -DIS_LIB -I"$BLASTEM_SRC" -I"$BLASTEM_SRC/zstd" $(pkg-config --cflags-only-I sdl2) \
  -o "$ROOT/build/oracles/psg_blastem" "$ROOT/tests/oracles/psg_blastem.c" \
  "$BLASTEM_SRC/psg.c" "$BLASTEM_SRC/serialize.c"
"$ROOT/build.sh" >/dev/null

failed=0
for seed in $(seq 1 "$count"); do
  "$ROOT/tests/psg_script.py" "$seed" >"$WORK/script.txt"
  "$ROOT/build/oracles/psg_blastem" <"$WORK/script.txt" >"$WORK/blastem.txt"
  "$ROOT/build/psgtest" <"$WORK/script.txt" >"$WORK/sheliak.txt"
  if ! cmp -s "$WORK/blastem.txt" "$WORK/sheliak.txt"; then
    echo "seed $seed differs:"
    { diff "$WORK/blastem.txt" "$WORK/sheliak.txt" || true; } | head -4 | sed 's/^/    /'
    failed=$((failed + 1))
  fi
done
echo "psg: $((count - failed)) of $count scripts match BlastEm"
[ "$failed" -eq 0 ]
