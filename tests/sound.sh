#!/usr/bin/env bash
#
# The whole sound path, end to end: a note from each chip — played by a test ROM
# (src/vdproms.lyra's sound_fm and sound_psg), run headless through the front end, mixed
# and resampled to its WAV — at the pitch the registers ask for, and audible.
#
#   tests/sound.sh
#
# The chips themselves are held bit for bit to their oracles by tests/ym.sh and
# tests/psg.sh; this checks what the front end makes of them.
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly WORK="$ROOT/build/sound"
mkdir -p "$WORK"
"$ROOT/build.sh" >/dev/null
"$ROOT/build/vdproms" "$WORK/roms" >/dev/null

status=0
for case in "sound_fm 250.7" "sound_psg 440.4"; do
  set -- $case
  SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy "$ROOT/build/sheliak" "$WORK/roms/$1.bin" \
    --frames 150 --wav "$WORK/$1.wav" >/dev/null
  "$ROOT/tests/wav_pitch.py" "$WORK/$1.wav" "$2" || status=1
done
exit "$status"
