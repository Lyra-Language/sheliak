#!/usr/bin/env bash
#
# Check Sheliak's VDP against BlastEm: every test ROM (src/vdproms.lyra) is run on both,
# to its parking loop, and the VDP's memories, registers, address and code registers, the
# start of work RAM and the frame are compared — a timing ROM's H counters within the slack
# its `.hslack` gives (tests/ram_compare.py).
#
#   tests/vdp.sh               # every ROM
#   tests/vdp.sh fill copy     # just these
#
# **BlastEm is the oracle, downloaded and built here, never committed or shipped**: GPLv3,
# so it is run as a separate program, the way the 68000 suite is downloaded as data. Pinned
# to one revision, built once into build/deps/blastem/. Needs a C compiler, make, python3,
# pkg-config and SDL2 (`brew install sdl2`). tests/blastem_patches.py patches two things,
# neither of them emulated: a line the no-OpenGL build cannot compile, and a `screenshot`
# debugger command. It runs off-screen on SDL's dummy drivers, with a scratch HOME so it writes no
# configuration of yours, driven through its debugger (`-t -d`, commands on stdin).
set -euo pipefail

readonly REVISION="9b71c8bd20654e8ac27b457fa55a8bc3b1d9446f"
# Bumped whenever tests/blastem_patches.py changes, so a cached build is rebuilt with it.
readonly PATCHES="4"
readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DEPS="$ROOT/build/deps/blastem"
readonly BLASTEM="$DEPS/blastem-$REVISION/blastem"
readonly WORK="$ROOT/build/vdp"

fetch_blastem() {
  if [ -x "$BLASTEM" ] && [ "$(cat "$DEPS/REVISION" 2>/dev/null)" = "$REVISION.$PATCHES" ]; then
    return
  fi
  rm -rf "$DEPS"
  mkdir -p "$DEPS"
  curl -fsSL --retry 2 -o "$DEPS/blastem.tar.gz" \
    "https://www.retrodev.com/repos/blastem/archive/$REVISION.tar.gz"
  tar -xzf "$DEPS/blastem.tar.gz" -C "$DEPS"
  rm -f "$DEPS/blastem.tar.gz"
  python3 "$ROOT/tests/blastem_patches.py" "$DEPS/blastem-$REVISION"
  echo "building BlastEm $REVISION (once; a few minutes)"
  (cd "$DEPS/blastem-$REVISION" && make NOGL=1 LIBS=sdl2 blastem -j8 >"$DEPS/build.log" 2>&1) ||
    { tail -20 "$DEPS/build.log"; exit 1; }
  printf '%s' "$REVISION.$PATCHES" >"$DEPS/REVISION"
}

# Run ROM on BlastEm to PARK, then two frames more — the program is parked, so nothing new is
# written, and whatever the VDP still had in hand (its FIFO, a DMA running in the access
# slots) completes — saving the settled state into OUT, and the next frame. vdpcheck runs
# Sheliak the same three frames past PARK; how long things took is the timing ROMs' to
# record, in work RAM.
run_blastem() {
  local rom="$1" park="$2" out="$3"
  mkdir -p "$out"
  cat >"$out/script.txt" <<EOF
advance 0x$park
frames 2
save/b "$out/vram.bin" vdp:vram
save/w "$out/cram.le" vdp:cram
save/w "$out/vsram.le" vdp:vsram
save/b "$out/regs.bin" vdp:reg
save/b "$out/ram.bin" [0xFF0000] 256
print vdp:address
print vdp:cd
screenshot "$out/frame.ppm"
frames 1
quit
EOF
  SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy HOME="$WORK/home" \
    "$BLASTEM" -t -d "$rom" <"$out/script.txt" >"$out/stdout.txt" 2>&1 &
  local pid=$!
  { sleep 30; kill "$pid"; } 2>/dev/null &
  local watchdog=$!
  wait "$pid" || { echo "  BlastEm failed on $(basename "$rom")"; return 1; }
  kill "$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  # `save/w` writes host-order (little-endian) words; Sheliak dumps big-endian.
  python3 - "$out" <<'EOF'
import sys
out = sys.argv[1]
for name in ("cram", "vsram"):
    data = open(f"{out}/{name}.le", "rb").read()
    open(f"{out}/{name}.bin", "wb").write(bytes(b for i in range(0, len(data), 2) for b in (data[i + 1], data[i])))
EOF
  local address cd
  address="$(sed -n 's/.*vdp:address: \([0-9]*\).*/\1/p' "$out/stdout.txt")"
  cd="$(sed -n 's/.*vdp:cd: \([0-9]*\).*/\1/p' "$out/stdout.txt")"
  printf 'address %s\ncd %s\n' "$address" "$cd" >"$out/state.txt"
}

# BlastEm's configuration in the scratch home: its defaults, with the NTSC overscan set to
# hide the border entirely (the values its own default.cfg suggests for that), so a
# screenshot is exactly the 320x224 active display. Its pads are left at its default,
# 6-button in both ports, as Sheliak's are.
configure_blastem() {
  local dir="$WORK/home/.config/blastem"
  mkdir -p "$dir"
  python3 - "$DEPS/blastem-$REVISION/default.cfg" "$dir/blastem.cfg" <<'EOF'
import sys
source = open(sys.argv[1]).read()
old = "\t\t\ttop 2\n\t\t\tbottom 1\n"
assert source.count(old) >= 1, "default.cfg changed; revisit the overscan override"
source = source.replace(old, "\t\t\ttop 11\n\t\t\tbottom 8\n", 1)
assert "\t\t1 gamepad6.1\n\t\t2 gamepad6.2\n" in source, "default.cfg's pads changed"
open(sys.argv[2], "w").write(source)
EOF
}

fetch_blastem
configure_blastem
"$ROOT/build.sh"
"$ROOT/build/vdproms" "$WORK/roms" >/dev/null

if [ $# -gt 0 ]; then names=("$@"); else
  names=()
  for rom in "$WORK/roms"/*.bin; do names+=("$(basename "$rom" .bin)"); done
fi

failed=0
for name in "${names[@]}"; do
  rom="$WORK/roms/$name.bin"
  park="$(cat "$WORK/roms/$name.park")"
  rm -rf "$WORK/blastem/$name" "$WORK/sheliak/$name"
  # BlastEm keeps save RAM between runs, in its home; each run starts with none.
  rm -rf "$WORK/home/.local/share/blastem"
  run_blastem "$rom" "$park" "$WORK/blastem/$name" || { failed=$((failed + 1)); continue; }
  "$ROOT/build/vdpcheck" "$rom" "$park" "$WORK/sheliak/$name" || { failed=$((failed + 1)); continue; }
  differs=()
  for file in vram.bin cram.bin vsram.bin regs.bin state.txt; do
    cmp -s "$WORK/blastem/$name/$file" "$WORK/sheliak/$name/$file" || differs+=("$file")
  done
  # A timing ROM's H counters are compared within its slack (tests/ram_compare.py).
  slack=()
  [ -f "$WORK/roms/$name.hslack" ] && slack=("$(cat "$WORK/roms/$name.hslack")")
  "$ROOT/tests/ram_compare.py" "$WORK/sheliak/$name/ram.bin" "$WORK/blastem/$name/ram.bin" ${slack[@]+"${slack[@]}"} \
    >"$WORK/sheliak/$name/ram.txt" || differs+=("ram.bin")
  # register_bits sets V30 on an NTSC console, a mode no NTSC display shows; its frame is
  # not compared.
  if [ "$name" != register_bits ] && ! "$ROOT/tests/frame_compare.py" "$WORK/sheliak/$name/frame.bin" "$WORK/blastem/$name/frame.ppm" \
    >"$WORK/sheliak/$name/frame.txt"; then
    differs+=("frame")
  fi
  # The front end's picture: the texels it sends to the window, after 30 frames from power
  # on (every ROM has parked by then and shows its settled frame), byte for byte against
  # BlastEm's screenshot — the colour conversion is the front end's own.
  if [ "$name" != register_bits ]; then
    SDL_VIDEODRIVER=dummy "$ROOT/build/sheliak" "$rom" --frames 30 --ppm "$WORK/sheliak/$name/window.ppm" \
      >/dev/null && cmp -s "$WORK/sheliak/$name/window.ppm" "$WORK/blastem/$name/frame.ppm" || differs+=("window")
  fi
  if [ ${#differs[@]} -eq 0 ]; then
    echo "$name: matches"
  else
    echo "$name: differs in ${differs[*]}"
    cat "$WORK/sheliak/$name/frame.txt" "$WORK/sheliak/$name/ram.txt" 2>/dev/null | sed 's/^/    /' 
    failed=$((failed + 1))
  fi
done
echo "vdp: $((${#names[@]} - failed)) of ${#names[@]} match BlastEm"
[ "$failed" -eq 0 ]
