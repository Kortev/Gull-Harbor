#!/bin/sh
# The music's demo reel as a video (tests/play_shot.gd's demo part): the game played by the QA bot from the title,
# through each weather's song, to a whole fish landed, the music panel on (-- --music-hud) and a caption for each
# part. Recorded by Godot's movie maker (an .avi: its frames and everything heard), then made an mp4 with a chapter
# for each caption (the bot's "DEMO <s> <caption>" lines).
#   tools/music_demo.sh [out.mp4]      (needs a window, for as long as the reel runs: about 15 minutes)
set -e
OUT=${1:-export/music_demo.mp4}
G=${GODOT:-/c/Users/gamek/Downloads/godot-4.7.2/Godot_v4.7.2-stable_win64.exe}
FF=$(command -v ffmpeg || python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
DIR=$(mktemp -d)
cd "$(dirname "$0")/.."
trap 'rm -rf "$DIR"' EXIT
mkdir -p "$DIR/shots" "$(dirname "$OUT")"
# (--shot-demo: the pause card never comes up, even with the window in the background)
"$G" --path . --resolution 1280x720 --fixed-fps 30 --write-movie "$(cygpath -w "$DIR")\\reel.avi" \
	res://tests/play_shot.tscn -- --part=demo --music-hud --shot-demo --out="$(cygpath -w "$DIR/shots")" \
	> "$DIR/log.txt" 2>&1 || true
grep -E "^(ok|FAIL|DEMO|PLAY)" "$DIR/log.txt" || true
# the chapters: each caption from its time to the next's
python - "$DIR/log.txt" "$DIR/chapters.txt" <<'EOF'
import sys
marks = []
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    if line.startswith("DEMO "):
        _, s, text = line.rstrip("\n").split(" ", 2)
        marks.append((int(float(s) * 1000), text.strip()))
with open(sys.argv[2], "w", encoding="utf-8") as f:
    f.write(";FFMETADATA1\ntitle=Bluefin: the music\n")
    for i, (ms, text) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else ms + 60000
        f.write("[CHAPTER]\nTIMEBASE=1/1000\nSTART=%d\nEND=%d\ntitle=%s\n" % (ms, end, text))
EOF
"$FF" -y -loglevel error -i "$DIR/reel.avi" -i "$DIR/chapters.txt" -map 0 -map_metadata 1 -map_chapters 1 \
	-c:v libx264 -preset slow -crf 26 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart "$OUT"
cp "$DIR/log.txt" "${OUT%.mp4}.log"
echo "DEMO $OUT"
