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


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	var u := unit(rect)
	var c := rect.get_center() + Vector2(0.0, 12.0 * u)
	var col := Kit.GOLD
	var word := "WAIT"
	var turn := 0.0           # 0 away .. 1 round to you
	var size := 1.0
	match phase:
		"wait":
			turn = 0.35 * feint()
			var breath := 0.5 + 0.5 * sin(time * 5.0)
			kit.ring(ci, c, (31.0 + 2.0 * breath) * u, Color(Kit.GOLD, 0.5 + 0.3 * breath), 3.0 * u)
		"now":
			col = Kit.GO
			word = "NOW!"
			turn = Kit.out_back(_pt / 0.1)
			size = Kit.pop(_pt, 0.5, 0.3)
			kit.glow(ci, c, 52.0 * u, Kit.GO, 1.5)
			kit.ring(ci, c, 31.0 * u, Kit.GO, 5.0 * u)
			# the time running out on it
			kit.arc(ci, c, 38.0 * u, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - _pt / TOO_LATE), Color(Kit.GO, 0.7), 3.0 * u)
		"show":
			col = [Kit.CORAL, Kit.GO, Kit.GOLD][last]
			word = "TOO SOON" if early else (["TOO SLOW", "GOT HIM", "SNAP!"][last] as String)
			turn = 1.0 if not early else 0.0
			var k := _pt / 0.6
			kit.ring(ci, c, (31.0 + 26.0 * k) * u, Color(col, 1.0 - k), 4.0 * u)
	# him: his head away from you, then round
	kit.fish(ci, c, 46.0 * u * size, col if phase != "wait" else Kit.FOAM, lerpf(1.0, -1.0, turn) if absf(lerpf(1.0, -1.0, turn)) > 0.15 else 0.15, 0.0)
	kit.text_pop(ci, Vector2(c.x, rect.position.y + 6.0 * u), word, 18.0 * u, col, size)
	for i in rounds:
		var p := Vector2(c.x + rect.size.x * 0.42, c.y + (i - (rounds - 1) * 0.5) * 10.0 * u)
		kit.dot(ci, p, 2.8 * u, Kit.FOAM if i == n else Color(Kit.FOAM, 0.25 if i > n else 0.6))
