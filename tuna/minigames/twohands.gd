extends "res://tuna/minigames/minigame.gd"
## Both hands (a boss: only ever the last game of a stage): two games at once, one a hand. Your right hand rides
## him: hold B to lift the needle, let go to drop it, keep it in his green band (the tall bar on the right). Your left
## hand counters his head shakes: tap A as each crosses the ring (the lane on the left).

const PERFECT := 0.08
const GOOD := 0.17
const ACC := 2.8
const VMAX := 1.0

var needle := 0.3
var vel := 0.0
var band_c := 0.5
var band_w := 0.19
var inside := false
var beats := PackedFloat32Array()
var state := PackedByteArray()
var _w := 1.0
var _ph := 0.0
var _lock := 0.0
var _flash := 0.0
var _flash_q := 0
var _ride := 0.0
var _ride_max := 0.0
var _tap := 0.0
var _tap_max := 0.0


func _init() -> void:
	id = "twohands"
	title = "BOTH HANDS"
	boss = true
	length = 8.0
	hitstop = false
	lead = 0.8


func _begin() -> void:
	band_w = lerpf(0.21, 0.15, tier)
	_w = lerpf(0.8, 1.25, tier)
	_ph = rng.randf() * TAU
	needle = 0.3
	vel = 0.0
	var gap := lerpf(0.85, 0.62, tier)
	beats = PackedFloat32Array()
	state = PackedByteArray()
	var at := 1.6
	while at < 7.4:
		beats.append(at)
		state.append(0)
		at += gap * (0.5 if tier > 0.5 and rng.randf() < 0.25 else 1.0)
	length = beats[beats.size() - 1] + 0.6
	_ride = 0.0
	_ride_max = 0.0
	_tap = 0.0
	_tap_max = 0.0
	_rest = 0.0


func _step(dt: float, _a: bool, b: bool, a_hit: bool, _b_hit: bool) -> void:
	# the right hand: the ride
	band_c = 0.52 + 0.2 * sin(t * _w + _ph) + 0.07 * sin(t * _w * 2.3 + _ph * 2.0)
	vel = clampf(vel + (ACC if b else -ACC) * dt, -VMAX, VMAX)
	needle += vel * dt
	if needle <= 0.0 or needle >= 1.0:
		needle = clampf(needle, 0.0, 1.0)
		vel = 0.0
	inside = absf(needle - band_c) <= band_w
	if live():
		_ride_max += dt
		if inside:
			_ride += dt
	if needle - band_c > band_w:
		fray = 0.6
	# the left hand: the shakes
	_lock = maxf(_lock - dt, 0.0)
	_flash = maxf(_flash - dt * 4.0, 0.0)
	for i in beats.size():
		if state[i] == 0 and t > beats[i] + GOOD:
			state[i] = 3
			_tap_max += 1.0
			_miss(0.6)
	if a_hit and _lock <= 0.0:
		var at := -1
		for i in beats.size():
			if state[i] == 0 and absf(t - beats[i]) <= GOOD:
				at = i
				break
		if at >= 0:
			var perfect := absf(t - beats[at]) <= PERFECT
			state[at] = 1 if perfect else 2
			_tap += 1.0 if perfect else 0.7
			_tap_max += 1.0
			_hit(2 if perfect else 1)
			_flash = 1.0
			_flash_q = 2 if perfect else 1
		else:
			_lock = 0.25
			_tap = maxf(_tap - 0.34, 0.0)
			_near()
	gain = clampf((1.0 if inside else -0.6) * 0.5 + mood * 0.5, -1.0, 1.0)
	tire = (0.5 if inside else 0.0) + 0.5 * maxf(mood, 0.0)
	tension = 0.3 + 0.5 * needle + (0.2 if fray > 0.0 else 0.0)
	pose = 0.4 + 0.4 * needle
	score = 0.5 * (_ride / _ride_max if _ride_max > 0.0 else 0.0) + 0.5 * (_tap / _tap_max if _tap_max > 0.0 else 0.0)


func cue() -> Array:
	return [Kit.TAP, Kit.HOLD if needle < band_c else Kit.RELEASE]


func hint() -> Dictionary:
	var a := false
	for i in beats.size():
		if state[i] == 0:
			a = t >= beats[i] - 0.02 and t <= beats[i] + 0.03
			break
	return {"a": a, "b": needle + vel * 0.16 < band_c}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	var u := unit(rect)
	var c := rect.get_center()
	var split := c.x + rect.size.x * 0.2
	kit.line(ci, Vector2(split, rect.position.y + 6.0 * u), Vector2(split, rect.end.y - 6.0 * u), Color(Kit.FOAM, 0.15), 1.5, false)
	# the left hand: his shakes coming along a lane to the ring
	var lx0 := rect.position.x + 6.0 * u
	var lx1 := split - 10.0 * u
	var ly := c.y + 6.0 * u
	var box := Vector2(lx0 + 20.0 * u, ly)
	var speed := (lx1 - lx0) * 0.5
	kit.line(ci, Vector2(lx0, ly), Vector2(lx1, ly), Kit.TRACK, 12.0 * u)
	var rc := Kit.GOLD
	if _flash > 0.0:
		rc = Kit.GOLD if _flash_q == 2 else Kit.GO
		kit.glow(ci, box, 28.0 * u * (1.0 + _flash), rc, 1.5 * _flash)
	kit.ring(ci, box, 12.0 * u * (1.0 + 0.25 * _flash), rc, 3.0 * u)
	for i in beats.size():
		var d := beats[i] - t
		var p := Vector2(box.x + d * speed, ly)
		if p.x > lx1 + 2.0 or p.x < lx0 - 2.0:
			continue
		if state[i] == 0:
			kit.dot(ci, p, 8.0 * u, Kit.FOAM)
		elif state[i] == 3 and d > -0.5:
			kit.dot(ci, p, 8.0 * u, Color(Kit.CORAL, 1.0 + d / 0.5))
	kit.fish(ci, Vector2(lx1 - 22.0 * u, ly - 26.0 * u), 30.0 * u, Kit.FOAM, -1.0, sin(time * 10.0) * 0.25)
	# the right hand: the needle in his band, up a tall bar
	var bx := split + (rect.end.x - split) * 0.5
	var bh := rect.size.y * 0.88
	var bar := Rect2(bx - 9.0 * u, c.y - bh * 0.5, 18.0 * u, bh)
	kit.pill(ci, bar, Kit.TRACK)
	kit.dot(ci, Vector2(bx, bar.position.y + 9.0 * u), 3.5 * u, Color(Kit.CORAL, 0.8))
	var by := bar.end.y - band_c * bh
	var band := Rect2(bar.position.x, by - band_w * bh, bar.size.x, band_w * bh * 2.0).intersection(bar)
	if inside:
		kit.glow(ci, band.get_center(), band.size.y * 0.8, Kit.GO, 1.0)
	kit.rrect(ci, band, 9.0 * u, Color(Kit.GO, 0.95 if inside else 0.5))
	var ny := bar.end.y - needle * bh
	var col := Kit.FOAM if inside else (Kit.CORAL if needle > band_c else Kit.TEAL)
	kit.line(ci, Vector2(bx - 17.0 * u, ny), Vector2(bx + 17.0 * u, ny), col, 4.0 * u)
