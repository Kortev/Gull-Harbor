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


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	var u := unit(rect)
	var c := rect.get_center() + Vector2(0.0, 4.0 * u)
	var w := rect.size.x * 0.92
	var way := -1.0 if mirror else 1.0
	var box := Vector2(c.x - way * w * 0.3, c.y)
	var speed := w * 0.42            # px a second
	kit.line(ci, Vector2(c.x - w * 0.5, c.y), Vector2(c.x + w * 0.5, c.y), Kit.TRACK, 12.0 * u)
	# the ring they're hit in
	var ring_col := Kit.GOLD
	if _flash > 0.0:
		ring_col = Kit.GOLD if _flash_q == 2 else Kit.GO
		kit.glow(ci, box, 30.0 * u * (1.0 + _flash), ring_col, 1.5 * _flash)
	kit.ring(ci, box, 13.0 * u * (1.0 + 0.25 * _flash), ring_col, 3.0 * u)
	kit.dot(ci, box, 3.0 * u, Color(ring_col, 0.8))
	for i in beats.size():
		var d := beats[i] - t
		var p := Vector2(box.x + way * d * speed, c.y)
		if absf(p.x - c.x) > w * 0.5 + 4.0:
			continue
		match state[i]:
			0:
				kit.dot(ci, p, 8.5 * u, Kit.FOAM)
				kit.chevron(ci, p + Vector2(way * 1.0 * u, 0.0), 7.0 * u, Vector2(-way, 0.0), Kit.DEEP, 2.0)
			3:
				if d > -0.6:
					kit.dot(ci, p, 8.5 * u, Color(Kit.CORAL, 1.0 + d / 0.6))
	# him, shaking his head at the far end
	var far := Vector2(c.x + way * w * 0.42, c.y - 24.0 * u)
	kit.fish(ci, far, 34.0 * u, Kit.FOAM, -way, sin(t * TAU / (STEP * 2.0)) * 0.3)
