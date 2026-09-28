#!/usr/bin/env bash
#
# Run the 68000 core against SingleStepTests: every file, or the ones named.
#
#   tests/cpu.sh                 # all 125 instruction files
#   tests/cpu.sh NOP MOVE.l      # just these
#
# Builds cputest and fetches the suite first if needed. One line per file, then a total;
# exits 1 if any test failed (unimplemented opcodes are counted separately, not failed).
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SUITE="$ROOT/build/deps/680x0/68000/v1"

"$ROOT/tests/fetch.sh"
"$ROOT/build.sh"

if [ $# -gt 0 ]; then
  files=()
  for name in "$@"; do files+=("$SUITE/$name.json.gz"); done
else
  files=("$SUITE"/*.json.gz)
fi

status=0
for file in "${files[@]}"; do
  name="$(basename "$file" .json.gz)"
  gzip -dc "$file" | "$ROOT/build/cputest" "$name" || status=1
done
exit "$status"
