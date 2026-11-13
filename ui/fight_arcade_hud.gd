extends Control
## The arcade fight's HUD (tuna/fight_arcade.gd; rods.gd feeds it the fight in your hands every frame), drawn as a
## ship's instruments and a fish market's stamps (ui/kit.gd: read its DRAWING A GAME). No panels anywhere: fine
## keylined linework straight over the world, three inks.
##
## - **The top instrument**, top middle: one ruler of the line out (a tick every 10 m, a number every 50), the boat
##   at its near end and him an orange pointer riding it, the line between them heavy (orange and blinking when
##   it's worn); his energy over it, a heavy bar for each stage, draining; the hook's hold left of it as five
##   squares; the metres out right of it, and the combo: a big yellow "x7" over a tally filling toward the next BIG
##   PULL.
## - **The frame**, centre-low: four corner ticks round the minigame on now (tuna/minigames/*.gd's draw()), its name
##   small in its top corner, the games left in the set as small squares. The ticks jump out on a hit (yellow for a
##   perfect), turn orange on a miss.
## - **The two buttons**, just outside the frame's lower corners, A's left and B's right: kit.button().
## - **The stamps**: each game's grade is stamped over the frame (PERFECT yellow, GREAT white, OK an outline, MISS
##   orange): it slams down, sits, fades. The BIG PULL is an auction tag stamped mid-screen, the metres won counting
##   up on it, flat yellow rays behind it, gone in a second.
## The sounds, the hit-stop, the rod's kick and the rumble are ui/juice.gd's.

const Arcade := preload("res://tuna/fight_arcade.gd")
const Kit := preload("res://ui/kit.gd")
const Juice := preload("res://ui/juice.gd")
const Pull := preload("res://tuna/minigames/pull.gd")
const GRADE_COL := {"PERFECT": Kit.YELLOW, "GREAT": Kit.PAPER, "OK": Kit.PAPER, "MISS": Kit.ORANGE}
const GRADE_ROT := {"PERFECT": -0.075, "GREAT": -0.05, "OK": 0.035, "MISS": 0.06}

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
var _base: Control
var _game: Control
var _over: Control
# what's eased: the line, his energy, the hook
var _line := 0.0
var _energy := 1.0
var _hold := 1.0
var _combo_t := 9.0
var _combo_was := 0
# the frame
var _game_a := 0.0          # (the game's drawing, faded in)
var _hit := 0.0
var _hit_q := 1
var _bad := 0.0
var _step := 0.0            # (a stage cleared)
var _boss := 0.0
var _last_title := ""
# the stamps
var _pop := ""
var _pop_t := 9.0
var _pull_t := 9.0
var _pull_m := 0.0
var _pull_ready := 9.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	# (the linework is smooth: the 2D's anti-aliased from here on)
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
			_hit_q = int(e[1])
		"stroke":
			_hit = 0.6
			_hit_q = 2 if float(e[1]) >= 1.0 else 1
		"miss":
			_bad = 1.0
		"game":
			_game_a = 0.0
			_boss = 1.0 if bool(e[2]) else 0.0
		"grade":
			_pop = str(e[1]).to_upper()
			_pop_t = 0.0
		"pull_ready":
			_pull_ready = 0.0
		"pull":
			_pull_t = 0.0
			_pull_m = float(e[1])
		"stage":
			_step = 1.0
		"boss":
			_boss = 0.0
			if bool(e[1]):
				_pop = "BOSS DOWN"
				_pop_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	_a = move_toward(_a, 1.0 if _f != null else 0.0, delta * 4.0)
	_pop_t += delta
	_pull_t += delta
	_pull_ready += delta
	_combo_t += delta
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
		_game_a = move_toward(_game_a, 1.0 if _f.game != null else 0.0, delta * (9.0 if _f.game != null else 6.0))
	visible = _a > 0.01
	if not visible:
		return
	kit.px = maxf(size.y / 1080.0, 0.4)
	_base.modulate.a = _a
	_game.modulate.a = _a * _game_a
	_over.modulate.a = _a
	_base.queue_redraw()
	_game.queue_redraw()
	_over.queue_redraw()


## The frame the minigame's drawn in.
func _stage_rect() -> Rect2:
	var p := kit.px
	var w := maxf(size.x * 0.3, 560.0 * p)
	var h := 300.0 * p
	# (a little left of the middle: the rod and your hands are to the right of it)
	return Rect2(size.x * 0.455 - w * 0.5, size.y * 0.71 - h * 0.5, w, h)


# ------------------------------------------------------------------ the top instrument, the frame, the buttons

func _draw_base() -> void:
	if _v.is_empty():
		return
	var ci := _base
	var p := kit.px
	kit.defer = true
	var cx := size.x * 0.5
	var y := 104.0 * p                    # the ruler's edge
	var x0 := cx - 350.0 * p
	var x1 := cx + 250.0 * p
	var w := x1 - x0

	# --- the ruler: the line out, a tick every 10 m, a number every 50
	var cap := Arcade.CAPACITY
	kit.scale(ci, Vector2(x0, y), Vector2(x1, y), int(cap / 10.0), 5, Kit.PAPER, 1.0, 6.0 * p, 13.0 * p)
	for m in range(0, int(cap) + 1, 50):
		kit.text(ci, Vector2(x0 + w * m / cap, y + 25.0 * p), str(m), 14.0 * p, Kit.PAPER, 0, 600)
	var fx := lerpf(x0, x1, clampf(_line / cap, 0.0, 1.0))
	var worn := float(_v["wear"]) > 0.55
	if not worn or fposmod(_t * 4.0, 1.0) < 0.6:
		kit.rule(ci, Vector2(x0, y), Vector2(fx, y), Kit.ORANGE if worn else Kit.PAPER, true)
	kit.boat(ci, Vector2(x0 - 17.0 * p, y - 5.0 * p), 26.0 * p, Kit.PAPER, 1.0)
	kit.tri(ci, Vector2(fx, y - 3.0 * p), 17.0 * p, Vector2.DOWN, Kit.ORANGE)

	# --- his energy: a heavy bar for each stage, draining
	var n := int(_v["stages"])
	var left := clampf((_energy - 0.2) / 0.8, 0.0, 1.0) * n
	var gap := 10.0 * p
	var sw := (w - (n - 1) * gap) / n
	var ey := y - 40.0 * p
	for i in n:
		var bx := x0 + i * (sw + gap)
		var fill := clampf(left - (n - 1 - i), 0.0, 1.0)       # (they empty from the left)
		kit.rule(ci, Vector2(bx, ey), Vector2(bx + sw, ey), Kit.PAPER)
		if fill > 0.0:
			kit.bar(ci, Rect2(bx + sw * (1.0 - fill), ey - 8.0 * p, sw * fill, 8.0 * p), Kit.ORANGE)
		elif _step > 0.35 and i == n - int(_v["stage"]):
			kit.bar(ci, Rect2(bx, ey - 8.0 * p, sw, 8.0 * p), Kit.YELLOW)

	# --- the hook's hold: five squares
	var hx := x0 - 68.0 * p
	var low := _hold < 0.42
	var hcol := Kit.ORANGE if low else Kit.PAPER
	var held := clampi(int(ceilf(clampf(_hold, 0.0, 1.0) * 5.0 - 0.001)), 0, 5)
	kit.label(ci, Vector2(hx, y - 22.0 * p), "HOOK", 13.0 * p, hcol, 1)
	for i in 5:
		var on := i < held and not (low and fposmod(_t * 4.0, 1.0) > 0.6)
		kit.square(ci, Vector2(hx - 6.0 * p - (4 - i) * 17.0 * p, y - 2.0 * p), 11.0 * p, hcol, on)

	# --- the metres out, and the combo
	var dx := x1 + 34.0 * p
	var dw := kit.num(ci, Vector2(dx, y - 9.0 * p), str(int(_line)), 38.0 * p, Kit.PAPER, -1)
	kit.label(ci, Vector2(dx + dw + 7.0 * p, y - 3.0 * p), "M", 17.0 * p, Kit.PAPER, -1)
	if bool(_v["leader"]):
		kit.label(ci, Vector2(dx, y + 25.0 * p), "LEADER", 13.0 * p, Kit.YELLOW, -1)
	# one line under the ruler for what's about to cost you the fish, the worst of it first: nothing near the boat
	# happens without it being said here
	var mid := Vector2((x0 + x1) * 0.5, y + 54.0 * p)
	var blink := fposmod(_t * 4.0, 1.0) < 0.65
	if str(_v["game"]) == "clear":
		pass        # (the game on screen is the warning)
	elif float(_v.get("prop", 0.0)) > 0.0:
		if blink:
			kit.tri(ci, mid + Vector2(-kit.text_w("LINE UNDER HER: OUT OF GEAR", 18.0 * p, 600, 3.0 * p) * 0.5 - 16.0 * p, 0.0), 14.0 * p, Vector2.RIGHT, Kit.ORANGE)
			kit.label(ci, mid, "LINE UNDER HER: OUT OF GEAR", 18.0 * p, Kit.ORANGE)
	elif float(_v.get("chafe", 0.0)) > 0.05:
		if blink or float(_v["wear"]) < 0.55:
			kit.label(ci, mid, "LINE ON THE HULL: TURN HER TO HIM", 18.0 * p, Kit.ORANGE)
		# (how much of the line's left: it empties as it wears)
		var ww := 220.0 * p
		var wy := mid.y + 22.0 * p
		kit.scale(ci, Vector2(mid.x - ww * 0.5, wy), Vector2(mid.x + ww * 0.5, wy), 10, 5, Kit.PAPER, 1.0, 4.0 * p, 8.0 * p)
		kit.rule(ci, Vector2(mid.x - ww * 0.5, wy), Vector2(mid.x - ww * 0.5 + ww * clampf(1.0 - float(_v["wear"]), 0.0, 1.0), wy), Kit.ORANGE, true)
	elif bool(_v.get("last_run", false)):
		kit.label(ci, mid, "HIS LAST RUN: LET HIM GO", 18.0 * p, Kit.YELLOW)
	elif bool(_v.get("bolt", false)):
		kit.label(ci, mid, "STILL FRESH: HE'LL RUN WHEN HE SEES HER", 16.0 * p, Kit.YELLOW)
	elif float(_v["angle"]) < 0.75 and fposmod(_t * 2.0, 1.0) < 0.7:
		# (he's off her stern: everything you do counts for less till she's turned to him)
		kit.label(ci, mid, "HE'S OFF THE STERN", 14.0 * p, Kit.YELLOW)
	var combo := int(_v["combo"])
	var every := Arcade.PULL_EVERY
	var due: bool = _f != null and (str(_v["phase"]) == "pull" or (_pull_ready < 2.0 and _f.game == null))
	var kx := x1 + 176.0 * p
	if combo > 0:
		kit.num(ci, Vector2(kx, y - 22.0 * p), "x%d" % combo, 66.0 * p * Kit.slam(_combo_t, 1.35), Kit.YELLOW, -1)
	var got := every if due else clampi(every - (int(_v["next_pull"]) - combo), 0, every)
	for i in every:
		var tx := kx + 5.0 * p + i * 11.0 * p
		var lit := i < got and not (due and fposmod(_t * 5.0, 1.0) > 0.6)
		kit.rule(ci, Vector2(tx, y + 13.0 * p), Vector2(tx, y + (31.0 if lit else 22.0) * p), Kit.YELLOW if lit else Kit.PAPER, lit)

	# --- the frame: four corner ticks, the game's name, the games left in the set
	var stage := _stage_rect()
	var fcol := Kit.PAPER
	var out := 0.0
	if _bad > 0.0:
		fcol = Kit.ORANGE
	elif _hit > 0.0:
		fcol = Kit.YELLOW if _hit_q >= 2 else Kit.PAPER
		out = ((9.0 if _hit_q >= 2 else 4.0) * p) if _hit > 0.45 else 0.0
	elif float(_v["tension"]) > Arcade.OVER and fposmod(_t * 6.0, 1.0) < 0.5:
		fcol = Kit.ORANGE
	kit.corners(ci, stage.grow(out), 20.0 * p, fcol)
	var title := str(_v["title"])
	if title != "":
		_last_title = title
	var ta := _game_a
	var tx0 := stage.position.x + 16.0 * p
	var ty := stage.position.y + 17.0 * p
	if _boss > 0.0:
		tx0 += kit.label(ci, Vector2(tx0, ty), "BOSS", 15.0 * p, Color(Kit.YELLOW, ta), -1) + 10.0 * p
	if str(_v["phase"]) != "pull":
		kit.label(ci, Vector2(tx0, ty), _last_title, 15.0 * p, Color(Kit.PAPER, ta), -1)
	# what to do, said in a line under the frame: big and yellow the first time a game's met (the fight waits while
	# it's read, and that go is free), small after that
	var how := str(_v.get("how", ""))
	if how != "" and str(_v["phase"]) == "game":
		how = how.replace("{A}", "RT" if Settings.pad else "LEFT CLICK").replace("{B}", "LT" if Settings.pad else "RIGHT CLICK")
		var hc := Vector2(stage.get_center().x, stage.end.y + 32.0 * p)
		if bool(_v.get("practice", false)):
			kit.text(ci, hc, how, 27.0 * p, Kit.YELLOW, 0, 700)
			var wait_s := float(_v.get("teach", 0.0))
			kit.label(ci, hc + Vector2(0.0, 34.0 * p), "NEW GAME: THIS GO IS PRACTICE" if wait_s > 0.0 else "PRACTICE: NOTHING TO LOSE",
					16.0 * p, Kit.PAPER)
			if wait_s > 0.0:
				var bw := 260.0 * p * clampf(wait_s / Arcade.TEACH, 0.0, 1.0)
				kit.rule(ci, hc + Vector2(-bw * 0.5, 54.0 * p), hc + Vector2(bw * 0.5, 54.0 * p), Kit.YELLOW, true)
		else:
			kit.text(ci, hc, how, 19.0 * p, Color(Kit.PAPER, 0.9 * ta), 0, 600)
	var more := int(_v["set_left"]) - (1 if _f != null and _f.game != null else 0)
	for i in clampi(more, 0, 4):
		kit.square(ci, Vector2(stage.end.x - 34.0 * p - i * 14.0 * p, ty), 6.0 * p, Kit.PAPER)

	# --- the buttons, just outside its lower corners: A's on the left, B's on the right
	var pad: bool = Settings.pad
	var live := _f != null and _f.game != null
	for side in 2:
		var cue := int(_v["a" if side == 0 else "b"]) if live else Kit.NONE
		var bc := Vector2(stage.position.x - 46.0 * p if side == 0 else stage.end.x + 46.0 * p, stage.end.y - 52.0 * p)
		kit.button(ci, bc, 56.0 * p, side, cue, _t, Input.is_action_pressed("use_primary" if side == 0 else "use_secondary"), pad)
	kit.flush()
	kit.defer = false


func _draw_game() -> void:
	if _f == null or _f.game == null:
		return
	var p := kit.px
	var stage := _stage_rect()
	var r := Rect2(stage.position + Vector2(22.0 * p, 40.0 * p), stage.size - Vector2(44.0 * p, 56.0 * p))
	kit.defer = true
	_f.game.draw(_game, r, kit, _t)
	kit.flush()
	kit.defer = false


# ------------------------------------------------------------------ the stamps

func _draw_over() -> void:
	var ci := _over
	var p := kit.px
	kit.defer = false
	var stage := _stage_rect()
	# the grade: stamped over the frame
	if _pop_t < 1.1 and _pop != "":
		var col: Color = GRADE_COL.get(_pop, Kit.YELLOW)
		var fade := clampf((1.1 - _pop_t) / 0.18, 0.0, 1.0)
		var big := _pop == "PERFECT" or _pop == "BOSS DOWN"
		kit.stamp(ci, Vector2(size.x * 0.5, stage.position.y - 54.0 * p), _pop, (60.0 if big else 50.0) * p, col,
				Kit.slam(_pop_t), fade, float(GRADE_ROT.get(_pop, -0.06)), _pop == "OK")
	# the BIG PULL: an auction tag stamped mid-screen, flat rays behind it
	if _pull_t < 1.15:
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		var t := _pull_t
		var n := 12
		var thin := 1.0 - Kit.in_cubic(t / 0.9)
		if thin > 0.02:
			for i in n:
				var a := TAU * (i + 0.5) / n - 0.08
				var half := (0.06 if i % 2 == 0 else 0.03) * thin
				var r_in := 215.0 * p
				var r_out := (560.0 if i % 2 == 0 else 420.0) * p * Kit.slam(t, 0.3)
				kit.solid(ci, PackedVector2Array([c + Vector2.from_angle(a - half * 0.35) * r_in, c + Vector2.from_angle(a - half) * r_out,
						c + Vector2.from_angle(a + half) * r_out, c + Vector2.from_angle(a + half * 0.35) * r_in]), Kit.YELLOW)
		var shown := _pull_m * Kit.out_cubic(t / 0.5)
		kit.tag(ci, c, Vector2(540.0, 236.0) * p, Kit.YELLOW, "BIG PULL", "+%d" % int(roundf(shown)), "M",
				Kit.slam(t), clampf((1.15 - t) / 0.15, 0.0, 1.0), -0.085)
