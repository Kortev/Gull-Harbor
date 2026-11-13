extends "res://tuna/minigames/minigame.gd"
## He jumps. He comes up (the line lifts), goes over: hands off both buttons while he's in the air (bow to him: a
## tight line throws the hook), then tap A as he lands to take up the slack.

const AIR := 0.7
const HANDS_OFF := 0.45
const EARLY := 0.15
const LATE := 0.28

## s before he leaves the water; s with a button down in the air; the landing tap (0 none, 1 good, 2 perfect).
var up := 1.1
var bad := 0.0
var landed := 0


func _init() -> void:
	id = "jump"
	title = "HE'S JUMPING"
	moves = ["jump"]
	only = true
	length = 2.6
	lead = 0.0


func _begin() -> void:
	up = 1.1
	bad = 0.0
	landed = 0
	length = up + AIR + 0.75
	score = 0.4


func _step(dt: float, a: bool, b: bool, a_hit: bool, _b_hit: bool) -> void:
	var ta := t - up
	surface = true
	leap = ta >= -0.5
	air = ta >= 0.0 and ta < AIR
	gain = 0.0
	tire = 0.6
	if ta < 0.0:
		tension = 0.4
		pose = 0.65
	elif ta < HANDS_OFF:
		pose = 0.0
		if a or b:
			bad += dt
			hook = 1.0
			tension = 0.95
		else:
			tension = 0.05
	elif ta < AIR + LATE:
		pose = 0.0
		tension = 0.1
		if a_hit and landed == 0 and ta >= AIR - EARLY:
			landed = 2 if absf(ta - AIR) <= 0.09 else 1
			_hit(landed)
			burst += 2.0
	else:
		if landed == 0:
			slack = 0.5
		pose = 0.4
		tension = 0.3
		gain = 1.0 if landed > 0 else -0.3
	if landed == 0 and ta >= AIR + LATE and ta - dt < AIR + LATE:
		_miss(0.9)
	score = (0.4 if bad < 0.08 else 0.0) + (0.6 if landed == 2 else (0.45 if landed == 1 else 0.0))


func cue() -> Array:
	var ta := t - up
	if ta < HANDS_OFF:
		return [Kit.OFF, Kit.OFF]
	if ta < AIR + LATE and landed == 0:
		return [Kit.TAP, Kit.NONE]
	return [Kit.NONE, Kit.NONE]


func hint() -> Dictionary:
	var ta := t - up
	return {"a": landed == 0 and ta >= AIR - 0.03 and ta < AIR + 0.2, "b": false}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	# a ruled waterline; his arc dashed over it, the hands-off part of it hatched orange; a yellow bracket on the
	# water where he lands, a pointer closing on it.
	var u := unit(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.92
	var sea_y := c.y + 24.0 * u
	var ta := t - up
	kit.scale(ci, Vector2(c.x - w * 0.5, sea_y), Vector2(c.x + w * 0.5, sea_y), 40, 5, Kit.PAPER, 1.0, 4.0 * u, 8.0 * u)
	var x0 := c.x - w * 0.26
	var x1 := c.x + w * 0.28
	var top := 52.0 * u
	var off := HANDS_OFF / AIR
	var arc_at := func(s: float) -> Vector2: return Vector2(lerpf(x0, x1, s), sea_y - top * sin(PI * s))
	# the hands-off stretch, hatched
	var hold := Rect2(x0, sea_y - 16.0 * u, (x1 - x0) * off, 12.0 * u)
	var live_hold := ta >= 0.0 and ta < HANDS_OFF
	kit.span(ci, hold, Kit.ORANGE, live_hold)
	kit.hatch(ci, hold.grow_individual(-3.0 * u, -3.0 * u, -3.0 * u, -3.0 * u), Kit.ORANGE, live_hold)
	# his arc, dashed
	var n := 30
	for i in n:
		if i % 2 == 1:
			continue
		var s0 := float(i) / n
		var s1 := float(i + 1) / n
		var seg := PackedVector2Array()
		for k in 3:
			seg.append(arc_at.call(lerpf(s0, s1, k / 2.0)) as Vector2)
		kit.path(ci, seg, Kit.ORANGE if s0 < off else Kit.PAPER, s0 < off)
	# where he lands
	var land := Vector2(x1, sea_y)
	var lb := Rect2(x1 - 15.0 * u, sea_y - 12.0 * u, 30.0 * u, 12.0 * u)
	var lcol := Kit.YELLOW if landed == 2 else Kit.PAPER
	kit.span(ci, lb, Kit.YELLOW, landed > 0)
	kit.hatch(ci, lb.grow_individual(-4.0 * u, -3.0 * u, -4.0 * u, -3.0 * u), Kit.YELLOW, landed > 0)
	if landed == 0 and ta < AIR:
		var g := clampf((AIR - ta) / (AIR + up), 0.0, 1.0)
		kit.tri(ci, land + Vector2(0.0, -(14.0 + 40.0 * g) * u), 14.0 * u, Vector2.DOWN, Kit.PAPER)
	elif landed > 0:
		kit.tri(ci, land + Vector2(0.0, -14.0 * u), 14.0 * u, Vector2.DOWN, lcol)
		var r := maxf(ta - AIR, 0.0)
		if r < 0.35:
			for i in 5:
				var ang := -PI * (0.15 + 0.7 * i / 4.0)
				kit.diamond(ci, land + Vector2.from_angle(ang) * (14.0 + 60.0 * r) * u, 6.0 * u, lcol)
	# him
	var fp: Vector2
	var rot := 0.0
	if ta < 0.0:
		var k := Kit.out_cubic(clampf(1.0 + ta / up, 0.0, 1.0))
		fp = Vector2(lerpf(x0 - 34.0 * u, x0, k), lerpf(sea_y + 22.0 * u, sea_y + 6.0 * u, k))
		rot = -0.6
	else:
		var s := clampf(ta / AIR, 0.0, 1.0)
		fp = arc_at.call(s) as Vector2
		rot = -atan2(top * PI * cos(PI * s), x1 - x0)
	if ta < AIR + 0.15:
		kit.fish(ci, fp, 34.0 * u, Kit.ORANGE, 1.0, rot)
