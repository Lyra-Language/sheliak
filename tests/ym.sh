#!/usr/bin/env bash
#
# Check Sheliak's YM2612 against Nuked-OPN2: random scripts of register writes and samples
# run on both, every sample's two outputs and every status read compared.
#
#   tests/ym.sh            # 100 scripts
#   tests/ym.sh 500        # more
#
# Nuked-OPN2 (LGPL-2.1) is downloaded pinned into build/deps/nuked-opn2 and compiled into
# tests/oracles/ym_nuked.c's harness — run as a separate program, never linked.
set -euo pipefail

readonly COMMIT="335747d78cb0abbc3b55b004e62dad9763140115"
readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly NUKED="$ROOT/build/deps/nuked-opn2"
readonly WORK="$ROOT/build/ym"
count="${1:-100}"

if [ "$(cat "$NUKED/COMMIT" 2>/dev/null)" != "$COMMIT" ]; then
  rm -rf "$NUKED"
  mkdir -p "$NUKED"
  for f in ym3438.c ym3438.h LICENSE; do
    curl -fsSL --retry 2 -o "$NUKED/$f" "https://raw.githubusercontent.com/nukeykt/Nuked-OPN2/$COMMIT/$f"
  done
  printf '%s' "$COMMIT" >"$NUKED/COMMIT"
fi
mkdir -p "$ROOT/build/oracles" "$WORK"
cc -O2 -I"$NUKED" -o "$ROOT/build/oracles/ym_nuked" "$ROOT/tests/oracles/ym_nuked.c"
"$ROOT/build.sh" >/dev/null

echo t | "$ROOT/build/oracles/ym_nuked" >"$WORK/roms_nuked.txt"
echo t | "$ROOT/build/ymtest" >"$WORK/roms_sheliak.txt"
cmp -s "$WORK/roms_nuked.txt" "$WORK/roms_sheliak.txt" || { echo "ym: the ROMs differ"; exit 1; }

failed=0
for seed in $(seq 1 "$count"); do
  "$ROOT/tests/ym_script.py" "$seed" >"$WORK/script.txt"
  "$ROOT/build/oracles/ym_nuked" <"$WORK/script.txt" >"$WORK/nuked.txt"
  "$ROOT/build/ymtest" <"$WORK/script.txt" >"$WORK/sheliak.txt"
  if ! cmp -s "$WORK/nuked.txt" "$WORK/sheliak.txt"; then
    line="$(cmp "$WORK/nuked.txt" "$WORK/sheliak.txt" | sed 's/.*line //' || true)"
    echo "seed $seed differs from output line $line:"
    { diff "$WORK/nuked.txt" "$WORK/sheliak.txt" || true; } | head -3 | sed 's/^/    /'
    failed=$((failed + 1))
  fi
done
echo "ym: $((count - failed)) of $count scripts match Nuked-OPN2"
[ "$failed" -eq 0 ]
