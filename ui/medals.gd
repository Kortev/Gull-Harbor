extends RefCounted
## The achievements' medals (core/achievements.gd's LIST): each a 32 x 32 picture on a little enamel plaque with a gold
## rim, drawn here pixel by pixel (the same in the game and in tools/make_medals.gd, which writes them out for Steam),
## only ever scaled by whole numbers, nearest. Locked: the same picture, greyed and sunk. A secret one (SECRET), locked,
## is a "?" on a grey plaque. The plaque's colour says what kind: the sea's blue, the money's green, Rivals' red.

const PixFont := preload("res://ui/pixfont.gd")

const N := 32
const RIM := Color("050c17")
const INK := Color("060b16")
const GOLD := Color("f4c542")
const GOLD_D := Color("a8701c")
const CREAM := Color("fff2d1")
const STEEL := Color("9fb3c4")
const STEEL_D := Color("5d7286")
const WOOD := Color("8a5a2b")
const RED := Color("d8432e")
const SKIN := Color("e3ad7f")
const OILSKIN := Color("f2c230")
const RAIN := Color(0.62, 0.78, 0.92, 0.85)
const WATER := Color("2f78a8")
const FOAM := Color("8fc4dc")
## A tuna's colours (tools/make_icon.gd's).
const BACK := Color("16336a")
const SIDE := Color("2f62a3")
const SILVER := Color("a9bccb")
const BELLY := Color("eef3f6")
const FINLET := Color("f4c542")
const FIN := Color("24406e")
## The boats' colours in Rivals (vs/card.gd's).
const TEAM := [Color(1.0, 0.74, 0.32), Color(0.45, 0.8, 1.0)]
## The plaque behind, by kind: [top, bottom].
const GROUNDS := {"sea": [Color("0b2240"), Color("1d5a82")], "money": [Color("0d2a1b"), Color("2b6a3d")],
		"rivals": [Color("33100f"), Color("7a2a20")], "night": [Color("04071a"), Color("162254")],
		"storm": [Color("151a22"), Color("3a4552")], "secret": [Color("1b1f25"), Color("343b44")]}
const KIND := {"FIRST_FISH": "sea", "GIANT": "sea", "ONE_THROW": "sea", "GRADE_ONE": "money", "TON": "money",
		"QUOTA": "money", "THREE_QUOTAS": "money", "SPORTFISHER": "money", "LIVE_BAIT": "sea", "CREW": "sea",
		"NIGHT": "night", "STORM": "storm", "RIVALS_DAY": "rivals", "RIVALS_MATCH": "rivals", "BOARDED": "rivals",
		"OVERBOARD": "rivals"}
## Kept a surprise till earned: a "?" and no words.
const SECRET := ["NIGHT", "STORM"]

static var _cache := {}


## The medal as a texture (made once, kept).
static func texture(api: String, locked := false) -> ImageTexture:
	var key := api + ("/locked" if locked else "")
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(image(api, locked))
	return _cache[key]


## Let go of the textures made (the game's closing: nothing left held at exit).
static func forget() -> void:
	_cache.clear()


## The medal, 32 x 32.
static func image(api: String, locked := false) -> Image:
	var secret := locked and SECRET.has(api)
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_plaque(img, "secret" if secret else str(KIND.get(api, "sea")))
	var m := {}          # the picture: Vector2i -> colour, outlined in ink
	var loose := {}      # over it, no outline: rain, stars, the sea's lines, a glint
	if secret:
		_text(m, 11, 9, "?", CREAM.darkened(0.2), 3)
	else:
		_picture(api, m, loose)
	_stamp(img, m, loose)
	if locked:
		_grey(img)
	return img


## The plaque: a square with its corners cut, a dark rim, a gold bevel (lit top left), its colour darkening upward.
static func _plaque(img: Image, kind: String) -> void:
	var g: Array = GROUNDS[kind]
	for y in N:
		for x in N:
			var cx := mini(x, N - 1 - x)
			var cy := mini(y, N - 1 - y)
			if cx + cy < 3:
				continue
			var ring := mini(mini(cx, cy), cx + cy - 3)
			var c: Color
			if ring == 0:
				c = RIM
			elif ring == 1:
				c = GOLD if x + y < N - 1 else GOLD_D
				if kind == "secret":
					c = Color("6b7280") if x + y < N - 1 else Color("454b55")
			elif ring == 2:
				c = (g[0] as Color).darkened(0.45)
			else:
				c = (g[0] as Color).lerp(g[1], floorf(float(y) / N * 5.0) / 4.0)
			img.set_pixel(x, y, c)


static func _picture(api: String, m: Dictionary, loose: Dictionary) -> void:
	match api:
		"FIRST_FISH":
			_tuna(m, 5.0, 27.0, 15.0, 11.0)
			_water(loose, 24)
			_px(loose, 7, 7, CREAM)
			_px(loose, 24, 6, CREAM)
		"GIANT":
			# bigger than her plaque: nose and tail out over the rim
			_tuna(m, 0.0, 32.0, 16.0, 16.0)
			_text(loose, 11, 24, "300", CREAM, 1)
		"ONE_THROW":
			for r: Array in [[9.5, RED], [7.5, CREAM], [5.5, RED], [3.5, CREAM], [1.6, RED]]:
				_disc(m, 19.5, 12.5, float(r[0]), r[1])
			_line(m, Vector2i(5, 27), Vector2i(17, 15), WOOD, 2)
			_poly(m, PackedVector2Array([Vector2(16, 13), Vector2(23, 7), Vector2(19, 17)]), STEEL)
			_px(m, 16, 14, STEEL_D)
			_line(loose, Vector2i(4, 28), Vector2i(3, 22), CREAM)
			_line(loose, Vector2i(3, 22), Vector2i(6, 19), CREAM)
		"GRADE_ONE":
			_poly(m, PackedVector2Array([Vector2(7, 9), Vector2(22, 9), Vector2(27, 14), Vector2(27, 27),
					Vector2(7, 27)]), CREAM)
			_disc(m, 22.5, 13.5, 1.6, INK)
			_text(m, 9, 15, "#", RED, 1)
			_text(m, 14, 11, "1", RED, 3)
			_line(loose, Vector2i(23, 12), Vector2i(28, 4), GOLD)
		"TON":
			_poly(m, PackedVector2Array([Vector2(6, 28), Vector2(26, 28), Vector2(22.5, 13), Vector2(9.5, 13)]),
					Color("4a5560"))
			_line(m, Vector2i(10, 14), Vector2i(7, 27), Color("6d7a86"))
			_ring(m, 16.0, 10.0, 3.0, 5.6, Color("4a5560"))
			_text(m, 9, 16, "1000", CREAM, 1)
			_text(m, 13, 22, "KG", GOLD, 1)
		"QUOTA":
			_coin(m, loose, 16.0, 16.0, 10.5, true)
		"THREE_QUOTAS":
			_coin(m, loose, 10.5, 20.5, 6.5, false)
			_coin(m, loose, 21.5, 20.5, 6.5, false)
			_coin(m, loose, 16.0, 11.0, 6.5, false)
		"SPORTFISHER":
			_line(loose, Vector2i(18, 12), Vector2i(5, 4), STEEL)
			_line(loose, Vector2i(15, 13), Vector2i(15, 7), STEEL)
			_line(loose, Vector2i(22, 13), Vector2i(22, 7), STEEL)
			_box(m, 13, 5, 12, 2, CREAM)
			_box(m, 12, 13, 13, 4, CREAM)
			_box(m, 14, 14, 9, 1, Color("1b2a3a"))
			_poly(m, PackedVector2Array([Vector2(3, 16), Vector2(29, 17), Vector2(29, 22), Vector2(26, 24),
					Vector2(9, 24)]), CREAM)
			_line(m, Vector2i(6, 21), Vector2i(28, 21), Color("1f3f78"))
			_water(loose, 25)
		"LIVE_BAIT":
			_line(loose, Vector2i(9, 2), Vector2i(9, 10), STEEL)
			_mackerel(m, 5.0, 28.0, 18.0, 9.0)
			_line(m, Vector2i(9, 11), Vector2i(9, 15), STEEL)
			_line(m, Vector2i(7, 19), Vector2i(5, 17), STEEL)
		"CREW":
			_hand(m, 21.0, 0.8)
			_hand(m, 11.0, 1.0)
		"NIGHT":
			_disc(m, 19.0, 11.0, 7.0, CREAM)
			for p: Vector2i in m.keys():
				if Vector2(p.x + 0.5, p.y + 0.5).distance_to(Vector2(22.5, 8.5)) < 6.2:
					m.erase(p)
			for s: Vector2i in [Vector2i(6, 6), Vector2i(10, 12), Vector2i(26, 18), Vector2i(7, 17), Vector2i(25, 5)]:
				_px(loose, s.x, s.y, CREAM if s.x % 2 == 0 else GOLD)
			_tuna(m, 6.0, 22.0, 23.0, 6.0)
			_water(loose, 27)
		"STORM":
			for d: Array in [[10.0, 11.0, 5.0], [16.5, 8.5, 6.5], [23.0, 11.0, 5.0]]:
				_disc(m, float(d[0]), float(d[1]), float(d[2]), Color("59636f"))
			_box(m, 8, 11, 17, 5, Color("59636f"))
			_box(m, 9, 7, 6, 3, Color("737e8a"))
			_poly(m, PackedVector2Array([Vector2(18, 14), Vector2(12, 22), Vector2(16, 22), Vector2(13, 29),
					Vector2(22, 19), Vector2(18, 19), Vector2(21, 14)]), GOLD)
			for r: Vector2i in [Vector2i(6, 19), Vector2i(9, 24), Vector2i(24, 21), Vector2i(21, 26), Vector2i(27, 17)]:
				_px(loose, r.x, r.y, RAIN)
				_px(loose, r.x - 1, r.y + 1, RAIN)
		"RIVALS_DAY":
			_line(m, Vector2i(9, 4), Vector2i(9, 27), WOOD, 2)
			_poly(m, PackedVector2Array([Vector2(11, 5), Vector2(27, 10), Vector2(11, 15)]), TEAM[0])
			_text(m, 13, 8, "1", INK, 1)
			_box(m, 6, 27, 8, 2, WOOD.darkened(0.3))
		"RIVALS_MATCH":
			_ring(m, 9.0, 11.0, 2.0, 4.0, GOLD_D)
			_ring(m, 23.0, 11.0, 2.0, 4.0, GOLD_D)
			_poly(m, PackedVector2Array([Vector2(9, 5), Vector2(23, 5), Vector2(21, 15), Vector2(18, 18),
					Vector2(14, 18), Vector2(11, 15)]), GOLD)
			_box(m, 15, 18, 2, 4, GOLD_D)
			_box(m, 11, 22, 10, 5, GOLD_D)
			_text(m, 15, 8, "3", GOLD_D.darkened(0.3), 1)
			_line(loose, Vector2i(12, 7), Vector2i(12, 12), CREAM)
		"BOARDED":
			_poly(m, PackedVector2Array([Vector2(2, 21), Vector2(13, 21), Vector2(12, 26), Vector2(4, 26)]), TEAM[0])
			_poly(m, PackedVector2Array([Vector2(19, 21), Vector2(30, 21), Vector2(28, 26), Vector2(20, 26)]), TEAM[1])
			for i in 17:
				var u := i / 16.0
				var p := Vector2(lerpf(7.0, 24.0, u), 19.0 - sin(u * PI) * 11.0)
				if i % 2 == 0 and absf(u - 0.5) > 0.2:
					_px(loose, int(p.x), int(p.y), CREAM)
			_disc(m, 16.0, 6.5, 2.0, SKIN)
			_box(m, 15, 9, 3, 4, OILSKIN)
			_line(m, Vector2i(14, 10), Vector2i(12, 8), OILSKIN)
			_line(m, Vector2i(18, 10), Vector2i(20, 8), OILSKIN)
			_px(loose, 23, 17, CREAM)
			_px(loose, 24, 18, CREAM)
			_px(loose, 22, 18, CREAM)
			_water(loose, 27)
		"OVERBOARD":
			for y in N:
				for x in N:
					var d := Vector2(x + 0.5, y + 0.5) - Vector2(16, 15)
					if d.length() >= 4.6 and d.length() <= 10.5:
						var seg := posmod(int(floorf((d.angle() + PI / 8.0) / (PI / 4.0))), 8)
						_px(m, x, y, RED if seg % 2 == 0 else CREAM)
			_water(loose, 24)
			for s: Vector2i in [Vector2i(4, 20), Vector2i(6, 17), Vector2i(27, 19), Vector2i(25, 16)]:
				_px(loose, s.x, s.y, FOAM)


# --- the pictures' pieces ---

## A bluefin facing left, nose at x0, tail at x1, her middle at `mid`, `depth` deep (tools/make_icon.gd's, any size).
static func _tuna(m: Dictionary, x0: float, x1: float, mid: float, depth: float) -> void:
	var length := x1 - x0
	for y in N:
		for x in range(floori(x0), ceili(x1)):
			var u := (x + 0.5 - x0) / length
			var v := y + 0.5
			if u < 0.0 or u > 1.0:
				continue
			if u <= 0.8:
				var t := u / 0.8
				var k := pow(sin(PI * pow(t, 0.72)), 0.8)
				k = maxf(k, 0.18 if t > 0.5 else 0.0)
				var top := mid - depth * 0.55 * k
				var bot := mid + depth * 0.45 * k
				if v < top or v > bot:
					continue
				var rel := (v - top) / maxf(bot - top, 0.001)
				_px(m, x, y, BACK if rel < 0.3 else (SIDE if rel < 0.45 else (SILVER if rel < 0.72 else BELLY)))
			else:
				var w := (u - 0.8) / 0.2
				var dv := v - mid
				var outer := depth * (0.1 + 0.55 * pow(w, 0.7))
				var inner := depth * (0.05 + 0.55 * pow(w, 1.9))
				if absf(dv) <= outer and (absf(dv) >= inner or w < 0.35):
					_px(m, x, y, BACK if dv < 0.0 else FIN)
	# the dorsal fin, the finlets, the eye
	var fx := x0 + length * 0.36
	for i in maxi(int(depth * 0.3), 1):
		_px(m, int(fx) + i, int(mid - depth * 0.55) - (maxi(int(depth * 0.3), 1) - i) + 1, FIN)
	if depth >= 8.0:
		for x in range(int(x0 + length * 0.55), int(x0 + length * 0.78), 2):
			_px(m, x, int(mid - depth * 0.32) - 1, FINLET)
			_px(m, x, int(mid + depth * 0.28) + 1, FINLET)
	var ex := int(x0 + length * 0.12)
	var ey := int(mid - depth * 0.08)
	_px(m, ex, ey, CREAM)
	if depth >= 10.0:
		_px(m, ex + 1, ey, INK)


## A mackerel facing left: green back barred black, silver belly.
static func _mackerel(m: Dictionary, x0: float, x1: float, mid: float, depth: float) -> void:
	var length := x1 - x0
	for y in N:
		for x in range(floori(x0), ceili(x1)):
			var u := (x + 0.5 - x0) / length
			var v := y + 0.5
			if u < 0.0 or u > 1.0:
				continue
			if u <= 0.84:
				var t := u / 0.84
				var k := pow(sin(PI * pow(t, 0.8)), 0.9)
				k = maxf(k, 0.15 if t > 0.5 else 0.0)
				var top := mid - depth * 0.5 * k
				var bot := mid + depth * 0.5 * k
				if v < top or v > bot:
					continue
				var rel := (v - top) / maxf(bot - top, 0.001)
				var c := Color("2f7f6c")
				if rel < 0.5 and int(x + 2.0 * sin(y * 1.3)) % 3 == 0 and u > 0.18:
					c = Color("123a33")
				elif rel >= 0.5:
					c = SILVER if rel < 0.7 else BELLY
				_px(m, x, y, c)
			else:
				var w := (u - 0.84) / 0.16
				if absf(v - mid) <= depth * (0.1 + 0.5 * w) and (absf(v - mid) >= depth * 0.4 * w * w or w < 0.4):
					_px(m, x, y, Color("2f7f6c"))
	_px(m, int(x0 + length * 0.1), int(mid - depth * 0.1), CREAM)


## A deckhand from the shoulders up, in a sou'wester and oilskins, centred on x (`shade`: the one behind, darker).
static func _hand(m: Dictionary, x: float, shade: float) -> void:
	var oil := OILSKIN.darkened(1.0 - shade)
	_poly(m, PackedVector2Array([Vector2(x - 7, 29), Vector2(x - 6, 23), Vector2(x - 2, 21), Vector2(x + 2, 21),
			Vector2(x + 6, 23), Vector2(x + 7, 29)]), oil)
	_disc(m, x, 16.5, 4.5, SKIN.darkened(1.0 - shade))
	_box(m, int(x) - 2, 16, 1, 1, INK)
	_box(m, int(x) + 1, 16, 1, 1, INK)
	_disc(m, x, 12.0, 4.0, oil)
	_box(m, int(x) - 6, 12, 13, 2, oil.darkened(0.1))


## A gold coin with a $ on it (`big`: the $ twice the size).
static func _coin(m: Dictionary, loose: Dictionary, cx: float, cy: float, r: float, big: bool) -> void:
	_disc(m, cx, cy, r, GOLD_D)
	_disc(m, cx - 0.5, cy - 0.5, r - 1.0, GOLD)
	_ring(m, cx - 0.5, cy - 0.5, r - 3.0, r - 2.2, GOLD_D)
	# (the font's $ is too small to read on a coin: an S with a bar through it)
	var s := 2 if big else 1
	var ink := GOLD_D.darkened(0.25)
	_text(m, int(cx - 1.5 * s), int(cy - 2.5 * s), "S", ink, s)
	_box(m, int(cx - 1.5 * s) + s, int(cy - 2.5 * s) - 1, s, 5 * s + 2, ink)
	_px(loose, int(cx - r * 0.55), int(cy - r * 0.55), CREAM)


## The sea's line across the plaque at row y, a fleck of foam here and there.
static func _water(loose: Dictionary, y: int) -> void:
	for x in range(3, N - 3):
		var yy := y + int(round(sin(x * 0.7) * 0.6))
		_px(loose, x, yy, WATER if (x * 7) % 11 != 0 else FOAM)


# --- drawing ---

static func _px(m: Dictionary, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < N and y < N:
		m[Vector2i(x, y)] = c


static func _box(m: Dictionary, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(m, xx, yy, c)


static func _disc(m: Dictionary, cx: float, cy: float, r: float, c: Color) -> void:
	_ring(m, cx, cy, -1.0, r, c)


static func _ring(m: Dictionary, cx: float, cy: float, r0: float, r1: float, c: Color) -> void:
	for y in range(floori(cy - r1) - 1, ceili(cy + r1) + 1):
		for x in range(floori(cx - r1) - 1, ceili(cx + r1) + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy))
			if d <= r1 and d > r0:
				_px(m, x, y, c)


static func _line(m: Dictionary, a: Vector2i, b: Vector2i, c: Color, w := 1) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var p := Vector2(a).lerp(Vector2(b), float(i) / maxf(n, 1)).round()
		_box(m, int(p.x), int(p.y), w, w, c)


static func _poly(m: Dictionary, pts: PackedVector2Array, c: Color) -> void:
	for y in N:
		for x in N:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				_px(m, x, y, c)


## Words in the pixel font (ui/pixfont.gd), each font pixel s x s.
static func _text(m: Dictionary, x: int, y: int, text: String, c: Color, s: int) -> void:
	for ch in text:
		var g: Array = PixFont.GLYPHS.get(ch, PixFont.GLYPHS[" "])
		for r in 5:
			for cx in 3:
				if (g[r] as String)[cx] == "#":
					_box(m, x + cx * s, y + r * s, s, s, c)
		x += 4 * s


## The picture onto the plaque: an ink outline round it first (only where there's plaque), then it, then the loose.
static func _stamp(img: Image, m: Dictionary, loose: Dictionary) -> void:
	for p: Vector2i in m:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if not m.has(q) and q.x >= 0 and q.y >= 0 and q.x < N and q.y < N and img.get_pixelv(q).a > 0.0:
				img.set_pixelv(q, INK)
	for layer: Dictionary in [m, loose]:
		for p: Vector2i in layer:
			var c: Color = layer[p]
			img.set_pixelv(p, img.get_pixelv(p).blend(c) if c.a < 1.0 else c)


## Locked: grey, sunk, a little cold.
static func _grey(img: Image) -> void:
	for y in N:
		for x in N:
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var v := c.get_luminance() * 0.5 + 0.05
			img.set_pixel(x, y, Color(v, v * 1.03, v * 1.12, c.a))
