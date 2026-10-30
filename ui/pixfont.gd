extends RefCounted
## The game's one typeface: a tiny 3 x 5 pixel font, to sit with the pixel look. Digits, capitals (lower case is
## drawn as capitals) and the marks the game's words use. Drawn two ways: as whole pixels straight onto a CanvasItem
## (draw(): the dash screens, the title), and as a Font (font(): every Label, Button and draw_string in the game,
## sea/sea.gd makes it the default), always at a whole multiple of its size so the pixels stay square.

const GLYPHS := {
	"0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["##.", "..#", ".#.", "#..", "###"], "3": ["##.", "..#", ".#.", "..#", "##."],
	"4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "##.", "..#", "##."],
	"6": [".##", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "##."],
	"A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
	"C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
	"E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
	"G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
	"I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", ".#."],
	"K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
	"M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
	"O": [".#.", "#.#", "#.#", "#.#", ".#."], "P": ["##.", "#.#", "##.", "#..", "#.."],
	"Q": [".#.", "#.#", "#.#", "##.", ".##"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
	"S": [".##", "#..", ".#.", "..#", "##."], "T": ["###", ".#.", ".#.", ".#.", ".#."],
	"U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
	"W": ["#.#", "#.#", "###", "###", "#.#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
	"Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
	".": ["...", "...", "...", "...", ".#."], "-": ["...", "...", "###", "...", "..."],
	":": ["...", ".#.", "...", ".#.", "..."], "/": ["..#", "..#", ".#.", "#..", "#.."],
	"°": ["##.", "##.", "...", "...", "..."], " ": ["...", "...", "...", "...", "..."],
	",": ["...", "...", "...", ".#.", "#.."], "!": [".#.", ".#.", ".#.", "...", ".#."],
	"?": ["##.", "..#", ".#.", "...", ".#."], "'": [".#.", ".#.", "...", "...", "..."],
	"(": [".#.", "#..", "#..", "#..", ".#."], ")": [".#.", "..#", "..#", "..#", ".#."],
	"+": ["...", ".#.", "###", ".#.", "..."], "_": ["...", "...", "...", "...", "###"],
	"&": [".#.", "#.#", ".#.", "#.#", ".##"], "$": [".##", "##.", ".#.", ".##", "##."],
	"%": ["#.#", "..#", ".#.", "#..", "#.#"], "#": ["#.#", "###", "#.#", "###", "#.#"],
	"*": ["...", "#.#", ".#.", "#.#", "..."], "=": ["...", "###", "...", "###", "..."],
	"<": ["..#", ".#.", "#..", ".#.", "..#"], ">": ["#..", ".#.", "..#", ".#.", "#.."],
	"\"": ["#.#", "#.#", "...", "...", "..."], ";": ["...", ".#.", "...", ".#.", "#.."],
	"·": ["...", "...", ".#.", "...", "..."], "[": ["##.", "#..", "#..", "#..", "##."],
	"]": [".##", "..#", "..#", "..#", ".##"],
}


static var _font: FontFile


## The font itself (see above): 6 px a line (5 up, 1 down), 4 px a letter, scaled only by whole numbers.
static func font() -> FontFile:
	if _font != null:
		return _font
	var keys := GLYPHS.keys()
	var img := Image.create(keys.size() * 4, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for i in keys.size():
		var g: Array = GLYPHS[keys[i]]
		for r in 5:
			for cx in 3:
				if (g[r] as String)[cx] == "#":
					img.set_pixel(i * 4 + cx, r, Color(1, 1, 1, 1))
	var f := FontFile.new()
	f.fixed_size = 6
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	var sz := Vector2i(6, 0)
	f.set_cache_ascent(0, 6, 5.0)
	f.set_cache_descent(0, 6, 1.0)
	f.set_texture_image(0, sz, 0, img)
	for i in keys.size():
		var ch: String = keys[i]
		var codes := [ch.unicode_at(0)]
		if ch.to_lower() != ch:
			codes.append(ch.to_lower().unicode_at(0))
		for code: int in codes:
			f.set_glyph_advance(0, 6, code, Vector2(4, 0))
			f.set_glyph_offset(0, sz, code, Vector2(0, -5))
			f.set_glyph_size(0, sz, code, Vector2(3, 5))
			f.set_glyph_uv_rect(0, sz, code, Rect2(i * 4, 0, 3, 5))
			f.set_glyph_texture_idx(0, sz, code, 0)
	_font = f
	return f


## How wide `text` is (px) at `scale`.
static func width(text: String, scale: int = 1) -> int:
	return maxi(text.length() * 4 - 1, 0) * scale


## Draws `text` with its top left at `at`, each font pixel `scale` px.
static func draw(ci: CanvasItem, at: Vector2, text: String, color: Color, scale: int = 1) -> void:
	var x := floorf(at.x)
	var y := floorf(at.y)
	for ch in text.to_upper():
		var g: Array = GLYPHS.get(ch, GLYPHS[" "])
		for r in 5:
			var row: String = g[r]
			for cx in 3:
				if row[cx] == "#":
					ci.draw_rect(Rect2(x + cx * scale, y + r * scale, scale, scale), color)
		x += 4 * scale
