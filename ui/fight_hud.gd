extends Control
## The fight's bit of HUD (rods.gd feeds it every frame). The fight is still read off the rod, the reel and the line
## (the bend, the drag screaming, the line's hum, the line going slack, the crew shouting: rods/fight_calls.gd); this
## makes sure none of it can be missed, and that a first-timer knows what to press right now:
##
## - **The strike**, for everyone aboard: FISH ON! ROD 2! across the screen, a white flash with the hit, and a marker
##   on that rod wherever it is on her (its tip, or the edge of the screen pointing to it) saying what to press to
##   take it, or who's on it.
## - **Your reel**, bottom right, while the fish is in your hands: his state in one word (RUNNING, DEEP, TIRED,
##   SURGING ...), the reel's side plate (the spool emptying, the drag lever on its quadrant, FREE / STRIKE / FULL
##   marked), the line left as a bar and in metres, the bend as a bar with where it parts, and the keys (lift, wind,
##   drag) as little pixel key caps, the one to use now lit.
## - **What to do now** (ui/fight_coach.gd), a line over the bottom of the screen: let him run, lift, wind as you
##   drop, drop the tip; it fades as you show you've got it, and comes back in red if you flounder.
## - **He's gone**: HE'S GONE, why, and what would have saved him; the screen's edges pulse red while the line's close
##   to parting; BOATSIDE when he's up.

const Fight := preload("res://tuna/fight.gd")
const FightCoach := preload("res://ui/fight_coach.gd")
const Sfx := preload("res://audio/sfx.gd")
const GREEN := Color(0.45, 0.95, 0.55)
const AMBER := Color(1.0, 0.75, 0.3)
const RED := Color(1.0, 0.3, 0.25)
const INK := Color(0.02, 0.03, 0.05, 0.82)
const PALE := Color(0.95, 0.93, 0.86)
const DIM := Color(0.62, 0.66, 0.68)
const LINE := Color(0.78, 0.84, 0.7)
const BACKING := Color(0.97, 0.97, 0.95)
const METAL := Color(0.55, 0.57, 0.6)
const U := 2.0                        # px a pixel of the reel and the key caps
## The reel's plate (px) and its margin off the screen's corner.
const PLATE := Vector2(348, 196)
const EDGE := 24.0

## (kept for rods.gd: nothing teaches over the fight with a card)
var teaching := false
var highlight := false
var coach := FightCoach.new()
var _on := false
var _a := 0.0                         # how much the reel's showing (fades in and out)
var _s := {}                          # the fight's state this frame
var _t := 0.0
var _spool := 0.0                     # (eased)
var _bend := 0.0
var _lever := Fight.STRIKE_DRAG
var _lever_t := 0.0                   # s since the lever last moved (the plate lights up)
var _banner := 0.0
var _banner_len := 1.0
var _banner_text := ""
var _banner_sub := ""
var _banner_col := PALE
var _flash := 0.0
var _lift_flash := 0.0                # (his tired moment just came: the state word flares)
var _edge: ColorRect
var _lesson := ""                     # under a loss: what would have saved it
## The rods with a fish on that aren't in your hands, to mark: [{at (world), i, name, word, tone, who, free}].
var _marks: Array = []

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
## The same in the arcade fight (tuna/fight_arcade.gd), where the hands are two buttons.
const ARCADE_LESSONS := {
	"Thrown on the jump.": "YOU HELD ON WHILE HE WAS IN THE AIR. WHEN HE JUMPS, LET GO OF BOTH.",
	"Hook pulled.": "TOO TIGHT, TOO LONG. WHEN THE PLATE GOES RED, EASE OFF.",
	"Hook fell out.": "MISSED BEATS AND SLACK WORKED IT LOOSE. TAP ON THE BEAT; HAMMER IT WHEN HE COMES AT YOU.",
	"Line parted.": "THE LINE FRAYED THROUGH: TOO TIGHT, TOO OFTEN. KEEP THE NEEDLE IN HIS GREEN.",
}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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


## This frame's fight in your hands (or {} for none): spool (0 full .. 1 empty), drag (the lever), danger (0 .. 1:
## how near the line is to parting), spin (the spool's turn, rad), bend (the line's tension), out (m), rod (its
## number, from 1), name (where she carries it), and for the coach the fight itself (fight), the rod's elevation
## (pitch) and your hand on the crank (crank).
func show_fight(s: Dictionary) -> void:
	if s.is_empty():
		_on = false
		return
	if not _on:
		_lesson = ""
		_lever = float(s.get("drag", Fight.STRIKE_DRAG))
		coach.begin()
		if float(s.get("since", 0.0)) > 12.0:
			_set_banner("YOU'VE GOT HIM", "", AMBER, 1.6)        # (taking over a fish that's been on a while)
		elif _banner <= 0.0 or _banner_col == AMBER:
			_set_banner("FISH ON!", "LET HIM RUN. WATCH YOUR REEL", AMBER, 2.2)
	_on = true
	_s = s
	var f: Fight = s.get("fight")
	if f != null:
		coach.tick(get_process_delta_time(), f, float(s.get("pitch", 0.6)), bool(s.get("crank", false)))
		if coach.now_lift:
			# his tired moment: a soft tick and a tap in the hands, the same every time (now lift)
			Sfx.play("ui.tick", 0.45, 1.5)
			Settings.buzz(0.0, 0.35, 0.06)
			_lift_flash = 1.0


## A strike on rod `rod` (from 1, where she carries it: `where`), for everyone aboard: `free` nobody's on it, `mine`
## it's in your hands already.
func strike(rod: int, where: String, free: bool, mine: bool) -> void:
	_flash = 1.0
	var sub := where.to_upper()
	if free and not mine:
		sub += ": E ON IT, TAKE THE ROD"
	_set_banner("FISH ON! ROD %d!" % rod, sub, AMBER, 3.2)


## The fish is gone: HE'S GONE, `why` under it, and (yours: `mine`) what would have saved it.
func lost(why: String, mine := true, rod := 0) -> void:
	var said := why.trim_suffix(".").to_upper()
	_lesson = str(LESSONS.get(why, "")) if mine else ""
	if mine and Fight.arcade and ARCADE_LESSONS.has(why):
		_lesson = str(ARCADE_LESSONS[why])
	_set_banner("HE'S GONE" if mine or rod <= 0 else "HE'S GONE: ROD %d" % rod, said, RED,
			6.5 if not _lesson.is_empty() else 3.0)
	if mine:
		_on = false


## Up alongside: a moment of green.
func won() -> void:
	_set_banner("BOATSIDE!", "", GREEN, 2.4)
	_lesson = "HARPOON HIM, THEN HAUL HIM ABOARD."
	_on = false


## The lever's moved a notch (rods.gd's set_drag, on the rod in your hands).
func dragged(drag: float, tighter: bool) -> void:
	coach.dragged(drag, tighter)


## The other rods with a fish on, to mark where they are (rods.gd, every frame).
func marks(list: Array) -> void:
	_marks = list


func _set_banner(text: String, sub: String, col: Color, secs: float) -> void:
	_banner_text = text
	_banner_sub = sub
	_banner_col = col
	_banner = secs
	_banner_len = secs


func _process(delta: float) -> void:
	_t += delta
	_banner = maxf(_banner - delta, 0.0)
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_lift_flash = maxf(_lift_flash - delta * 2.0, 0.0)
	_a = move_toward(_a, 1.0 if _on else 0.0, delta * (4.0 if _on else 2.0))
	_lever_t += delta
	if _on:
		_spool = lerpf(_spool, float(_s.get("spool", 0.0)), minf(1.0, delta * 6.0))
		_bend = lerpf(_bend, float(_s.get("bend", 0.0)), minf(1.0, delta * 10.0))
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
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.97, 0.9, 0.35 * _flash))
	_draw_marks()
	if _a > 0.01:
		var at := (size - PLATE - Vector2(EDGE, EDGE)).floor()
		_draw_plate(at, _a)
		_draw_caps(at + Vector2(0, -50), _a * coach.caps_a)
		_draw_coach(_a)
	if _banner > 0.0:
		_draw_banner()


# ------------------------------------------------------------------ the reel's plate

func _draw_plate(at: Vector2, a: float) -> void:
	var font := get_theme_default_font()
	var lit := 1.0 - smoothstep(0.6, 1.4, _lever_t)
	var empty := _spool > 0.85
	var blink := (0.55 + 0.45 * sin(_t * 9.0)) if empty else 1.0
	draw_rect(Rect2(at, PLATE), Color(INK, INK.a * a))
	var edge := RED if empty else (AMBER if lit > 0.0 else Color(PALE, 0.25))
	_frame(Rect2(at, PLATE), Color(edge, a * (blink if empty else maxf(lit, 0.6))))
	# the top line: which rod, and him in a word
	_text(font, at + Vector2(12, 24), "ROD %d" % int(_s.get("rod", 1)), 12, Color(DIM, a))
	var word := coach.word
	var wcol := _tone_col(coach.word_tone)
	var ww := _w(font, word, 24)
	var flick := 1.0 if coach.word != "RUNNING" or fmod(_t, 0.5) < 0.35 else 0.6
	if _lift_flash > 0.0:
		# (his tired moment: a green plate flares behind the word)
		draw_rect(Rect2(at + Vector2(PLATE.x - 18 - ww, 4), Vector2(ww + 12, 34)), Color(GREEN, 0.35 * _lift_flash * a))
	_text(font, at + Vector2(PLATE.x - 12 - ww, 30), word, 24, Color(wcol, a * flick))
	# the reel: its side plate, the spool on it, the drag lever on its quadrant
	var c := (at + Vector2(66, 116)).floor()
	_ring(c, 21.0, 22.0, Color(METAL, a * 0.9))
	var fill := clampf(1.0 - _spool, 0.0, 1.0)
	var arbor := 7.0
	var full := 20.0
	var top := arbor + (full - arbor) * fill
	var back_top := arbor + (full - arbor) * 0.5          # (the backing's the lower half of the spool)
	_ring(c, arbor, minf(top, back_top), Color(BACKING, a))
	if top > back_top:
		_ring(c, back_top, top, Color(LINE, a))
	_disc(c, arbor, Color(METAL.lightened(0.15), a))
	var spin := float(_s.get("spin", 0.0))
	for k in 3:
		var ang := spin + TAU * k / 3.0
		var p := (c + Vector2(cos(ang), sin(ang)) * (arbor - 2.0) * U).floor()
		draw_rect(Rect2(p - Vector2(U, U), Vector2(U * 2.0, U * 2.0)), Color(INK, a * 0.8))
	var mark := c + Vector2(cos(spin), sin(spin)) * (top - 1.0) * U
	draw_rect(Rect2(mark.floor() - Vector2(U, U), Vector2(U * 2.0, U * 2.0)), Color(0.4, 0.45, 0.4, a))
	for k in 11:
		var lv := k / 10.0
		var p := (c + Vector2(cos(_lever_ang(lv)), sin(_lever_ang(lv))) * 27.0 * U).floor()
		var strike := absf(lv - Fight.STRIKE_DRAG) < 0.01
		var col := AMBER if strike else Color(PALE, 0.55)
		draw_rect(Rect2(p - Vector2(U, U), Vector2(U * (3.0 if strike else 2.0), U * (3.0 if strike else 2.0))),
				Color(col, a))
	var la := _lever_ang(_lever)
	for k in range(int(arbor) + 2, 26):
		var p := (c + Vector2(cos(la), sin(la)) * float(k) * U).floor()
		draw_rect(Rect2(p, Vector2(U, U)), Color(METAL.lightened(0.25), a))
	var knob := (c + Vector2(cos(la), sin(la)) * 25.0 * U).floor()
	draw_rect(Rect2(knob - Vector2(U * 2.0, U * 2.0), Vector2(U * 4.0, U * 4.0)), Color(0.85, 0.15, 0.1, a))
	# the quadrant's three marks, named
	var on := func(lv: float) -> float: return 1.0 if absf(_lever - lv) < 0.05 else 0.5
	_text(font, c + Vector2(cos(_lever_ang(1.0)), sin(_lever_ang(1.0))) * 27.0 * U + Vector2(6, 2), "FULL", 12,
			Color(PALE, on.call(1.0) * a))
	_text(font, c + Vector2(27.0 * U + 8, 2 + sin(_lever_ang(Fight.STRIKE_DRAG)) * 27.0 * U), "STRIKE", 12,
			Color(AMBER, on.call(Fight.STRIKE_DRAG) * a))
	_text(font, c + Vector2(cos(_lever_ang(0.0)), sin(_lever_ang(0.0))) * 27.0 * U + Vector2(6, 10), "FREE", 12,
			Color(PALE, on.call(0.0) * a))
	# the line left and the bend, as bars
	var bx := at.x + 196.0
	var bw := PLATE.x - 196.0 - 14.0
	var left_m := maxf(Fight.CAPACITY * (1.0 - _spool), 0.0)
	var lcol := GREEN if _spool < 0.5 else (AMBER if _spool < 0.8 else RED)
	_text(font, Vector2(bx, at.y + 66), "LINE LEFT", 12, Color(DIM, a))
	_bar(Rect2(bx, at.y + 72, bw, 10), clampf(1.0 - _spool, 0.0, 1.0), Color(lcol, a * (blink if empty else 1.0)), a)
	_text(font, Vector2(bx, at.y + 100), "%d M" % roundi(left_m), 12, Color(PALE, a))
	var bend := clampf(_bend, 0.0, 1.0)
	var danger := float(_s.get("danger", 0.0))
	var bcol := Color(PALE, 0.8).lerp(AMBER, smoothstep(0.35, 0.6, bend)).lerp(RED, danger)
	_text(font, Vector2(bx, at.y + 126), "BEND", 12, Color(DIM, a))
	_bar(Rect2(bx, at.y + 132, bw, 10), pow(bend, 0.6), Color(bcol, a), a)      # (a light bend still shows)
	# (where it parts: the bar's end, marked red)
	draw_rect(Rect2(bx + bw - 4.0, at.y + 128, 4.0, 18.0), Color(RED, a * 0.9))
	var feel := "ON - LIGHT" if bend < 0.12 else ("ON - TIGHT" if danger < 0.3 else "ABOUT TO PART!")
	if coach.word == "SLACK":
		feel = "SLACK! WIND!"
	_text(font, Vector2(bx, at.y + 160), feel, 12,
			Color(RED if danger >= 0.3 or feel == "SLACK!" else PALE, a))
	# the drag: what this notch does, a moment after it moves
	if coach.drag_t < 2.5:
		var k := clampf(2.5 - coach.drag_t, 0.0, 1.0) * a
		var note := "DRAG %d/10: %s" % [roundi(_lever * 10.0), coach.drag_note]
		_plate_text(Vector2(at.x + PLATE.x - _w(font, note, 12) - 12, at.y - 66), note, 12, Color(AMBER, k), k)


## A bar `k` full in `r`, on a dark ground.
func _bar(r: Rect2, k: float, col: Color, a: float) -> void:
	draw_rect(r, Color(0.0, 0.0, 0.0, 0.5 * a))
	draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * clampf(k, 0.0, 1.0)), r.size.y)), col)


static func _tone_col(tone: String) -> Color:
	match tone:
		"bad":
			return RED
		"do":
			return GREEN
	return AMBER


## Where the lever points at setting `lv` (rad: free down and to the right, full up and to the right).
static func _lever_ang(lv: float) -> float:
	return lerpf(1.05, -1.05, clampf(lv, 0.0, 1.0))


# ------------------------------------------------------------------ the keys

## The three things you do with a fish on, as pixel key caps over the reel's plate: lift, wind, the drag; the one
## the coach wants now lit and pulsing. The pad's buttons while it's the pad in your hands.
func _draw_caps(at: Vector2, a: float) -> void:
	if a <= 0.01:
		return
	var font := get_theme_default_font()
	var want := coach.keys
	var pulse := 0.65 + 0.35 * sin(_t * 8.0)
	var pad := Settings.pad
	var caps := [
		["lift", "RS UP" if pad else "", "LIFT", "up"],
		["wind", "RT" if pad else "", "WIND", "left"],
		["drag", "LB/RB" if pad else "", "DRAG", "wheel"],
	]
	var x := at.x + PLATE.x
	for ci in range(caps.size() - 1, -1, -1):
		var cap: Array = caps[ci]
		var id := str(cap[0])
		var lit := want == id or (id == "drag" and want.begins_with("drag")) or (id == "lift" and want == "drop") 				or (id == "wind" and want == "wait")
		var w := 112.0
		x -= w + (6.0 if ci < caps.size() - 1 else 0.0)
		var r := Rect2(Vector2(x, at.y), Vector2(w, 44))
		draw_rect(r, Color(INK, INK.a * a))
		_frame(r, Color(GREEN if lit else Color(PALE, 0.35), a * (pulse if lit else 1.0)))
		var col := Color(GREEN if lit else PALE, a * (1.0 if lit else 0.7))
		var icon := r.position + Vector2(8, 6)
		if pad:
			var k := str(cap[1])
			var kw := _w(font, k, 12) + 8.0
			draw_rect(Rect2(icon + Vector2(0, 6), Vector2(kw, 20)), Color(col, 0.18 * a))
			_frame(Rect2(icon + Vector2(0, 6), Vector2(kw, 20)), col)
			_text(font, icon + Vector2(4, 22), k, 12, col)
			if id == "lift" and want == "drop":
				_text(font, icon + Vector2(4, 22), "RS DN", 12, col)
		else:
			_mouse(icon, str(cap[3]), col, lit and want != "drop", want == "drop" and id == "lift",
					want == "drag_down", want == "drag_up")
		var label := str(cap[2])
		if id == "lift" and want == "drop":
			label = "DROP TIP"
		elif id == "wind" and want == "none":
			label = "HANDS OFF"
			col = Color(AMBER, a * pulse)
		elif id == "lift" and want == "wait":
			label = "WAIT..."
		_text(font, Vector2(r.position.x + r.size.x - 6 - _w(font, label, 12), r.position.y + 28), label, 12, col)


## A little pixel mouse at `o` (10 x 15 px of U): `kind` "up" (the arrow up beside it), "left" (its left button lit),
## "wheel" (its wheel lit, the arrows up and down).
func _mouse(o: Vector2, kind: String, col: Color, lit: bool, down: bool, wheel_down: bool, wheel_up: bool) -> void:
	o = o.floor()
	var line := Color(col, col.a)
	_box(o, Vector2(9, 15), line)
	_px(o, Vector2(4, 1), Vector2(1, 5), line)
	_px(o, Vector2(1, 6), Vector2(7, 1), line)
	match kind:
		"left":
			if lit:
				_px(o, Vector2(1, 1), Vector2(3, 5), line)
		"wheel":
			_px(o, Vector2(4, 2), Vector2(1, 3), Color(AMBER, col.a) if lit else line)
			_arrow(o + Vector2(11, 0) * U, -1.0, Color(line, line.a * (1.0 if wheel_up or not lit else 0.3)))
			_arrow(o + Vector2(11, 8) * U, 1.0, Color(line, line.a * (1.0 if wheel_down or not lit else 0.3)))
		"up":
			_arrow(o + Vector2(11, 1) * U, 1.0 if down else -1.0, line)


## A rectangle in key-cap pixels from `o`.
func _px(o: Vector2, p: Vector2, s: Vector2, col: Color) -> void:
	draw_rect(Rect2((o + p * U).round(), (s * U).round().max(Vector2.ONE)), col)


## A one-pixel outline, `s` key-cap pixels.
func _box(o: Vector2, s: Vector2, col: Color) -> void:
	_px(o, Vector2(0, 0), Vector2(s.x, 1), col)
	_px(o, Vector2(0, s.y - 1), Vector2(s.x, 1), col)
	_px(o, Vector2(0, 0), Vector2(1, s.y), col)
	_px(o, Vector2(s.x - 1, 0), Vector2(1, s.y), col)


## An arrow 5 wide and 7 tall, pointing down (`way` 1) or up (-1).
func _arrow(o: Vector2, way: float, col: Color) -> void:
	_px(o, Vector2(2, 0 if way > 0.0 else 2), Vector2(1, 5), col)
	for k in 3:
		_px(o, Vector2(k, 4.0 + k if way > 0.0 else 2.0 - k), Vector2(5 - 2 * k, 1), col)


# ------------------------------------------------------------------ what to do now

func _draw_coach(a: float) -> void:
	var k := coach.a * a
	if coach.tone == "bad":
		k = a
	if k <= 0.01 or coach.say.is_empty():
		return
	var font := get_theme_default_font()
	var col := _tone_col(coach.tone)
	var one := _keys_said(coach.say)
	var two := _keys_said(coach.then)
	var px := 24
	var gap := "  >  "
	var w := _w(font, one, px) + (_w(font, gap + two, px) if not two.is_empty() else 0.0)
	if w > size.x - 120.0:
		px = 18
		w = _w(font, one, px) + (_w(font, gap + two, px) if not two.is_empty() else 0.0)
	var y := roundf(size.y * 0.66)
	var x := roundf((size.x - w) * 0.5)
	if x + w + 16.0 > size.x - PLATE.x - EDGE - 8.0:
		# (clear of the reel's plate: centred in what's left of the screen)
		x = maxf(roundf((size.x - PLATE.x - EDGE - w) * 0.5), 24.0)
	var pulse := 0.8 + 0.2 * sin(_t * 7.0)
	draw_rect(Rect2(Vector2(x - 16.0, y - px - 12.0), Vector2(w + 32.0, px + 24.0)), Color(INK, INK.a * k))
	draw_rect(Rect2(Vector2(x - 16.0, y - px - 12.0), Vector2(w + 32.0, 4.0)), Color(col, 0.9 * k))
	if two.is_empty():
		_text(font, Vector2(x, y), one, px, Color(col, k * pulse))
		return
	# the pump's two halves: the one you're on lit, the other waiting
	var lit := Color(AMBER if coach.keys == "wait" else GREEN, k * pulse)
	var wait := Color(DIM, k * 0.6)
	_text(font, Vector2(x, y), one, px, lit if coach.first else wait)
	var x2 := x + _w(font, one, px)
	_text(font, Vector2(x2, y), gap, px, Color(PALE, k * 0.5))
	_text(font, Vector2(x2 + _w(font, gap, px), y), two, px, wait if coach.first else lit)


## The coach's words with the pad's keys while it's the pad in your hands.
static func _keys_said(text: String) -> String:
	if not Settings.pad or text.is_empty():
		return text
	return text.replace("(MOUSE UP)", "(RIGHT STICK UP)").replace("(MOUSE DOWN)", "(RIGHT STICK DOWN)") \
			.replace("(SCROLL DOWN)", "(RB)").replace("(SCROLL UP)", "(LB)").replace("(HOLD LMB)", "(HOLD RT)") \
			.replace("SCROLL", "LB/RB")


# ------------------------------------------------------------------ the other rods

## Each rod with a fish on that isn't in your hands: a marker on its tip (or on the screen's edge, pointing to it):
## the rod's number, him in a word, and E: TAKE THE ROD, or who's on it.
func _draw_marks() -> void:
	if _marks.is_empty() or size.x < 300.0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var font := get_theme_default_font()
	var blink := 1.0 if fmod(_t, 0.6) < 0.4 else 0.55
	for m: Dictionary in _marks:
		var at: Vector3 = m["at"]
		var behind := cam.is_position_behind(at)
		var p := cam.unproject_position(at)
		var inset := Rect2(Vector2(70, 90), size - Vector2(140, 200))
		var off := behind or not inset.has_point(p)
		if behind:
			# (behind you: low on the screen, toward the side to turn to)
			var right := (cam.global_transform.affine_inverse() * at).x > 0.0
			p = Vector2(size.x * (0.75 if right else 0.25), size.y)
		var free := bool(m.get("free", false))
		var head := "ROD %d: %s" % [int(m["i"]) + 1, str(m.get("word", "FISH ON"))]
		if behind:
			head = "ROD %d: BEHIND YOU" % (int(m["i"]) + 1)
		var under := ("E: TAKE THE ROD" if free else "%s'S ON IT" % str(m.get("who", "")).to_upper())
		under = Settings.say(under)
		var col := AMBER if free else PALE
		var w := maxf(_w(font, head, 18), _w(font, under, 12)) + 20.0
		if off:
			var c := size * 0.5
			var d := (p - c)
			if d.length() < 1.0:
				d = Vector2(0, 1)
			# out to the edge of the inset rectangle along d
			var sx := (inset.size.x * 0.5) / maxf(absf(d.x), 0.001)
			var sy := (inset.size.y * 0.5) / maxf(absf(d.y), 0.001)
			var q := c + d * minf(sx, sy)
			var n := d.normalized()
			_pointer(q, n, Color(col, blink))
			# (the words just inside the arrow, never over it)
			var mid := q - n * Vector2(w * 0.5 + 26.0, 46.0)
			var box := Vector2(clampf(roundf(mid.x - w * 0.5), 8.0, size.x - w - 8.0),
					clampf(roundf(mid.y - 23.0), 8.0, size.y - 60.0))
			draw_rect(Rect2(box, Vector2(w, 46)), Color(INK, INK.a))
			_text(font, box + Vector2(10, 22), head, 18, Color(col, 1.0))
			_text(font, box + Vector2(10, 38), under, 12, Color(PALE, blink if free else 0.8))
		else:
			# over the tip: a bobbing arrow down onto it, the words above
			var bob := roundf(sin(_t * 6.0) * 3.0)
			var tip := p.floor() + Vector2(0, -10 + bob)
			_pointer(tip, Vector2(0, 1), Color(col, blink))
			var box := Vector2(roundf(tip.x - w * 0.5), tip.y - 70.0)
			draw_rect(Rect2(box, Vector2(w, 46)), Color(INK, INK.a))
			_text(font, box + Vector2(10, 22), head, 18, Color(col, 1.0))
			_text(font, box + Vector2(10, 38), under, 12, Color(PALE, blink if free else 0.8))


## A chunky pixel arrowhead at `p` pointing along `dir`.
func _pointer(p: Vector2, dir: Vector2, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	for k in 8:
		var row := p - dir * float(k) * 4.0
		for s in range(-k, k + 1):
			draw_rect(Rect2((row + side * float(s) * 4.0).floor() - Vector2(2, 2), Vector2(4, 4)), col)


# ------------------------------------------------------------------ the moments

func _draw_banner() -> void:
	var k := clampf(_banner, 0.0, 1.0)
	var age := _banner_len - _banner
	var punch := 1.0 - smoothstep(0.0, 0.2, age)
	var font := get_theme_default_font()
	var px := 48 if _banner_col != GREEN else 36
	var y := roundf(size.y * 0.3 - punch * 24.0)
	var w := _w(font, _banner_text, px)
	var shake := Vector2(roundf(sin(age * 70.0) * 4.0 * punch), 0) if _banner_col == AMBER else Vector2.ZERO
	draw_rect(Rect2(Vector2(roundf((size.x - w) * 0.5) - 20.0, y - px - 12.0) + shake, Vector2(w + 40.0, px + 24.0)),
			Color(INK, INK.a * k))
	_text(font, Vector2((size.x - w) * 0.5, y) + shake, _banner_text, px, Color(_banner_col, k))
	var y2 := y + 36.0
	if not _banner_sub.is_empty():
		_plate_text(Vector2(size.x * 0.5, y2), _banner_sub, 24, Color(PALE, k), k, true)
		y2 += 42.0
	if not _lesson.is_empty() and _banner_col != AMBER:
		_plate_text(Vector2(size.x * 0.5, y2), _lesson, 18, Color(PALE, k), k, true)


## Words on a dark plate at `at` (its left end, or `centred` on it): the pixel font reads cleanest on a solid ground.
func _plate_text(at: Vector2, text: String, px: int, col: Color, a: float, centred := false) -> void:
	var font := get_theme_default_font()
	text = Settings.say(text)
	var w := _w(font, text, px)
	var x := roundf(at.x - w * 0.5) if centred else roundf(at.x)
	draw_rect(Rect2(Vector2(x - 12.0, at.y - px - 6.0), Vector2(w + 24.0, px + 16.0)), Color(INK, INK.a * a))
	_text(font, Vector2(x, at.y), text, px, col)


# ------------------------------------------------------------------ drawing

func _w(font: Font, text: String, px: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


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
	draw_string(font, at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
