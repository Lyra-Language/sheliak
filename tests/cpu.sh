#!/usr/bin/env bash
#
# Run the 68000 core against SingleStepTests: every file, or the ones named.
#
#   tests/cpu.sh                 # all 125 instruction files
#   tests/cpu.sh NOP MOVE.l      # just these
#   CPUTEST_FLAGS=--no-address-errors tests/cpu.sh MOVE.w   # skip tests ending in one
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
  # shellcheck disable=SC2086 # the flags are meant to split
  gzip -dc "$file" | "$ROOT/build/cputest" "$name" ${CPUTEST_FLAGS:-} || status=1
done
exit "$status"
