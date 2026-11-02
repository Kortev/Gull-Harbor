#!/bin/sh
# The clip to show the game off (tests/promo_shot.gd): recorded by Godot's movie maker in a tall window, then
# trimmed, doubled up nearest-neighbour to 1080x1920, the name laid over the end (tools/promo_title.py), and put
# together as an mp4 with its sound.
#   tools/promo.sh <out.mp4>    (needs a window; ffmpeg from `pip install imageio-ffmpeg`)
set -e
OUT=${1:-export/bluefin_clip.mp4}
G=${GODOT:-/c/Users/gamek/Downloads/godot-4.7.2/Godot_v4.7.2-stable_win64.exe}
FF=$(python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
DIR=$(mktemp -d)
cd "$(dirname "$0")/.."
# (the movie maker opens the project's window and holds it: tall for this run only)
printf '[display]\n\nwindow/size/viewport_width=540\nwindow/size/viewport_height=960\n' > override.cfg
trap 'rm -f override.cfg; rm -rf "$DIR"' EXIT
"$G" --path . --fixed-fps 30 --write-movie "$(cygpath -w "$DIR")\\f.png" res://tests/promo_shot.tscn > "$DIR/log.txt" 2>&1
rm -f override.cfg
python tools/promo_title.py "$DIR/title.png"
# (the first 10 s are her getting up to speed: tests/promo_shot.gd's LENGTH after that)
"$FF" -y -loglevel error -framerate 30 -start_number 300 -i "$DIR/f%08d.png" -ss 10 -i "$DIR/f.wav" \
	-loop 1 -framerate 30 -i "$DIR/title.png" -frames:v 420 \
	-filter_complex "[0]scale=1080:1920:flags=neighbor[v];[2]format=rgba,fade=t=in:st=10.6:d=0.8:alpha=1[t];[v][t]overlay=shortest=1,fade=t=in:st=0:d=0.4,fade=t=out:st=13.4:d=0.6[o]" \
	-map "[o]" -map 1:a -af "afade=t=in:st=0:d=0.4,afade=t=out:st=13.2:d=0.8" -t 14 \
	-c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart "$OUT"
echo "CLIP $OUT"
