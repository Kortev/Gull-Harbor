extends "res://tuna/minigames/minigame.gd"
## Thumb the spool: the reel's spinning. Tap A to stop the mark on the gold tooth (perfect) or in the green beside
## it (good); anywhere else it bites. A few spins, each quicker and the other way round. Twist: the tooth creeps.
## (A good one to copy for a game of single timed presses.)

## How far round the mark is and where the tooth is (turns, 0..1); turns a second (signed).
var mark := 0.0
var tooth := 0.5
var speed := 0.8
var gold_w := 0.03
var green_w := 0.085
var spin := 0
var spins := 4
## After a press: s of showing how it went (and what: 2 perfect, 1 good, 0 missed) before the next spin.
var show_t := 0.0
var last := -1
var _turned := 0.0


func _init() -> void:
	id = "spool"
	title = "THUMB THE SPOOL"
	moves = ["run", "surge", "sound"]
	can_boss = true
	length = 9.0
	lead = 0.0


func _begin() -> void:
	spins = (3 if tier < 0.6 else 4) + (2 if big else 0)
	gold_w = lerpf(0.046, 0.037, tier)
	green_w = lerpf(0.115, 0.09, tier)
	spin = 0
	last = -1
	show_t = 0.0
	_next(1.0)


func _next(way: float) -> void:
	speed = way * lerpf(0.5, 0.8, tier) * fast * (1.0 + 0.08 * spin)
	mark = rng.randf()
	# (the tooth at least a third of a turn ahead: time to see it coming)
	tooth = fposmod(mark + way * rng.randf_range(0.35, 0.7), 1.0)
	_turned = 0.0


## How far the mark is from the tooth (turns, signed: under 0 it's still coming).
func off() -> float:
	return wrapf(mark - tooth, -0.5, 0.5) * signf(speed)


func _step(dt: float, _a: bool, _b: bool, a_hit: bool, _b_hit: bool) -> void:
	gain = mood
	tire = maxf(mood, 0.0)
	tension = 0.45
	pose = 0.5
	if show_t > 0.0:
		show_t -= dt
		if show_t <= 0.0:
			spin += 1
			if spin >= spins:
				done = true
			else:
				_next(-signf(speed))
		return
	mark = fposmod(mark + speed * dt, 1.0)
	_turned += absf(speed) * dt
	if twist:
		tooth = fposmod(tooth - signf(speed) * 0.05 * dt, 1.0)
	var end := -1
	if a_hit:
		var d := absf(off())
		end = 2 if d <= gold_w else (1 if d <= green_w else 0)
	elif _turned > 2.2:
		end = 0
	if end >= 0:
		last = end
		show_t = 0.4
		_max += 1.0
		if end > 0:
			_pts += 1.0 if end == 2 else 0.65
			_hit(end)
		else:
			_miss()


func cue() -> Array:
	return [Kit.TAP if show_t <= 0.0 else Kit.NONE, Kit.NONE]


func hint() -> Dictionary:
	var o := off()
	return {"a": show_t <= 0.0 and o > -absf(speed) * 0.035 and o < gold_w * 0.6, "b": false}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, _time: float) -> void:
	# the reel as a ticked dial: the tooth a solid yellow block on its rim, the good either
	# side of it hatched between two brackets; the mark a pointer turning from the hub.
	var u := unit(rect)
	var c := rect.get_center()
	var rad := 35.0 * u
	var ang := func(v: float) -> float: return -PI * 0.5 + TAU * v
	kit.dial(ci, c, rad, 60, 5, Kit.PAPER, 4.0 * u, 9.0 * u)
	kit.circle(ci, c, 4.0 * u)
	# the tooth, and the good either side of it
	var ta := ang.call(tooth) as float
	var r0 := rad + 3.0 * u
	var r1 := rad + 12.0 * u
	for s: float in [-1.0, 1.0]:
		var edge := ta + s * TAU * green_w
		kit.hatch_arc(ci, c, r0, r1, ta + s * TAU * gold_w, edge, Kit.YELLOW, false, 5.0 * kit.px)
		kit.rule(ci, c + Vector2.from_angle(edge) * rad, c + Vector2.from_angle(edge) * r1, Kit.YELLOW)
	kit.sweep(ci, c, r1, ta - TAU * green_w, ta + TAU * green_w, Kit.YELLOW)
	var block := PackedVector2Array()
	for i in 5:
		block.append(c + Vector2.from_angle(ta + TAU * gold_w * (i / 2.0 - 1.0)) * r1)
	for i in 5:
		block.append(c + Vector2.from_angle(ta - TAU * gold_w * (i / 2.0 - 1.0)) * r0)
	kit.solid(ci, block, Kit.YELLOW)
	# the mark
	var mp := Vector2.from_angle(ang.call(mark) as float)
	var col := Kit.PAPER
	if show_t > 0.0:
		col = [Kit.ORANGE, Kit.PAPER, Kit.YELLOW][last]
	kit.rule(ci, c + mp * 4.0 * u, c + mp * (rad - 8.0 * u), col, true)
	kit.tri(ci, c + mp * (rad + (5.0 * u if show_t > 0.2 and last > 0 else 0.0)), 11.0 * u, mp, col)
	# the spins left
	for i in spins:
		var p := Vector2(rect.end.x - 5.0 * u, c.y + (i - (spins - 1) * 0.5) * 13.0 * u)
		kit.square(ci, p, 7.0 * u, Kit.PAPER, i >= spin)
