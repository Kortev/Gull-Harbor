extends Control
## The fight, read at a glance (rods.gd feeds it every frame while you've a fish on; it's gone the rest of the time).
## Bottom middle, the tension bar with its GREEN band and the needle, KEEP IT IN THE GREEN over it; above it one line
## saying what to do right now (HOLD LEFT MOUSE: REEL, HE'S RUNNING! LET GO, HE'S CHARGING THE BOAT! REEL, REEL!,
## HE'S GONE UNDER THE BOAT: CAPTAIN, SWING HER, ARMS GONE! ...), coloured by how urgent, a little mouse beside it
## with the button lit or crossed out; under the bar how much fight he's got left, the line out, your ARMS and how
## square on him you are. To the bar's right, her from above, bow up, and where he is round her: the green astern is
## where you can lift him, the red forward of her beam is where the line's on her hull (tuna/fight.gd's angle_k and
## side_rub). Over it all, while other lines are still out, a plate: REEL THE OTHER LINES IN!, red once he's heading
## for one. Too slack or too tight for long and the screen's edges pulse red. And the moments: FISH ON when it takes;
## when it's lost, why in red and under it what would have saved it. While the first fish's lesson is up
## (ui/fight_tutor.gd, `teaching`) its card does the talking, so the words line stands down, and the bar glows when the
## lesson's about it (`highlight`).

const Fight := preload("res://tuna/fight.gd")
const GREEN := Color(0.45, 0.95, 0.55)
const AMBER := Color(1.0, 0.75, 0.3)
const RED := Color(1.0, 0.3, 0.25)
const BLUE := Color(0.4, 0.85, 1.0)
const INK := Color(0.02, 0.03, 0.05, 0.8)
const PALE := Color(0.95, 0.93, 0.86)
const W := 420.0                      # the bar's width (px)
const U := 2.0                        # px a pixel of the little mouse
## The bar runs from slack (0) to past parting (FULL).
const FULL := 1.1

var teaching := false
var highlight := false
var _on := false
var _a := 0.0                         # how much it's showing (fades in and out)
var _s := {}                          # the fight's state this frame
var _t := 0.0
var _tension := 0.0                   # (eased, for the needle)
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
	"Thrown on the jump.": "YOU REELED WHILE HE JUMPED. WHEN HE JUMPS, LET GO.",
	"Hook pulled.": "THE LINE WENT SLACK. REEL TO KEEP THE NEEDLE IN THE GREEN.",
	"Line parted.": "TOO TIGHT TOO LONG. IN THE RED, OR WHEN HE RUNS: LET GO.",
	"Line parted on the rail.": "THE LINE RUBBED THE BOAT. CAPTAIN: KEEP THE STERN TO THE FISH (A/D).",
	"Chafed through on the hull.": "HE GOT UNDER THE BOAT. CAPTAIN: STERN TO HIM (A/D). ALONE: ROD IN THE HOLDER, STEER.",
	"Spooled.": "HE TOOK ALL THE LINE. REEL IN THE GREEN BETWEEN RUNS. CAPTAIN: BACK DOWN TOWARD HIM (S).",
	"Cut on the props.": "THE LINE WENT IN THE PROPS. CAPTAIN: KEEP HIM OFF THE STERN, IN NEUTRAL.",
	"Lines tangled and parted.": "HE CROSSED A LINE LEFT OUT. FISH ON: E ON EVERY OTHER ROD, REEL THEM IN.",
}


func _init() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# the red at the screen's edges, too slack or too tight too long
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


## This frame's fight (or {} for none): tension (the needle), slack_t and red_t (s too slack, too tight), line_out,
## energy, move, slipping (he's running), airborne, reeling, paused.
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
	var danger := 0.0
	if _on:
		danger = maxf(float(_s.get("red_t", 0.0)) / Fight.BREAK_HOLD, float(_s.get("slack_t", 0.0)) / Fight.SLACK_HOLD)
	if _edge and _edge.material:
		var pulse := 0.5 + 0.5 * sin(_t * 14.0)
		(_edge.material as ShaderMaterial).set_shader_parameter("k", clampf(danger, 0.0, 1.0) * 0.8 * pulse * _a)
	queue_redraw()


func _draw() -> void:
	if _banner > 0.0:
		_draw_banner()
	if _a <= 0.01:
		return
	var a := _a
	var font := get_theme_default_font()
	var t := _tension
	var shake := (Vector2(sin(_t * 61.0), cos(_t * 47.0)) * 3.0 * smoothstep(Fight.RED, 1.05, t)).round()
	var x0 := -W * 0.5
	draw_rect(Rect2(Vector2(x0 - 18.0, -138.0), Vector2(W + 36.0, 122.0)), Color(INK, INK.a * a))
	_draw_round(Vector2(x0 + W + 26.0, -138.0), a)
	if _words_a > 0.01:
		_draw_do(Vector2(0.0, -172.0), a * _words_a)
		_draw_lines(Vector2(0.0, -218.0), a * _words_a)
	# the bar: slack, the green band, the red; the needle
	var bar := Rect2(Vector2(x0, -108.0) + shake, Vector2(W, 24.0))
	var g0 := roundf(W * Fight.GREEN_LO / FULL)
	var g1 := roundf(W * Fight.GREEN_HI / FULL)
	var r0 := roundf(W * Fight.RED / FULL)
	var sl := roundf(W * Fight.SLACK / FULL)
	var bands := [[0.0, sl, RED, 0.35], [sl, g0, AMBER, 0.25], [g0, g1, GREEN, 0.7], [g1, r0, AMBER, 0.25],
			[r0, W, RED, 0.45]]
	for z: Array in bands:
		draw_rect(Rect2(bar.position + Vector2(float(z[0]), 0.0), Vector2(float(z[1]) - float(z[0]), bar.size.y)),
				Color(z[2] as Color, float(z[3]) * a))
	var label := "KEEP IT IN THE GREEN"
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_text(font, Vector2(x0 + (g0 + g1) * 0.5 - lw * 0.5, -116.0), label, 12, Color(GREEN, a))
	var nx := roundf(x0 + W * clampf(t / FULL, 0.0, 1.0)) + shake.x
	var nc := GREEN if t >= Fight.GREEN_LO and t <= Fight.GREEN_HI else (RED if t > Fight.RED or t < Fight.SLACK else AMBER)
	draw_rect(Rect2(Vector2(nx - 3.0, bar.position.y - 6.0), Vector2(6.0, bar.size.y + 12.0)), Color(0, 0, 0, 0.7 * a))
	draw_rect(Rect2(Vector2(nx - 2.0, bar.position.y - 5.0), Vector2(4.0, bar.size.y + 10.0)), Color(nc.lightened(0.4), a))
	_text(font, Vector2(x0, -68.0), "SLACK", 12, Color(PALE, 0.6 * a))
	var tw := font.get_string_size("SNAPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_text(font, Vector2(x0 + W - tw, -68.0), "SNAPS", 12, Color(PALE, 0.6 * a))
	if highlight:
		var k := 0.55 + 0.45 * sin(_t * 6.0)
		_frame(bar.grow(8.0), Color(AMBER, k * a))
	# under it: how much fight he's got, and the line out
	var e := clampf(float(_s.get("energy", 1.0)), 0.0, 1.0)
	_text(font, Vector2(x0, -48.0), "FISH", 12, Color(PALE, 0.9 * a))
	var eb := Rect2(Vector2(x0 + 42.0, -56.0), Vector2(150.0, 10.0))
	draw_rect(eb, Color(0, 0, 0, 0.55 * a))
	draw_rect(Rect2(eb.position, Vector2(roundf(eb.size.x * e), eb.size.y)), Color(GREEN if e < 0.25 else BLUE, a))
	var lc := RED if _gain < -0.3 else (GREEN if _gain > 0.3 else PALE)
	var ltxt := "LINE OUT %d M" % roundi(_line)
	var ltw := font.get_string_size(ltxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_text(font, Vector2(x0 + W - ltw, -48.0), ltxt, 12, Color(lc, a))
	# your arms: going down as you reel, back up hands off (the notch: under it, tired)
	var arm := clampf(float(_s.get("arms", 1.0)), 0.0, 1.0)
	var ac := PALE if arm >= Fight.TIRED else (RED if arm < 0.12 else AMBER)
	var flash := (0.6 + 0.4 * sin(_t * 9.0)) if arm < 0.12 else 1.0
	_text(font, Vector2(x0, -26.0), "ARMS", 12, Color(ac, 0.9 * a * flash))
	var ab := Rect2(Vector2(x0 + 42.0, -34.0), Vector2(150.0, 10.0))
	draw_rect(ab, Color(0, 0, 0, 0.55 * a))
	draw_rect(Rect2(ab.position, Vector2(roundf(ab.size.x * arm), ab.size.y)), Color(ac, a * flash))
	draw_rect(Rect2(ab.position + Vector2(roundf(ab.size.x * Fight.TIRED), 0.0), Vector2(2.0, ab.size.y)),
			Color(INK, a))
	# how square on him you are (tuna/fight.gd's angle_k): off to the side you win less, abeam nothing
	var ang := clampf(float(_s.get("angle", 1.0)), 0.0, 1.0)
	var atxt := "ANGLE GOOD" if ang > 0.8 else ("ANGLE POOR" if ang > 0.4 else "NO ANGLE")
	var atw := font.get_string_size(atxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_text(font, Vector2(x0 + W - atw, -26.0), atxt, 12,
			Color(GREEN if ang > 0.8 else (AMBER if ang > 0.4 else RED), a))


## Her from above, bow up, and him round her, on a plate `at` (top left). The ring's green astern (where you can lift
## him), red forward of her beam (where the line's on her), dim between; him a square out along his bearing coloured
## by the angle, the line to him from her stern.
func _draw_round(at: Vector2, a: float) -> void:
	draw_rect(Rect2(at, Vector2(122.0, 122.0)), Color(INK, INK.a * a))
	var font := get_theme_default_font()
	_text(font, at + Vector2(10.0, 18.0), "HIM", 12, Color(PALE, 0.6 * a))
	var c := at + Vector2(61.0, 64.0)
	var r := 44.0
	for k in 48:
		var rb := TAU * k / 48.0
		var d := absf(wrapf(rb, -PI, PI))
		var col := GREEN if d < Fight.SQUARE else (RED if d > Fight.SIDE_FROM else PALE)
		var al := 0.9 if d < Fight.SQUARE or d > Fight.SIDE_FROM else 0.3
		var p := (c + Vector2(sin(rb), cos(rb)) * r).round()
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(col, al * a))
	# her: a hull 14 wide, bow up, pointed, her cockpit dark
	var hull := Color(PALE, 0.9 * a)
	draw_rect(Rect2(c + Vector2(-7, -12), Vector2(14, 28)), hull)
	draw_rect(Rect2(c + Vector2(-5, -18), Vector2(10, 6)), hull)
	draw_rect(Rect2(c + Vector2(-3, -22), Vector2(6, 4)), hull)
	draw_rect(Rect2(c + Vector2(-5, 4), Vector2(10, 10)), Color(INK, a))
	# him, and the line from her stern
	var bearing := float(_s.get("bearing", 0.0))
	var stern := c + Vector2(0, 16)
	var fish := (c + Vector2(sin(bearing), cos(bearing)) * r).round()
	for k in 16:
		var q := stern.lerp(fish, float(k) / 16.0).round()
		draw_rect(Rect2(q, Vector2(2, 2)), Color(PALE, 0.6 * a))
	var ang := float(_s.get("angle", 1.0))
	var fc := GREEN if ang > 0.8 else (AMBER if ang > 0.4 else RED)
	draw_rect(Rect2(fish - Vector2(6, 6), Vector2(12, 12)), Color(0, 0, 0, 0.85 * a))
	draw_rect(Rect2(fish - Vector2(4, 4), Vector2(8, 8)), Color(fc, a))


## While other lines are still out: REEL THE OTHER LINES IN! on a plate, red once he's heading for one (rods.gd's
## lines_out: how many, the worst threat, its name).
func _draw_lines(at: Vector2, a: float) -> void:
	var lines: Array = _s.get("lines", [0, 0.0, ""])
	if bool(_s.get("tangled", false)) or int(lines[0]) <= 0:
		return
	var words := "REEL THE OTHER LINES IN! %d STILL OUT" % int(lines[0])
	var col := AMBER
	if float(lines[1]) > 0.0:
		words = "HE'S HEADING FOR THE %s LINE! REEL IT IN!" % str(lines[2]).to_upper()
		col = RED
	var pulse := 0.75 + 0.25 * sin(_t * 8.0)
	var font := get_theme_default_font()
	var w := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var x := roundf(at.x - w * 0.5)
	draw_rect(Rect2(Vector2(x - 14.0, at.y - 16.0), Vector2(w + 24.0, 24.0)), Color(INK, INK.a * a))
	draw_rect(Rect2(Vector2(x - 14.0, at.y - 16.0), Vector2(4.0, 24.0)), Color(col, pulse * a))
	_text(font, Vector2(x, at.y), words, 12, Color(col, pulse * a))


## What to do right now: the words on a plate, coloured by how urgent, the mouse beside them.
func _draw_do(at: Vector2, a: float) -> void:
	var t := float(_s.get("tension", 0.0))
	var m := str(_s.get("move", ""))
	var words := "HOLD LEFT MOUSE: REEL"
	var col := GREEN
	var icon := "left"
	var solo := int(_s.get("crew", 1)) <= 1
	var b := float(_s.get("bearing", 0.0))
	var side := "STARBOARD" if b >= 0.0 else "PORT"
	var arms := float(_s.get("arms", 1.0))
	var angle := float(_s.get("angle", 1.0))
	# (whose job the boat is: the captain's, somebody's if nobody's at the wheel, or yours from the holder)
	var swing := "ROD IN THE HOLDER (Q), STEER" if solo else (
			"CAPTAIN, SWING HER" if bool(_s.get("captain", false)) else "SOMEONE TAKE THE WHEEL")
	if t > Fight.RED:
		words = "TOO TIGHT! LET GO"
		col = RED
		icon = "none"
	elif m == "jump":
		words = "HE'S JUMPING! LET GO"
		col = AMBER
		icon = "none"
	elif m == "charge":
		words = "HE'S CHARGING THE BOAT! REEL, REEL!"
		col = RED
	elif bool(_s.get("slipping", false)):
		words = "HE'S RUNNING! LET GO"
		col = AMBER
		icon = "none"
	elif t < Fight.SLACK and float(_s.get("slack_t", 0.0)) > 0.2:
		words = "TOO SLACK! REEL"
		col = RED
	elif float(_s.get("props", 0.0)) > 0.0:
		words = "HE'S UNDER THE PROPS! CAPTAIN: OUT OF GEAR"
		col = RED
	elif bool(_s.get("tangled", false)):
		words = "LINES TANGLED! " + ("ROD IN THE HOLDER (Q), E ON THE OTHER" if solo else "MATE: E ON THE OTHER ROD, WIND IT IN")
		col = RED
	elif float(_s.get("chafe", 0.0)) > 0.3:
		var under := absf(b) > Fight.UNDER - 0.3
		words = ("HE'S GONE UNDER THE BOAT: " if under else "LINE ON THE HULL: ") + swing
		col = RED
		icon = "none" if solo else "left"
	elif arms < 0.12:
		words = "ARMS GONE! " + ("Q: REST THE ROD IN A HOLDER" if solo else "HAND OVER: A MATE PRESSES E ON YOUR ROD")
		col = RED
		icon = "none"
	elif angle < 0.6:
		words = "HE'S OFF TO %s: %s" % [side, swing]
		col = AMBER
		icon = "none" if solo else "left"
	elif t > Fight.GREEN_HI:
		words = "EASE OFF: LET GO A MOMENT"
		col = AMBER
		icon = "none"
	elif arms < Fight.TIRED:
		words = "ARMS TIRING: " + ("REST THEM IN THE HOLDER SOON" if solo else "TIME TO SWAP ON THE ROD")
		col = AMBER
	elif m == "spiral" or bool(_s.get("beaten", false)):
		words = "HE'S BEATEN, CIRCLING: REEL HIM UP"
	else:
		# what he's doing, so you know he's still fighting, and the one thing to do
		var doing := {"sound": "HE'S DIVING DEEP", "dog": "HE'S HANGING DEEP", "circle": "HE'S CIRCLING",
				"shake": "HE'S SHAKING HIS HEAD"}.get(m, "") as String
		var good := t >= Fight.GREEN_LO and bool(_s.get("reeling", false))
		if good:
			words = (doing + ". " if not doing.is_empty() else "GOOD! ") + "KEEP IT IN THE GREEN"
		elif not doing.is_empty():
			words = doing + ": HOLD LEFT MOUSE, REEL"
	var urgent := col != GREEN
	var pulse := 0.75 + 0.25 * sin(_t * 8.0)
	var font := get_theme_default_font()
	var tw := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var iw := 18.0 * U
	var left := roundf(at.x - (tw + iw) * 0.5)
	draw_rect(Rect2(Vector2(left - 12.0, at.y - 22.0), Vector2(tw + iw + 24.0, 44.0)), Color(INK, INK.a * a))
	_mouse(Vector2(left, at.y - 16.0), icon, col, a, pulse if urgent else 1.0)
	_text(font, Vector2(left + iw, at.y + 9.0), words, 18, Color(col, (pulse if urgent else 0.95) * a))


## The little mouse in whole pixels: the left button lit, or both crossed out (hands off).
func _mouse(o: Vector2, kind: String, col: Color, a: float, pulse: float) -> void:
	var line := Color(PALE, 0.7 * a)
	var lit := Color(col, pulse * a)
	_box(o, Vector2(10, 16), line)
	_px(o, Vector2(5, 1), Vector2(0.5, 5), line)
	_px(o, Vector2(1, 6), Vector2(8, 0.5), line)
	if kind == "left":
		_px(o, Vector2(1, 1), Vector2(4, 5), lit)
	else:
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


## A 2 px outline round `r`.
func _frame(r: Rect2, col: Color) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), col)
	draw_rect(Rect2(r.position + Vector2(0.0, r.size.y - 2.0), Vector2(r.size.x, 2.0)), col)
	draw_rect(Rect2(r.position, Vector2(2.0, r.size.y)), col)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 2.0, 0.0), Vector2(2.0, r.size.y)), col)


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
