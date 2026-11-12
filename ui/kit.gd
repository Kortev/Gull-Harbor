extends RefCounted
## The new look's kit: the pieces every new screen shares (first: the fight's minigames, tuna/minigames/*.gd, and
## its HUD, ui/fight_arcade_hud.gd). Clean type, the sea's own colours, soft dark glass, everything anti-aliased and
## eased; nothing here is a pixel font or a hard box.
##
## - **Type**: font(weight): the system's Bahnschrift (then Segoe UI, then Arial, then the engine's own) with tabular
##   numbers; text() draws it centred on a point with a soft shadow, so it reads over bright water and a night storm.
## - **Colour**: DEEP (the sea at depth), FOAM (white water), MIST (second-rank words), TEAL (the sea in the sun),
##   GOLD (reward), CORAL (danger), GO (do it now).
## - **Panels**: glass(): a translucent dark rounded panel with a thin light edge and a soft shadow; blur_rect(): a
##   node that blurs what's behind it (the HUD puts one under each panel).
## - **Shapes**: rrect, pill, meter, line, arc, ring, dot, glow, chevron, fish, boat, hook: all anti-aliased.
## - **Motion**: out_cubic, out_back, out_elastic, pop (a springy scale), beat (a pulse); nothing snaps on or off.
## - **Buttons**: button(): the mouse with its left (A) or right (B) button lit, or the pad's trigger, the glyph itself
##   moving to say HOLD, TAP, MASH, RELEASE or HANDS OFF, with the one word under it.
## Every draw call takes the CanvasItem to draw on, so anything with a _draw can use it: `var kit := Kit.new()`.

const DEEP := Color(0.03, 0.085, 0.11)
const GLASS := Color(0.025, 0.07, 0.095, 0.7)
const EDGE := Color(1.0, 1.0, 1.0, 0.17)
const FOAM := Color(0.95, 0.985, 0.975)
const MIST := Color(0.7, 0.82, 0.85)
const DIM := Color(0.62, 0.74, 0.78, 0.45)
const TRACK := Color(1.0, 1.0, 1.0, 0.11)
const TEAL := Color(0.2, 0.8, 0.82)
const GOLD := Color(1.0, 0.79, 0.3)
const CORAL := Color(1.0, 0.42, 0.37)
const GO := Color(0.36, 0.93, 0.57)

## What a button's asked to do (the minigames' cue()): nothing, hold it, tap it, hammer it, let it go, hands off.
enum {NONE, HOLD, TAP, MASH, RELEASE, OFF = -1}

const WORDS := {HOLD: "HOLD", TAP: "TAP", MASH: "MASH", RELEASE: "LET GO", OFF: "HANDS OFF"}

static var _fonts := {}
static var _blur: Shader

var _sb := StyleBoxFlat.new()


# ------------------------------------------------------------------ type

## The typeface at a weight (400 regular, 600 semibold, 700 bold).
static func font(weight := 600) -> Font:
	if not _fonts.has(weight):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Semibold", "Segoe UI", "Arial"])
		f.font_weight = weight
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		f.generate_mipmaps = true
		f.allow_system_fallback = true
		var behind: Array[Font] = [ThemeDB.fallback_font]
		f.fallbacks = behind
		var v := FontVariation.new()
		v.base_font = f
		var ts := TextServerManager.get_primary_interface()
		if ts != null:
			v.opentype_features = {ts.name_to_tag("tnum"): 1}
		_fonts[weight] = v
	return _fonts[weight]


func text_w(s: String, size: float, weight := 600, spacing := 0.0) -> float:
	return font(weight).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, maxi(int(size), 1)).x + spacing * maxi(s.length() - 1, 0)


## `s` with its middle (align 0), left (-1) or right (1) end at `at`, vertically centred on it. `spacing`: px between
## letters (small capitals want some). Returns its width.
func text(ci: CanvasItem, at: Vector2, s: String, size: float, col: Color, align := 0, weight := 600,
		spacing := 0.0, shadow := true) -> float:
	var f := font(weight)
	var px := maxi(int(size), 1)
	var w := text_w(s, size, weight, spacing)
	var x := at.x - w * 0.5 * (align + 1)
	var y := at.y + px * 0.35
	# (under it a soft dark halo, so it reads over white water and bright sky)
	var halo := Color(0.0, 0.03, 0.05, 0.28 * col.a * col.a)
	var halo_px := clampi(int(px * 0.16), 2, 10)
	if spacing == 0.0:
		if shadow:
			ci.draw_string_outline(f, Vector2(x, y + px * 0.03), s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, halo_px, halo)
		ci.draw_string(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, col)
		return w
	var x0 := x
	for pass_n in 2:
		if pass_n == 0 and not shadow:
			continue
		x = x0
		for i in s.length():
			var ch := s[i]
			if pass_n == 0:
				ci.draw_string_outline(f, Vector2(x, y + px * 0.03), ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, halo_px, halo)
			else:
				ci.draw_string(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, col)
			x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x + spacing
	return w


## Text scaled about its own middle (a pop): `k` 1 is its size.
func text_pop(ci: CanvasItem, at: Vector2, s: String, size: float, col: Color, k: float, weight := 700) -> void:
	ci.draw_set_transform(at, 0.0, Vector2(k, k))
	text(ci, Vector2.ZERO, s, size, col, 0, weight)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ panels and shapes

## A rounded rectangle: filled, with an optional edge and soft shadow.
func rrect(ci: CanvasItem, r: Rect2, radius: float, col: Color, edge := Color(0, 0, 0, 0), edge_w := 0.0,
		shadow := 0.0, shadow_col := Color(0, 0, 0, 0.35)) -> void:
	var rad := int(clampf(radius, 0.0, minf(r.size.x, r.size.y) * 0.5))
	_sb.bg_color = col
	_sb.set_corner_radius_all(rad)
	_sb.corner_detail = 10
	_sb.anti_aliasing = true
	_sb.anti_aliasing_size = 1.0
	_sb.set_border_width_all(int(ceilf(edge_w)))
	_sb.border_color = edge
	_sb.shadow_size = int(shadow)
	_sb.shadow_color = shadow_col
	_sb.shadow_offset = Vector2(0.0, shadow * 0.3)
	_sb.draw_center = col.a > 0.0
	ci.draw_style_box(_sb, r)


## The panel everything sits on: dark glass, a thin light edge, a soft shadow.
func glass(ci: CanvasItem, r: Rect2, radius := 16.0, alpha := 1.0, tint := GLASS) -> void:
	rrect(ci, r, radius, Color(tint, tint.a * alpha), Color(EDGE, EDGE.a * alpha), 1.0, 14.0, Color(0, 0, 0, 0.3 * alpha))


func pill(ci: CanvasItem, r: Rect2, col: Color) -> void:
	rrect(ci, r, r.size.y * 0.5, col)


## A meter: a rounded track with `frac` of it filled from the left (or from the bottom, a tall one).
func meter(ci: CanvasItem, r: Rect2, frac: float, col: Color, track := TRACK) -> void:
	pill(ci, r, track)
	frac = clampf(frac, 0.0, 1.0)
	if frac <= 0.0:
		return
	if r.size.x >= r.size.y:
		pill(ci, Rect2(r.position, Vector2(maxf(r.size.x * frac, r.size.y), r.size.y)), col)
	else:
		var h := maxf(r.size.y * frac, r.size.x)
		rrect(ci, Rect2(r.position.x, r.end.y - h, r.size.x, h), r.size.x * 0.5, col)


func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 2.0, round_ends := true) -> void:
	ci.draw_line(a, b, col, w, true)
	if round_ends and w > 2.5:
		ci.draw_circle(a, w * 0.5, col, true, -1.0, true)
		ci.draw_circle(b, w * 0.5, col, true, -1.0, true)


func polyline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w := 2.0) -> void:
	if pts.size() >= 2:
		ci.draw_polyline(pts, col, w, true)


## An arc from angle a0 to a1 (radians, 0 = right, clockwise on screen), with round ends.
func arc(ci: CanvasItem, c: Vector2, radius: float, a0: float, a1: float, col: Color, w := 3.0, round_ends := true) -> void:
	if absf(a1 - a0) < 0.001:
		return
	var n := maxi(int(absf(a1 - a0) * radius / 4.0), 6)
	ci.draw_arc(c, radius, a0, a1, n, col, w, true)
	if round_ends and w > 2.5:
		ci.draw_circle(c + Vector2.from_angle(a0) * radius, w * 0.5, col, true, -1.0, true)
		ci.draw_circle(c + Vector2.from_angle(a1) * radius, w * 0.5, col, true, -1.0, true)


func ring(ci: CanvasItem, c: Vector2, radius: float, col: Color, w := 2.0) -> void:
	if radius > 0.2:
		ci.draw_circle(c, radius, col, false, w, true)


func dot(ci: CanvasItem, c: Vector2, radius: float, col: Color) -> void:
	if radius > 0.1:
		ci.draw_circle(c, radius, col, true, -1.0, true)


## A soft light: for things that are hot right now.
func glow(ci: CanvasItem, c: Vector2, radius: float, col: Color, strength := 1.0) -> void:
	var n := clampi(int(radius / 6.0), 8, 36)        # (enough rings that none of them shows)
	for i in n:
		var k := 1.0 - float(i) / n
		ci.draw_circle(c, radius * (0.15 + 0.85 * k), Color(col, 0.36 / n * strength * col.a), true, -1.0, true)


func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)


## A chevron pointing along `dir` (a unit vector), `size` across.
func chevron(ci: CanvasItem, c: Vector2, size: float, dir: Vector2, col: Color, w := 2.5) -> void:
	var n := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([c - dir * size * 0.3 + n * size * 0.5, c + dir * size * 0.3, c - dir * size * 0.3 - n * size * 0.5])
	ci.draw_polyline(pts, col, w, true)


## A bluefin, `length` long, its nose toward `way` (+1 right, -1 left), turned `rot` radians.
func fish(ci: CanvasItem, c: Vector2, length: float, col: Color, way := 1.0, rot := 0.0) -> void:
	ci.draw_set_transform(c, rot, Vector2(length * way, length))
	var body := PackedVector2Array([Vector2(0.5, 0.0)])
	var n := 8
	for i in range(1, n + 1):
		var u := float(i) / n
		body.append(Vector2(lerpf(0.5, -0.3, u), -maxf(0.16 * pow(sin(PI * pow(u, 0.75)), 0.8), 0.024 if u > 0.5 else 0.0)))
	for i in range(n, 0, -1):
		var u := float(i) / n
		body.append(Vector2(lerpf(0.5, -0.3, u), maxf(0.13 * pow(sin(PI * pow(u, 0.75)), 0.8), 0.024 if u > 0.5 else 0.0)))
	ci.draw_colored_polygon(body, col)
	# the tail's two blades, the fins
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-0.27, -0.024), Vector2(-0.5, -0.24), Vector2(-0.4, 0.0), Vector2(-0.27, 0.024)]), col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-0.27, 0.024), Vector2(-0.4, 0.0), Vector2(-0.5, 0.24)]), col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0.12, -0.13), Vector2(-0.02, -0.28), Vector2(-0.07, -0.12)]), col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0.1, 0.1), Vector2(-0.04, 0.23), Vector2(-0.04, 0.09)]), col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A little boat from the side, `length` long, her bow toward `way`.
func boat(ci: CanvasItem, c: Vector2, length: float, col: Color, way := 1.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2(length * way, length))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-0.5, -0.08), Vector2(0.5, -0.1), Vector2(0.34, 0.12), Vector2(-0.42, 0.12)]), col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-0.18, -0.3), Vector2(0.14, -0.3), Vector2(0.2, -0.1), Vector2(-0.18, -0.1)]), col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A hook, `size` tall.
func hook(ci: CanvasItem, c: Vector2, size: float, col: Color, w := 2.0) -> void:
	var r := size * 0.26
	line(ci, c + Vector2(r, -size * 0.5), c + Vector2(r, size * 0.24), col, w, false)
	arc(ci, c + Vector2(0.0, size * 0.24), r, 0.0, PI * 1.05, col, w, false)
	line(ci, c + Vector2(-r, size * 0.2), c + Vector2(-r * 0.3, size * 0.02), col, w, false)
	ring(ci, c + Vector2(r, -size * 0.5 - w), w * 1.1, col, w * 0.8)


## A screen-space blur in a rounded rectangle, to sit under a panel: add it as a child and give it the panel's rect
## (place()). Falls back to nothing more than its tint if the screen can't be read.
static func blur_rect() -> ColorRect:
	if _blur == null:
		_blur = Shader.new()
		_blur.code = """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec2 size = vec2(100.0, 40.0);
uniform float radius = 16.0;
uniform float lod = 2.6;
uniform float amount = 1.0;
void fragment() {
	vec2 p = (UV - 0.5) * size;
	vec2 q = abs(p) - size * 0.5 + radius;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float m = 1.0 - smoothstep(-1.2, 0.2, d);
	vec3 c = textureLod(screen, SCREEN_UV, lod).rgb;
	COLOR = vec4(c * 0.82, m * amount);
}"""
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _blur
	r.material = m
	return r


static func place(blur: ColorRect, r: Rect2, radius: float, amount := 1.0) -> void:
	blur.position = r.position
	blur.size = r.size
	blur.visible = amount > 0.01
	var m := blur.material as ShaderMaterial
	m.set_shader_parameter("size", r.size)
	m.set_shader_parameter("radius", minf(radius, minf(r.size.x, r.size.y) * 0.5))
	m.set_shader_parameter("amount", amount)


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

## The colour a cue is drawn in.
static func cue_col(cue: int) -> Color:
	match cue:
		HOLD:
			return GO
		TAP, MASH:
			return GOLD
		RELEASE:
			return FOAM
		OFF:
			return CORAL
	return DIM


## One button and what it's asked to do, its middle at `c`, `h` tall: the mouse with its left (`side` 0: A) or right
## (1: B) button lit, or the pad's trigger (RT is A, LT is B), moving the way the cue says; the one word under it.
## `down`: you've got it pressed now.
func button(ci: CanvasItem, c: Vector2, h: float, side: int, cue: int, t: float, down: bool, pad := false, alpha := 1.0) -> void:
	var col := cue_col(cue)
	col.a *= alpha
	var line_col := Color(FOAM, (0.85 if cue != NONE else 0.4) * alpha)
	var w := h * 0.64
	var body := Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
	# how it moves: a hold sinks and stays, a tap bounces, a mash hammers, a release lifts
	var lit := 0.0
	var push := 0.0
	match cue:
		HOLD:
			lit = 1.0
			push = 1.0
		TAP:
			var k := fposmod(t * 2.2, 1.0)
			lit = 1.0 - smoothstep(0.2, 0.7, k) * 0.5
			push = 1.0 - smoothstep(0.0, 0.5, k)
		MASH:
			var k := fposmod(t * 7.0, 1.0)
			lit = 1.0 if k < 0.5 else 0.5
			push = lit
		RELEASE:
			lit = 0.25 + 0.2 * sin(t * 9.0)
			push = 0.0
		OFF:
			lit = 0.85
	var btn: Rect2
	if pad:
		# a trigger: a tall rounded tab that pulls down
		var tw := h * 0.72
		var tr := Rect2(c.x - tw * 0.5, c.y - h * 0.42 + push * h * 0.07, tw, h * 0.74)
		rrect(ci, tr, h * 0.2, Color(col, col.a * lit) if cue != NONE else Color(TRACK, TRACK.a * alpha), line_col, 1.5)
		text(ci, tr.get_center(), "RT" if side == 0 else "LT", h * 0.3, Color(DEEP if lit > 0.6 and cue != NONE else FOAM, alpha), 0, 700, 0.0, false)
		btn = tr
	else:
		rrect(ci, body, w * 0.46, Color(DEEP, 0.55 * alpha), line_col, 1.5)
		var bh := h * 0.42
		var half := w * 0.5
		btn = Rect2(body.position.x + (0.0 if side == 0 else half), body.position.y, half, bh)
		if cue != NONE:
			# the lit button: the top corner of the mouse, rounded with it
			var inset := 2.5 + push * 1.0
			var r := Rect2(btn.position + Vector2(inset if side == 0 else 1.0, inset), btn.size - Vector2(inset + 1.0, inset))
			_sb.bg_color = Color(col, col.a * lit)
			_sb.set_corner_radius_all(3)
			if side == 0:
				_sb.corner_radius_top_left = int(w * 0.4)
			else:
				_sb.corner_radius_top_right = int(w * 0.4)
			_sb.set_border_width_all(0)
			_sb.shadow_size = 0
			_sb.draw_center = true
			_sb.anti_aliasing = true
			ci.draw_style_box(_sb, r)
		line(ci, Vector2(body.position.x + 3.0, body.position.y + bh), Vector2(body.end.x - 3.0, body.position.y + bh), line_col, 1.2, false)
		line(ci, Vector2(c.x, body.position.y + 2.0), Vector2(c.x, body.position.y + bh), line_col, 1.2, false)
	var bc := btn.get_center()
	if down:
		# (you've got it pressed: it lights)
		rrect(ci, btn.grow(-2.5), 4.0, Color(FOAM, 0.4 * alpha))
	# the motion round it
	var above := Vector2(bc.x, body.position.y - h * 0.18)
	match cue:
		HOLD:
			var k := 0.5 + 0.5 * sin(t * 4.0)
			chevron(ci, above + Vector2(0.0, k * 2.0), h * 0.2, Vector2.DOWN, col, 2.5)
			chevron(ci, above - Vector2(0.0, h * 0.13 - k * 2.0), h * 0.2, Vector2.DOWN, Color(col, col.a * 0.45), 2.5)
		TAP, MASH:
			# (a finger coming down on it and off again: once for a tap, over and over for a mash)
			var k := fposmod(t * (2.2 if cue == TAP else 7.0), 1.0)
			var bounce := absf(sin(PI * k)) * h * 0.14
			chevron(ci, above - Vector2(0.0, bounce), h * 0.2, Vector2.DOWN, col, 2.5)
			if cue == MASH:
				chevron(ci, above - Vector2(0.0, bounce + h * 0.13), h * 0.2, Vector2.DOWN, Color(col, col.a * 0.6), 2.5)
		RELEASE:
			var k := fposmod(t * 1.8, 1.0)
			chevron(ci, above - Vector2(0.0, k * h * 0.16), h * 0.2, Vector2.UP, Color(col, col.a * (1.0 - k * 0.7)), 2.5)
		OFF:
			var x := h * 0.11
			line(ci, bc - Vector2(x, x), bc + Vector2(x, x), Color(DEEP, alpha), 3.0)
			line(ci, bc - Vector2(x, -x), bc + Vector2(x, -x), Color(DEEP, alpha), 3.0)
	if WORDS.has(cue):
		var word: String = WORDS[cue]
		var size := h * 0.24
		size *= minf(1.0, h * 1.25 / maxf(text_w(word, size, 700, 1.0), 1.0))       # (fitted to the chip it's on)
		text(ci, Vector2(c.x, body.end.y + h * 0.26), word, size, col, 0, 700, 1.0)
