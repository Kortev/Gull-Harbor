#!/bin/sh
# The music on the real sound card, at the real pace (tests/music_live_test.tscn: a small window opens for half a
# minute): the song heard, the strike heard at once and running on into the fight, the flourish, the song again,
# never silent where it's meant to play. Every other music test runs headless (tests/music_*test.tscn).
#   tools/music_check.sh      (GODOT: the editor binary)
set -e
G=${GODOT:-/c/Users/gamek/Downloads/godot-4.7.2/Godot_v4.7.2-stable_win64.exe}
cd "$(dirname "$0")/.."
OUT=$(mktemp)
"$G" --path . --resolution 160x90 res://tests/music_live_test.tscn > "$OUT" 2>&1 || { grep -E "^(ok|FAIL)" "$OUT"; exit 1; }
grep -E "^(ok|FAIL)" "$OUT"
