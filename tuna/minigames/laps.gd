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
	# a ticked dial: the yellow half (toward you) and the orange half hatched outside it, the change-over a pointer;
	# the fish going round, the line to him from the hub.
	var u := unit(rect)
	var c := rect.get_center() + Vector2(0.0, -2.0 * u)
	var rad := 36.0 * u
	var way := -1.0 if mirror else 1.0
	var g := green()
	var a0 := PI * 0.5 - way * TAU * GREEN * 0.5
	var a_green_end := a0 + way * TAU * GREEN
	var a_end := a0 + way * TAU
	kit.dial(ci, c, rad, 48, 4, Kit.PAPER, 5.0 * u, 10.0 * u)
	var r0 := rad + 3.0 * u
	var r1 := rad + 13.0 * u
	kit.hatch_arc(ci, c, r0, r1, a0, a_green_end, Kit.YELLOW, g, 7.0 * kit.px)
	kit.hatch_arc(ci, c, r0, r1, a_green_end, a_end, Kit.ORANGE, not g, 7.0 * kit.px)
	kit.sweep(ci, c, r1, minf(a0, a_green_end), maxf(a0, a_green_end), Kit.YELLOW, g)
	kit.sweep(ci, c, r1, minf(a_green_end, a_end), maxf(a_green_end, a_end), Kit.ORANGE, not g)
	for a: float in [a0, a_green_end]:
		kit.rule(ci, c + Vector2.from_angle(a) * rad, c + Vector2.from_angle(a) * (r1 + 2.0 * u), Kit.PAPER, true)
	# the change-over he turns toward you at
	var p0 := Vector2.from_angle(a0)
	kit.tri(ci, c + p0 * (r1 + 16.0 * u), 12.0 * u, -p0, Kit.YELLOW if (sharp and g) else Kit.PAPER)
	# him, going round
	var am := a0 + way * TAU * lap()
	var pm := c + Vector2.from_angle(am) * rad
	var burning := red_t > 0.2
	kit.rule(ci, c, c + Vector2.from_angle(am) * (rad - 24.0 * u), Kit.ORANGE if burning else Kit.PAPER)
	kit.circle(ci, c, 4.0 * u)
	kit.fish(ci, c + Vector2.from_angle(am) * (rad - 14.0 * u), 26.0 * u, Kit.ORANGE, 1.0, am + way * PI * 0.5)
	kit.tri(ci, pm, 11.0 * u, -Vector2.from_angle(am), Kit.YELLOW if (sharp and g) else Kit.PAPER)
	if burning and sin(time * 24.0) > 0.0:
		kit.circle(ci, c, r1 + 6.0 * u, Kit.ORANGE, true)
