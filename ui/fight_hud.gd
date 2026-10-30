extends Control
## The fight, read at a glance (rods.gd feeds it every frame while you've a fish on; it's gone the rest of the time).
## Bottom middle, three rows, every one labelled, nothing to decode:
## - on top, what to do now, in words on a dark plate with the mouse beside it (the button lit, which way to move it):
##   HOLD LEFT MOUSE: REEL HIM IN; HE'S RUNNING: LET GO; TOO TIGHT: SCROLL DOWN; GRINDING: PUMP; HE'S JUMPING: TIP DOWN;
##   in the death spiral, COMING UP: REEL / GOING UNDER: LET HIM. Its colour is how urgent: green, blue, amber, red.
## - the TENSION bar: how hard the line's pulling, green, amber, red (in the red too long and it parts: it shakes, and
##   the screen's edges pulse), with the DRAG mark on it, named (past the mark the drag slips and the reel screams)
## - under it, small: FISH (how much fight he's got left), HOOK (how well it's holding, flashing as it works loose),
##   and LINE (metres out: red while he takes it, green while you win it back; red near the end of the spool)
## And the moments: FISH ON when it takes; when it's lost, why in red and under it what would have saved it (a first
## fight's a lot to take in: the words are the teacher). While the first fish's lesson is up (ui/fight_tutor.gd,
## `teaching`) its card says what to do, so the words row stands down.

const GREEN := Color(0.45, 0.95, 0.55)
const AMBER := Color(1.0, 0.75, 0.3)
const RED := Color(1.0, 0.3, 0.25)
const BLUE := Color(0.4, 0.85, 1.0)
const INK := Color(0.02, 0.03, 0.05, 0.8)
const PALE := Color(0.95, 0.93, 0.86)
const DIM := Color(0.62, 0.66, 0.68)
const W := 420.0                      # the tension bar's width (px)
const U := 2.0                        # px a pixel of the little mouse
## The drag lever's notches (tuna/fight.gd's DETENTS), by name.
const DRAG_NAMES := ["FREE", "LIGHT", "STRIKE", "FULL"]

var teaching := false
var _on := false
var _a := 0.0                         # how much it's showing (fades in and out)
var _s := {}                          # the fight's state this frame
var _t := 0.0
var _tension := 0.0                   # (eased, for the bar)
var _line := 0.0
var _gain := 0.0                      # m/s won back (+) or given (-), eased
var _words_a := 1.0
var _banner := 0.0                    # FISH ON, counting down
var _banner_text := ""
var _banner_col := PALE
var _edge: ColorRect
var _lesson := ""                     # under a loss: what would have saved it

## What each loss means, and what to do about it next time (rods.gd's WHY, said plainly).
const LESSONS := {
	"Thrown on the jump.": "HE JUMPED WITH THE ROD UP. WHEN HE JUMPS, MOUSE DOWN: DROP THE TIP.",
	"Hook pulled.": "THE HOOK WORKED LOOSE. DON'T LET THE LINE GO SLACK: KEEP REELING WHEN HE COMES AT YOU.",
	"Line parted.": "TOO TIGHT. LET GO WHILE HE RUNS, SCROLL DOWN TO EASE THE DRAG IN THE RED.",
	"Line parted on the rail.": "THE LINE RUBBED THE BOAT. CAPTAIN: KEEP THE STERN TO THE FISH.",
	"Chafed through on the hull.": "THE LINE RUBBED THE HULL. CAPTAIN: KEEP THE STERN TO THE FISH.",
	"Spooled.": "HE TOOK ALL THE LINE. CAPTAIN: BACK DOWN TOWARD HIM (S).",
	"Cut on the props.": "THE LINE WENT IN THE PROPS. CAPTAIN: KEEP HIM OFF THE STERN, IN NEUTRAL.",
	"Lines tangled and parted.": "TWO LINES CROSSED. REEL THE OTHER RODS IN WHILE YOU FIGHT ONE.",
	"Cut off.": "SOMETHING CUT THE LINE. THE OTHER BOAT CROSSING YOUR STERN?",
}


func _init() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
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


## This frame's fight (or {} for none): tension (all the line's taking: 1 parts it), danger (0..1 toward parting),
## drag, line_out, spool (0..1 used), energy, hold, move, slipping, grinding, airborne, under (the spiral's going
## under), paused.
func show_fight(s: Dictionary) -> void:
	if s.is_empty():
		_on = false
		return
	if not _on:
		_line = float(s.get("line_out", 0.0))
		_lesson = ""
		_banner_text = "FISH ON!"
		_banner_col = AMBER
		_banner = 1.8
	_on = true
	_s = s


## The fish is gone: `why` across the middle a moment, in red.
func lost(why: String) -> void:
	_banner_text = why.trim_suffix(".").to_upper()
	_banner_col = RED
	_lesson = str(LESSONS.get(why, ""))
	_banner = 6.0 if not _lesson.is_empty() else 2.2
	_on = false


## Up alongside: a moment of green.
func won() -> void:
	_banner_text = "BOATSIDE!"
	_lesson = "HARPOON HIM, THEN HAUL HIM ABOARD."
	_banner_col = GREEN
	_banner = 2.0
	_on = false


func _process(delta: float) -> void:
	_t += delta
	_banner = maxf(_banner - delta, 0.0)
	_a = move_toward(_a, 1.0 if _on else 0.0, delta * (4.0 if _on else 2.0))
	_words_a = move_toward(_words_a, 0.0 if teaching else 1.0, delta * 4.0)
	if _on:
		_tension = lerpf(_tension, float(_s.get("tension", 0.0)), minf(1.0, delta * 14.0))
		var out := float(_s.get("line_out", 0.0))
		if delta > 0.0 and not bool(_s.get("paused", false)):
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
	var font := get_theme_default_font()
	var t := _tension
	var shake := (Vector2(sin(_t * 61.0), cos(_t * 47.0)) * 3.0 * smoothstep(0.85, 1.05, t)).round()
	var x0 := -W * 0.5
	# a dark plate behind the bars
	draw_rect(Rect2(Vector2(x0 - 18.0, -150.0), Vector2(W + 36.0, 112.0)), Color(INK, INK.a * a))
	# what to do now
	if _words_a > 0.01:
		_draw_do(Vector2(0.0, -186.0), a * _words_a)
	# TENSION, and the bar: green, amber, red, filled to how hard it's pulling
	var bar := Rect2(Vector2(x0, -122.0) + shake, Vector2(W, 18.0))
	var lit := GREEN if t < 0.6 else (AMBER if t < 0.85 else RED)
	_text(font, Vector2(x0, -128.0), "TENSION", 12, Color(PALE, 0.9 * a))
	var word := "SNAPPING!" if t > 0.9 else ("TIGHT" if t >= 0.6 else "")
	if not word.is_empty():
		var ww := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_text(font, Vector2(x0 + W - ww, -128.0), word, 12, Color(lit, a))
	var zones := [[0.0, 0.6, GREEN], [0.6, 0.85, AMBER], [0.85, 1.0, RED]]
	for z: Array in zones:
		draw_rect(Rect2(bar.position + Vector2(roundf(W * float(z[0])), 0.0),
				Vector2(roundf(W * (float(z[1]) - float(z[0]))), bar.size.y)), Color(z[2] as Color, 0.2 * a))
	draw_rect(Rect2(bar.position, Vector2(roundf(W * clampf(t, 0.0, 1.0)), bar.size.y)), Color(lit, 0.95 * a))
	# the drag mark: past it the drag slips; named under it
	var drag := clampf(float(_s.get("drag", 0.72)), 0.0, 1.0)
	var dx := roundf(x0 + W * drag)
	draw_rect(Rect2(Vector2(dx - 1.0, bar.position.y - 4.0), Vector2(3.0, bar.size.y + 8.0)), Color(PALE, a))
	var notch := 0
	for k in 4:
		if absf([0.0, 0.45, 0.72, 0.95][k] - drag) < 0.05:
			notch = k
	var dname := "DRAG: %s" % DRAG_NAMES[notch]
	var dw := font.get_string_size(dname, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_text(font, Vector2(clampf(dx - dw * 0.5, x0, x0 + W - dw), -86.0), dname, 12, Color(PALE, 0.9 * a))
	# FISH, HOOK, LINE
	var e := clampf(float(_s.get("energy", 1.0)), 0.0, 1.0)
	var ec := GREEN if e < 0.25 else (AMBER if e < 0.6 else BLUE)
	_meter(font, Vector2(x0, -56.0), "FISH", e, ec, a)
	var h := clampf(float(_s.get("hold", 1.0)), 0.0, 1.0)
	var flash := h < 0.4 and fmod(_t, 0.4) < 0.2
	_meter(font, Vector2(x0 + 150.0, -56.0), "HOOK", h, RED if flash else (PALE if h > 0.6 else AMBER), a)
	var spool := float(_s.get("spool", 0.0))
	var lc := RED if spool > 0.75 or _gain < -0.3 else (GREEN if _gain > 0.3 else PALE)
	var ltxt := "LINE %d M" % roundi(_line) + ("  LOW!" if spool > 0.75 else "")
	_text(font, Vector2(x0 + 300.0, -48.0), ltxt, 12, Color(lc, a))


## A small labelled bar: LABEL [####    ].
func _meter(font: Font, at: Vector2, label: String, v: float, col: Color, a: float) -> void:
	_text(font, at + Vector2(0.0, 8.0), label, 12, Color(PALE, 0.9 * a))
	var bar := Rect2(at + Vector2(42.0, 0.0), Vector2(84.0, 10.0))
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.55 * a))
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * v), bar.size.y)), Color(col, a))


## What to do right now: the words on a plate, coloured by how urgent, the mouse beside them with the button lit.
func _draw_do(at: Vector2, a: float) -> void:
	var t := float(_s.get("tension", 0.0))
	var m := str(_s.get("move", ""))
	var what := "crank"
	if bool(_s.get("airborne", false)):
		what = "tip_down"
	elif t > 0.9:
		what = "ease"
	elif bool(_s.get("slipping", false)):
		what = "hands_off"
	elif bool(_s.get("grinding", false)):
		what = "pump"
	elif m == "spiral" and bool(_s.get("under", false)):
		what = "under"
	var words := {"crank": "HOLD LEFT MOUSE: REEL HIM IN",
			"pump": "GRINDING: PUMP! RIGHT MOUSE LIFTS, LEFT WINDS AS YOU DROP",
			"hands_off": "HE'S RUNNING: LET GO, LET HIM TAKE LINE",
			"ease": "TOO TIGHT! LET GO, SCROLL DOWN: EASE THE DRAG",
			"tip_down": "HE'S JUMPING! MOUSE DOWN: DROP THE TIP",
			"under": "HE'S GOING UNDER: LET HIM"}[what] as String
	var col := {"crank": GREEN, "pump": BLUE, "hands_off": AMBER, "ease": RED, "tip_down": AMBER,
			"under": AMBER}[what] as Color
	var icon := {"crank": "left", "pump": "pump", "hands_off": "none", "ease": "wheel_down", "tip_down": "down",
			"under": "none"}[what] as String
	if what == "crank" and m == "spiral":
		words = "HE'S COMING UP: REEL"
	elif what == "crank" and m == "jump":
		words = "HE'S COMING UP TO JUMP! GET READY: MOUSE DOWN"
		col = AMBER
		icon = "down"
	var pulse := 0.75 + 0.25 * sin(_t * 8.0)
	var font := get_theme_default_font()
	var tw := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var iw := 18.0 * U
	var left := roundf(at.x - (tw + iw) * 0.5)
	draw_rect(Rect2(Vector2(left - 12.0, at.y - 22.0), Vector2(tw + iw + 24.0, 44.0)), Color(INK, INK.a * a))
	_mouse(Vector2(left, at.y - 16.0), icon, col, a, pulse if what != "crank" else 1.0)
	_text(font, Vector2(left + iw, at.y + 9.0), words, 18, Color(col, (pulse if what != "crank" else 0.95) * a))


## The little mouse in whole pixels: the button lit (pump: right then left, taking turns), crossed out for hands off,
## an arrow for which way.
func _mouse(o: Vector2, kind: String, col: Color, a: float, pulse: float) -> void:
	var line := Color(PALE, 0.7 * a)
	var lit := Color(col, pulse * a)
	_box(o, Vector2(10, 16), line)
	_px(o, Vector2(5, 1), Vector2(0.5, 5), line)
	_px(o, Vector2(1, 6), Vector2(8, 0.5), line)
	match kind:
		"left":
			_px(o, Vector2(1, 1), Vector2(4, 5), lit)
		"pump":
			var first := fmod(_t, 1.6) < 0.8
			_px(o, Vector2(5.5, 1) if first else Vector2(1, 1), Vector2(3.5 if first else 4.0, 5), lit)
			_arrow(o + Vector2(12, 2) * U, -1.0 if first else 1.0, lit)
		"wheel_down":
			_px(o, Vector2(4.5, 1.5), Vector2(1, 3), lit)
			_arrow(o + Vector2(12, 2) * U, 1.0, lit)
		"down":
			_arrow(o + Vector2(12, 2) * U, 1.0, lit)
		"none":
			for k in 9:
				_px(o, Vector2(0.5 + k, 0.5 + k * 0.6), Vector2(1, 1), lit)
				_px(o, Vector2(8.5 - k, 0.5 + k * 0.6), Vector2(1, 1), lit)


func _px(o: Vector2, p: Vector2, s: Vector2, col: Color) -> void:
	draw_rect(Rect2((o + p * U).round(), (s * U).round().max(Vector2.ONE)), col)


func _box(o: Vector2, s: Vector2, col: Color) -> void:
	_px(o, Vector2(0, 0), Vector2(s.x, 1), col)
	_px(o, Vector2(0, s.y - 1), Vector2(s.x, 1), col)
	_px(o, Vector2(0, 0), Vector2(1, s.y), col)
	_px(o, Vector2(s.x - 1, 0), Vector2(1, s.y), col)


## An arrow 5 wide and 12 tall, pointing down (`way` 1) or up (-1).
func _arrow(o: Vector2, way: float, col: Color) -> void:
	_px(o, Vector2(2, 0 if way > 0.0 else 3), Vector2(1, 9), col)
	for k in 3:
		_px(o, Vector2(k, 9.0 + k if way > 0.0 else 2.0 - k), Vector2(5 - 2 * k, 1), col)


func _text(font: Font, at: Vector2, text: String, px: int, col: Color) -> void:
	draw_string(font, at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw_banner() -> void:
	var k := clampf(_banner, 0.0, 1.0)
	var slide := (1.0 - smoothstep(0.0, 0.25, 1.8 - _banner)) * 40.0 if _banner_col == AMBER else 0.0
	var font := get_theme_default_font()
	var y := roundf(-330.0 - slide)
	var w := font.get_string_size(_banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	draw_rect(Rect2(Vector2(roundf(-w * 0.5) - 18.0, y - 42.0), Vector2(w + 36.0, 54.0)), Color(INK, INK.a * k))
	_text(font, Vector2(-w * 0.5, y), _banner_text, 36, Color(_banner_col, k))
	if not _lesson.is_empty() and _banner_col != AMBER:
		_plate(Vector2(0, y + 36), _lesson, Color(PALE, k), k)


## Words on a dark plate, centred on `at` (the pixel font reads cleanest on a solid ground, not outlined).
func _plate(at: Vector2, text: String, col: Color, a: float) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var x := roundf(at.x - w * 0.5)
	draw_rect(Rect2(Vector2(x - 12.0, at.y - 22.0), Vector2(w + 24.0, 34.0)), Color(INK, INK.a * a))
	_text(font, Vector2(x, at.y), text, 18, col)
