extends Control
## The fight, read at a glance (rods.gd feeds it every frame while you've a fish on; it's gone the rest of the time).
## Bottom middle, over where the hotbar sits:
## - the tension arc, bent like the rod: green, amber, red; the needle is the line's tension, the tick where the drag
##   slips (past it the reel screams); held in the red it shakes and the screen's edges pulse
## - in its middle, the line out (metres, an arrow: red while it takes line, green while you win it) inside a ring of
##   what's left on the spool
## - left, the fish: how much fight it's got and a picture of what it's doing (running, sounding, circling, jumping)
## - right, the hook: how well it's holding, flashing as it works loose
## - over the arc, what to do now, as a mouse with the button lit: hands off while it runs, pump when the reel grinds,
##   tip down when it jumps, wheel down (ease the drag) in the red
## And the moments: FISH ON when it takes, a crack and red when it's lost.

const GREEN := Color(0.45, 0.95, 0.55)
const AMBER := Color(1.0, 0.75, 0.3)
const RED := Color(1.0, 0.3, 0.25)
const INK := Color(0.03, 0.05, 0.07, 0.62)
const PALE := Color(0.95, 0.93, 0.86)
const R := 92.0                       # the arc's radius (px)

var _on := false
var _a := 0.0                         # how much it's showing (fades in and out)
var _s := {}                          # the fight's state this frame
var _t := 0.0
var _tension := 0.0                   # (eased, for the needle)
var _line := 0.0
var _gain := 0.0                      # m/s won back (+) or given (-), eased
var _banner := 0.0                    # FISH ON, counting down
var _banner_text := ""
var _banner_col := PALE
var _edge: ColorRect


func _init() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -150.0
	offset_bottom = -150.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# the red at the screen's edges, held in the red too long
	_edge = ColorRect.new()
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float k = 0.0;
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float e = smoothstep(0.55, 1.05, max(d.x, d.y * 1.15));
	COLOR = vec4(0.85, 0.08, 0.05, e * k);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_edge.material = m
	get_parent().add_child.call_deferred(_edge)


## This frame's fight (or {} for none): tension, danger (0..1 toward parting), drag, line_out, spool (0..1 used),
## energy, hold, move, slipping, grinding, airborne.
func show_fight(s: Dictionary) -> void:
	if s.is_empty():
		_on = false
		return
	if not _on:
		_line = float(s.get("line_out", 0.0))
		_banner_text = "FISH ON!"
		_banner_col = AMBER
		_banner = 1.8
	_on = true
	_s = s


## The fish is gone: `why` across the middle a moment, in red.
func lost(why: String) -> void:
	_banner_text = why.trim_suffix(".").to_upper()
	_banner_col = RED
	_banner = 2.2
	_on = false


## Up alongside: a moment of green.
func won() -> void:
	_banner_text = "BOATSIDE"
	_banner_col = GREEN
	_banner = 2.0
	_on = false


func _process(delta: float) -> void:
	_t += delta
	_banner = maxf(_banner - delta, 0.0)
	_a = move_toward(_a, 1.0 if _on else 0.0, delta * (4.0 if _on else 2.0))
	if _on:
		_tension = lerpf(_tension, float(_s.get("tension", 0.0)), minf(1.0, delta * 14.0))
		var out := float(_s.get("line_out", 0.0))
		if delta > 0.0:
			_gain = lerpf(_gain, (_line - out) / delta, minf(1.0, delta * 2.5))
		_line = out
	var danger := float(_s.get("danger", 0.0)) if _on else 0.0
	if _edge and _edge.material:
		var pulse := 0.5 + 0.5 * sin(_t * 14.0)
		(_edge.material as ShaderMaterial).set_shader_parameter("k",
				clampf(danger * 0.9 + (0.25 if _tension > 0.9 else 0.0) * pulse, 0.0, 0.9) * _a)
	queue_redraw()


func _draw() -> void:
	if _banner > 0.0:
		_draw_banner()
	if _a <= 0.01:
		return
	var a := _a
	var t := _tension
	var red := t > 0.9
	var shake := Vector2(sin(_t * 61.0), cos(_t * 47.0)) * (3.0 * smoothstep(0.85, 1.05, t))
	var c := Vector2(0.0, 0.0) + shake
	# a dark plate behind it all
	draw_circle(c, R + 22.0, Color(INK, INK.a * a))
	# the arc: from lower left round over the top to lower right (the rod bending as the tension rises)
	var a0 := PI * 0.8
	var a1 := PI * 2.2
	var zones := [[0.0, 0.6, GREEN], [0.6, 0.85, AMBER], [0.85, 1.0, RED]]
	for z: Array in zones:
		draw_arc(c, R, lerpf(a0, a1, z[0]), lerpf(a0, a1, z[1]), 24, Color(z[2] as Color, 0.22 * a), 14.0, true)
	var lit := GREEN if t < 0.6 else (AMBER if t < 0.85 else RED)
	draw_arc(c, R, a0, lerpf(a0, a1, clampf(t, 0.0, 1.0)), 48, Color(lit, 0.95 * a), 14.0, true)
	# the drag's tick: past it the drag slips
	var drag := clampf(float(_s.get("drag", 0.72)), 0.0, 1.0)
	var da := lerpf(a0, a1, drag)
	draw_line(c + Vector2.from_angle(da) * (R - 13.0), c + Vector2.from_angle(da) * (R + 13.0), Color(PALE, 0.9 * a), 3.0)
	# the needle
	var na := lerpf(a0, a1, clampf(t, 0.0, 1.05))
	draw_line(c + Vector2.from_angle(na) * 18.0, c + Vector2.from_angle(na) * (R + 6.0), Color(PALE, a), 3.0, true)
	draw_circle(c, 6.0, Color(PALE, a))
	# the drag's notches under it (free, light, strike, full)
	var detents := [0.0, 0.45, 0.72, 0.95]
	for i in 4:
		var on := absf(float(detents[i]) - drag) < 0.05
		var p := c + Vector2(-27.0 + i * 18.0, R * 0.55)
		draw_rect(Rect2(p - Vector2(6, 4), Vector2(12, 8)), Color(AMBER if on else PALE, (0.95 if on else 0.3) * a))
	# the line out, and which way it's going
	var font := get_theme_default_font()
	var out := roundi(_line)
	draw_string(font, c + Vector2(-60, 14), "%d" % out, HORIZONTAL_ALIGNMENT_CENTER, 120, 34, Color(PALE, a))
	draw_string(font, c + Vector2(-60, 34), "m", HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(PALE, 0.6 * a))
	if absf(_gain) > 0.3:
		var up := _gain > 0.0
		var col := GREEN if up else RED
		var ax := c + Vector2(44.0, 2.0)
		var tri := PackedVector2Array([ax + Vector2(-7, 5 if up else -5), ax + Vector2(7, 5 if up else -5),
				ax + Vector2(0, -7 if up else 7)])
		draw_colored_polygon(tri, Color(col, a))
	# what's left on the spool: a thin inner ring, draining
	var spool := clampf(1.0 - float(_s.get("spool", 0.0)), 0.0, 1.0)
	var spool_col := PALE if spool > 0.25 else RED
	draw_arc(c, R - 22.0, -PI * 0.5, -PI * 0.5 + TAU * spool, 48, Color(spool_col, 0.45 * a), 3.0, true)
	# the fish: its fight left, and what it's doing
	_draw_fish(c + Vector2(-R - 58.0, -10.0), a)
	# the hook
	_draw_hook(c + Vector2(R + 58.0, -10.0), a)
	# what to do now
	_draw_do(c + Vector2(0.0, -R - 46.0), a)


func _draw_fish(at: Vector2, a: float) -> void:
	var e := clampf(float(_s.get("energy", 1.0)), 0.0, 1.0)
	# a little tuna: body, tail
	var col := Color(0.6, 0.78, 0.95, a)
	var body := PackedVector2Array([at + Vector2(-16, 0), at + Vector2(-6, -7), at + Vector2(10, -5),
			at + Vector2(16, 0), at + Vector2(10, 5), at + Vector2(-6, 7)])
	draw_colored_polygon(body, col)
	draw_colored_polygon(PackedVector2Array([at + Vector2(14, 0), at + Vector2(24, -8), at + Vector2(24, 8)]), col)
	# its fight left: a bar under it, draining
	var bar := Rect2(at + Vector2(-26, 16), Vector2(52, 7))
	draw_rect(bar, Color(0, 0, 0, 0.5 * a))
	var ec := GREEN if e < 0.25 else (AMBER if e < 0.6 else Color(0.6, 0.78, 0.95))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * e, bar.size.y)), Color(ec, a))
	# what it's doing
	var m := str(_s.get("move", ""))
	var p := at + Vector2(0, -26)
	var w := Color(PALE, 0.85 * a)
	match m:
		"run", "surge":
			draw_line(p + Vector2(-12, 0), p + Vector2(10, 0), w, 3.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(10, -6), p + Vector2(18, 0), p + Vector2(10, 6)]), w)
		"sound", "dog":
			draw_line(p + Vector2(0, -10), p + Vector2(0, 8), w, 3.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 8), p + Vector2(6, 8), p + Vector2(0, 15)]), w)
		"circle", "spiral":
			draw_arc(p, 9.0, 0.0, PI * 1.6, 16, w, 3.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(9, -1), p + Vector2(4, -8), p + Vector2(14, -8)]), w)
		"jump":
			draw_arc(p + Vector2(0, 8), 12.0, PI, TAU, 16, Color(AMBER, a), 3.0)
		"shake":
			for k in 3:
				draw_line(p + Vector2(-10 + k * 8, -6), p + Vector2(-6 + k * 8, 6), w, 2.5)


func _draw_hook(at: Vector2, a: float) -> void:
	var h := clampf(float(_s.get("hold", 1.0)), 0.0, 1.0)
	var flash := h < 0.4 and fmod(_t, 0.4) < 0.2
	var col := RED if flash else (PALE if h > 0.6 else AMBER)
	# the hook: a shank and a bend with its point
	draw_line(at + Vector2(4, -14), at + Vector2(4, 6), Color(col, a), 3.0)
	draw_arc(at + Vector2(-2, 6), 6.0, 0.0, PI, 12, Color(col, a), 3.0)
	draw_line(at + Vector2(-8, 6), at + Vector2(-8, 0), Color(col, a), 3.0)
	var bar := Rect2(at + Vector2(-26, 16), Vector2(52, 7))
	draw_rect(bar, Color(0, 0, 0, 0.5 * a))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * h, bar.size.y)), Color(col, a))


## A mouse with the button that matters lit (or crossed out): what to do right now.
func _draw_do(at: Vector2, a: float) -> void:
	var t := float(_s.get("tension", 0.0))
	var what := "crank"
	if bool(_s.get("airborne", false)):
		what = "tip_down"
	elif t > 0.92:
		what = "ease"
	elif bool(_s.get("slipping", false)):
		what = "hands_off"
	elif bool(_s.get("grinding", false)):
		what = "pump"
	var pulse := 0.75 + 0.25 * sin(_t * 8.0)
	var body := Rect2(at - Vector2(13, 18), Vector2(26, 36))
	var base := Color(PALE, 0.35 * a)
	draw_rect(body, Color(INK, INK.a * a))
	draw_rect(body, base, false, 2.0)
	draw_line(at + Vector2(0, -18), at + Vector2(0, -4), base, 2.0)
	var left := Rect2(at + Vector2(-12, -17), Vector2(11, 13))
	var right := Rect2(at + Vector2(1, -17), Vector2(11, 13))
	match what:
		"crank":
			draw_rect(left, Color(GREEN, 0.8 * a))
		"pump":
			# lift (right), then wind as you drop (left): both, taking turns
			var first := fmod(_t, 1.6) < 0.8
			draw_rect(right if first else left, Color(Color(0.4, 0.85, 1.0), pulse * a))
			draw_line(at + Vector2(22, 10), at + Vector2(22, -14), Color(Color(0.4, 0.85, 1.0), a), 3.0)
			draw_colored_polygon(PackedVector2Array([at + Vector2(16, -10), at + Vector2(28, -10), at + Vector2(22, -18)]),
					Color(Color(0.4, 0.85, 1.0), a))
		"hands_off":
			draw_rect(left, Color(AMBER, 0.35 * a))
			draw_line(at + Vector2(-18, -20), at + Vector2(18, 20), Color(AMBER, pulse * a), 3.0)
		"ease":
			# the wheel, rolled down: ease the drag
			draw_rect(Rect2(at + Vector2(-2, -15), Vector2(4, 9)), Color(RED, pulse * a))
			draw_colored_polygon(PackedVector2Array([at + Vector2(16, -6), at + Vector2(28, -6), at + Vector2(22, 4)]),
					Color(RED, pulse * a))
		"tip_down":
			draw_line(at + Vector2(-26, -16), at + Vector2(-26, 8), Color(AMBER, pulse * a), 3.0)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-32, 4), at + Vector2(-20, 4), at + Vector2(-26, 14)]),
					Color(AMBER, pulse * a))


func _draw_banner() -> void:
	var k := clampf(_banner, 0.0, 1.0)
	var slide := (1.0 - smoothstep(0.0, 0.25, 1.8 - _banner)) * 40.0 if _banner_col == AMBER else 0.0
	var font := get_theme_default_font()
	var y := -300.0 - slide
	draw_string_outline(font, Vector2(-300, y), _banner_text, HORIZONTAL_ALIGNMENT_CENTER, 600, 46, 10,
			Color(0, 0, 0, 0.7 * k))
	draw_string(font, Vector2(-300, y), _banner_text, HORIZONTAL_ALIGNMENT_CENTER, 600, 46, Color(_banner_col, k))
