extends Control
## The fight's little bit of HUD (rods.gd feeds it every frame while you've a fish on; it's gone the rest of the time).
## The fight itself is read off the rod, the reel and the line (the bend, the drag screaming, the reel grinding, the
## line going slack, him jumping, the crew shouting: rods/fight_calls.gd); all this adds is what you'd see glancing down
## at your own reel, drawn in the corner: its side plate, the spool on it emptying as he takes line (the line on top,
## the white backing under it, the bare metal arbor when he's nearly got the lot), turning as it goes, and the drag
## lever on its quadrant (free at the back, the strike detent marked, full forward). And when the line's close to
## parting, the screen's edges pulse red. The moments: FISH ON when it takes; when it's lost, why in red and under it
## what would have saved it (it's always something); BOATSIDE.

const Fight := preload("res://tuna/fight.gd")
const GREEN := Color(0.45, 0.95, 0.55)
const AMBER := Color(1.0, 0.75, 0.3)
const RED := Color(1.0, 0.3, 0.25)
const INK := Color(0.02, 0.03, 0.05, 0.8)
const PALE := Color(0.95, 0.93, 0.86)
const LINE := Color(0.78, 0.84, 0.7)
const BACKING := Color(0.97, 0.97, 0.95)
const METAL := Color(0.55, 0.57, 0.6)
const U := 2.0                        # px a pixel of the reel

## (kept for rods.gd: nothing teaches over the fight any more)
var teaching := false
var highlight := false
var _on := false
var _a := 0.0                         # how much it's showing (fades in and out)
var _s := {}                          # the fight's state this frame
var _t := 0.0
var _spool := 0.0                     # (eased)
var _lever := Fight.STRIKE_DRAG
var _lever_t := 0.0                   # s since the lever last moved (the plate lights up)
var _banner := 0.0
var _banner_text := ""
var _banner_col := PALE
var _edge: ColorRect
var _lesson := ""                     # under a loss: what would have saved it

## What each loss means, and what would have saved it (rods.gd's WHY, said plainly): the fault's always findable.
const LESSONS := {
	"Thrown on the jump.": "THE LINE WAS TIGHT WHILE HE JUMPED. WHEN HE JUMPS, DROP THE TIP.",
	"Hook pulled.": "TOO MUCH DRAG FOR TOO LONG TORE IT OUT. BENT DOUBLE? BACK THE DRAG OFF (SCROLL).",
	"Hook fell out.": "SLACK LINE WHILE HE SHOOK HIS HEAD. KEEP IT TIGHT: WIND WHEN HE COMES AT YOU.",
	"Line parted.": "A JOLT ON A HEAVY DRAG. EASE IT OFF CLOSE IN: A SHORT LINE HAS NO GIVE.",
	"Line parted, twisted.": "YOU CRANKED WHILE HE TOOK LINE: IT TWISTS AND WEAKENS. HANDS OFF ON A RUN.",
	"Line parted on the rail.": "THE LINE WAS WORN ON THE HULL, THEN HE PULLED. KEEP THE STERN TO HIM (A/D).",
	"Chafed through on the hull.": "THE LINE RUBBED THROUGH ON HER. KEEP THE STERN TO HIM, OR TAKE THE ROD ROUND.",
	"Spooled.": "HE TOOK EVERY METRE. CHASE HIM: BACK HER DOWN (S) WHILE HE RUNS.",
	"Cut on the props.": "THE LINE WENT IN THE PROPS. HE'S UNDER HER: OUT OF GEAR, STEER ONLY.",
	"Lines tangled and parted.": "HE CROSSED A LINE LEFT OUT. FISH ON: E ON EVERY OTHER ROD, REEL THEM IN.",
}


func _init() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# the red at the screen's edges, the line close to parting
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


## This frame's fight (or {} for none): spool (0 full .. 1 empty), drag (the lever), danger (0 .. 1: how near the line
## is to parting), spin (the spool's turn, rad).
func show_fight(s: Dictionary) -> void:
	if s.is_empty():
		_on = false
		return
	if not _on:
		_lesson = ""
		_banner_text = "FISH ON!"
		_banner_col = AMBER
		_banner = 1.8
		_lever = float(s.get("drag", Fight.STRIKE_DRAG))
	_on = true
	_s = s


## The fish is gone: `why` across the middle a moment, in red, and what would have saved it.
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
	_lever_t += delta
	if _on:
		_spool = lerpf(_spool, float(_s.get("spool", 0.0)), minf(1.0, delta * 6.0))
		var lv := float(_s.get("drag", _lever))
		if absf(lv - _lever) > 0.001:
			_lever_t = 0.0
		_lever = move_toward(_lever, lv, delta * 3.0)
	var danger := float(_s.get("danger", 0.0)) if _on else 0.0
	if _edge and _edge.material:
		var pulse := 0.5 + 0.5 * sin(_t * 14.0)
		(_edge.material as ShaderMaterial).set_shader_parameter("k", clampf(danger, 0.0, 1.0) * 0.8 * pulse * _a)
	queue_redraw()


func _draw() -> void:
	if _banner > 0.0:
		_draw_banner()
	if _a <= 0.01:
		return
	var vw := get_viewport_rect().size.x
	_draw_reel(Vector2(roundf(vw * 0.5) - 156.0, -168.0), _a)


## The reel's side plate on a plate `at` (its top left): the spool and the line on it, the drag lever and its quadrant.
func _draw_reel(at: Vector2, a: float) -> void:
	var lit := 1.0 - smoothstep(0.6, 1.4, _lever_t)
	var empty := _spool > 0.85
	var blink := (0.55 + 0.45 * sin(_t * 9.0)) if empty else 1.0
	draw_rect(Rect2(at, Vector2(136, 136)), Color(INK, INK.a * a))
	var edge := RED if empty else AMBER
	if empty or lit > 0.0:
		_frame(Rect2(at, Vector2(136, 136)), Color(edge, a * (blink if empty else lit)))
	var c := (at + Vector2(56, 70)).floor()
	# the plate: a flange ring
	_ring(c, 21.0, 22.0, Color(METAL, a * 0.9))
	# the line on it: the arbor (bare metal), the backing on that, the line on top; as it goes out the top comes off
	var fill := clampf(1.0 - _spool, 0.0, 1.0)
	var arbor := 7.0
	var full := 20.0
	var top := arbor + (full - arbor) * fill
	var back_top := arbor + (full - arbor) * 0.5          # (the backing's the lower half of the spool)
	_ring(c, arbor, minf(top, back_top), Color(BACKING, a))
	if top > back_top:
		_ring(c, back_top, top, Color(LINE, a))
	_disc(c, arbor, Color(METAL.lightened(0.15), a))
	# the spool turning: a spoke on the arbor and a mark on the line, going round with it
	var spin := float(_s.get("spin", 0.0))
	for k in 3:
		var ang := spin + TAU * k / 3.0
		var p := (c + Vector2(cos(ang), sin(ang)) * (arbor - 2.0) * U).floor()
		draw_rect(Rect2(p - Vector2(U, U), Vector2(U * 2.0, U * 2.0)), Color(INK, a * 0.8))
	var mark := c + Vector2(cos(spin), sin(spin)) * (top - 1.0) * U
	draw_rect(Rect2(mark.floor() - Vector2(U, U), Vector2(U * 2.0, U * 2.0)), Color(0.4, 0.45, 0.4, a))
	# the drag quadrant, to the right of it: free at the bottom, full at the top, the strike detent marked
	var piv := c + Vector2(0, 0)
	for k in 11:
		var lv := k / 10.0
		var ang := _lever_ang(lv)
		var p := (piv + Vector2(cos(ang), sin(ang)) * 27.0 * U).floor()
		var strike := absf(lv - Fight.STRIKE_DRAG) < 0.01
		var col := AMBER if strike else Color(PALE, 0.55)
		draw_rect(Rect2(p - Vector2(U, U), Vector2(U * (3.0 if strike else 2.0), U * (3.0 if strike else 2.0))),
				Color(col, a))
	var la := _lever_ang(_lever)
	for k in range(int(arbor) + 2, 26):
		var p := (piv + Vector2(cos(la), sin(la)) * float(k) * U).floor()
		draw_rect(Rect2(p, Vector2(U, U)), Color(METAL.lightened(0.25), a))
	var knob := (piv + Vector2(cos(la), sin(la)) * 25.0 * U).floor()
	draw_rect(Rect2(knob - Vector2(U * 2.0, U * 2.0), Vector2(U * 4.0, U * 4.0)), Color(0.85, 0.15, 0.1, a))
	var font := get_theme_default_font()
	_text(font, at + Vector2(96, 22), "FULL", 12, Color(PALE, 0.55 * a))
	_text(font, at + Vector2(96, 128), "FREE", 12, Color(PALE, 0.55 * a))
	_text(font, at + Vector2(8, 22), "DRAG", 12, Color(AMBER if lit > 0.0 else PALE, (0.6 + 0.4 * lit) * a))


## Where the lever points at setting `lv` (rad: free down and to the right, full up and to the right).
static func _lever_ang(lv: float) -> float:
	return lerpf(1.05, -1.05, clampf(lv, 0.0, 1.0))


## A pixel ring round `c`, `r0` to `r1` reel-pixels out.
func _ring(c: Vector2, r0: float, r1: float, col: Color) -> void:
	var n := int(ceilf(r1))
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var d := sqrt(float(x * x + y * y))
			if d >= r0 and d < r1:
				draw_rect(Rect2(c + Vector2(x, y) * U, Vector2(U, U)), col)


func _disc(c: Vector2, r: float, col: Color) -> void:
	_ring(c, 0.0, r, col)


## A 2 px outline round `r`.
func _frame(r: Rect2, col: Color) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), col)
	draw_rect(Rect2(r.position + Vector2(0.0, r.size.y - 2.0), Vector2(r.size.x, 2.0)), col)
	draw_rect(Rect2(r.position, Vector2(2.0, r.size.y)), col)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 2.0, 0.0), Vector2(2.0, r.size.y)), col)


func _text(font: Font, at: Vector2, text: String, px: int, col: Color) -> void:
	draw_string(font, at.round(), Settings.say(text), HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


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
	text = Settings.say(text)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var x := roundf(at.x - w * 0.5)
	draw_rect(Rect2(Vector2(x - 12.0, at.y - 22.0), Vector2(w + 24.0, 34.0)), Color(INK, INK.a * a))
	_text(font, Vector2(x, at.y), text, 18, col)
