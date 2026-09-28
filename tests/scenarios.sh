#!/usr/bin/env bash
#
# Run the 68000's interrupt, STOP and trace scenarios (src/scenariotest.lyra), which the
# recorded suite has none of.
#
#   tests/scenarios.sh
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/build.sh"
"$ROOT/build/scenariotest"
