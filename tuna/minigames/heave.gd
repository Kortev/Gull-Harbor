extends "res://tuna/minigames/minigame.gd"
## The power heave: hold B and the power winds up round the dial, quicker and quicker; let go as it crosses the gold
## (perfect) or the green either side (good) and you heave him toward you. Let it run off the end and he's had you.
## A few heaves, the gold somewhere new each time. Twist: the gold's narrower.

var power := 0.0
var gold := 0.8
var gold_w := 0.045
var green_w := 0.12
var n := 0
var heaves := 3
## "wait" (to start: hold B), "fill", "show" (how it went: `last` 2 perfect, 1 good, 0 missed).
var phase := "wait"
var last := -1
var _pt := 0.0
var _rate := 0.9


func _init() -> void:
	id = "heave"
	title = "HEAVE"
	moves = ["sound", "dog", "run", "surge"]
	can_boss = true
	length = 10.0
	lead = 0.0


func _begin() -> void:
	heaves = (3 if tier < 0.7 else 4) + (1 if big else 0)
	gold_w = lerpf(0.055, 0.045, tier) * (0.75 if twist else 1.0)
	green_w = gold_w + lerpf(0.09, 0.07, tier)
	_rate = lerpf(0.62, 0.78, tier) * fast
	n = 0
	last = -1
	_deal()


func _deal() -> void:
	power = 0.0
	gold = rng.randf_range(0.5, 0.86)
	phase = "wait"
	_pt = 0.0


func _step(dt: float, _a: bool, b: bool, _a_hit: bool, b_hit: bool) -> void:
	_pt += dt
	gain = mood
	tire = maxf(mood, 0.0)
	tension = 0.3
	pose = 0.3
	match phase:
		"wait":
			if b_hit or (b and _pt > 0.15):
				phase = "fill"
			elif _pt > 2.2:
				_end(0)
		"fill":
			tension = 0.3 + 0.55 * power
			pose = 0.3 + 0.2 * power
			gain = 0.0
			if not b:
				var d := absf(power - gold)
				_end(2 if d <= gold_w else (1 if d <= green_w else 0))
			else:
				power += _rate * (0.55 + 1.1 * power) * dt
				if power >= 1.0:
					power = 1.0
					tension = 0.97
					fray = 1.0
					_end(0)
		"show":
			pose = move_toward(pose, 0.9 if last > 0 else 0.3, 4.0 * dt)
			if _pt >= 0.4:
				n += 1
				if n >= heaves:
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
		pose = 0.9
	else:
		_miss()


func cue() -> Array:
	if phase == "fill":
		return [Kit.NONE, Kit.RELEASE if power >= gold - green_w - 0.04 else Kit.HOLD]
	return [Kit.NONE, Kit.HOLD if phase == "wait" else Kit.NONE]


func hint() -> Dictionary:
	var hold := phase == "wait" and _pt > 0.1
	if phase == "fill":
		# (let go when the next frame would be past the middle of the gold)
		hold = power + _rate * (0.55 + 1.1 * power) / 60.0 < gold
	return {"a": false, "b": hold}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	var u := unit(rect)
	var c := rect.get_center() + Vector2(0.0, 30.0 * u)
	var rad := 66.0 * u
	var a0 := PI * 1.08
	var a1 := PI * 1.92
	var ang := func(v: float) -> float: return lerpf(a0, a1, v)
	kit.arc(ci, c, rad, a0, a1, Kit.TRACK, 12.0 * u)
	# the end of it: too far
	kit.arc(ci, c, rad, ang.call(0.96) as float, a1, Color(Kit.CORAL, 0.7), 12.0 * u)
	# the gold, green either side
	kit.arc(ci, c, rad, ang.call(gold - green_w) as float, ang.call(minf(gold + green_w, 0.96)) as float, Color(Kit.GO, 0.8), 12.0 * u, false)
	kit.arc(ci, c, rad, ang.call(gold - gold_w) as float, ang.call(gold + gold_w) as float, Kit.GOLD, 15.0 * u, false)
	# the power, winding up
	var col := Kit.FOAM
	if phase == "show":
		col = [Kit.CORAL, Kit.GO, Kit.GOLD][last]
	if power > 0.005:
		kit.arc(ci, c, rad - 13.0 * u, a0, ang.call(power) as float, Color(col, 0.9), 6.0 * u)
	var hp := c + Vector2.from_angle(ang.call(power) as float) * rad
	if phase == "show":
		var k := _pt / 0.5
		kit.ring(ci, hp, (9.0 + 30.0 * k) * u, Color(col, 1.0 - k), 3.0 * u)
		if last > 0:
			kit.glow(ci, hp, 34.0 * u, col, 2.0 * (1.0 - k))
	kit.dot(ci, hp, 8.0 * u, col)
	kit.dot(ci, hp, 3.5 * u, Kit.DEEP)
	# him, hauled up toward you on a good one
	var lift := 0.0
	if phase == "show" and last > 0:
		lift = sin(PI * minf(_pt / 0.5, 1.0)) * 10.0 * u
	kit.fish(ci, c + Vector2(0.0, -24.0 * u - lift + sin(time * 2.5) * 1.5 * u), 44.0 * u, Color(Kit.FOAM, 0.85) if phase != "show" or last == 0 else col, 1.0, -0.1 - lift * 0.02)
	# the heaves left
	for i in heaves:
		var p := Vector2(c.x + (i - (heaves - 1) * 0.5) * 10.0 * u, c.y + 12.0 * u)
		kit.dot(ci, p, 2.8 * u, Kit.FOAM if i == n else Color(Kit.FOAM, 0.25 if i > n else 0.6))
