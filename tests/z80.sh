#!/usr/bin/env bash
#
# Run the Z80 core against SingleStepTests: every file, or the ones named.
#
#   tests/z80.sh                 # all 1,604 opcode files
#   tests/z80.sh 00 "dd 34"      # just these
#
# Fetches the suite and builds z80test first if needed. One line per file, then a total;
# exits 1 if any test failed.
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SUITE="$ROOT/build/deps/z80/v1"

"$ROOT/tests/fetch_z80.sh"
"$ROOT/build.sh" >/dev/null

if [ $# -gt 0 ]; then
  files=()
  for name in "$@"; do files+=("$SUITE/$name.json"); done
else
  files=("$SUITE"/*.json)
fi

status=0
failed_files=0
for file in "${files[@]}"; do
  name="$(basename "$file" .json)"
  if ! "$ROOT/build/z80test" "$name" <"$file"; then
    status=1
    failed_files=$((failed_files + 1))
  fi
done
echo "z80: $((${#files[@]} - failed_files)) of ${#files[@]} files pass"
exit "$status"
