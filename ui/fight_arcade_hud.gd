extends Control
## The arcade fight's HUD (tuna/fight_arcade.gd; rods.gd feeds it the fight in your hands every frame). All of it in
## chunky pixels, no sentences: it's read by shape, colour and motion.
##
## - **Under the crosshair**, the set-piece on now, each its own shape: the run a bar with his green band and your
##   needle; the head shakes a lane of beats coming to a gold box; the jump his arc over the water, red while your hands
##   must be off, a green ring where he lands; the pump a tall meter with gold at the top; the charge a line sagging
##   between the boat and him; the laps a ring, green toward you, red away.
## - **Under that**, the two buttons (the mouse's, or the pad's triggers): the one to hold lit green, to tap gold, to
##   hammer blinking, to leave alone crossed red; white round the one you've got down.
## - **Over the top**, how it's going: the line from the boat to him (how far, how frayed), his energy cut into its
##   stages, the hook's hold as pips, the streak, and where he is round the boat (for whoever's at the wheel).
## - A word when a piece ends (PERFECT, GOOD, OK, MISS) and the streak it leaves.

const Arcade := preload("res://tuna/fight_arcade.gd")
const PixFont := preload("res://ui/pixfont.gd")
const Sfx := preload("res://audio/sfx.gd")
const GREEN := Color(0.4, 0.95, 0.5)
const GOLD := Color(1.0, 0.82, 0.25)
const AMBER := Color(1.0, 0.62, 0.2)
const RED := Color(1.0, 0.28, 0.22)
const BLUE := Color(0.35, 0.7, 1.0)
const PALE := Color(0.95, 0.93, 0.86)
const DIM := Color(0.45, 0.5, 0.54)
const INK := Color(0.02, 0.03, 0.06, 0.85)
const DARK := Color(0.1, 0.13, 0.17, 0.9)

var _f: Arcade
var _v := {}
var _a := 0.0
var _t := 0.0
var _u := 3.0
var _o := Vector2.ZERO
var _al := 1.0
var _pop := ""
var _pop_n := 0
var _pop_t := 9.0
var _hit := 0.0          # (a beat, a stroke, a tap landed: the piece flashes)
var _hit_col := GOLD
var _bad := 0.0
var _step := 0.0         # (a stage cleared)
var _streak_t := 9.0
var _line := 0.0
var _energy := 1.0
var _fish_x := 1.0       # (the charge: him coming)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## The arcade fight in your hands this frame, or null.
func show_fight(f: Arcade) -> void:
	if f != null and f != _f:
		_line = f.line_out
		_energy = f.energy
	_f = f
	if f == null:
		return
	_v = f.view()
	for e: Array in f.take_events():
		match str(e[0]):
			"hit":
				_hit = 1.0
				_hit_col = GOLD if bool(e[1]) else GREEN
				Sfx.play("ui.tick", 0.55, (1.5 if bool(e[1]) else 1.2) + 0.03 * mini(f.streak, 10))
				Settings.buzz(0.0, 0.4, 0.05)
			"stroke":
				_hit = 0.7
				_hit_col = GOLD if float(e[1]) >= 1.0 else (GREEN if float(e[1]) >= 0.7 else DIM)
				Sfx.play("ui.tick", 0.4, 0.8 + 0.6 * float(e[1]))
			"miss", "whiff":
				_bad = 1.0
				Sfx.play("ui.cross", 0.4 if e[0] == "miss" else 0.2, 0.8)
				Settings.buzz(0.5, 0.0, 0.1)
			"grade":
				_pop = str(e[1]).to_upper()
				_pop_n = int(e[2])
				_pop_t = 0.0
				_streak_t = 0.0
				if e[1] == "perfect":
					Sfx.play("ui.check", 0.5, 1.0 + 0.04 * mini(_pop_n, 10))
			"stage":
				_step = 1.0
				Sfx.play("ui.stamp", 0.6, 1.0)
				Settings.buzz(0.3, 0.6, 0.2)


func _process(delta: float) -> void:
	_t += delta
	_a = move_toward(_a, 1.0 if _f != null else 0.0, delta * 4.0)
	_pop_t += delta
	_streak_t += delta
	_hit = maxf(_hit - delta * 4.0, 0.0)
	_bad = maxf(_bad - delta * 3.0, 0.0)
	_step = maxf(_step - delta * 0.8, 0.0)
	if _f != null:
		_line = lerpf(_line, _f.line_out, minf(1.0, delta * 8.0))
		_energy = lerpf(_energy, _f.energy, minf(1.0, delta * 5.0))
	visible = _a > 0.01
	queue_redraw()


func _draw() -> void:
	if _a <= 0.01 or _v.is_empty():
		return
	_u = maxf(roundf(size.y / 216.0), 2.0)
	_al = _a
	_draw_top()
	var c := Vector2(size.x * 0.5, size.y * 0.5 + 52.0 * _u).floor()
	_o = c
	var intro := float(_v["intro"])
	var blink := 0.6 + 0.4 * signf(sin(_t * 16.0)) if intro > 0.0 else 1.0
	_al = _a * blink
	var piece := str(_v["piece"])
	# its plate
	_r(-46, -20, 92, 40, INK)
	var edge := DARK
	if _bad > 0.0:
		edge = Color(RED, 0.5 + 0.5 * _bad)
	elif _hit > 0.0:
		edge = Color(_hit_col, 0.4 + 0.6 * _hit)
	elif float(_v["tension"]) > Arcade.OVER:
		edge = Color(RED, 0.5 + 0.5 * sin(_t * 20.0))
	_frame(-46, -20, 92, 40, edge)
	match piece:
		"run", "surge":
			_draw_run()
		"shake":
			_draw_shake()
		"jump":
			_draw_jump()
		"sound", "dog":
			_draw_pump()
		"charge":
			_draw_charge()
		"circle", "spiral":
			_draw_laps()
	if intro > 0.0:
		# (getting ready: a bar running out under it)
		_al = _a
		_r(-46, 21, 92.0 * clampf(intro / 1.5, 0.0, 1.0), 1, GOLD)
	_al = _a
	# the buttons, beside it, twice the size: they're what teaches it
	_o = c + Vector2(62.0, -16.0) * _u
	_u *= 2.0
	_draw_buttons()
	_u *= 0.5
	if _pop_t < 1.3:
		var col: Color = {"PERFECT": GOLD, "GOOD": GREEN, "OK": PALE, "MISS": RED}.get(_pop, PALE)
		var s := int(_u) * 2
		var text := _pop
		_al = _a * clampf((1.3 - _pop_t) / 0.4, 0.0, 1.0)
		var at := c + Vector2(-PixFont.width(text, s) * 0.5, (-34.0 - 8.0 * minf(_pop_t, 0.5)) * _u)
		_text(at, text, col, s)
		_al = _a


# ------------------------------------------------------------------ over the top: how it's going

func _draw_top() -> void:
	_o = Vector2(size.x * 0.5, 14.0 * _u).floor()
	var w := 120.0
	_r(-w * 0.5 - 16, -10, w + 32, 27, INK)
	# the line, from the boat (left) to him: how far (the far end's a full spool), how frayed
	var wear := float(_v["wear"])
	var line_col := PALE.lerp(RED, clampf(wear * 1.3, 0.0, 1.0))
	var x := -w * 0.5 + w * sqrt(clampf(_line / Arcade.CAPACITY, 0.0, 1.0))
	_r(-w * 0.5, 0, w, 1, Color(DIM, 0.5))
	_r(-w * 0.5, 0, x + w * 0.5, 1, line_col)
	if wear > 0.05:
		# (frayed: bits standing off it)
		for i in int(wear * 8.0) + 1:
			_r(-w * 0.5 + 6.0 + i * 9.0, -1 if i % 2 == 0 else 1, 1, 1, line_col)
	# the boat
	_r(-w * 0.5 - 9, -1, 8, 3, PALE)
	_r(-w * 0.5 - 7, -3, 3, 2, PALE)
	_r(-w * 0.5 - 8, 2, 6, 1, DIM)
	# him
	_fish(x + 1.0, 0.0, RED.lerp(BLUE, 0.5) if _step <= 0.0 else GOLD, 1.0)
	var dist := "%dM" % int(_line)
	_text(_at(clampf(x - PixFont.width(dist, 1) * 0.5, -w * 0.5, w * 0.5 - 16.0), -9.0), dist, PALE, int(_u))
	# his energy, in its stages: what's left of each
	var n := int(_v["stages"])
	var left := clampf((_energy - 0.2) / 0.8, 0.0, 1.0) * n
	var sw := (w - (n - 1) * 2.0) / n
	for i in n:
		var sx := -w * 0.5 + i * (sw + 2.0)
		var fill := clampf(left - (n - 1 - i), 0.0, 1.0)       # (they empty from the left: the boat's end)
		_r(sx, 5, sw, 4, DARK)
		if fill > 0.0:
			_r(sx + sw * (1.0 - fill), 5, sw * fill, 4, RED.lerp(AMBER, float(i) / maxf(n - 1.0, 1.0)))
		elif _step > 0.0 and i == n - int(_v["stage"]):
			_r(sx, 5, sw, 4, Color(GOLD, _step))
	# the hook's hold: five pips
	var hold := float(_v["hold"])
	_hook(-w * 0.5 - 12.0, 5.0, PALE)
	for i in 5:
		var on := hold > i * 0.2 + 0.02
		_r(-w * 0.5 + i * 5.0, 12, 4, 3, (GOLD if hold > 0.45 else RED) if on else DARK)
	# the streak
	var st := int(_v["streak"])
	if st > 0:
		var s := int(_u) * (2 if _streak_t < 0.25 else 1)
		var text := "X%d" % st
		_text(_at(w * 0.5 - PixFont.width(text, 1) - 14.0, 11.0), text, GOLD if st >= 3 else PALE, s)
	# where he is round her (from above: her bow up, him a dot): green astern, red forward of the beam
	if _f != null:
		var bx := w * 0.5 + 8.0
		_r(bx - 1.5, 6, 3, 6, PALE)
		_r(bx - 0.5, 4, 1, 2, PALE)
		var b := wrapf(_f.bearing, -PI, PI)
		var ang := float(_v["angle"])
		var d := Vector2(sin(b), cos(b)) * 6.5
		_r(bx + d.x - 1.0, 9.0 + d.y - 1.0, 2, 2, GREEN if ang > 0.8 else (AMBER if ang > 0.4 else RED))


# ------------------------------------------------------------------ the set-pieces

## The run: a bar, slack (blue) at its left, parting (red) at its right; his green band moving; your needle.
func _draw_run() -> void:
	var w := 80.0
	_r(-40, -4, w, 8, DARK)
	_r(-40, -4, 5, 8, Color(BLUE, 0.55))
	_r(35, -4, 5, 8, Color(RED, 0.6))
	var bc := float(_v["band_c"])
	var bw := float(_v["band_w"])
	var n := float(_v["needle"])
	var inside := absf(n - bc) <= bw
	_r(-40.0 + (bc - bw) * w, -4, 2.0 * bw * w, 8, Color(GREEN, 0.95 if inside else 0.55))
	_fish(-40.0 + bc * w, -10.0, GREEN if inside else PALE, -1.0)
	var col := PALE if inside else (RED if n > bc else BLUE)
	var nx := -40.0 + n * w
	_r(nx - 1.0, -7, 2, 14, col)
	_r(nx - 2.0, 7, 4, 2, col)
	# (which way to take it)
	if not inside:
		var way := 1.0 if n < bc else -1.0
		for i in 3:
			_r(nx + way * (4.0 + i * 3.0 + fmod(_t * 6.0, 3.0)) - 0.5, 12, 1, 2, col)
	# the line pouring off, at the slack end: a spool, turning faster the looser
	var spin := _t * (4.0 + 20.0 * clampf(bc - bw - n, 0.0, 0.3) / 0.3)
	_r(-44.5 + cos(spin) * 2.0, 12.0 + sin(spin) * 2.0, 1, 1, BLUE)
	_r(-45, 11.5, 2, 2, Color(BLUE, 0.5))


## The head shakes: beats coming down a lane from the right to the gold box.
func _draw_shake() -> void:
	_r(-40, -3, 80, 6, DARK)
	var box := -28.0
	var t := float(_v["t"])
	var beats: PackedFloat32Array = _v["beats"]
	var hits: PackedByteArray = _v["beat_hit"]
	var near := 9.0
	for i in beats.size():
		var dt := beats[i] - t
		var x := box + dt * 30.0
		if hits[i] == 0:
			near = minf(near, absf(dt))
			if x < 42.0:
				_r(x - 2.0, -5, 4, 10, PALE)
				_r(x - 3.0, -2, 1, 4, PALE)
		elif hits[i] == 3 and dt > -0.5:
			_r(x - 2.0, -5, 4, 10, Color(RED, 1.0 + dt * 2.0))
	var lit := near < Arcade.HIT_GOOD
	var col := Color(_hit_col, 1.0) if _hit > 0.0 else (GOLD if lit else Color(GOLD, 0.6))
	var g := 1.0 + 2.0 * _hit
	_frame(box - 4.0 - g, -8.0 - g, 8.0 + 2.0 * g, 16.0 + 2.0 * g, col)
	_fish(34.0, -12.0 + sin(t * TAU / Arcade.BEAT) * 2.0, PALE, -1.0)


## The jump: his arc over the water from the left; red while your hands must be off; the green ring where he lands.
func _draw_jump() -> void:
	var air := float(_v["air"])
	var up := float(_v["up"])
	for i in 20:
		_r(-40.0 + i * 4.0, 9.0 + (1.0 if (i + int(_t * 3.0)) % 2 == 0 else 0.0), 3, 1, BLUE)
	var x0 := -22.0
	var x1 := 24.0
	var off := Arcade.HANDS_OFF / Arcade.AIR
	for i in 24:
		var s := (i + 0.5) / 24.0
		var p := Vector2(lerpf(x0, x1, s), 9.0 - 22.0 * sin(PI * s))
		_r(p.x - 0.5, p.y - 0.5, 1, 1, Color(RED, 0.9) if s < off else Color(DIM, 0.8))
	# where he lands: a ring closing on it
	var landed := int(_v["landed"])
	var ring_col := GOLD if landed == 2 else GREEN
	_frame(x1 - 4.0, 5, 8, 8, ring_col)
	if landed == 0 and air < Arcade.AIR:
		var g := clampf((Arcade.AIR - air) / (Arcade.AIR + up), 0.0, 1.0) * 14.0
		_frame(x1 - 4.0 - g, 5.0 - g, 8.0 + 2.0 * g, 8.0 + 2.0 * g, Color(GREEN, 0.5))
	# him
	var fp := Vector2(x0, 9.0)
	if air < 0.0:
		var k := clampf(1.0 + air / up, 0.0, 1.0)
		fp = Vector2(lerpf(x0 - 16.0, x0, k), lerpf(18.0, 9.0, k))
		for i in 3:
			_r(x0 - 0.5, 3.0 - i * 3.0 - fmod(_t * 8.0, 3.0), 1, 2, Color(AMBER, 0.9))
	else:
		var s := clampf(air / Arcade.AIR, 0.0, 1.0)
		fp = Vector2(lerpf(x0, x1, s), 9.0 - 22.0 * sin(PI * s))
		if s >= 1.0:
			for i in 5:
				var r := (air - Arcade.AIR) * 14.0
				_r(x1 + (i - 2) * (2.0 + r * 0.5), 8.0 - r * (1.0 - absf(i - 2) * 0.3), 1, 2, PALE)
	_fish(fp.x, fp.y, RED if air >= 0.0 and air < Arcade.HANDS_OFF and float(_v["bad"]) > 0.0 else PALE, 1.0)


## The pump: a tall meter, gold at its top; lift into the gold, wind down. The kick: it flares amber, then red.
func _draw_pump() -> void:
	var h := 32.0
	var rod := float(_v["rod"])
	var kick := int(_v["kick"])
	_r(-5, -16, 10, h, DARK)
	var gold_h := h * (1.0 - Arcade.GOLD)
	_r(-5, -16, 10, gold_h, Color(GOLD, 0.35 + 0.25 * sin(_t * 6.0)))
	var col := GOLD if rod >= Arcade.GOLD else PALE
	if int(_v["dir"]) == -1:
		col = GREEN
	_r(-4, 16.0 - h * rod, 8, h * rod, col)
	_r(-7, 16.0 - h * rod - 1.0, 14, 2, col)
	if kick > 0:
		var kc := AMBER if kick == 1 else RED
		if kick == 2 or sin(_t * 30.0) > 0.0:
			_frame(-8, -19, 16, h + 6.0, kc)
			_text(_at(11.0, -4.0), "!", kc, int(_u) * 2)
			_text(_at(-15.0, -4.0), "!", kc, int(_u) * 2)
	else:
		# which way now: up the left (lift), down the right (wind)
		var lifting := int(_v["b"]) == 1
		_arrow(-16.0, 0.0, -1.0, PALE if lifting else Color(DIM, 0.5), lifting)
		_arrow(16.0, 0.0, 1.0, GREEN if not lifting else Color(DIM, 0.5), not lifting)
	# him, down there: deeper the further into it
	_fish(30.0, 8.0 + 3.0 * sin(_t * 2.0), PALE, -1.0)
	_r(5, 16.0 - h * rod, 22, 1, Color(PALE, 0.4))


## The charge: the line between the boat and him, sagging as it slackens; down in the water and it's red.
func _draw_charge() -> void:
	var slack := float(_v["slack"])
	var k := clampf(float(_v["t"]) / maxf(float(_v["len"]), 0.1), 0.0, 1.0)
	_fish_x = lerpf(38.0, 2.0, k)
	for i in 20:
		_r(-40.0 + i * 4.0, 13.0 + (1.0 if (i + int(_t * 3.0)) % 2 == 0 else 0.0), 3, 1, BLUE)
	_r(-40, -4, 6, 10, PALE)
	_r(-36, -12, 1, 8, PALE)
	var x0 := -35.0
	var col := PALE.lerp(RED, smoothstep(0.5, 0.85, slack))
	var n := 22
	for i in n + 1:
		var s := float(i) / n
		var sag := 4.0 * s * (1.0 - s) * (2.0 + 20.0 * slack)
		_r(lerpf(x0, _fish_x, s) - 0.5, -11.0 + 9.0 * s + sag, 1.5, 1.5, col)
	_fish(_fish_x + 3.0, 0.0, PALE, 1.0)
	for i in 3:
		_r(_fish_x + 9.0 + i * 3.0 + fmod(_t * 12.0, 3.0), -1.0 + i, 2, 1, Color(PALE, 0.5))


## The laps: a ring; the green of it (at the bottom: toward you) is him coming up, wind; the red, going away, brace.
func _draw_laps() -> void:
	var lap := float(_v["lap"])
	var g := float(_v["green"])
	var n := 32
	var rad := 15.0
	var is_green := lap < g and float(_v["intro"]) <= 0.0
	for i in n:
		var ph := float(i) / n
		var ang := PI * 0.5 + TAU * (ph - g * 0.5)
		var p := Vector2(cos(ang), sin(ang)) * rad
		var in_g := ph < g
		var col := Color(GREEN, 1.0 if is_green else 0.6) if in_g else Color(RED, 0.75 if not is_green else 0.4)
		_r(p.x - 1.0, p.y - 1.0, 2, 2, col)
	# (the mark where he turns toward you: on to the handle right there)
	var a0 := PI * 0.5 + TAU * (-g * 0.5)
	var p0 := Vector2(cos(a0), sin(a0))
	_r(p0.x * (rad + 3.0) - 1.0, p0.y * (rad + 3.0) - 1.0, 2, 2, GOLD)
	_r(p0.x * (rad - 3.0) - 1.0, p0.y * (rad - 3.0) - 1.0, 2, 2, GOLD)
	var am := PI * 0.5 + TAU * (lap - g * 0.5)
	var pm := Vector2(cos(am), sin(am)) * rad
	var mc := GOLD if bool(_v["arc_perfect"]) and is_green else (GREEN if is_green else PALE)
	if float(_v["red_t"]) > 0.2:
		mc = RED
	_r(pm.x - 2.5, pm.y - 2.5, 5, 5, mc)
	_r(pm.x - 1.0, pm.y - 1.0, 2, 2, INK)
	# you, at the bottom; the line to him
	_r(-2, rad + 3.0, 4, 2, PALE)
	_fish(pm.x * 0.45, pm.y * 0.45, Color(mc, 0.7), 1.0 if pm.x >= 0.0 else -1.0)


# ------------------------------------------------------------------ the buttons

## The mouse (A its left button, B its right) or the pad's triggers (LT is B, RT is A): what each wants now.
func _draw_buttons() -> void:
	var want_a := int(_v["a"])
	var want_b := int(_v["b"])
	var down_a := Input.is_action_pressed("use_primary")
	var down_b := Input.is_action_pressed("use_secondary")
	if Settings.pad:
		_trigger(-14.0, "LT", want_b, down_b)
		_trigger(4.0, "RT", want_a, down_a)
		_reel(6.0, 11.0, _want_col(want_a))
		_rodpic(-12.0, 10.0, _want_col(want_b))
		return
	# the mouse: its body, its two buttons
	_r(-6, -2, 12, 16, INK)
	_frame(-6, -2, 12, 16, DIM)
	_r(-5, 6, 10, 7, Color(DIM, 0.35))
	_btn(-5.0, -1.0, 4.5, 6.0, want_a, down_a)
	_btn(0.5, -1.0, 4.5, 6.0, want_b, down_b)
	_reel(-6.0, 17.0, _want_col(want_a))
	_rodpic(1.0, 16.0, _want_col(want_b))


func _want_col(want: int) -> Color:
	match want:
		1:
			return GREEN
		2:
			return GOLD
		3:
			return GOLD if sin(_t * 28.0) > 0.0 else Color(GOLD, 0.35)
		-1:
			return RED
	return Color(DIM, 0.6)


func _btn(x: float, y: float, w: float, h: float, want: int, down: bool) -> void:
	_r(x, y, w, h, _want_col(want) if want != 0 else DARK)
	if want == -1:
		_r(x + 1.0, y + 2.5, w - 2.0, 1, INK)
	if down:
		_frame(x - 1.0, y - 1.0, w + 2.0, h + 2.0, PALE)


func _trigger(x: float, label: String, want: int, down: bool) -> void:
	_r(x, 0, 10, 8, _want_col(want) if want != 0 else DARK)
	_text(_at(x + 1.5, 1.5), label, INK if want != 0 else DIM, int(_u))
	if down:
		_frame(x - 1.0, -1, 12, 10, PALE)


## A reel (A winds) and a rod (B leans back), beside their buttons.
func _reel(x: float, y: float, col: Color) -> void:
	_r(x, y + 1.0, 5, 3, col)
	_r(x + 1.0, y, 3, 5, col)
	_r(x + 2.0, y + 2.0, 1, 1, INK)
	var a := _t * 6.0 if int(_v["a"]) > 0 else 0.6
	_r(x + 2.0 + cos(a) * 3.5, y + 2.0 + sin(a) * 3.5, 1.5, 1.5, col)


func _rodpic(x: float, y: float, col: Color) -> void:
	for i in 6:
		_r(x + i, y + 5.0 - i, 1.5, 1.5, col)
	_r(x + 6.0, y, 1, 4, Color(col, 0.6))


# ------------------------------------------------------------------ bits

func _at(x: float, y: float) -> Vector2:
	return (_o + Vector2(x, y) * _u).floor()


func _r(x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2((_o + Vector2(x, y) * _u).floor(), (Vector2(w, h) * _u).ceil()), Color(col, col.a * _al))


func _frame(x: float, y: float, w: float, h: float, col: Color) -> void:
	_r(x, y, w, 1, col)
	_r(x, y + h - 1.0, w, 1, col)
	_r(x, y, 1, h, col)
	_r(x + w - 1.0, y, 1, h, col)


func _text(at: Vector2, text: String, col: Color, scale: int) -> void:
	PixFont.draw(self, at + Vector2(scale, scale), text, Color(INK, _al), scale)
	PixFont.draw(self, at, text, Color(col, col.a * _al), scale)


## A little tuna, its nose at x toward `way` (+1 right, -1 left), centred on y.
func _fish(x: float, y: float, col: Color, way: float) -> void:
	_r(x - (3.0 if way > 0.0 else -0.0) - 1.5, y - 1.5, 6, 3, col)
	_r(x + (2.5 if way > 0.0 else -4.5), y - 0.5, 2, 1, col)
	_r(x - (5.5 if way > 0.0 else -4.5), y - 2.5, 1, 5, col)
	_r(x - (4.5 if way > 0.0 else -3.5), y - 1.0, 1, 2, col)
	_r(x - 1.0, y - 2.5, 2, 1, col)


func _hook(x: float, y: float, col: Color) -> void:
	_r(x + 3.0, y, 1, 6, col)
	_r(x, y + 5.0, 3, 1, col)
	_r(x, y + 3.0, 1, 2, col)
	_r(x + 2.0, y - 1.0, 3, 1, col)


## An arrow, up (`way` -1) or down (+1), bobbing that way when it's `on`.
func _arrow(x: float, y: float, way: float, col: Color, on: bool) -> void:
	var bob := way * fmod(_t * 5.0, 2.0) if on else 0.0
	y += bob
	_r(x - 1.0, y - 4.0, 2, 8, col)
	_r(x - 3.0, y + way * 2.0 - (1.0 if way < 0.0 else 0.0), 6, 1, col)
	_r(x - 2.0, y + way * 3.0 - (1.0 if way < 0.0 else 0.0), 4, 1, col)
	_r(x - 1.0, y + way * 4.0 - (1.0 if way < 0.0 else 0.0), 2, 1, col)
