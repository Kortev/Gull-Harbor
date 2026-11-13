extends "res://tuna/minigames/minigame.gd"
## His head shakes come down a lane on a beat: tap B on each as it crosses the ring (a counter-pull). A miss works
## the hook. Mirrored: they come from the other side. Twist: a quick extra one on the end.

const STEP := 0.3125         # s: half of one of his shakes (he shakes 1.6 times a second)
const PERFECT := 0.075
const GOOD := 0.16

## Each beat's time, and how it went (0 to come, 1 perfect, 2 good, 3 missed).
var beats := PackedFloat32Array()
var state := PackedByteArray()
var _lock := 0.0
var _flash := 0.0
var _flash_q := 0


func _init() -> void:
	id = "beats"
	title = "HEAD SHAKES"
	moves = ["shake", "dog"]
	can_boss = true
	length = 4.5
	hitstop = false


func _begin() -> void:
	var pats: Array = [[0, 2, 4, 6], [0, 2, 4, 6, 8]]
	if tier > 0.7:
		pats = [[0, 2, 3, 4, 6, 8, 9, 10], [0, 2, 4, 5, 6, 8, 10, 11, 12]]
	elif tier > 0.4:
		pats = [[0, 2, 3, 4, 6, 8], [0, 2, 4, 6, 7, 8], [0, 2, 4, 5, 6, 8]]
	var pat: Array = (pats[rng.randi_range(0, pats.size() - 1)] as Array).duplicate()
	if big:
		for s: int in pat.duplicate():
			pat.append(s + 14)
	if twist:
		pat.append(int(pat[pat.size() - 1]) + 1)
	beats = PackedFloat32Array()
	state = PackedByteArray()
	for s: int in pat:
		beats.append(1.1 + STEP / fast * s)
		state.append(0)
	length = beats[beats.size() - 1] + 0.5
	_lock = 0.0
	_flash = 0.0
	_rest = -0.1


func _step(dt: float, _a: bool, _b: bool, _a_hit: bool, b_hit: bool) -> void:
	_lock = maxf(_lock - dt, 0.0)
	_flash = maxf(_flash - dt * 4.0, 0.0)
	var near := 9.0
	for i in beats.size():
		if state[i] == 0:
			near = minf(near, absf(t - beats[i]))
			if t > beats[i] + GOOD:
				state[i] = 3
				_max += 1.0
				_miss(0.7)
	if b_hit and _lock <= 0.0:
		var at := -1
		for i in beats.size():
			if state[i] == 0 and absf(t - beats[i]) <= GOOD:
				at = i
				break
		if at >= 0:
			var perfect := absf(t - beats[at]) <= PERFECT
			state[at] = 1 if perfect else 2
			_pts += 1.0 if perfect else 0.7
			_max += 1.0
			_hit(2 if perfect else 1)
			_flash = 1.0
			_flash_q = 2 if perfect else 1
			pose = 0.85
		else:
			_lock = 0.25
			_pts = maxf(_pts - 0.34, 0.0)
			_near()
	pose = move_toward(pose, 0.4, 1.5 * dt)
	tension = 0.3 + 0.3 * clampf(1.0 - near / 0.2, 0.0, 1.0)
	gain = mood
	tire = maxf(mood, 0.0)


func cue() -> Array:
	return [Kit.NONE, Kit.TAP]


func hint() -> Dictionary:
	for i in beats.size():
		if state[i] == 0:
			return {"a": false, "b": t >= beats[i] - 0.02 and t <= beats[i] + 0.03}
	return {"a": false, "b": false}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, _time: float) -> void:
	# a tape running to a gate: a tick for every half shake, a diamond on the ones to answer; the gate two heavy
	# yellow ticks. Him at the far end, shaking his head.
	var u := unit(rect)
	var c := rect.get_center() + Vector2(0.0, 10.0 * u)
	var w := rect.size.x * 0.96
	var way := -1.0 if mirror else 1.0
	var gate := Vector2(c.x - way * w * 0.32, c.y)
	var speed := w * 0.42            # px a second
	var x_lo := c.x - w * 0.5
	var x_hi := c.x + w * 0.5
	kit.rule(ci, Vector2(x_lo, c.y), Vector2(x_hi, c.y))
	var st := STEP / fast
	var k0 := int(ceilf((t - 1.1 - w / speed) / st))
	for k in range(k0, k0 + int(w * 2.0 / speed / st) + 2):
		var x := gate.x + way * (1.1 + k * st - t) * speed
		if x > x_lo and x < x_hi:
			kit.rule(ci, Vector2(x, c.y), Vector2(x, c.y + (9.0 if posmod(k, 4) == 0 else 5.0) * u))
	# the gate: it jumps open on a hit
	var gcol := Kit.YELLOW
	var jump := 0.0
	if _flash > 0.4:
		gcol = Kit.YELLOW if _flash_q == 2 else Kit.PAPER
		jump = (7.0 if _flash_q == 2 else 3.0) * u
	for s: float in [-1.0, 1.0]:
		kit.rule(ci, gate + Vector2(0.0, s * (10.0 * u + jump)), gate + Vector2(0.0, s * (24.0 * u + jump)), gcol, true)
	for i in beats.size():
		var d := beats[i] - t
		var p := Vector2(gate.x + way * d * speed, c.y)
		if p.x < x_lo or p.x > x_hi:
			continue
		match state[i]:
			0:
				kit.diamond(ci, p, 17.0 * u, Kit.PAPER)
			3:
				if d > -0.45:
					kit.diamond(ci, p, 17.0 * u, Kit.ORANGE, false)
	kit.fish(ci, Vector2(c.x + way * w * 0.4, c.y - 34.0 * u), 30.0 * u, Kit.ORANGE, -way, sin(t * TAU / (STEP * 2.0)) * 0.3)
