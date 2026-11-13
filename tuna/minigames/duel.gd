extends "res://tuna/minigames/minigame.gd"
## The duel: he's turned away, holding. Wait... and the instant his head comes round (NOW), tap A: the quicker the
## better. Go early and you've pulled the hook on nothing. Twist: he feints first (a twitch that isn't the turn).

const PERFECT := 0.3
const GOOD := 0.5
const TOO_LATE := 0.75

var n := 0
var rounds := 3
## "wait", "now", "show" (how it went: `last` 2 perfect, 1 good, 0 missed or early).
var phase := "wait"
var last := -1
var early := false
var _pt := 0.0
var _wait := 1.5
var _feint := -1.0


func _init() -> void:
	id = "duel"
	title = "WAIT FOR IT"
	moves = ["shake", "dog", "circle"]
	length = 12.0
	lead = 0.0
	_rest = 0.0


func _begin() -> void:
	rounds = 4 if big else (2 if tier < 0.35 else 3)
	n = 0
	last = -1
	_deal()


func _deal() -> void:
	phase = "wait"
	_pt = 0.0
	_wait = rng.randf_range(0.8, 1.8) / fast
	_feint = rng.randf_range(0.4, _wait - 0.4) if twist and _wait > 1.1 else -1.0
	early = false


## How far his head's twitched in a feint (0..1).
func feint() -> float:
	if phase != "wait" or _feint < 0.0:
		return 0.0
	return clampf(1.0 - absf(_pt - _feint) / 0.12, 0.0, 1.0)


func _step(dt: float, _a: bool, _b: bool, a_hit: bool, _b_hit: bool) -> void:
	_pt += dt
	gain = mood
	tire = maxf(mood, 0.0)
	pose = 0.45
	match phase:
		"wait":
			tension = 0.5 + 0.2 * clampf(_pt / _wait, 0.0, 1.0)
			if a_hit and _pt > 0.15:
				early = true
				_end(0)
			elif _pt >= _wait:
				phase = "now"
				_pt = 0.0
		"now":
			tension = 0.75
			if a_hit:
				_end(2 if _pt <= PERFECT else (1 if _pt <= GOOD else 0))
			elif _pt > TOO_LATE:
				_end(0)
		"show":
			tension = 0.3
			pose = move_toward(pose, 0.85 if last > 0 else 0.45, 4.0 * dt)
			if _pt >= 0.5:
				n += 1
				if n >= rounds:
					done = true
				else:
					_deal()


func _end(q: int) -> void:
	last = q
	phase = "show"
	_pt = 0.0
	_max += 1.0
	if q > 0:
		_pts += 1.0 if q == 2 else 0.65
		_hit(q)
	else:
		_miss()


func cue() -> Array:
	match phase:
		"wait":
			return [Kit.OFF, Kit.NONE]
		"now":
			return [Kit.TAP, Kit.NONE]
	return [Kit.NONE, Kit.NONE]


func hint() -> Dictionary:
	return {"a": phase == "now" and _pt < 0.1, "b": false}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, _time: float) -> void:
	# him on a ruled waterline, turned away; under it a fuse, a ruler with a marker creeping along it. At the turn he
	# flips, a yellow bracket snaps round him, NOW stamped beside him and the marker runs out of road.
	var u := unit(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.8
	var x0 := c.x - w * 0.5
	var x1 := c.x + w * 0.5
	var fy := c.y - 4.0 * u
	var wy := c.y + 10.0 * u
	var fy2 := c.y + 30.0 * u
	var turn := 0.0           # 0 away .. 1 round to you
	var prog := 0.0
	match phase:
		"wait":
			turn = 0.35 * feint()
			prog = clampf(_pt / _wait, 0.0, 1.0)
		"now":
			turn = Kit.out_back(_pt / 0.1)
			prog = 1.0
		"show":
			turn = 1.0 if not early else 0.0
			prog = 1.0 if not early else clampf(_pt / 0.5, 0.0, 1.0)
	# the waterline
	kit.scale(ci, Vector2(c.x - w * 0.3, wy), Vector2(c.x + w * 0.3, wy), 24, 4, Kit.PAPER, 1.0, 3.0 * u, 6.0 * u)
	# him
	var way := lerpf(1.0, -1.0, turn)
	if absf(way) < 0.15:
		way = 0.15
	var fc := Vector2(c.x, fy)
	kit.fish(ci, fc, 42.0 * u, Kit.ORANGE, way, 0.0)
	# the bracket, snapping in
	if phase == "now" or (phase == "show" and not early):
		var k := lerpf(2.2, 1.0, Kit.out_cubic(_pt / 0.08)) if phase == "now" else 1.0
		var bc := Kit.YELLOW if (phase == "now" or last > 0) else Kit.ORANGE
		var half := Vector2(34.0, 19.0) * u * k
		kit.span(ci, Rect2(fc - half, half * 2.0), bc, phase == "now" or last == 2)
	if phase == "now":
		kit.stamp(ci, Vector2(c.x - w * 0.4, fy - 4.0 * u), "NOW", 13.0 * u, Kit.YELLOW, Kit.slam(_pt), 1.0, -0.07)
	# the fuse
	kit.scale(ci, Vector2(x0, fy2), Vector2(x1, fy2), 40, 5, Kit.PAPER, -1.0, 4.0 * u, 9.0 * u)
	if phase == "now":
		var rest := clampf(1.0 - _pt / TOO_LATE, 0.0, 1.0)
		kit.rule(ci, Vector2(x1 - w * rest, fy2 - 6.0 * u), Vector2(x1, fy2 - 6.0 * u), Kit.YELLOW, true)
	var mx := lerpf(x0, x1, prog)
	var mcol := Kit.PAPER
	if phase == "show" and last == 0:
		mcol = Kit.ORANGE
	elif phase == "now" or (phase == "show" and last == 2):
		mcol = Kit.YELLOW
	kit.rule(ci, Vector2(mx, fy2 + 2.0 * u), Vector2(mx, fy2 - 12.0 * u), mcol, true)
	kit.tri(ci, Vector2(mx, fy2 + 3.0 * u), 12.0 * u, Vector2.UP, mcol)
	# the rounds
	for i in rounds:
		var p := Vector2(rect.end.x - 5.0 * u, c.y + (i - (rounds - 1) * 0.5) * 13.0 * u)
		kit.square(ci, p, 7.0 * u, Kit.PAPER, i >= n)
