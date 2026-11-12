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
	var u := unit(rect)
	var c := rect.get_center()
	var h := rect.size.y * 0.9
	var w := 26.0 * u
	var m := Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
	var gold_h := h * (1.0 - GOLD) + w * 0.3
	# the meter, gold at its top
	kit.pill(ci, m, Kit.TRACK)
	kit.rrect(ci, Rect2(m.position, Vector2(w, gold_h)), w * 0.5, Color(Kit.GOLD, 0.75 + 0.2 * sin(time * 6.0)))
	var col := Kit.GOLD if rod >= GOLD else Kit.FOAM
	if dir == -1:
		col = Kit.GO.lerp(Kit.GOLD, 1.0 if q >= 1.0 else 0.0)
	var fh := maxf((h - 6.0 * u) * rod, 0.0)
	if fh > 1.0:
		kit.rrect(ci, Rect2(m.position.x + 3.0 * u, m.end.y - 3.0 * u - fh, w - 6.0 * u, fh), (w - 6.0 * u) * 0.5, col)
	var head := Vector2(c.x, m.end.y - 3.0 * u - fh)
	if _flash > 0.0:
		kit.glow(ci, Vector2(c.x, m.end.y), 40.0 * u, Kit.GOLD, 2.0 * _flash)
	kit.line(ci, head - Vector2(w * 0.75, 0.0), head + Vector2(w * 0.75, 0.0), col, 4.0 * u)
	if kick > 0:
		var kc := Kit.GOLD if kick == 1 else Kit.CORAL
		if kick == 2 or sin(time * 30.0) > 0.0:
			kit.rrect(ci, m.grow(5.0 * u), w * 0.5 + 5.0 * u, Color(0, 0, 0, 0), kc, 3.0 * u)
			kit.text(ci, Vector2(c.x - 44.0 * u, c.y), "!", 44.0 * u, kc, 0, 700)
			kit.text(ci, Vector2(c.x + 44.0 * u, c.y), "!", 44.0 * u, kc, 0, 700)
	else:
		# which way now: winding down on the A side, lifting on the B side
		var lifting := dir != -1 and rod < GOLD
		for i in 3:
			var k := fposmod(time * 1.6 + i / 3.0, 1.0)
			var on_a := not lifting
			kit.chevron(ci, Vector2(c.x - 40.0 * u, c.y + (-14.0 + 28.0 * k) * u), 11.0 * u, Vector2.DOWN,
					Color(Kit.GO, (1.0 - absf(k - 0.5) * 2.0) if on_a else 0.12), 3.0 * u)
			kit.chevron(ci, Vector2(c.x + 40.0 * u, c.y + (14.0 - 28.0 * k) * u), 11.0 * u, Vector2.UP,
					Color(Kit.FOAM, (1.0 - absf(k - 0.5) * 2.0) if not on_a else 0.12), 3.0 * u)
	# him, down there on the end of it
	var fx := c.x + rect.size.x * 0.36
	var fy := c.y + 26.0 * u + 3.0 * u * sin(time * 2.0) - 10.0 * u * (1.0 if dir == -1 else 0.0)
	kit.line(ci, head + Vector2(w * 0.75, 0.0), Vector2(fx - 16.0 * u, fy), Color(Kit.FOAM, 0.35), 1.5, false)
	kit.fish(ci, Vector2(fx, fy), 32.0 * u, Color(Kit.FOAM, 0.85), -1.0, 0.25 if kick == 2 else 0.0)
