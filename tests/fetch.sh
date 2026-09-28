#!/usr/bin/env bash
#
# Download the SingleStepTests 68000 suite into build/deps/680x0/.
#
#   tests/fetch.sh
#
# **Downloaded, never committed or shipped**: the suite declares no licence, so it is used
# only as test input on a developer's machine. Pinned to one commit — a tarball of a commit
# is fixed content — and fetched once; a second run finds it and does nothing. About 200 MB.
set -euo pipefail

readonly COMMIT="e0d5ece9670205cc84a0101081837deb446f86a3"
readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DEST="$ROOT/build/deps/680x0"

if [ -f "$DEST/COMMIT" ] && [ "$(cat "$DEST/COMMIT")" = "$COMMIT" ]; then
  exit 0
fi

rm -rf "$DEST"
mkdir -p "$DEST"
tarball="$DEST/680x0.tar.gz"
curl -fsSL --retry 2 -o "$tarball" "https://github.com/SingleStepTests/680x0/archive/$COMMIT.tar.gz"
tar -xzf "$tarball" -C "$DEST" --strip-components=1 "680x0-$COMMIT/68000/v1"
rm -f "$tarball"
printf '%s' "$COMMIT" >"$DEST/COMMIT"
printf 'fetched %s test files into %s\n' "$(ls "$DEST/68000/v1" | wc -l | tr -d ' ')" "$DEST/68000/v1"
