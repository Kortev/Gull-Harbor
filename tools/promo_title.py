"""The clip's name card (tools/promo.sh): BLUEFIN in the game's pixel font (ui/pixfont.gd's glyphs), small and low,
on a clear 1080x1920 frame to lay over the video."""
import re
import sys
from PIL import Image, ImageDraw

out = sys.argv[1]
src = open("ui/pixfont.gd", encoding="utf-8").read()
glyphs = {k: v.split('", "') for k, v in re.findall(r'"(.)": \["([^\]]*)"\]', src)}
text, s = "BLUEFIN", 14
w, h = (len(text) * 4 - 1) * s, 5 * s
im = Image.new("RGBA", (1080, 1920), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
x0, y0 = (1080 - w) // 2, int(1920 * 0.80)
for off, col in (((s // 2, s // 2), (0, 0, 0, 130)), ((0, 0), (255, 247, 230, 255))):
    x = x0 + off[0]
    for ch in text:
        for r, row in enumerate(glyphs[ch]):
            for c, p in enumerate(row.strip('"')):
                if p == "#":
                    d.rectangle([x + c * s, y0 + off[1] + r * s, x + c * s + s - 1, y0 + off[1] + r * s + s - 1], fill=col)
        x += 4 * s
im.save(out)
