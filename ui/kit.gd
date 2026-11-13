extends RefCounted
## The fight's drawing kit: INSTRUMENTS AND STAMPS. Everything the arcade fight puts on screen (its HUD,
## ui/fight_arcade_hud.gd, and every minigame, tuna/minigames/*.gd) is drawn with this and nothing else.
##
## DRAWING A GAME (read this before you draw one; ride.gd, beats.gd, spool.gd and lanes.gd are the ones to copy)
##  1. It's a ship's instrument: fine linework straight over the world, like a compass card, a sounder's scale or a
##     chart. NO panels: no fills behind things, no boxes, no rounded corners, no pills, no glow, no gradient, no
##     shadow, no translucent anything. If in doubt, take it away.
##  2. Three inks: PAPER for nearly everything, YELLOW for reward (the good zone, a perfect, the combo), ORANGE for
##     danger and for the fish himself. No other colour, and no mixing them. Alpha only to fade a thing out.
##  3. Two line weights: rule(ci, a, b, col) is fine, rule(ci, a, b, col, true) is heavy; path() for a bent or
##     closed line, circle() and sweep() only for things that really are round (a reel, a dial). Every stroke is
##     keylined in dark by the kit (that's how it reads over white foam and over a black night): never draw your own
##     backing, and never call ci.draw_* yourself.
##  4. A quantity is a SCALE: scale() is a ruler (a line with minor and major ticks), dial() a ticked circle.
##  5. A zone on a scale is a span() (two brackets) with hatch() inside it (hatch_arc() on a dial): never a fill.
##     Yellow if it's where you want to be, orange if it hurts. Heavy when you're in it, fine when you're not.
##  6. Markers are small solids: tri() (a pointer, its tip on what it points at), square(), diamond(), bar(); the
##     same shapes hollow (filled false) for one that's spent or still to come. Yours are PAPER.
##  7. The fish is fish() in ORANGE, small; the boat boat() in PAPER.
##  8. Words: none if a shape can say it. Otherwise label() (small spaced capitals) and num() (big numerals, the
##     unit after it in a label: "140 M"). The game's name, the frame's four corner ticks, the button glyphs (HOLD,
##     TAP, RELEASE) and the grade's stamp are the HUD's: don't draw them.
##  9. Motion is hard: a thing is there or it isn't, it steps or it travels at a steady rate. A hit is shown by a
##     mark jumping or turning solid for a few frames (slam(), or `if flash > 0.5`), never by a soft pulse.
## 10. Lay it out in `unit(rect)` (a rect 100 tall is 1) and keep inside the rect; line weights are the kit's own
##     (they follow the screen: `px` is 1 at 1080p).
## 11. Everything is drawn from the game's own state, the same on every screen: nothing random in draw().
##
## What else is here: font() (a condensed system face, tabular numerals), text(), box(), solid(), corners() (the
## frame), stamp() and tag() (the fish-market stamps: the one loud thing), button() (the engraved mouse or the pad's
## trigger acting out a cue), and the easing (slam, out_cubic, in_cubic, out_back, pop, beat, follow).
## Every call takes the CanvasItem to draw on: `var kit := Kit.new()`. The HUD sets `px`, and draws in two passes
## (`defer` on: every keyline at once, then flush() lays all the ink on top, so no keyline ever darkens a stroke).

const PAPER := Color(0.957, 0.945, 0.910)
const YELLOW := Color(1.0, 0.824, 0.122)
const ORANGE := Color(1.0, 0.310, 0.122)
## The keyline under every stroke, and the stamps' lettering.
const INK := Color(0.03, 0.035, 0.04, 0.62)
const BLACK := Color(0.055, 0.055, 0.06)

## What a button's asked to do (the minigames' cue()): nothing, hold it, tap it, hammer it, let it go, hands off.
enum {NONE, HOLD, TAP, MASH, RELEASE, OFF = -1}

const WORDS := {HOLD: "HOLD", TAP: "TAP", MASH: "MASH", RELEASE: "RELEASE", OFF: "HANDS OFF"}
## The stamps' letters that get a stencil's bridge.
const STENCIL := "ADOPQR04689"

static var _fonts := {}

## The screen's scale: 1 at 1080p (the HUD sets it).
var px := 1.0
## Two passes: keylines as they're asked for, the ink held back till flush().
var defer := false
var _ops: Array[Callable] = []


# ------------------------------------------------------------------ ink

func fine() -> float:
	return 2.0 * px


func heavy() -> float:
	return 4.5 * px


func _key(col: Color) -> Color:
	return Color(INK, INK.a * col.a)


func _ink(fn: Callable) -> void:
	if defer:
		_ops.append(fn)
	else:
		fn.call()


## Lay down the ink that's been held back.
func flush() -> void:
	for fn in _ops:
		fn.call()
	_ops.clear()


func _stroke(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	if a.distance_squared_to(b) < 0.01 or col.a <= 0.0:
		return
	var k := 2.0 * px
	var d := (b - a).normalized() * k
	ci.draw_line(a - d, b + d, _key(col), w + k * 2.0, true)
	_ink(func() -> void: ci.draw_line(a, b, col, w, true))


## A straight line: fine, or heavy.
func rule(ci: CanvasItem, a: Vector2, b: Vector2, col := PAPER, hvy := false) -> void:
	_stroke(ci, a, b, col, heavy() if hvy else fine())


## A bent line through `pts` (closed: back to the first).
func path(ci: CanvasItem, pts: PackedVector2Array, col := PAPER, hvy := false, closed := false) -> void:
	if pts.size() < 2 or col.a <= 0.0:
		return
	var p := pts.duplicate()
	if closed:
		p.append(pts[0])
	var w := heavy() if hvy else fine()
	ci.draw_polyline(p, _key(col), w + 4.0 * px, true)
	_ink(func() -> void: ci.draw_polyline(p, col, w, true))


## A solid shape.
func solid(ci: CanvasItem, pts: PackedVector2Array, col := PAPER) -> void:
	if pts.size() < 3 or col.a <= 0.0:
		return
	var area := 0.0
	for i in pts.size():
		area += pts[i].cross(pts[(i + 1) % pts.size()])
	if absf(area) < 1.0:
		return
	var p := pts.duplicate()
	p.append(pts[0])
	# (a solid's keyline is darker: it's all that shows a white shape on white water)
	ci.draw_polyline(p, Color(INK, 0.82 * col.a), 4.0 * px, true)
	_ink(func() -> void: ci.draw_colored_polygon(pts, col))


## A solid rectangle (a bar on a scale).
func bar(ci: CanvasItem, r: Rect2, col := PAPER) -> void:
	solid(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), col)


## A rectangle's outline.
func box(ci: CanvasItem, r: Rect2, col := PAPER, hvy := false) -> void:
	path(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), col, hvy, true)


## A circle's line: only for what's really round.
func circle(ci: CanvasItem, c: Vector2, radius: float, col := PAPER, hvy := false) -> void:
	if radius < 0.3 or col.a <= 0.0:
		return
	var w := heavy() if hvy else fine()
	ci.draw_circle(c, radius, _key(col), false, w + 4.0 * px, true)
	_ink(func() -> void: ci.draw_circle(c, radius, col, false, w, true))


## Part of a circle's line, from angle a0 to a1 (radians, 0 right, clockwise on screen).
func sweep(ci: CanvasItem, c: Vector2, radius: float, a0: float, a1: float, col := PAPER, hvy := false) -> void:
	if absf(a1 - a0) < 0.001 or radius < 0.3 or col.a <= 0.0:
		return
	var w := heavy() if hvy else fine()
	var n := maxi(int(absf(a1 - a0) * radius / 3.0), 6)
	ci.draw_arc(c, radius, a0, a1, n, _key(col), w + 4.0 * px, true)
	_ink(func() -> void: ci.draw_arc(c, radius, a0, a1, n, col, w, true))


# ------------------------------------------------------------------ scales, zones, the frame

## A ruler from `a` to `b`: `n` divisions, every `major`th tick long. The ticks stand on the side `side` (+1: to the
## right of a->b, which is below a ruler drawn left to right). `base`: with its line.
func scale(ci: CanvasItem, a: Vector2, b: Vector2, n: int, major := 5, col := PAPER, side := 1.0, minor_len := -1.0,
		major_len := -1.0, base := true) -> void:
	var d := (b - a).normalized()
	var nrm := Vector2(-d.y, d.x) * side
	if minor_len < 0.0:
		minor_len = 6.0 * px
	if major_len < 0.0:
		major_len = minor_len * 2.0
	if base:
		rule(ci, a, b, col)
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxi(n, 1))
		rule(ci, p, p + nrm * (major_len if i % maxi(major, 1) == 0 else minor_len), col)


## A ticked circle: `n` divisions, every `major`th long, the ticks standing inward (or outward: `inward` false). The
## first tick's at the top.
func dial(ci: CanvasItem, c: Vector2, radius: float, n: int, major := 5, col := PAPER, minor_len := -1.0, major_len := -1.0,
		inward := true) -> void:
	if minor_len < 0.0:
		minor_len = 6.0 * px
	if major_len < 0.0:
		major_len = minor_len * 2.0
	circle(ci, c, radius, col)
	for i in n:
		var dir := Vector2.from_angle(-PI * 0.5 + TAU * i / n)
		var l := major_len if i % maxi(major, 1) == 0 else minor_len
		rule(ci, c + dir * radius, c + dir * (radius - l if inward else radius + l), col)


## A zone on a scale: a bracket at each end of `r` ([ and ]), their feet turned in. Put hatch() inside it.
func span(ci: CanvasItem, r: Rect2, col := YELLOW, hvy := false) -> void:
	var foot := minf(5.0 * px, r.size.x * 0.25)
	path(ci, PackedVector2Array([Vector2(r.position.x + foot, r.position.y), r.position, Vector2(r.position.x, r.end.y),
			Vector2(r.position.x + foot, r.end.y)]), col, hvy)
	path(ci, PackedVector2Array([Vector2(r.end.x - foot, r.position.y), Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.end.x - foot, r.end.y)]), col, hvy)


## Diagonal hatching across `r` (parallel lines at 45 degrees, `gap` apart; -1: the kit's own).
func hatch(ci: CanvasItem, r: Rect2, col := YELLOW, hvy := false, gap := -1.0) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0 or col.a <= 0.0:
		return
	if gap <= 0.0:
		gap = 9.0 * px
	var w := heavy() if hvy else fine()
	var h := r.size.y
	var lines := PackedVector2Array()
	var o := -h + gap * 0.5
	while o < r.size.x:
		var a := Vector2(r.position.x + o, r.end.y)
		var b := Vector2(r.position.x + o + h, r.position.y)
		if a.x < r.position.x:
			a = Vector2(r.position.x, r.end.y - (r.position.x - a.x))
		if b.x > r.end.x:
			b = Vector2(r.end.x, r.position.y + (b.x - r.end.x))
		if a.distance_squared_to(b) > 4.0:
			lines.append(a)
			lines.append(b)
		o += gap
	if lines.is_empty():
		return
	ci.draw_multiline(lines, _key(col), w + 2.0 * px, true)
	_ink(func() -> void: ci.draw_multiline(lines, col, w, true))


## Hatching round part of a dial: slanted strokes between radius r0 and r1, from angle a0 to a1.
func hatch_arc(ci: CanvasItem, c: Vector2, r0: float, r1: float, a0: float, a1: float, col := YELLOW, hvy := false, gap := -1.0) -> void:
	if gap <= 0.0:
		gap = 9.0 * px
	var w := heavy() if hvy else fine()
	var mid := (r0 + r1) * 0.5
	var skew := (r1 - r0) / maxf(mid, 1.0)
	var da := gap / maxf(mid, 1.0)
	var lines := PackedVector2Array()
	var lo := minf(a0, a1)
	var end := maxf(a0, a1)
	skew = minf(skew, (end - lo) * 0.6)
	var a := lo + skew * 0.5 + da * 0.35
	while a + skew * 0.5 < end - da * 0.2:
		lines.append(c + Vector2.from_angle(a - skew * 0.5) * r0)
		lines.append(c + Vector2.from_angle(a + skew * 0.5) * r1)
		a += da
	if lines.is_empty() or col.a <= 0.0:
		return
	ci.draw_multiline(lines, _key(col), w + 2.0 * px, true)
	_ink(func() -> void: ci.draw_multiline(lines, col, w, true))


## The frame: four corner ticks (little L marks) at the corners of `r`, their legs `leg` long.
func corners(ci: CanvasItem, r: Rect2, leg: float, col := PAPER, hvy := true) -> void:
	for i in 4:
		var p := Vector2(r.position.x if i % 2 == 0 else r.end.x, r.position.y if i < 2 else r.end.y)
		var dx := leg if i % 2 == 0 else -leg
		var dy := leg if i < 2 else -leg
		path(ci, PackedVector2Array([p + Vector2(dx, 0.0), p, p + Vector2(0.0, dy)]), col, hvy)


# ------------------------------------------------------------------ markers

## A pointer: a solid triangle with its tip at `tip`, pointing along `dir`, `size` across its back.
func tri(ci: CanvasItem, tip: Vector2, size: float, dir: Vector2, col := PAPER, filled := true) -> void:
	var n := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([tip, tip - dir * size * 0.95 + n * size * 0.5, tip - dir * size * 0.95 - n * size * 0.5])
	if filled:
		solid(ci, pts, col)
	else:
		path(ci, pts, col, false, true)


func square(ci: CanvasItem, c: Vector2, size: float, col := PAPER, filled := true) -> void:
	var r := Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size))
	if filled:
		bar(ci, r, col)
	else:
		box(ci, r, col)


## A square on its corner, `size` from point to point.
func diamond(ci: CanvasItem, c: Vector2, size: float, col := PAPER, filled := true) -> void:
	var h := size * 0.5
	var pts := PackedVector2Array([c + Vector2(0.0, -h), c + Vector2(h, 0.0), c + Vector2(0.0, h), c + Vector2(-h, 0.0)])
	if filled:
		solid(ci, pts, col)
	else:
		path(ci, pts, col, false, true)


func _placed(pts: Array, c: Vector2, rot: float, sx: float, sy: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(c + Vector2(p.x * sx, p.y * sy).rotated(rot))
	return out


## The bluefin, cut square: `length` long, his nose toward `way` (+1 right, -1 left), turned `rot` radians.
func fish(ci: CanvasItem, c: Vector2, length: float, col := ORANGE, way := 1.0, rot := 0.0) -> void:
	var sx := length * way
	var body := [Vector2(0.5, 0.0), Vector2(0.24, -0.13), Vector2(0.06, -0.15), Vector2(-0.04, -0.27), Vector2(-0.1, -0.12),
			Vector2(-0.3, -0.035), Vector2(-0.5, -0.22), Vector2(-0.41, 0.0), Vector2(-0.5, 0.22), Vector2(-0.3, 0.035),
			Vector2(-0.08, 0.11), Vector2(0.22, 0.12)]
	var pts := _placed(body, c, rot * way, sx, length)
	if way < 0.0:
		pts.reverse()
	solid(ci, pts, col)


## A little boat from the side, cut square: `length` long, her bow toward `way`.
func boat(ci: CanvasItem, c: Vector2, length: float, col := PAPER, way := 1.0) -> void:
	var hull := [Vector2(-0.5, -0.06), Vector2(-0.2, -0.06), Vector2(-0.2, -0.3), Vector2(0.12, -0.3), Vector2(0.2, -0.06),
			Vector2(0.5, -0.1), Vector2(0.34, 0.14), Vector2(-0.42, 0.14)]
	var pts := _placed(hull, c, 0.0, length * way, length)
	if way < 0.0:
		pts.reverse()
	solid(ci, pts, col)


# ------------------------------------------------------------------ type

## The typeface at a weight (600 for labels, 700 for numerals and stamps): the system's Bahnschrift (then Arial
## Narrow, Segoe UI, Arial, the engine's own), condensed, with tabular numbers.
static func font(weight := 600) -> Font:
	if not _fonts.has(weight):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift", "Arial Narrow", "Segoe UI", "Arial"])
		f.font_weight = weight
		f.font_stretch = 80
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		f.generate_mipmaps = true
		f.allow_system_fallback = true
		var v := FontVariation.new()
		v.base_font = f
		var ts := TextServerManager.get_primary_interface()
		if ts != null:
			v.opentype_features = {ts.name_to_tag("tnum"): 1}
		_fonts[weight] = v
	return _fonts[weight]


func text_w(s: String, size: float, weight := 600, spacing := 0.0) -> float:
	return font(weight).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, maxi(int(roundf(size)), 1)).x + spacing * maxi(s.length() - 1, 0)


## `s` with its middle (align 0), left (-1) or right (1) end at `at`, vertically centred on it, with a thin dark
## outline (`outline` false: none, for lettering on a solid). `spacing`: px between letters. Returns its width.
func text(ci: CanvasItem, at: Vector2, s: String, size: float, col := PAPER, align := 0, weight := 600,
		spacing := 0.0, outline := true) -> float:
	var f := font(weight)
	var fs := maxi(int(roundf(size)), 1)
	var w := text_w(s, size, weight, spacing)
	if col.a <= 0.0 or s == "":
		return w
	var x := at.x - w * 0.5 * (align + 1)
	var y := at.y + fs * 0.36
	var ol := maxi(int(roundf(clampf(size * 0.1, 2.0 * px, 4.0 * px))), 1)
	var key := Color(INK, minf(INK.a * 1.3, 1.0) * col.a)
	if spacing == 0.0:
		if outline:
			ci.draw_string_outline(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, ol, key)
		_ink(func() -> void: ci.draw_string(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col))
		return w
	var xs := PackedFloat32Array()
	for i in s.length():
		xs.append(x)
		x += f.get_string_size(s[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x + spacing
	if outline:
		for i in s.length():
			ci.draw_string_outline(f, Vector2(xs[i], y), s[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, ol, key)
	_ink(func() -> void:
		for i in s.length():
			ci.draw_string(f, Vector2(xs[i], y), s[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col))
	return w


## A label: small capitals, widely spaced. Returns its width.
func label(ci: CanvasItem, at: Vector2, s: String, size: float, col := PAPER, align := 0) -> float:
	return text(ci, at, s.to_upper(), size, col, align, 600, size * 0.17)


## A numeral: big and heavy. Returns its width.
func num(ci: CanvasItem, at: Vector2, s: String, size: float, col := PAPER, align := 0) -> float:
	return text(ci, at, s, size, col, align, 700)


# ------------------------------------------------------------------ the stamps

## A block of stamped ink: `r` filled with `col`, with a few specks and nicks knocked out of it (holes: the world
## shows through; the same every frame for the same `mark`), its top left corner cut by `chamfer`, a round hole
## punched at `hole` (x, y, radius; radius 0: none). Drawn under whatever transform is set.
func _block(ci: CanvasItem, r: Rect2, col: Color, mark: int, chamfer := 0.0, hole := Vector3.ZERO) -> void:
	var out := PackedVector2Array([Vector2(r.position.x + chamfer, r.position.y), Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y + chamfer), Vector2(r.position.x + chamfer, r.position.y)])
	ci.draw_polyline(out, Color(INK, col.a * 0.8), 4.0 * px, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = mark
	var specks: Array = []           # [x, y, half width, half height]
	for i in clampi(int(r.get_area() / (px * px) / 2000.0) + 4, 5, 40):
		var sp := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		var edge := rng.randf()
		if edge < 0.14:
			sp.x = r.position.x
		elif edge < 0.28:
			sp.x = r.end.x
		elif edge < 0.4:
			sp.y = r.position.y
		elif edge < 0.52:
			sp.y = r.end.y
		specks.append([sp.x, sp.y, rng.randf_range(1.5, 5.0) * px, rng.randf_range(1.2, 4.0) * px])
	var rh := maxf(px, 1.0)
	var rows := int(ceilf(r.size.y / rh))
	var pts := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in rows:
		var y0 := minf(r.position.y + i * rh, r.end.y)
		var y1 := minf(r.position.y + (i + 1) * rh, r.end.y)
		var ym := (y0 + y1) * 0.5
		var x := r.position.x + maxf(chamfer - (ym - r.position.y), 0.0)
		var cuts: Array = []
		for s: Array in specks:
			var dy := absf(ym - float(s[1])) / float(s[3])
			if dy < 1.0:
				var hw := float(s[2]) * sqrt(1.0 - dy * dy)
				cuts.append(Vector2(float(s[0]) - hw, float(s[0]) + hw))
		if hole.z > 0.0 and absf(ym - hole.y) < hole.z:
			var hw := sqrt(hole.z * hole.z - (ym - hole.y) * (ym - hole.y))
			cuts.append(Vector2(hole.x - hw, hole.x + hw))
		cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		cuts.append(Vector2(r.end.x, r.end.x))
		for cut: Vector2 in cuts:
			var to := minf(cut.x, r.end.x)
			if to > x + 0.01:
				var at := pts.size()
				pts.append_array([Vector2(x, y0), Vector2(to, y0), Vector2(to, y1), Vector2(x, y1)])
				idx.append_array([at, at + 1, at + 2, at, at + 2, at + 3])
			x = maxf(x, cut.y)
	if idx.size() >= 3:
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, PackedColorArray([col]))


## Stencil lettering in BLACK for a stamp, its middle at `at` (under the transform that's set); `col` is the block's
## (the stencil's bridges are cut in it).
func _stencil(ci: CanvasItem, at: Vector2, s: String, size: float, col: Color, spacing: float) -> void:
	var f := font(700)
	var fs := maxi(int(roundf(size)), 1)
	var x := at.x - text_w(s, size, 700, spacing) * 0.5
	var y := at.y + fs * 0.36
	var black := Color(BLACK, col.a)
	for i in s.length():
		var cw := f.get_string_size(s[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
		ci.draw_string(f, Vector2(x, y), s[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, black)
		if STENCIL.contains(s[i]):
			ci.draw_rect(Rect2(x + cw * 0.5 - fs * 0.022, at.y - fs * 0.42, fs * 0.044, fs * 0.84), col)
		x += cw + spacing


## A fish-market stamp: `word` in heavy stencil capitals in a solid block of `col`, a few degrees off square, a
## little dry-ink roughness. `hollow`: the block's outline only, the word in `col`. `k`: its scale (slam() it in);
## `alpha`: to fade it out. Its middle at `at`; `size`: the letters' height. Always on top of what's been drawn.
func stamp(ci: CanvasItem, at: Vector2, word: String, size: float, col: Color, k := 1.0, alpha := 1.0, rot := -0.07, hollow := false) -> void:
	if alpha <= 0.0:
		return
	flush()
	var was := defer
	defer = false
	var sp := size * 0.09
	var tw := text_w(word, size, 700, sp)
	var r := Rect2(-tw * 0.5 - size * 0.4, -size * 0.62, tw + size * 0.8, size * 1.24)
	var c := Color(col, col.a * alpha)
	ci.draw_set_transform(at, rot, Vector2(k, k))
	if hollow:
		box(ci, r, c, true)
		text(ci, Vector2.ZERO, word, size, c, 0, 700, sp)
	else:
		_block(ci, r, c, hash(word))
		_stencil(ci, Vector2.ZERO, word, size, c, sp)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	defer = was


## An auction tag: a block `size` big with one corner cut and a hole punched by it, `title` small across its top and
## `big` huge under it with `unit_s` after it. `k`, `alpha`, `rot` as stamp().
func tag(ci: CanvasItem, at: Vector2, size: Vector2, col: Color, title: String, big: String, unit_s := "", k := 1.0, alpha := 1.0, rot := -0.07) -> void:
	if alpha <= 0.0:
		return
	flush()
	var was := defer
	defer = false
	var r := Rect2(-size * 0.5, size)
	var h := size.y
	var c := Color(col, col.a * alpha)
	ci.draw_set_transform(at, rot, Vector2(k, k))
	_block(ci, r, c, hash(title), h * 0.3, Vector3(r.position.x + h * 0.27, r.position.y + h * 0.27, h * 0.055))
	var black := Color(BLACK, c.a)
	var ts := h * 0.17
	var f := font(700)
	# the title, left of the middle of its top; a ruled line under it
	_stencil(ci, Vector2(r.position.x + h * 0.44 + text_w(title, ts, 700, ts * 0.2) * 0.5, r.position.y + h * 0.2), title, ts, c, ts * 0.2)
	ci.draw_line(Vector2(r.position.x + h * 0.44, r.position.y + h * 0.34), Vector2(r.end.x - h * 0.12, r.position.y + h * 0.34), black, heavy(), true)
	# the number, hard against the right, its unit after it on the same line
	var bs := maxi(int(h * 0.58), 1)
	var us := maxi(int(h * 0.24), 1)
	var uw := (f.get_string_size(unit_s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, us).x + h * 0.04) if unit_s != "" else 0.0
	var bw := f.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1.0, bs).x
	var base := r.end.y - h * 0.13
	var right := r.end.x - h * 0.12
	ci.draw_string(f, Vector2(right - uw - bw, base), big, HORIZONTAL_ALIGNMENT_LEFT, -1.0, bs, black)
	if unit_s != "":
		ci.draw_string(f, Vector2(right - uw + h * 0.04, base), unit_s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, us, black)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	defer = was


# ------------------------------------------------------------------ motion

static func out_cubic(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


static func in_cubic(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x


## Past its mark and back: for things arriving.
static func out_back(x: float, over := 1.70158) -> float:
	x = clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + (over + 1.0) * x * x * x + over * x * x


static func out_elastic(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	if x <= 0.0 or x >= 1.0:
		return x
	return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * TAU / 3.0) + 1.0


## A stamp coming down, `t` s after it lands: from `big` to a hair under 1 in a couple of frames, then 1.
static func slam(t: float, big := 2.4) -> float:
	if t < 0.0:
		return big
	if t < 0.07:
		return lerpf(big, 0.93, t / 0.07)
	if t < 0.13:
		return lerpf(0.93, 1.0, (t - 0.07) / 0.06)
	return 1.0


## A springy scale for something that's just happened `t` s ago: big, then settling to 1.
static func pop(t: float, big := 0.45, secs := 0.4) -> float:
	if t >= secs or t < 0.0:
		return 1.0
	var x := t / secs
	return 1.0 + big * exp(-5.0 * x) * cos(x * 9.0)


## A pulse `hz` times a second: 1 at the top of each, falling away.
static func beat(t: float, hz: float) -> float:
	return pow(1.0 - fposmod(t * hz, 1.0), 2.0)


## A value eased toward where it's going (a counter rolling, a meter filling): call every frame.
static func follow(now: float, to: float, dt: float, rate := 10.0) -> float:
	return lerpf(now, to, 1.0 - exp(-rate * dt))


# ------------------------------------------------------------------ the buttons

## The ink a cue is drawn in.
static func cue_col(cue: int) -> Color:
	return ORANGE if cue == OFF else PAPER


## Is a cue's button shown pressed right now? (HOLD: yes. TAP and MASH: it blinks, sharply. RELEASE: no.)
static func cue_on(cue: int, t: float) -> bool:
	match cue:
		HOLD:
			return true
		TAP:
			return fposmod(t * 2.2, 1.0) < 0.42
		MASH:
			return fposmod(t * 7.0, 1.0) < 0.5
	return false


## One button and what it's asked to do, its middle at `c`, `h` tall: an engraved mouse (an upright outline with its
## corners cut, split down the top) with its left (`side` 0: A) or right (1: B) button solid, or the pad's trigger
## (RT is A, LT is B); its outline goes heavy while the button's solid. HOLD: solid, and a short bar under it. TAP, MASH: it blinks. RELEASE: it's empty. HANDS OFF:
## crossed out in orange. The one word under it. `down`: you've got it pressed now (an outline in the button).
func button(ci: CanvasItem, c: Vector2, h: float, side: int, cue: int, t: float, down: bool, pad := false, alpha := 1.0) -> void:
	var col := Color(cue_col(cue), alpha * (1.0 if cue != NONE else 0.45))
	var on := cue_on(cue, t)
	var w := h * (0.86 if pad else 0.62)
	var x0 := c.x - w * 0.5
	var x1 := c.x + w * 0.5
	var y0 := c.y - h * 0.5
	var y1 := c.y + h * 0.5
	var cell: PackedVector2Array
	var inset := 3.0 * px
	if pad:
		# a trigger: its top corners cut, the outer one more
		y0 = c.y - h * 0.3
		y1 = c.y + h * 0.3
		var big := w * 0.34
		var small := w * 0.12
		var cl := big if side == 1 else small
		var cr := small if side == 1 else big
		path(ci, PackedVector2Array([Vector2(x0 + cl, y0), Vector2(x1 - cr, y0), Vector2(x1, y0 + cr), Vector2(x1, y1),
				Vector2(x0, y1), Vector2(x0, y0 + cl)]), col, on, true)
		cell = PackedVector2Array([Vector2(x0 + cl + inset * 0.41, y0 + inset), Vector2(x1 - cr - inset * 0.41, y0 + inset),
				Vector2(x1 - inset, y0 + cr + inset * 0.41), Vector2(x1 - inset, y1 - inset), Vector2(x0 + inset, y1 - inset),
				Vector2(x0 + inset, y0 + cl + inset * 0.41)])
	else:
		var ch := w * 0.26
		var ys := y0 + h * 0.42
		path(ci, PackedVector2Array([Vector2(x0 + ch, y0), Vector2(x1 - ch, y0), Vector2(x1, y0 + ch), Vector2(x1, y1 - ch),
				Vector2(x1 - ch, y1), Vector2(x0 + ch, y1), Vector2(x0, y1 - ch), Vector2(x0, y0 + ch)]), col, on, true)
		rule(ci, Vector2(x0, ys), Vector2(x1, ys), col)
		rule(ci, Vector2(c.x, y0), Vector2(c.x, ys), col)
		var i2 := inset * 0.5
		if side == 0:
			cell = PackedVector2Array([Vector2(x0 + ch + inset * 0.41, y0 + inset), Vector2(c.x - i2 - fine() * 0.5, y0 + inset),
					Vector2(c.x - i2 - fine() * 0.5, ys - i2 - fine() * 0.5), Vector2(x0 + inset, ys - i2 - fine() * 0.5), Vector2(x0 + inset, y0 + ch + inset * 0.41)])
		else:
			cell = PackedVector2Array([Vector2(c.x + i2 + fine() * 0.5, y0 + inset), Vector2(x1 - ch - inset * 0.41, y0 + inset),
					Vector2(x1 - inset, y0 + ch + inset * 0.41), Vector2(x1 - inset, ys - i2 - fine() * 0.5), Vector2(c.x + i2 + fine() * 0.5, ys - i2 - fine() * 0.5)])
	if on:
		solid(ci, cell, col)
	elif down and cue != OFF:
		path(ci, cell, col, false, true)
	if pad:
		text(ci, Vector2(c.x, (y0 + y1) * 0.5 + h * 0.03), "RT" if side == 0 else "LT", h * 0.26, Color(BLACK, alpha) if on else col, 0, 700, 0.0, not on)
	if cue == OFF:
		var m := Vector2(c.x, (y0 + y1) * 0.5)
		var x := h * 0.36
		rule(ci, m - Vector2(x, x), m + Vector2(x, x), col, true)
		rule(ci, m - Vector2(x, -x), m + Vector2(x, -x), col, true)
	if cue == HOLD:
		rule(ci, Vector2(x0, y1 + h * 0.16), Vector2(x1, y1 + h * 0.16), col, true)
	if WORDS.has(cue):
		label(ci, Vector2(c.x, y1 + h * 0.44), WORDS[cue], h * 0.27, col)


# ------------------------------------------------------------------ Godot labels in the same hand

## The kit's face with `spacing` px between the letters (for a Label's font override).
static func spaced(weight := 600, spacing := 0.0) -> Font:
	if spacing == 0.0:
		return font(weight)
	var key := "sp%d_%d" % [weight, int(spacing * 10.0)]
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = font(weight)
		v.spacing_glyph = int(roundf(spacing))
		_fonts[key] = v
	return _fonts[key]


## A Godot Label (or RichTextLabel-less text) put in the kit's hand: its condensed face, `col` ink, a dark outline
## and no panel behind it. `spacing`: px between letters (0 for running sentences).
static func style_label(l: Label, size: int, col := PAPER, spacing := 0.0, weight := 600) -> void:
	l.add_theme_font_override("font", spaced(weight, spacing))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.035, 0.04, 0.88))
	l.add_theme_constant_override("outline_size", maxi(int(roundf(size * 0.22)), 3))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_stylebox_override("normal", StyleBoxEmpty.new())


# ------------------------------------------------------------------ in place of the old pixel font

## The menus were laid out with ui/pixfont.gd's two calls (draw and width, `scale` px a font pixel, a capital
## 5 * scale tall, `at` the top left). These are the same two in the kit's face, so a screen can be moved over a line
## at a time: the same height of capital, a dark keyline round it (so no shadow copy is wanted any more).
static func old_size(scale: float) -> int:
	return maxi(int(roundf(scale * 7.2)), 9)


static func old_width(s: String, scale: float, weight := 600) -> float:
	return font(weight).get_string_size(s.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, old_size(scale)).x


static func old_draw(ci: CanvasItem, at: Vector2, s: String, col: Color, scale: float, weight := 600) -> void:
	if col.a <= 0.0 or s == "":
		return
	var f := font(weight)
	var fs := old_size(scale)
	var base := Vector2(floorf(at.x), floorf(at.y + scale * 5.0))
	var t := s.to_upper()
	ci.draw_string_outline(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, maxi(int(roundf(fs * 0.12)), 2),
			Color(0.03, 0.035, 0.04, 0.8 * col.a))
	ci.draw_string(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)
