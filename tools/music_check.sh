#!/bin/sh
# The music on the real sound card, at the real pace (tests/music_live_test.tscn: a small window opens for half a
# minute): the song heard, the strike heard at once and running on into the fight, the flourish, the song again,
# never silent where it's meant to play. Every other music test runs headless (tests/music_*test.tscn).
#   tools/music_check.sh            (GODOT: the editor binary)
#   tools/music_check.sh --render   the music as it leaves the mixer instead: a scripted trip recorded by the movie
#                                   maker (tests/music_render.tscn, a small window for two or three minutes) and
#                                   measured (tools/music_render.py): levels, clicks, clipping, silences, the fight
#                                   over the song, the strike a step up. Needs imageio-ffmpeg (or ffmpeg).
set -e
G=${GODOT:-/c/Users/gamek/Downloads/godot-4.7.2/Godot_v4.7.2-stable_win64.exe}
cd "$(dirname "$0")/.."
if [ "$1" = "--render" ]; then
	FF=$(command -v ffmpeg || python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
	DIR=$(mktemp -d)
	trap 'rm -rf "$DIR"' EXIT
	"$G" --path . --resolution 160x90 --fixed-fps 30 --write-movie "$(cygpath -w "$DIR")\music.avi" \
		res://tests/music_render.tscn > "$DIR/log.txt" 2>&1 || true
	"$FF" -y -loglevel error -i "$DIR/music.avi" -vn "$DIR/music.wav"
	python tools/music_render.py "$DIR/music.wav" "$DIR/log.txt"
	exit $?
fi
OUT=$(mktemp)
"$G" --path . --resolution 160x90 res://tests/music_live_test.tscn > "$OUT" 2>&1 || { grep -E "^(ok|FAIL)" "$OUT"; exit 1; }
grep -E "^(ok|FAIL)" "$OUT"
