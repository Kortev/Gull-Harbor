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
	var u := unit(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.9
	var x0 := c.x - w * 0.5
	var x1 := c.x + w * 0.5
	var kx := c.x - pos * w * 0.3
	var shake := sin(time * 40.0) * 1.2 * u * _jerk
	# your line and his: get the knot over yours
	var yours := c.x - w * 0.3
	var his := c.x + w * 0.3
	kit.line(ci, Vector2(yours, c.y - 18.0 * u), Vector2(yours, c.y + 18.0 * u), Color(Kit.GO, 0.9), 3.0 * u)
	kit.line(ci, Vector2(his, c.y - 18.0 * u), Vector2(his, c.y + 18.0 * u), Color(Kit.CORAL, 0.8), 3.0 * u)
	kit.line(ci, Vector2(c.x, c.y - 9.0 * u), Vector2(c.x, c.y + 9.0 * u), Color(Kit.FOAM, 0.25), 2.0 * u)
	# the rope, bar-tight, the knot on it
	var col := Kit.FOAM.lerp(Kit.CORAL, _slip)
	kit.line(ci, Vector2(x0 + 22.0 * u, c.y + shake), Vector2(x1 - 30.0 * u, c.y - shake), col, 3.5 * u)
	var kc := Kit.GO if pos >= 0.0 else Kit.GOLD.lerp(Kit.CORAL, clampf(-pos * 1.5, 0.0, 1.0))
	kit.glow(ci, Vector2(kx, c.y), 22.0 * u, kc, 0.6 + _jerk)
	kit.dot(ci, Vector2(kx, c.y), (9.0 + 3.0 * _jerk) * u, kc)
	kit.dot(ci, Vector2(kx, c.y), 3.5 * u, Kit.DEEP)
	# him on his end, hauling; your two hands on yours, the next one lit
	kit.fish(ci, Vector2(x1 - 12.0 * u + sin(time * 14.0) * 1.5 * u, c.y), 38.0 * u, Kit.FOAM, 1.0, sin(time * 14.0) * 0.08)
	for h in 2:
		var p := Vector2(x0 + (6.0 + h * 15.0) * u - (4.0 * u * _jerk if h != next else 0.0), c.y)
		var on := h == next
		kit.dot(ci, p, 7.0 * u, Kit.GOLD if on else Color(Kit.FOAM, 0.35))
		if on:
			kit.ring(ci, p, (8.0 + 6.0 * fposmod(time * 4.0, 1.0)) * u, Color(Kit.GOLD, 1.0 - fposmod(time * 4.0, 1.0)), 2.0 * u)
