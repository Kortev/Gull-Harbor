extends "res://tuna/minigames/minigame.gd"
## Pump him: he's down deep. Hold B to lift the rod into the gold at the top, then hold A to wind down: every stroke
## is line, more the fuller it was. Held at the top too long the line's hurt. With `kicks` (dog.gd, or the twist): he
## kicks now and then (the meter flares gold, then red): let go of B while he does or he rips the rod down.

const GOLD := 0.86
const LIFT := 1.25           # of the meter a second
const DROP := 2.4
const KICK_WARN := 0.5
const KICK_LEN := 0.6

var kicks := false
var rod := 0.0
## -1 winding down, 1 lifting, 0 neither.
var dir := 0
var top_t := 0.0
var q := 0.0
## 0 no kick, 1 it's coming, 2 he's kicking.
var kick := 0
var _kick_t := 0.0
var _kick_in := 2.0
var _caught := false
var _flash := 0.0


func _init() -> void:
	id = "pump"
	title = "PUMP AND WIND"
	moves = ["sound", "dog"]
	can_boss = true
	length = 6.0


func _begin() -> void:
	length = rng.randf_range(5.4, 6.6) * (1.5 if big else 1.0)
	rod = 0.0
	dir = 0
	top_t = 0.0
	q = 0.0
	kick = 0
	_kick_t = 0.0
	_kick_in = rng.randf_range(1.5, 2.3)
	if twist:
		kicks = true
	# what a steady hand makes of it: a stroke every so long
	var stroke := (1.0 / (LIFT * fast) + 1.0 / DROP + 0.25) * (1.25 if kicks else 1.0)
	_max = maxf(floorf((length - lead) / stroke), 1.0)


func _step(dt: float, a: bool, b: bool, _a_hit: bool, _b_hit: bool) -> void:
	_flash = maxf(_flash - dt * 3.0, 0.0)
	var kicking := false
	if kicks:
		if _kick_t > 0.0:
			_kick_t -= dt
			kicking = _kick_t <= KICK_LEN
			kick = 2 if kicking else 1
			if _kick_t <= 0.0:
				kick = 0
				if not _caught:
					_hit(1)
				_kick_in = rng.randf_range(1.8, 3.0) * lerpf(1.2, 0.8, tier)
		else:
			_kick_in -= dt
			if _kick_in <= 0.0 and length - t > KICK_WARN + KICK_LEN + 0.3:
				_kick_t = KICK_WARN + KICK_LEN
				_caught = false
	gain = -0.6
	tire = 0.0
	tension = 0.2 + 0.4 * rod
	if b and not a:
		if kicking:
			rod = move_toward(rod, 0.0, 3.0 * dt)       # (he rips it down)
			dir = 0
			tension = 0.95
			if not _caught:
				_caught = true
				_miss()
		else:
			rod = minf(rod + LIFT * fast * dt, 1.0)
			dir = 1
			top_t = top_t + dt if rod >= 1.0 else 0.0
			gain = -0.2
			tire = 0.3
			if top_t > 0.4:
				tension = 0.95
				fray = clampf(top_t - 0.4, 0.2, 1.0)
	elif a and not b:
		if dir != -1:
			q = 1.0 if rod >= GOLD else (0.7 if rod >= 0.62 else rod * 0.7)
			if rod > 0.15:
				events.append(["stroke", q])
			top_t = 0.0
		dir = -1
		var d := minf(DROP * dt, rod)
		rod -= d
		if d > 0.0:
			gain = q
			tire = q
			tension = 0.15
			if rod <= 0.0:
				_pts += q
				dir = 0
				if q >= 1.0:
					_hit(2)
					_flash = 1.0
				elif q >= 0.7:
					_hit(1)
		else:
			gain = -0.4
			dir = 0
	elif a and b:
		gain = -0.4
		tension = 0.5
	else:
		rod = move_toward(rod, 0.0, 0.5 * dt)
		if rod <= 0.0:
			dir = 0
	if kicking:
		tension = maxf(tension, 0.6)
	pose = rod
	score = clampf(_pts / _max, 0.0, 1.0)


func cue() -> Array:
	if kick == 2 or (kick == 1 and _kick_t <= KICK_LEN + 0.2):
		return [Kit.HOLD if rod > 0.0 else Kit.NONE, Kit.OFF]
	if dir == -1 or rod >= GOLD:
		return [Kit.HOLD, Kit.RELEASE if rod >= GOLD and dir == 1 else Kit.NONE]
	return [Kit.NONE, Kit.HOLD]


func hint() -> Dictionary:
	if dir == -1 and rod > 0.0:
		return {"a": true, "b": false}
	if kick > 0:
		return {"a": rod >= 0.62, "b": false}
	if rod >= GOLD + 0.05:
		return {"a": true, "b": false}
	return {"a": false, "b": true}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	# a tall ruler, the yellow span hatched at its top, a pointer riding it; arrows say which way (down on the A
	# side, up on the B side); in a kick an orange hatched band sweeps the scale in an orange frame.
	var u := unit(rect)
	var c := rect.get_center()
	var h := rect.size.y * 0.92
	var top := Vector2(c.x, c.y - h * 0.5)
	var bot := Vector2(c.x, c.y + h * 0.5)
	kit.scale(ci, bot, top, 40, 5, Kit.PAPER, -1.0, 5.0 * u, 11.0 * u)
	var in_gold := rod >= GOLD
	var zone := Rect2(c.x + 4.0 * u, top.y, 34.0 * u, h * (1.0 - GOLD))
	kit.span(ci, zone, Kit.YELLOW, in_gold)
	kit.hatch(ci, zone.grow_individual(-4.0 * u, -3.0 * u, -4.0 * u, -3.0 * u), Kit.YELLOW, in_gold)
	var my := bot.y - h * rod
	if rod > 0.0:
		kit.rule(ci, bot, Vector2(c.x, my), Kit.PAPER, true)
	kit.tri(ci, Vector2(c.x + 2.0 * u, my), 15.0 * u, Vector2.LEFT, Kit.YELLOW if (in_gold or (dir == -1 and q >= 1.0)) else Kit.PAPER)
	if _flash > 0.5:
		kit.square(ci, Vector2(c.x, bot.y), 14.0 * u, Kit.YELLOW)
	if kick > 0:
		var frame := Rect2(c.x - 30.0 * u, top.y - 3.0 * u, 60.0 * u, h + 6.0 * u)
		if kick == 2 or sin(time * 30.0) > 0.0:
			kit.box(ci, frame, Kit.ORANGE, kick == 2)
		var prog := clampf(1.0 - _kick_t / (KICK_WARN + KICK_LEN), 0.0, 1.0)
		var bh := h * 0.28
		var by := lerpf(bot.y, top.y - bh, prog)
		var y0 := maxf(by, top.y)
		var y1 := minf(by + bh, bot.y)
		if y1 > y0 + 2.0:
			kit.hatch(ci, Rect2(c.x - 27.0 * u, y0, 54.0 * u, y1 - y0), Kit.ORANGE, kick == 2, 11.0 * kit.px)
	else:
		var lifting := dir != -1 and rod < GOLD
		for i in 3:
			var k := fposmod(time * 1.6 + i / 3.0, 1.0)
			var ay := (-14.0 + 28.0 * k) * u
			if not lifting:
				var p := Vector2(c.x - 44.0 * u, c.y + ay)
				kit.path(ci, PackedVector2Array([p + Vector2(-9.0, -5.0) * u, p + Vector2(0.0, 5.0) * u, p + Vector2(9.0, -5.0) * u]), Kit.PAPER, true)
			else:
				var p := Vector2(c.x + 44.0 * u, c.y - ay)
				kit.path(ci, PackedVector2Array([p + Vector2(-9.0, 5.0) * u, p + Vector2(0.0, -5.0) * u, p + Vector2(9.0, 5.0) * u]), Kit.PAPER, true)
	# him, down there
	var fx := c.x - rect.size.x * 0.36
	var fy := c.y + 26.0 * u + 3.0 * u * sin(time * 2.0) - 10.0 * u * (1.0 if dir == -1 else 0.0)
	kit.fish(ci, Vector2(fx, fy), 32.0 * u, Kit.ORANGE, 1.0, 0.25 if kick == 2 else 0.0)
