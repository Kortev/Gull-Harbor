#!/bin/sh
# The music through the real mixer (tests/music_render.tscn under the movie maker: a window opens for a minute or
# two), then checked by ear (tools/music_check.py): on the grid, in step, no clicks, the hush; then the song on the
# real sound card through a stalled frame (tests/music_stall_test.tscn).
#   tools/music_check.sh [dir]   (GODOT: the editor binary)
set -e
G=${GODOT:-/c/Users/gamek/Downloads/godot-4.7.2/Godot_v4.7.2-stable_win64.exe}
DIR=${1:-$(mktemp -d)}
mkdir -p "$DIR"
cd "$(dirname "$0")/.."
W=$(cygpath -w "$DIR" 2>/dev/null || echo "$DIR")
"$G" --path . --fixed-fps 30 --resolution 160x90 --write-movie "$W/f.png" res://tests/music_render.tscn \
	-- "--out=$W/f.json" > "$DIR/log.txt" 2>&1
rm -f "$DIR"/f*.png
python tools/music_check.py "$DIR"
# and the real sound card's own clock (the movie maker's isn't it): a stalled frame, the bed stopped
"$G" --path . --resolution 160x90 res://tests/music_stall_test.tscn > "$DIR/stall.txt" 2>&1 || { grep -E "^(ok|FAIL)" "$DIR/stall.txt"; exit 1; }
grep -E "^(ok|FAIL)" "$DIR/stall.txt"
