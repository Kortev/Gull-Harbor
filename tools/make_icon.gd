extends SceneTree
## The game's icon: a bluefin in chunky pixels on a square of deep water, drawn here pixel by pixel at 32 x 32 (and
## at 16 x 16 for the smallest sizes, so they stay readable), only ever scaled by whole numbers, nearest.
## Writes:
##   icon.svg               the project's icon (config/icon): the 32 grid as squares, crisp at any size
##   icon.ico               the exe's (export_presets.cfg application/icon): 16 (the 16 grid), 32 (the 32), 48
##                          (16 x 3), 64, 128 and 256 (32 x 2, 4, 8): every size Godot's exporter asks for
##   art/icon/icon_*.png    16 and 48 (the 16 grid), 32, 64, 256, 512 and 1024 px, for Steam's pages and the like
## Run: godot --headless --path . --script res://tools/make_icon.gd

const SEA_TOP := Color("0a1a30")
const SEA_LOW := Color("12385c")
const SURF := Color("1d5a82")
const FOAM := Color("6fa7c4")
const RIM := Color("050c17")
const INK := Color("060b16")
const BACK := Color("16336a")
const STEEL := Color("2f62a3")
const SILVER := Color("a9bccb")
const BELLY := Color("eef3f6")
const GILL := Color("7d93a6")
const FINLET := Color("f4c542")
const FIN := Color("24406e")
const EYE := Color("f6f2e4")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/icon"))
	var big := draw(32)
	var small := draw(16)
	for px: int in [32, 64, 256, 512, 1024]:
		scaled(big, px / 32).save_png("res://art/icon/icon_%d.png" % px)
	small.save_png("res://art/icon/icon_16.png")
	scaled(small, 3).save_png("res://art/icon/icon_48.png")
	_write_svg(big, "res://icon.svg")
	_write_ico([small, big, scaled(small, 3), scaled(big, 2), scaled(big, 4), scaled(big, 8)], "res://icon.ico")
	print("make_icon: icon.svg, icon.ico, art/icon/icon_*.png")
	quit()


## The icon at n x n pixels (n is 16 or 32).
static func draw(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fish := {}       # Vector2i -> colour, before its outline
	var f := float(n)
	# the water: a square with its corners knocked off, dark above, lighter toward the surface low down, a rim
	var cut := 2 if n >= 32 else 1
	for y in n:
		for x in n:
			var cx := mini(x, n - 1 - x)
			var cy := mini(y, n - 1 - y)
			if cx + cy < cut:
				continue
			var edge := cx == 0 or cy == 0 or cx + cy == cut
			var band := floorf(float(y) / f * 5.0) / 4.0
			var c := SEA_TOP.lerp(SEA_LOW, band)
			img.set_pixel(x, y, RIM if edge else c)
	# a line of swell low down, with a fleck or two of foam
	var sy := int(f * 0.81)
	for x in range(1, n - 1):
		var up := int(round(sin(float(x) / f * TAU * 2.0) * f / 64.0))
		for y in range(sy + up, n - 1):
			if img.get_pixel(x, y) != RIM:
				img.set_pixel(x, y, SURF)
		if (x * 7) % 11 == 0 and n >= 32:
			img.set_pixel(x, sy + up, FOAM)
	# the body: a torpedo, deepest a third of the way back, the back fuller than the belly
	var nose := 0.06
	var root := 0.70
	var mid := 0.45
	for y in n:
		for x in n:
			var u := (x + 0.5) / f
			var v := (y + 0.5) / f
			if u < nose or u > root + 0.04:
				continue
			var t := clampf((u - nose) / (root - nose), 0.0, 1.0)
			var k := pow(sin(PI * pow(t, 0.72)), 0.8)
			k = maxf(k, 0.18 if t > 0.5 else 0.0)
			var top := mid - 0.19 * k
			var bot := mid + 0.15 * k
			if v < top or v > bot:
				continue
			var rel := (v - top) / maxf(bot - top, 0.001)
			var c := BACK if rel < 0.3 else (STEEL if rel < 0.45 else (SILVER if rel < 0.72 else BELLY))
			fish[Vector2i(x, y)] = c
	# the tail: a crescent, its two lobes swept back from a thin stalk
	for y in n:
		for x in n:
			var u := (x + 0.5) / f
			var v := (y + 0.5) / f
			if u < root or u > 0.9:
				continue
			var w := (u - root) / (0.9 - root)
			var dv := v - mid
			var outer := 0.04 + 0.22 * pow(w, 0.7)
			var inner := 0.02 + 0.22 * pow(w, 1.9)
			if absf(dv) <= outer and (absf(dv) >= inner or w < 0.35):
				fish[Vector2i(x, y)] = BACK if dv < 0.0 else FIN
	# the first dorsal fin, and the pectoral lying back along her side
	for y in n:
		for x in n:
			var u := (x + 0.5) / f
			var v := (y + 0.5) / f
			var a := (u - 0.33) / 0.14
			if a >= 0.0 and a <= 1.0 and v < mid - 0.17 and v > mid - 0.17 - 0.1 * (1.0 - a):
				fish[Vector2i(x, y)] = FIN
			var b := (u - 0.27) / 0.16
			if n >= 32 and b >= 0.0 and b <= 1.0 and absf(v - (mid + 0.01 + 0.03 * b)) < 0.025 * (1.0 - b) + 0.012:
				fish[Vector2i(x, y)] = FIN
	# the finlets, yellow, along her back and belly toward the tail
	for x in range(int(f * 0.53), int(f * root) + 1, 2):
		var col := _column(fish, x)
		if col.x >= 0:
			fish[Vector2i(x, col.x - 1)] = FINLET
			fish[Vector2i(x, col.y + 1)] = FINLET
	# the gill line, and the eye
	if n >= 32:
		var gx := int(f * 0.25)
		var col := _column(fish, gx)
		for y in range(col.x + 3, col.y - 1):
			if fish.get(Vector2i(gx, y), BACK) != BELLY:
				fish[Vector2i(gx, y)] = GILL
	var ex := int(f * 0.16)
	var ey := int(f * (mid - 0.05))
	fish[Vector2i(ex, ey)] = EYE
	if n >= 32:
		fish[Vector2i(ex + 1, ey)] = EYE
		fish[Vector2i(ex, ey + 1)] = EYE
		fish[Vector2i(ex + 1, ey + 1)] = INK
	else:
		fish[Vector2i(ex, ey)] = BELLY
	# onto the water, with a dark outline round all of it
	for p: Vector2i in fish:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if not fish.has(q) and q.x >= 0 and q.y >= 0 and q.x < n and q.y < n:
				img.set_pixelv(q, INK)
	for p: Vector2i in fish:
		img.set_pixelv(p, fish[p])
	return img


## The top and bottom of the fish in column x (-1, -1: none of her there).
static func _column(fish: Dictionary, x: int) -> Vector2i:
	var lo := 1 << 20
	var hi := -1
	for p: Vector2i in fish:
		if p.x == x and fish[p] != FINLET:
			lo = mini(lo, p.y)
			hi = maxi(hi, p.y)
	return Vector2i(lo, hi) if hi >= 0 else Vector2i(-1, -1)


static func scaled(img: Image, by: int) -> Image:
	var out := img.duplicate() as Image
	out.resize(img.get_width() * by, img.get_height() * by, Image.INTERPOLATE_NEAREST)
	return out


## The image as an SVG of squares, a row's runs of one colour as one rect, 4 units a pixel (128 x 128).
static func _write_svg(img: Image, path: String) -> void:
	var n := img.get_width()
	var s := PackedStringArray()
	s.append('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 %d %d" '
			% [n, n] + 'shape-rendering="crispEdges">')
	for y in n:
		var x := 0
		while x < n:
			var c := img.get_pixel(x, y)
			var run := 1
			while x + run < n and img.get_pixel(x + run, y) == c:
				run += 1
			if c.a > 0.0:
				s.append('<rect x="%d" y="%d" width="%d" height="1" fill="#%s"/>' % [x, y, run, c.to_html(false)])
			x += run
	s.append("</svg>")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(s) + "\n")
	f.close()


## A Windows .ico: the small ones as 32-bit bitmaps (every Windows reads those), 256 as a PNG.
static func _write_ico(imgs: Array, path: String) -> void:
	var blobs: Array[PackedByteArray] = []
	for img: Image in imgs:
		blobs.append(img.save_png_to_buffer() if img.get_width() >= 256 else _dib(img))
	var out := PackedByteArray()
	out.append_array(_u16(0) + _u16(1) + _u16(imgs.size()))
	var offset := 6 + 16 * imgs.size()
	for i in imgs.size():
		var w: int = (imgs[i] as Image).get_width()
		out.append_array(PackedByteArray([w % 256, w % 256, 0, 0]))
		out.append_array(_u16(1) + _u16(32) + _u32(blobs[i].size()) + _u32(offset))
		offset += blobs[i].size()
	for b in blobs:
		out.append_array(b)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(out)
	f.close()


## An icon's bitmap: BITMAPINFOHEADER (twice the height: the colours, then the mask), BGRA rows bottom up, then the
## 1-bit AND mask (rows padded to 4 bytes), set where it's see-through.
static func _dib(img: Image) -> PackedByteArray:
	var w := img.get_width()
	var h := img.get_height()
	var b := PackedByteArray()
	b.append_array(_u32(40) + _u32(w) + _u32(h * 2) + _u16(1) + _u16(32) + _u32(0) + _u32(0) + _u32(0) + _u32(0)
			+ _u32(0) + _u32(0))
	for y in range(h - 1, -1, -1):
		for x in w:
			var c := img.get_pixel(x, y)
			b.append_array(PackedByteArray([c.b8, c.g8, c.r8, c.a8]))
	var row := ((w + 31) / 32) * 4
	for y in range(h - 1, -1, -1):
		var bits := PackedByteArray()
		bits.resize(row)
		bits.fill(0)
		for x in w:
			if img.get_pixel(x, y).a8 < 128:
				bits[x / 8] |= 0x80 >> (x % 8)
		b.append_array(bits)
	return b


static func _u16(v: int) -> PackedByteArray:
	return PackedByteArray([v & 255, (v >> 8) & 255])


static func _u32(v: int) -> PackedByteArray:
	return PackedByteArray([v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255])
