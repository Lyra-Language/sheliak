#!/usr/bin/env bash
#
# Download the SingleStepTests Z80 suite into build/deps/z80/.
#
#   tests/fetch_z80.sh
#
# **Downloaded, never committed or shipped**, as the 68000 suite is (tests/fetch.sh) —
# though this one is MIT-licensed. Pinned to one commit, fetched once; a second run finds it
# and does nothing. The tarball is a few hundred MB; only v1/ is kept (about 1.3 GB of JSON,
# 1,000 tests an opcode).
set -euo pipefail

readonly COMMIT="ebe1875d48f374bcfd4b505d8eb8ee751568b5f7"
readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DEST="$ROOT/build/deps/z80"

if [ -f "$DEST/COMMIT" ] && [ "$(cat "$DEST/COMMIT")" = "$COMMIT" ]; then
  exit 0
fi

rm -rf "$DEST"
mkdir -p "$DEST"
tarball="$DEST/z80.tar.gz"
curl -fsSL --retry 2 -o "$tarball" "https://github.com/SingleStepTests/z80/archive/$COMMIT.tar.gz"
tar -xzf "$tarball" -C "$DEST" --strip-components=1 "z80-$COMMIT/v1"
rm -f "$tarball"
printf '%s' "$COMMIT" >"$DEST/COMMIT"
printf 'fetched %s test files into %s\n' "$(ls "$DEST/v1" | wc -l | tr -d ' ')" "$DEST/v1"
