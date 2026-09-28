#!/usr/bin/env bash
#
# Run the 68000's interrupt and STOP scenarios (src/interrupttest.lyra), which the
# recorded suite has none of.
#
#   tests/interrupts.sh
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/build.sh"
"$ROOT/build/interrupttest"
