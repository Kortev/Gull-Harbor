extends "res://tuna/minigames/minigame.gd"
## On the beat: two lanes, A's on the left and B's on the right. Notes fall down them in time with the music; tap
## each lane's button as its note lands on the line. Later in the fight they come on the off-beats too, and now and
## then both at once. Mirrored: the pattern's lanes are swapped.

const PERFECT := 0.075
const GOOD := 0.16
const FALL := 1.25           # s a note's on screen before it lands

## Each note: when it lands, its lane (0 A, 1 B), how it went (0 to come, 1 perfect, 2 good, 3 missed).
var when := PackedFloat32Array()
var lane := PackedByteArray()
var state := PackedByteArray()
var _lock := [0.0, 0.0]
var _flash := [0.0, 0.0]
var _flash_q := [0, 0]


func _init() -> void:
	id = "lanes"
	title = "ON THE BEAT"
	moves = ["shake", "circle", "spiral", "dog"]
	can_boss = true
	length = 6.0
	hitstop = false
	lead = 0.0
	_rest = -0.1


func _begin() -> void:
	var half := beat * 0.5 / fast
	# the first lands on a beat of the music, at least FALL from now
	var t0 := to_beat
	while t0 < FALL:
		t0 += beat
	var steps := 10 if tier < 0.5 else 14
	if big:
		steps += 10
	when = PackedFloat32Array()
	lane = PackedByteArray()
	state = PackedByteArray()
	var l := rng.randi_range(0, 1)
	for s in steps:
		var on_beat := s % 2 == 0
		if not on_beat and rng.randf() > lerpf(0.0, 0.55, tier):
			continue
		if on_beat and s > 0 and rng.randf() < 0.12:
			continue                      # (a rest)
		if rng.randf() < (0.6 if on_beat else 0.35):
			l = 1 - l
		var both := on_beat and tier > 0.55 and rng.randf() < 0.18
		for k in (2 if both else 1):
			when.append(t0 + s * half)
			lane.append((1 - l if mirror else l) if k == 0 else (l if mirror else 1 - l))
			state.append(0)
	length = when[when.size() - 1] + 0.5


func _step(dt: float, _a: bool, _b: bool, a_hit: bool, b_hit: bool) -> void:
	for l in 2:
		_lock[l] = maxf(float(_lock[l]) - dt, 0.0)
		_flash[l] = maxf(float(_flash[l]) - dt * 4.0, 0.0)
	for i in when.size():
		if state[i] == 0 and t > when[i] + GOOD:
			state[i] = 3
			_max += 1.0
			_miss(0.6)
	for l in 2:
		if not (a_hit if l == 0 else b_hit) or float(_lock[l]) > 0.0:
			continue
		var at := -1
		for i in when.size():
			if state[i] == 0 and lane[i] == l and absf(t - when[i]) <= GOOD:
				at = i
				break
		if at >= 0:
			var perfect := absf(t - when[at]) <= PERFECT
			state[at] = 1 if perfect else 2
			_pts += 1.0 if perfect else 0.7
			_max += 1.0
			_hit(2 if perfect else 1)
			_flash[l] = 1.0
			_flash_q[l] = 2 if perfect else 1
			pose = 0.8
		else:
			_lock[l] = 0.2
			_pts = maxf(_pts - 0.34, 0.0)
			_near()
	pose = move_toward(pose, 0.4, 1.5 * dt)
	tension = 0.4
	gain = mood
	tire = maxf(mood, 0.0)


func cue() -> Array:
	return [Kit.TAP, Kit.TAP]


func hint() -> Dictionary:
	var out := {"a": false, "b": false}
	for l in 2:
		for i in when.size():
			if state[i] == 0 and lane[i] == l:
				out["a" if l == 0 else "b"] = t >= when[i] - 0.02 and t <= when[i] + 0.03
				break
	return out


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, _time: float) -> void:
	# two ruled columns, a tick down their sides on every beat; square notes falling to the line; a yellow box on
	# the line for each to land in.
	var u := unit(rect)
	var c := rect.get_center()
	var gap := 40.0 * u
	var half := 16.0 * u
	var top := rect.position.y
	var line_y := rect.end.y - 13.0 * u
	var fall := line_y - top
	for l in 2:
		var x := c.x + (l * 2.0 - 1.0) * gap
		for s: float in [-1.0, 1.0]:
			kit.rule(ci, Vector2(x + s * half, top), Vector2(x + s * half, line_y))
			# the beats, coming down
			var k0 := int(ceilf((t - to_beat) / beat))
			for k in range(k0, k0 + int(FALL / beat) + 1):
				var d := to_beat + k * beat - t
				if d >= 0.0 and d < FALL:
					var y := line_y - fall * d / FALL
					kit.rule(ci, Vector2(x + s * half, y), Vector2(x + s * (half - 5.0 * u), y))
	kit.rule(ci, Vector2(c.x - gap - half - 8.0 * u, line_y), Vector2(c.x + gap + half + 8.0 * u, line_y), Kit.PAPER, true)
	for l in 2:
		var p := Vector2(c.x + (l * 2.0 - 1.0) * gap, line_y)
		if float(_flash[l]) > 0.4:
			kit.square(ci, p, 25.0 * u, Kit.YELLOW if int(_flash_q[l]) == 2 else Kit.PAPER)
		else:
			kit.square(ci, p, 21.0 * u, Kit.YELLOW, false)
	for i in when.size():
		var d := when[i] - t
		if d > FALL:
			continue
		var p := Vector2(c.x + (lane[i] * 2.0 - 1.0) * gap, line_y - fall * d / FALL)
		match state[i]:
			0:
				kit.square(ci, p, 15.0 * u, Kit.PAPER)
			3:
				if d > -0.3 and p.y < rect.end.y - 4.0 * u:
					kit.square(ci, p, 15.0 * u, Kit.ORANGE, false)
