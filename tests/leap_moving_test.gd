extends Node
## Boat to boat under way (crew/player.gd), headless, Rivals (vs/vs.gd), two sportfishers running north side by side
## at different speeds, a calm sea and a heavy one: you up on one's rail (a walk at it and a jump) and a leap across
## to the other, both ways, alongside and 2 m off, and a sprint and a jump straight over both rails 1 m off: you go
## with her deck as it was going (her way, her roll), in the world's frame once you're clear of her, in the other's
## once you're in over her (into her deck space, still falling), and down on her deck; nothing jumps the whole way,
## in the world or over her deck (what you see, and your eyes), and a deck going by under you is a stumble, not a
## jolt. 6 m off, too far: into the sea.
## Run: godot --headless --fixed-fps 30 --path . res://tests/leap_moving_test.tscn [-- --trace]

const Sea := preload("res://sea/sea.gd")
const Player := preload("res://crew/player.gd")

## B's way and A's (m/s, both ahead, bow north), where B starts.
const B_SPEED := 7.0
const A_SPEED := 5.5
const SPOT := Vector2(300.0, -600.0)
## Most a frame's step may change by (m: a pop, a frame of her way at these speeds, is half as much again or more).
## Your body's measured across the deck (its feet do stop dead coming down on it); your eyes, every way (your knees
## take that).
const JERK := 0.12

var fails: Array[String] = []
var sea: Sea
var _wall := 0.0
var _ha: Node
var _hb: Node


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	_done()


func _process(delta: float) -> void:
	# (the sea's clock is the wall clock, but headless at a fixed 30 fps the frames run as fast as the machine lets
	# them: the waves held to the game's pace, so the boats ride the sea as they would playing, however loaded it is)
	var wall := Time.get_ticks_msec() / 1000.0
	if _wall > 0.0 and sea != null and sea.ocean != null:
		sea.ocean.clock_offset -= (wall - _wall) - delta
	_wall = wall
	# (both held at their way: nobody's at either wheel, and she'd coast down)
	for pair: Array in [[_hb, B_SPEED], [_ha, A_SPEED]]:
		var h: Node = pair[0]
		if h != null:
			h.set("speed", pair[1])
			h.set("heading", 0.0)
			h.set("drift", Vector2.ZERO)
			h.set("spin", 0.0)


func _run() -> void:
	var vs := sea.vs
	vs.host_set_on(true)
	await get_tree().process_frame
	vs.ask_team(1)
	await get_tree().process_frame
	sea.fish_hold.call("head_out", "sportfisher")
	var a_boat := vs.sides[0].get("boat") as Node3D
	var b_boat := vs.sides[1].get("boat") as Node3D
	var me := sea.crew.me
	me.force_input = true
	await get_tree().create_timer(0.3).timeout
	# (the leap's what's tested, from a gap that holds: the sea's orbits carrying the two of them, boat/boat.gd's carry,
	# open and close a gap between hulls lying a few metres apart by most of a metre in a heavy sea, so a scripted
	# leap timed for 2 m falls short now and then; that's the sea's, not the leap's)
	for bt: Node3D in [a_boat, b_boat]:
		bt.set("carry", 0.0)
	_ha = a_boat.get("helm")
	_hb = b_boat.get("helm")
	_hb.set("at", SPOT)
	for sea_is: String in ["calm", "heavy"]:
		sea.set_condition(sea_is)
		await get_tree().create_timer(0.5).timeout
		print("(%s)" % sea_is)
		for gap: float in [0.05, 2.0, 6.0]:
			for way: int in [1, -1]:
				await _leap(me, a_boat, b_boat, gap, way, false)
		for way: int in [1, -1]:
			await _leap(me, a_boat, b_boat, 1.0, way, true)


## From B to A (way +1: A off B's starboard side) or back, `gap` m apart, both under way: up on her rail and a leap
## off it, or (`run`) a sprint at it and a jump, straight over.
func _leap(me: Node3D, a_boat: Node3D, b_boat: Node3D, gap: float, way: int, run: bool) -> void:
	var from := b_boat if way > 0 else a_boat
	var to := a_boat if way > 0 else b_boat
	# (side by side again where B's got to, A a little ahead: she's the slower, and drops back level as you go)
	var at := _hb.get("at") as Vector2
	_ha.set("at", at + Vector2(float(b_boat.get("beam")) + gap, -2.0))
	await get_tree().create_timer(0.4).timeout
	me.place(Vector3((float(from.get("beam")) * 0.5 - 0.7) * way, float(from.get("deck")) + 0.02, 3.5),
			-PI * 0.5 * way, from)
	await get_tree().create_timer(0.4).timeout
	var w := {"t": 0.0, "jerk": 0.0, "deck_jerk": 0.0, "eye_jerk": 0.0, "went": false, "after": 0, "p": [], "l": [],
			"e": [], "stumbled": false, "rel": 0.0, "given": Vector2.ZERO, "launch": Vector3.ZERO, "world": false,
			"into": false}
	if run:
		# a sprint at her rail and a jump: straight over it in one
		me.place(Vector3(0.0, float(from.get("deck")) + 0.02, 3.5), -PI * 0.5 * way, from)
		await get_tree().create_timer(0.3).timeout
		Input.action_press("sprint")
		Input.action_press("move_forward")
		while me.mode == Player.DECK and float(w["t"]) < 2.0:
			if absf(me.local_position().x) > float(from.get("beam")) * 0.5 - 0.75:
				Input.action_press("jump")
			await _watch(me, to, w)
	else:
		# up on her rail (a walk into it and a jump), then W and Space (Shift too, for a gap): the leap
		Input.action_press("move_forward")
		Input.action_press("jump")
		await _watch(me, to, w)
		Input.action_release("jump")
		while me.on_rail() == Vector3.ZERO and float(w["t"]) < 1.5:
			await _watch(me, to, w)
			if float(w["t"]) > 0.25:
				Input.action_release("move_forward")
		Input.action_release("move_forward")
		for k in 8:
			await _watch(me, to, w)
		if gap > 1.0:
			Input.action_press("sprint")        # (lying alongside, a walk's leap: a sprint takes you to her far rail)
		Input.action_press("move_forward")
		Input.action_press("jump")
		await _watch(me, to, w)
	Input.action_release("jump")
	while not (me.mode == Player.DECK and me.frame == to and me.body.is_on_floor()) and me.mode != Player.SWIM \
			and float(w["t"]) < 6.0:
		await _watch(me, to, w)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	# (and a moment on, after it)
	for k in 12:
		await _watch(me, to, w)
	var where := "%s %s" % ["A" if me.boat == a_boat else "B", ["deck", "sea", "ladder", "air"][me.mode]]
	var what := "%.0f m gap, %s%s" % [gap, "B to A" if way > 0 else "A to B", ", running" if run else ""]
	if gap > 0.5:
		_check(bool(w["world"]), "%s: clear of her, in the world's frame, still in the air" % what)
	if gap < 3.0:
		_check(bool(w["into"]), "%s: in over her, in her frame, still in the air" % what)
	var v_from := Player._deck_velocity(from, Vector3.ZERO)
	_check(absf((w["launch"] as Vector3).z - v_from.z) < 1.0,
			"%s: off her going her way (%.1f m/s ahead, her %.1f)" % [what, -(w["launch"] as Vector3).z, -v_from.z])
	if gap < 3.0:
		_check(me.boat == to and me.mode == Player.DECK and me.frame == to,
				"%s: the leap lands you on her deck (%s, %.1f s)" % [what, where, float(w["t"])])
		_check(float(w["jerk"]) < JERK and float(w["deck_jerk"]) < JERK,
				"%s: nothing jumping, in the world or over her deck (%.3f, %.3f m a frame's change at most)"
				% [what, float(w["jerk"]), float(w["deck_jerk"])])
		_check(float(w["eye_jerk"]) < JERK, "%s: nor your eyes (%.3f)" % [what, float(w["eye_jerk"])])
		_check(bool(w["stumbled"]) == (float(w["rel"]) > Player.LAND_STUMBLE),
				"%s: her deck going by under you (%.1f m/s): %s" % [what, float(w["rel"]),
				"a stumble" if w["stumbled"] else "you're just down on it"])
	else:
		_check(me.mode == Player.SWIM, "%s: too far, into the sea (%s)" % [what, where])
		_check(float(w["jerk"]) < JERK, "%s: nothing jumping going in (%.3f)" % [what, float(w["jerk"])])


## A frame of a leap: the change in a frame's step (m) of where you're shown, in the world and over the deck you
## land on (from when you're down on it), and of your eyes; whether you stumbled down on her deck.
func _watch(me: Node3D, to: Node3D, w: Dictionary) -> void:
	var was_mode: int = me.mode
	await get_tree().process_frame
	w["t"] = float(w["t"]) + 1.0 / 30.0
	if me.mode == Player.AIR and not w["went"]:
		w["went"] = true
		w["launch"] = me.get("_air_v")
	if not w["went"]:
		return
	# (in her frame, in her deck space or not yet, still falling)
	w["into"] = bool(w["into"]) or (me.frame == to and not (me.mode == Player.DECK and me.body.is_on_floor()))
	var at: Vector3 = me.global_position
	var eye: Vector3 = (me.get("cam") as Node3D).global_position
	var p: Array = w["p"]
	var e: Array = w["e"]
	p.append(at)
	e.append(eye)
	if p.size() >= 3:
		w["jerk"] = maxf(float(w["jerk"]), _flat(p[-1] - 2.0 * p[-2] + p[-3]))
		w["eye_jerk"] = maxf(float(w["eye_jerk"]), (e[-1] - 2.0 * e[-2] + e[-3]).length())
	if me.mode == Player.AIR:
		w["world"] = bool(w["world"]) or me.frame == null
		# (the way the deck you left gave you, past your own leap)
		var given: Vector3 = (me.get("_air_v") as Vector3) - (me.get("_air_push") as Vector3)
		w["given"] = Vector2(given.x, given.z)
	if me.mode == Player.DECK and me.frame == to:
		if was_mode == Player.AIR:
			var under := Player._deck_velocity(to, me.local_position())
			w["rel"] = ((w["given"] as Vector2) - Vector2(under.x, under.z)).length()
		var l: Array = w["l"]
		l.append(to.global_transform.affine_inverse() * at)
		if l.size() >= 3:
			w["deck_jerk"] = maxf(float(w["deck_jerk"]), _flat(l[-1] - 2.0 * l[-2] + l[-3]))
		if me.get("_gesture") == "stumble":
			w["stumbled"] = true
	if OS.get_cmdline_user_args().has("--trace"):
		var l2: Vector3 = (to.global_transform.affine_inverse() * at)
		var j: float = _flat(p[-1] - 2.0 * p[-2] + p[-3]) if p.size() >= 3 else 0.0
		var je: float = (e[-1] - 2.0 * e[-2] + e[-3]).length() if e.size() >= 3 else 0.0
		var f: Node = me.get("frame")
		print("  t %.2f mode %d rail %s frame %s  in her: %.2f %.2f %.2f  jerk %.3f eyes %.3f" % [float(w["t"]),
				me.get("mode"), me.on_rail(), f.get_parent().name if f else "-", l2.x, l2.y, l2.z, j, je])


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("LEAP MOVING TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
