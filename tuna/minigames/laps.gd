extends "res://tuna/minigames/minigame.gd"
## His laps round a ring. On the green part (he's coming up toward you) hold A and wind him in; on the red (going
## away) hold B and brace: winding into the red hurts the line. On to A right as he turns toward you (the gold
## mark) for a perfect. Mirrored: he goes round the other way.

const GREEN := 0.42          # the share of a lap that's green

var lap_len := 5.0
var red_t := 0.0
var sharp := false
var _was_green := false
var _laps := 1.5


func _init() -> void:
	id = "laps"
	title = "WIND HIM ROUND"
	moves = ["circle", "spiral"]
	from = 0.3
	can_boss = true
	length = 6.0
	lead = 0.4


func _begin() -> void:
	lap_len = lerpf(4.4, 3.2, tier) / fast
	_laps = 2.0 if big else 1.5
	length = lead + lap_len * _laps
	red_t = 0.0
	sharp = false
	_was_green = false


## Where he is round the lap (0..1): it starts on the red, GREEN before the turn, so there's time to see it coming.
func lap() -> float:
	return fposmod((t - lead) / lap_len + 1.0 - (1.0 - GREEN) * 0.5, 1.0)


func green() -> bool:
	return lap() < GREEN and live()


func _step(dt: float, a: bool, b: bool, a_hit: bool, _b_hit: bool) -> void:
	var g := green()
	if _was_green and not g:
		sharp = false
	if a_hit and live():
		var to_green := minf(lap(), 1.0 - lap()) * lap_len
		if to_green <= 0.14 and (g or lap() > 0.5):
			sharp = true
			_hit(2)
	_was_green = g
	gain = -0.5
	tire = 0.1
	tension = 0.3
	pose = 0.45
	if g:
		red_t = 0.0
		if a and not b:
			gain = 1.0
			tire = 1.0
			tension = 0.5
			pose = 0.25
			if live():
				_pts += dt
		if live():
			_max += dt
	else:
		if a:
			red_t += dt
			if red_t > 0.22:
				tension = 0.97
				fray = 0.8
				gain = -0.2
				if live():
					_pts = maxf(_pts - 0.5 * dt, 0.0)
		elif b:
			red_t = 0.0
			gain = 0.0
			tire = 0.5
			tension = 0.6
			pose = 0.75
			if live():
				_pts += 0.5 * dt
		else:
			red_t = 0.0
			gain = -1.0
		if live():
			_max += 0.5 * dt


func cue() -> Array:
	if green():
		return [Kit.HOLD, Kit.NONE]
	return [Kit.OFF if red_t > 0.0 else Kit.NONE, Kit.HOLD]


func hint() -> Dictionary:
	var g := green()
	return {"a": g, "b": not g}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	var u := unit(rect)
	var c := rect.get_center() + Vector2(0.0, -2.0 * u)
	var rad := 38.0 * u
	var way := -1.0 if mirror else 1.0
	var g := green()
	# the ring: green at the bottom (toward you), red the rest
	var a0 := PI * 0.5 - way * TAU * GREEN * 0.5
	var a_green_end := a0 + way * TAU * GREEN
	var a_end := a0 + way * TAU
	kit.arc(ci, c, rad, a_green_end, a_end, Color(Kit.CORAL, 0.8 if not g else 0.35), 7.0 * u, false)
	kit.arc(ci, c, rad, a0, a_green_end, Color(Kit.GO, 1.0 if g else 0.55), 7.0 * u)
	# the mark where he turns toward you
	var p0 := Vector2.from_angle(a0)
	kit.line(ci, c + p0 * (rad - 9.0 * u), c + p0 * (rad + 9.0 * u), Kit.GOLD, 3.5 * u)
	# him, going round
	var am := a0 + way * TAU * lap()
	var pm := c + Vector2.from_angle(am) * rad
	var mc := Kit.GOLD if sharp and g else (Kit.GO if g else Kit.FOAM)
	if red_t > 0.2:
		mc = Kit.CORAL
	if g:
		kit.glow(ci, pm, 20.0 * u, mc, 1.2)
	kit.dot(ci, pm, 8.0 * u, mc)
	kit.fish(ci, c + Vector2.from_angle(am) * (rad - 17.0 * u), 26.0 * u, Color(mc, 0.9), 1.0, am + way * PI * 0.5)
	# you, in the middle of it, the line out to him
	kit.line(ci, c, pm, Color(Kit.FOAM, 0.3), 1.5, false)
	kit.dot(ci, c, 3.5 * u, Kit.FOAM)
	# what the half you're on wants, either side
	var lx := rect.size.x * 0.36
	kit.text(ci, c + Vector2(-lx, 0.0), "WIND", 15.0 * u, Color(Kit.GO, 1.0 if g else 0.25), 0, 700, 1.0)
	kit.text(ci, c + Vector2(lx, 0.0), "BRACE", 15.0 * u, Color(Kit.CORAL, 1.0 if not g else 0.25), 0, 700, 1.0)
	if red_t > 0.2 and sin(time * 24.0) > 0.0:
		kit.ring(ci, c, rad + 8.0 * u, Kit.CORAL, 2.0 * u)
