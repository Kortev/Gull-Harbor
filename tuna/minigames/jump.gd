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
	var u := unit(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.9
	var sea_y := c.y + 26.0 * u
	var ta := t - up
	# the water
	var wave := PackedVector2Array()
	for i in 41:
		var x := c.x - w * 0.5 + w * i / 40.0
		wave.append(Vector2(x, sea_y + sin(x * 0.06 + time * 2.5) * 2.0 * u))
	kit.polyline(ci, wave, Color(Kit.TEAL, 0.8), 2.5 * u)
	var x0 := c.x - w * 0.26
	var x1 := c.x + w * 0.28
	var top := 52.0 * u
	var off := HANDS_OFF / AIR
	# his arc: red while your hands must be off it
	var n := 26
	for i in n:
		var s := (i + 0.5) / n
		var p := Vector2(lerpf(x0, x1, s), sea_y - top * sin(PI * s))
		kit.dot(ci, p, 2.2 * u, Color(Kit.CORAL, 0.95) if s < off else Color(Kit.FOAM, 0.55))
	# where he lands: a ring closing on it
	var land := Vector2(x1, sea_y)
	var ring_col := Kit.GOLD if landed == 2 else Kit.GO
	if landed > 0:
		kit.glow(ci, land, 26.0 * u, ring_col, 1.5)
	kit.ring(ci, land, 9.0 * u, ring_col, 3.0 * u)
	if landed == 0 and ta < AIR:
		var g := clampf((AIR - ta) / (AIR + up), 0.0, 1.0)
		kit.ring(ci, land, (9.0 + 30.0 * g) * u, Color(Kit.GO, 0.7 * (1.0 - g * 0.6)), 2.0 * u)
	# him
	var fp := Vector2(x0, sea_y)
	var rot := 0.0
	var col := Kit.FOAM
	if ta < 0.0:
		var k := Kit.out_cubic(clampf(1.0 + ta / up, 0.0, 1.0))
		fp = Vector2(lerpf(x0 - 34.0 * u, x0, k), lerpf(sea_y + 20.0 * u, sea_y + 2.0 * u, k))
		rot = -0.6
		col = Color(Kit.FOAM, 0.35 + 0.5 * k)
		for i in 3:
			var kk := fposmod(time * 2.0 + i / 3.0, 1.0)
			kit.ring(ci, Vector2(x0, sea_y), (4.0 + 16.0 * kk) * u, Color(Kit.GOLD, (1.0 - kk) * k), 1.5 * u)
	else:
		var s := clampf(ta / AIR, 0.0, 1.0)
		fp = Vector2(lerpf(x0, x1, s), sea_y - top * sin(PI * s))
		rot = -atan2(top * PI * cos(PI * s), x1 - x0)
		if s < off and bad > 0.0:
			col = Kit.CORAL
		if s >= 1.0:
			var r := ta - AIR
			col = Color(Kit.FOAM, clampf(1.0 - r * 3.0, 0.0, 1.0))
			for i in 7:
				var ang := -PI * (0.15 + 0.7 * i / 6.0)
				kit.dot(ci, land + Vector2.from_angle(ang) * (8.0 + 70.0 * r) * u + Vector2(0.0, 120.0 * r * r * u), 2.0 * u, Color(Kit.FOAM, clampf(1.0 - r * 2.0, 0.0, 1.0)))
	kit.fish(ci, fp, 36.0 * u, col, 1.0, rot)
