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
	# a ticked dial the power winds round (clockwise from the bottom left): the good a hatched span outside the rim,
	# the gold in it a heavier block of hatching, the end of the dial orange. Power a heavy sweep inside, a pointer on
	# the rim; him in the middle; a square for every heave.
	var u := unit(rect)
	var c := rect.get_center() + Vector2(0.0, 2.0 * u)
	var rad := 34.0 * u
	var a0 := PI * 0.75
	var a1 := PI * 2.25
	var ang := func(v: float) -> float: return lerpf(a0, a1, v)
	kit.dial(ci, c, rad, 60, 5, Kit.PAPER, 4.0 * u, 9.0 * u)
	var r0 := rad + 3.0 * u
	var r1 := rad + 12.0 * u
	# the end of it: too far
	var ea := ang.call(0.96) as float
	kit.hatch_arc(ci, c, r0, r1, ea, a1, Kit.ORANGE, false, 5.0 * kit.px)
	kit.rule(ci, c + Vector2.from_angle(ea) * rad, c + Vector2.from_angle(ea) * r1, Kit.ORANGE, true)
	# the good either side of the gold, the gold itself
	var g0 := ang.call(gold - green_w) as float
	var g1 := ang.call(minf(gold + green_w, 0.96)) as float
	var k0 := ang.call(gold - gold_w) as float
	var k1 := ang.call(gold + gold_w) as float
	kit.hatch_arc(ci, c, r0, r1, g0, k0, Kit.YELLOW, false, 5.0 * kit.px)
	kit.hatch_arc(ci, c, r0, r1, k1, g1, Kit.YELLOW, false, 5.0 * kit.px)
	for a: float in [g0, g1]:
		kit.rule(ci, c + Vector2.from_angle(a) * rad, c + Vector2.from_angle(a) * r1, Kit.YELLOW)
	kit.sweep(ci, c, r1, g0, g1, Kit.YELLOW)
	var block := PackedVector2Array()
	for i in 5:
		block.append(c + Vector2.from_angle(lerpf(k0, k1, i / 4.0)) * r1)
	for i in 5:
		block.append(c + Vector2.from_angle(lerpf(k1, k0, i / 4.0)) * r0)
	kit.solid(ci, block, Kit.YELLOW)
	# the power, winding up
	var col := Kit.PAPER
	if phase == "show":
		col = [Kit.ORANGE, Kit.PAPER, Kit.YELLOW][last]
	var pa := ang.call(power) as float
	if power > 0.005:
		kit.sweep(ci, c, rad - 9.0 * u, a0, pa, col, true)
	var pd := Vector2.from_angle(pa)
	var out := 5.0 * u if (phase == "show" and _pt > 0.05 and _pt < 0.3 and last > 0) else 0.0
	kit.rule(ci, c + pd * 5.0 * u, c + pd * (rad - 12.0 * u), col, true)
	kit.tri(ci, c + pd * (rad + 1.0 * u + out), 11.0 * u, pd, col)
	# him, hauled up toward you on a good one
	var lift := 0.0
	if phase == "show" and last > 0:
		lift = sin(PI * minf(_pt / 0.5, 1.0)) * 8.0 * u
	kit.fish(ci, c + Vector2(0.0, -4.0 * u - lift + sin(time * 2.5) * 1.5 * u), 30.0 * u, Kit.ORANGE, 1.0, -0.1 - lift * 0.02)
	# the heaves: spent ones hollow
	for i in heaves:
		var p := Vector2(rect.end.x - 5.0 * u, c.y + (i - (heaves - 1) * 0.5) * 13.0 * u)
		kit.square(ci, p, 7.0 * u, Kit.PAPER, i >= n)
