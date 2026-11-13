extends "res://tuna/minigames/minigame.gd"
## The tug of war: he hauls the knot his way all the time; you haul it back hand over hand: A, B, A, B... as fast as
## you can. The same hand twice slips. Get the knot over your line and you've won it early. Twist: he heaves
## harder in bursts.

const STEP := 0.05          # what one good hand's worth
const SLIP := 0.03

## Where the knot is: -1 his .. 1 yours.
var pos := 0.0
## The hand that's next: 0 A, 1 B.
var next := 0
var hands := 0
var _pull := 0.25
var _heave := 0.0
var _heave_in := 1.2
var _jerk := 0.0
var _slip := 0.0


func _init() -> void:
	id = "tug"
	title = "TUG OF WAR"
	moves = ["run", "surge", "circle", "spiral", "dog"]
	from = 0.15
	can_boss = true
	length = 5.0
	hitstop = false
	lead = 0.5


func _begin() -> void:
	length = rng.randf_range(4.2, 5.2) * (1.5 if big else 1.0)
	_pull = lerpf(0.16, 0.26, tier) * fast
	pos = 0.0
	next = 1 if mirror else 0
	hands = 0
	_heave_in = rng.randf_range(1.0, 1.6)


func _step(dt: float, _a: bool, _b: bool, a_hit: bool, b_hit: bool) -> void:
	_jerk = maxf(_jerk - dt * 5.0, 0.0)
	_slip = maxf(_slip - dt * 3.0, 0.0)
	var pull := _pull
	if twist:
		_heave_in -= dt
		if _heave_in <= 0.0:
			_heave_in = rng.randf_range(1.2, 1.8)
			_heave = 0.45
		if _heave > 0.0:
			_heave -= dt
			pull *= 2.2
	if live():
		pos -= pull * dt
	for h in 2:
		if not (a_hit if h == 0 else b_hit):
			continue
		if h == next:
			pos += STEP
			next = 1 - next
			hands += 1
			_jerk = 1.0
			if hands % 4 == 0:
				_hit(1)
		else:
			pos -= SLIP
			_slip = 1.0
			_near()
	pos = clampf(pos, -1.0, 1.0)
	gain = clampf(pos * 1.5 + 0.3 * _jerk, -1.0, 1.0)
	tire = clampf(0.4 + pos + 0.4 * _jerk, 0.0, 1.0)
	tension = 0.55 + 0.25 * _jerk
	pose = 0.4 + 0.2 * _jerk
	if pos <= -0.95:
		hook = 0.5
	if live():
		_max += dt
		if pos >= -0.02:
			_pts += dt
	if pos >= 1.0 and not done:
		# (won outright: the rest of it's yours)
		_pts += maxf(length - t, 0.0)
		_max += maxf(length - t, 0.0)
		_hit(2)
		done = true


func cue() -> Array:
	return [Kit.TAP if next == 0 else Kit.NONE, Kit.TAP if next == 1 else Kit.NONE]


func hint() -> Dictionary:
	# (one hand every 0.14 s: seven a second)
	var on := fposmod(t, 0.14) < 0.07 and int(t / 0.14) % 2 == next
	return {"a": on and next == 0, "b": on and next == 1}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	# a rope, a heavy rule knotted with regular ticks, and THE knot a solid diamond riding it: your line a yellow
	# bracket at one end, his an orange one at the other. Two square hands under it, the next one solid.
	var u := unit(rect)
	var c := rect.get_center() + Vector2(0.0, -4.0 * u)
	var w := rect.size.x * 0.9
	var x0 := c.x - w * 0.5
	var x1 := c.x + w * 0.5
	var kx := c.x - pos * w * 0.3
	var shake := sin(time * 40.0) * 1.2 * u * _jerk
	var yours := c.x - w * 0.3
	var his := c.x + w * 0.3
	var foot := 7.0 * u
	kit.path(ci, PackedVector2Array([Vector2(yours + foot, c.y - 22.0 * u), Vector2(yours, c.y - 22.0 * u),
			Vector2(yours, c.y + 22.0 * u), Vector2(yours + foot, c.y + 22.0 * u)]), Kit.YELLOW, true)
	kit.path(ci, PackedVector2Array([Vector2(his - foot, c.y - 22.0 * u), Vector2(his, c.y - 22.0 * u),
			Vector2(his, c.y + 22.0 * u), Vector2(his - foot, c.y + 22.0 * u)]), Kit.ORANGE, true)
	kit.rule(ci, Vector2(c.x, c.y - 8.0 * u), Vector2(c.x, c.y + 8.0 * u))
	# the rope
	var col := Kit.ORANGE if _slip > 0.4 else Kit.PAPER
	var ra := Vector2(x0, c.y + shake)
	var rb := Vector2(x1 - 22.0 * u, c.y - shake)
	kit.rule(ci, ra, rb, col, true)
	for i in 27:
		var p := ra.lerp(rb, (i + 0.5) / 27.0)
		kit.rule(ci, p + Vector2(0.0, -5.0 * u), p + Vector2(0.0, 5.0 * u), col)
	kit.diamond(ci, Vector2(kx, c.y), (22.0 + 4.0 * _jerk) * u, Kit.ORANGE if pos < -0.5 else Kit.PAPER)
	# him on his end, hauling
	kit.fish(ci, Vector2(x1 - 8.0 * u + sin(time * 14.0) * 1.5 * u, c.y), 32.0 * u, Kit.ORANGE, 1.0, sin(time * 14.0) * 0.08)
	# your hands: the next one solid
	for h in 2:
		var p := Vector2(yours + (h * 2.0 - 1.0) * 14.0 * u, c.y + 36.0 * u)
		kit.square(ci, p, 11.0 * u, Kit.PAPER, h == next)
