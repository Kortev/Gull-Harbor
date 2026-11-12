extends Control
## The arcade fight's HUD (tuna/fight_arcade.gd; rods.gd feeds it the fight in your hands every frame), in the new
## look (ui/kit.gd): one fight HUD, read by shape, colour and motion.
##
## - **The stage**, centre-low, a fifth of the screen wide: the minigame on now draws itself there
##   (tuna/minigames/*.gd's draw()), its name over it, the games left in this set as dots. A boss's is edged in gold.
## - **The two buttons**, either side of it, A's on the left and B's on the right (as they are under your fingers):
##   the mouse with that button lit, or the pad's trigger, moving the way it's asked: HOLD, TAP, MASH, LET GO, HANDS OFF.
## - **The band**, top middle: the hook's hold (a ring round the hook, left), his energy in its stages and the line
##   out from the boat to him (middle), and the combo (right): the loudest thing on it, growing as it grows, with the
##   ring round it filling toward the next BIG PULL.
## - **The pops**: each game's grade (PERFECT, GREAT, OK, MISS) springs up over the stage and drifts off; sparks fly
##   off the stage on every hit; and the BIG PULL takes the whole screen for a second: a flash, a burst, the metres won
##   counting up.
## The sounds, the hit-stop, the rod's kick and the rumble are ui/juice.gd's.

const Arcade := preload("res://tuna/fight_arcade.gd")
const Kit := preload("res://ui/kit.gd")
const Juice := preload("res://ui/juice.gd")
const Pull := preload("res://tuna/minigames/pull.gd")
const GRADE_COL := {"PERFECT": Kit.GOLD, "GREAT": Kit.GO, "OK": Kit.FOAM, "MISS": Kit.CORAL}

## rods/rods.gd, for the juice's rod kick (rods.gd sets it).
var rods: Node:
	set(v):
		rods = v
		juice.rods = v
var kit := Kit.new()
var juice := Juice.new()

var _f: Arcade
var _v := {}
var _a := 0.0
var _t := 0.0
var _s := 1.0
var _blur_band: ColorRect
var _blur_stage: ColorRect
var _base: Control
var _game: Control
var _over: Control
# what's eased: the line, his energy, the hook, the combo's size
var _line := 0.0
var _energy := 1.0
var _hold := 1.0
var _combo_t := 9.0
var _combo_was := 0
# the stage
var _game_a := 0.0          # (the game's drawing, faded in)
var _game_t := 0.0          # (s since this game came on)
var _hit := 0.0
var _hit_col := Kit.GOLD
var _bad := 0.0
var _step := 0.0            # (a stage cleared)
var _boss := 0.0
var _last_title := ""
# the pops
var _pop := ""
var _pop_t := 9.0
var _pull_t := 9.0
var _pull_m := 0.0
var _pull_ready := 9.0
var _sparks: Array = []     # [pos, vel, life, max, col, r]


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur_band = Kit.blur_rect()
	_blur_stage = Kit.blur_rect()
	add_child(_blur_band)
	add_child(_blur_stage)
	_base = _layer(_draw_base)
	_game = _layer(_draw_game)
	_over = _layer(_draw_over)


func _layer(fn: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	c.draw.connect(fn)
	add_child(c)
	return c


func _ready() -> void:
	# (the new look's lines and shapes are smooth: the 2D's anti-aliased from here on)
	get_viewport().msaa_2d = Viewport.MSAA_4X
	Arcade.beat_fn = _beat


## The music's beat for the games that play to it: [s a beat, s to the next].
func _beat() -> Array:
	var cue: Dictionary = Music.call("_cue_of", Music.cue)
	var bpm := float(cue.get("bpm", 0.0))
	if bpm <= 0.0:
		return [0.0, 0.0]
	return [60.0 / bpm, maxf(Music.next_tick(1) - Music.now(), 0.0)]


## The arcade fight in your hands this frame, or null.
func show_fight(f: Arcade) -> void:
	if f != null and f != _f:
		_line = f.line_out
		_energy = f.energy
		_hold = f.hold
		_combo_was = f.combo
	_f = f
	if f == null:
		return
	_v = f.view()
	for e: Array in f.take_events():
		juice.on_event(e, f)
		_on_event(e)


func _on_event(e: Array) -> void:
	match str(e[0]):
		"hit":
			_hit = 1.0
			_hit_col = Kit.GOLD if int(e[1]) >= 2 else Kit.GO
			_sparks_off(_stage_rect(), _hit_col, 14 if int(e[1]) >= 2 else 6)
		"stroke":
			_hit = 0.6
			_hit_col = Kit.GOLD if float(e[1]) >= 1.0 else Kit.GO
		"miss":
			_bad = 1.0
		"game":
			_game_t = 0.0
			_game_a = 0.0
			_boss = 1.0 if bool(e[2]) else 0.0
		"grade":
			_pop = str(e[1]).to_upper()
			_pop_t = 0.0
			if e[1] == "perfect":
				_burst(_stage_rect().get_center() - Vector2(0.0, _stage_rect().size.y * 0.5 + 10.0 * _s), Kit.GOLD, 18, 240.0)
		"pull_ready":
			_pull_ready = 0.0
		"pull":
			_pull_t = 0.0
			_pull_m = float(e[1])
			_burst(Vector2(size.x * 0.5, size.y * 0.42), Kit.GOLD, 70, 620.0)
			_burst(Vector2(size.x * 0.5, size.y * 0.42), Kit.FOAM, 30, 420.0)
		"stage":
			_step = 1.0
		"boss":
			_boss = 0.0
			if bool(e[1]):
				_pop = "BOSS DOWN"
				_pop_t = 0.0


## Sparks off the stage's edge, flying outward (never over the game).
func _sparks_off(r: Rect2, col: Color, n: int) -> void:
	for i in n:
		var k := randf()
		var side := randi() % 4
		var at := Vector2(lerpf(r.position.x, r.end.x, k), r.position.y if side == 0 else r.end.y)
		var out := Vector2(0.0, -1.0 if side == 0 else 1.0)
		if side >= 2:
			at = Vector2(r.position.x if side == 2 else r.end.x, lerpf(r.position.y, r.end.y, k))
			out = Vector2(-1.0 if side == 2 else 1.0, 0.0)
		var v := (out + Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))) * randf_range(60.0, 190.0) * _s
		var life := randf_range(0.3, 0.65)
		_sparks.append([at, v, life, life, col, randf_range(1.4, 2.8) * _s])


func _burst(at: Vector2, col: Color, n: int, speed: float) -> void:
	for i in n:
		var ang := randf() * TAU
		var v := Vector2.from_angle(ang) * speed * _s * randf_range(0.35, 1.0)
		var life := randf_range(0.35, 0.8)
		_sparks.append([at + v * 0.03, v, life, life, col, randf_range(1.5, 3.2) * _s])
	if _sparks.size() > 260:
		_sparks = _sparks.slice(-260)


func _process(delta: float) -> void:
	_t += delta
	_a = move_toward(_a, 1.0 if _f != null else 0.0, delta * 4.0)
	_pop_t += delta
	_pull_t += delta
	_pull_ready += delta
	_combo_t += delta
	_game_t += delta
	_hit = maxf(_hit - delta * 4.0, 0.0)
	_bad = maxf(_bad - delta * 3.0, 0.0)
	_step = maxf(_step - delta * 0.8, 0.0)
	if _f != null:
		_line = Kit.follow(_line, _f.line_out, delta, 9.0)
		_energy = Kit.follow(_energy, _f.energy, delta, 5.0)
		_hold = Kit.follow(_hold, _f.hold, delta, 6.0)
		if _f.combo != _combo_was:
			_combo_was = _f.combo
			_combo_t = 0.0
		_game_a = move_toward(_game_a, 1.0 if _f.game != null else 0.0, delta * (7.0 if _f.game != null else 5.0))
	for i in range(_sparks.size() - 1, -1, -1):
		var p: Array = _sparks[i]
		p[2] = float(p[2]) - delta
		if float(p[2]) <= 0.0:
			_sparks.remove_at(i)
			continue
		p[1] = (p[1] as Vector2) * exp(-2.5 * delta) + Vector2(0.0, 300.0 * _s * delta)
		p[0] = (p[0] as Vector2) + (p[1] as Vector2) * delta
	visible = _a > 0.01
	if not visible:
		return
	_s = maxf(size.y / 648.0, 0.25)
	var band := _band_rect()
	var stage := _stage_rect()
	Kit.place(_blur_band, band, 20.0 * _s, _a)
	Kit.place(_blur_stage, stage, 18.0 * _s, _a)
	_base.modulate.a = _a
	_game.modulate.a = _a * Kit.out_cubic(_game_a)
	# (a game comes on with a little spring)
	_game.pivot_offset = stage.get_center()
	_game.scale = Vector2.ONE * lerpf(0.9, 1.0, Kit.out_back(_game_t / 0.22))
	_over.modulate.a = _a
	_base.queue_redraw()
	_game.queue_redraw()
	_over.queue_redraw()


func _band_rect() -> Rect2:
	var w := 500.0 * _s
	return Rect2(size.x * 0.5 - w * 0.5, 18.0 * _s, w, 58.0 * _s)


func _stage_rect() -> Rect2:
	var w := maxf(size.x * 0.215, 240.0 * _s)
	var h := 132.0 * _s
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y * 0.735 - h * 0.5, w, h)
	# (a perfect: it jumps a hair)
	return r.grow(4.0 * _s * _hit * (1.0 if _hit_col == Kit.GOLD else 0.4))


# ------------------------------------------------------------------ the band and the stage's panel

func _draw_base() -> void:
	if _v.is_empty():
		return
	var ci := _base
	var s := _s
	var band := _band_rect()
	kit.glass(ci, band, 20.0 * s)
	var cy := band.get_center().y
	# --- the hook's hold: a ring round the hook
	var hc := Vector2(band.position.x + 6.0 * s, cy)
	var hr := 30.0 * s
	var low := _hold < 0.42
	kit.dot(ci, hc, hr + 5.0 * s, Color(Kit.DEEP, 0.92))
	kit.ring(ci, hc, hr + 5.0 * s, Kit.EDGE, 1.0)
	kit.ring(ci, hc, hr, Kit.TRACK, 3.0 * s)
	var hold_col := Kit.CORAL if low else Kit.FOAM
	if low:
		hold_col.a = 0.65 + 0.35 * sin(_t * 10.0)
	kit.arc(ci, hc, hr, -PI * 0.5, -PI * 0.5 + TAU * clampf(_hold, 0.0, 1.0), hold_col, 3.0 * s)
	kit.hook(ci, hc + Vector2(0.0, -1.0 * s), 24.0 * s, hold_col, 2.5 * s)
	# --- the combo: a ring filling toward the next BIG PULL, the number in it growing as it grows
	var combo := int(_v["combo"])
	var grown := clampf(combo / 20.0, 0.0, 1.0)
	var cr := (32.0 + 10.0 * grown) * s
	var cc := Vector2(band.end.x - 6.0 * s, cy + 3.0 * s * grown)
	var pulse := Kit.pop(_combo_t, 0.35, 0.45)
	var due: bool = _f != null and (str(_v["phase"]) == "pull" or (_pull_ready < 2.0 and _f.game == null))
	kit.dot(ci, cc, (cr + 6.0 * s) * pulse, Color(Kit.DEEP, 0.94))
	if combo > 0:
		kit.glow(ci, cc, (cr + 26.0 * s * (0.4 + grown)) * pulse, Kit.GOLD, 0.5 + 1.2 * grown + (1.0 if due else 0.0))
	kit.ring(ci, cc, (cr + 6.0 * s) * pulse, Color(Kit.GOLD, 0.5) if combo > 0 else Kit.EDGE, 1.0)
	kit.ring(ci, cc, cr * pulse, Kit.TRACK, 5.0 * s)
	var every := Arcade.PULL_EVERY
	var to_pull := 1.0 if due else clampf(1.0 - float(int(_v["next_pull"]) - combo) / every, 0.0, 1.0)
	if to_pull > 0.0:
		kit.arc(ci, cc, cr * pulse, -PI * 0.5, -PI * 0.5 + TAU * to_pull, Kit.GOLD, 5.0 * s)
	for i in every:
		var a := -PI * 0.5 + TAU * i / every
		kit.line(ci, cc + Vector2.from_angle(a) * (cr - 4.0 * s) * pulse, cc + Vector2.from_angle(a) * (cr + 4.0 * s) * pulse, Color(Kit.DEEP, 0.9), 2.0 * s, false)
	if combo > 0:
		kit.text_pop(ci, cc + Vector2(0.0, -3.0 * s), "x%d" % combo, (25.0 + 9.0 * grown) * s, Kit.GOLD, pulse)
		kit.text(ci, cc + Vector2(0.0, (15.0 + 4.0 * grown) * s), "COMBO", 8.5 * s, Color(Kit.GOLD, 0.8), 0, 700, 1.2 * s, false)
	else:
		kit.text(ci, cc, "COMBO", 9.5 * s, Kit.DIM, 0, 700, 1.2 * s, false)
	# --- the middle: his energy in its stages, the line out under it
	var x0 := band.position.x + 62.0 * s
	var x1 := band.end.x - 70.0 * s - 10.0 * s * grown
	var w := x1 - x0
	var ey := cy - 9.0 * s
	var n := int(_v["stages"])
	var left := clampf((_energy - 0.2) / 0.8, 0.0, 1.0) * n
	var gap := 4.0 * s
	var sw := (w - 26.0 * s - (n - 1) * gap) / n
	kit.fish(ci, Vector2(x0 + 9.0 * s, ey), 24.0 * s, Kit.CORAL.lerp(Kit.GOLD, _step), 1.0)
	for i in n:
		var r := Rect2(x0 + 26.0 * s + i * (sw + gap), ey - 4.5 * s, sw, 9.0 * s)
		var fill := clampf(left - (n - 1 - i), 0.0, 1.0)       # (they empty from the left)
		kit.pill(ci, r, Kit.TRACK)
		if fill > 0.0:
			var fw := maxf(sw * fill, r.size.y)
			kit.pill(ci, Rect2(r.end.x - fw, r.position.y, fw, r.size.y), Kit.CORAL.lerp(Kit.GOLD, 0.55 * i / maxf(n - 1.0, 1.0)))
			if _boss > 0.0 and fill < 1.0:
				kit.rrect(ci, r.grow(2.0 * s), r.size.y, Color(0, 0, 0, 0), Color(Kit.GOLD, 0.6 + 0.4 * sin(_t * 8.0)), 1.5 * s)
		elif _step > 0.0 and i == n - int(_v["stage"]):
			kit.pill(ci, r, Color(Kit.GOLD, _step))
			kit.glow(ci, r.get_center(), sw * 0.7, Kit.GOLD, 2.0 * _step)
	# the line: the boat, the line out (the far end's a full spool), him; red as it wears
	var ly := cy + 12.0 * s
	var wear := float(_v["wear"])
	var line_col := Kit.FOAM.lerp(Kit.CORAL, clampf(wear * 1.3, 0.0, 1.0))
	var dist := "%d m" % int(_line)
	var lx1 := x1 - 50.0 * s
	var lx0 := x0 + 22.0 * s
	var fx := lerpf(lx0, lx1, sqrt(clampf(_line / Arcade.CAPACITY, 0.0, 1.0)))
	kit.boat(ci, Vector2(x0 + 9.0 * s, ly - 1.0 * s), 18.0 * s, Kit.MIST, 1.0)
	kit.line(ci, Vector2(lx0, ly), Vector2(lx1, ly), Kit.TRACK, 2.0 * s)
	kit.line(ci, Vector2(lx0, ly), Vector2(fx, ly), line_col, 2.0 * s)
	kit.dot(ci, Vector2(fx, ly), 4.0 * s, line_col)
	kit.text(ci, Vector2(x1, ly), dist, 15.0 * s, Kit.FOAM, 1, 600)
	if bool(_v["leader"]):
		kit.text(ci, Vector2(x1, ey), "LEADER", 9.0 * s, Kit.GOLD, 1, 700, 1.0 * s, false)
	elif float(_v["angle"]) < 0.75:
		# (he's off her stern: everything you do counts for less till she's turned to him)
		kit.text(ci, Vector2(band.get_center().x, band.end.y + 12.0 * s), "HE'S OFF THE STERN", 10.0 * s, Color(Kit.GOLD, 0.6 + 0.4 * sin(_t * 5.0)), 0, 700, 1.5 * s)

	# --- the stage: its panel, its name, the games left in the set, the two buttons
	var stage := _stage_rect()
	var edge := Kit.EDGE
	if _bad > 0.0:
		edge = Kit.EDGE.lerp(Kit.CORAL, _bad)
	elif _hit > 0.0:
		edge = Kit.EDGE.lerp(_hit_col, _hit)
	elif _boss > 0.0:
		edge = Color(Kit.GOLD, 0.75)
	elif float(_v["tension"]) > Arcade.OVER:
		edge = Kit.EDGE.lerp(Kit.CORAL, 0.5 + 0.5 * sin(_t * 20.0))
	if _hit > 0.0 or _bad > 0.0:
		var gc := Kit.CORAL if _bad > 0.0 else _hit_col
		kit.rrect(ci, stage.grow(3.0 * s), 21.0 * s, Color(0, 0, 0, 0), Color(gc, 0.0), 0.0, 22.0 * s * maxf(_hit, _bad), Color(gc, 0.5 * maxf(_hit, _bad)))
	kit.glass(ci, stage, 18.0 * s)
	kit.rrect(ci, stage, 18.0 * s, Color(0, 0, 0, 0), edge, 1.5 * s)
	var title := str(_v["title"])
	if title != "":
		_last_title = title
	var ta := Kit.out_cubic(_game_a)
	if _boss > 0.0:
		var bw := kit.text(ci, stage.position + Vector2(14.0 * s, 13.0 * s), "BOSS", 9.5 * s, Color(Kit.GOLD, ta), -1, 700, 1.5 * s, false)
		kit.text(ci, stage.position + Vector2(22.0 * s + bw, 13.0 * s), _last_title, 9.5 * s, Color(Kit.MIST, 0.9 * ta), -1, 700, 1.5 * s, false)
	else:
		kit.text(ci, stage.position + Vector2(14.0 * s, 13.0 * s), _last_title, 9.5 * s, Color(Kit.MIST, 0.9 * ta), -1, 700, 1.5 * s, false)
	var more := int(_v["set_left"]) - (1 if _f != null and _f.game != null else 0)
	for i in clampi(more, 0, 4):
		kit.dot(ci, Vector2(stage.end.x - 14.0 * s - i * 8.0 * s, stage.position.y + 13.0 * s), 2.2 * s, Color(Kit.MIST, 0.7))
	if _game_a < 1.0:
		# (the breath between two: the water keeps moving)
		var c := stage.get_center() + Vector2(0.0, 8.0 * s)
		var pts := PackedVector2Array()
		for i in 31:
			var x := (i / 30.0 - 0.5) * stage.size.x * 0.6
			pts.append(c + Vector2(x, sin(x * 0.07 / s + _t * 6.0) * 5.0 * s * (1.0 - absf(i / 15.0 - 1.0))))
		kit.polyline(ci, pts, Color(Kit.TEAL, 0.8 * (1.0 - ta)), 2.5 * s)
	# the buttons: A's on the left, B's on the right
	var pad: bool = Settings.pad
	var live := _f != null and _f.game != null
	for side in 2:
		var cue := int(_v["a" if side == 0 else "b"]) if live else Kit.NONE
		var bc := Vector2(stage.position.x - 46.0 * s if side == 0 else stage.end.x + 46.0 * s, stage.get_center().y - 4.0 * s)
		var chip := Rect2(bc.x - 34.0 * s, bc.y - 42.0 * s, 68.0 * s, 98.0 * s)
		kit.glass(ci, chip, 16.0 * s, 0.9 if cue != Kit.NONE else 0.6)
		if cue != Kit.NONE and cue != Kit.OFF:
			kit.rrect(ci, chip, 16.0 * s, Color(0, 0, 0, 0), Color(Kit.cue_col(cue), 0.55), 1.5 * s)
		kit.button(ci, bc, 46.0 * s, side, cue, _t, Input.is_action_pressed("use_primary" if side == 0 else "use_secondary"), pad,
				1.0 if cue != Kit.NONE else 0.55)


func _draw_game() -> void:
	if _f == null or _f.game == null:
		return
	var s := _s
	var stage := _stage_rect()
	var r := Rect2(stage.position + Vector2(14.0 * s, 26.0 * s), stage.size - Vector2(28.0 * s, 36.0 * s))
	_f.game.draw(_game, r, kit, _t)


# ------------------------------------------------------------------ the pops, the sparks, the BIG PULL

func _draw_over() -> void:
	var ci := _over
	var s := _s
	for p: Array in _sparks:
		var life := float(p[2]) / float(p[3])
		kit.dot(ci, p[0], float(p[5]) * (0.5 + 0.5 * life), Color(p[4] as Color, life))
	var stage := _stage_rect()
	# the grade: springs up over the stage, drifts off
	if _pop_t < 1.25 and _pop != "":
		var col: Color = GRADE_COL.get(_pop, Kit.GOLD)
		var fade := clampf((1.25 - _pop_t) / 0.35, 0.0, 1.0)
		var at := Vector2(size.x * 0.5, stage.position.y - (6.0 + 12.0 * Kit.out_cubic(_pop_t / 1.25)) * s)
		var big := _pop == "PERFECT" or _pop == "BOSS DOWN"
		if big:
			kit.glow(ci, at, 54.0 * s, Color(col, fade), 0.7)
		kit.text_pop(ci, at, _pop, (34.0 if big else 28.0) * s, Color(col, fade), Kit.pop(_pop_t, 0.6 if big else 0.4, 0.45))
	# the BIG PULL: the whole screen, for a second
	if _pull_t < 1.3:
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		var t := _pull_t
		var out := clampf((1.3 - t) / 0.35, 0.0, 1.0)
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.93, 0.7, 0.4 * clampf(1.0 - t / 0.28, 0.0, 1.0)))
		var grow := Kit.out_cubic(t / 1.0)
		# the burst: wedges of light opening out from behind the number, turning a little; streaks flying off
		var n := 18
		for i in n:
			var a := TAU * i / n + t * 0.35
			var half := 0.05 + 0.03 * (i % 2)
			var r_in := (120.0 + 60.0 * grow) * s
			var r_out := (260.0 + 520.0 * grow) * s * (1.0 if i % 2 == 0 else 0.75)
			var wedge := PackedVector2Array([c + Vector2.from_angle(a - half * 0.4) * r_in, c + Vector2.from_angle(a - half) * r_out,
					c + Vector2.from_angle(a + half) * r_out, c + Vector2.from_angle(a + half * 0.4) * r_in])
			kit.poly(ci, wedge, Color(Kit.GOLD if i % 2 == 0 else Kit.FOAM, 0.5 * sqrt(1.0 - grow) * out))
		for i in 26:
			var a := TAU * i / 26.0 + 0.11 * (i % 3)
			var d := Vector2.from_angle(a)
			var r0 := (170.0 + 520.0 * grow + 50.0 * (i % 2)) * s
			var ray := (120.0 - 60.0 * grow) * s
			kit.line(ci, c + d * r0, c + d * (r0 + ray), Color(Kit.GOLD if i % 2 == 0 else Kit.FOAM, 0.9 * (1.0 - grow) * out), (5.0 if i % 2 == 0 else 3.0) * s)
		kit.ring(ci, c, (80.0 + 640.0 * grow) * s, Color(Kit.GOLD, 0.8 * (1.0 - grow)), 6.0 * s * (1.0 - grow) + 1.0)
		# (a soft dark behind the number, so the gold's bright on any sky)
		kit.glow(ci, c + Vector2(0.0, -14.0 * s), 260.0 * s, Color(Kit.DEEP, out), 1.5)
		var shown := _pull_m * Kit.out_cubic(t / 0.55)
		var k := Kit.pop(t, 0.7, 0.5)
		var rise := 18.0 * s * Kit.in_cubic(clampf((t - 0.9) / 0.4, 0.0, 1.0))
		kit.glow(ci, c - Vector2(0.0, rise), 200.0 * s, Color(Kit.GOLD, out), 0.5)
		kit.text(ci, c + Vector2(0.0, -62.0 * s - rise), "BIG PULL", 26.0 * s, Color(Kit.FOAM, out), 0, 700, 6.0 * s)
		kit.text_pop(ci, c - Vector2(0.0, rise), "+%d m" % int(roundf(shown)), 92.0 * s, Color(Kit.GOLD, out), k)
