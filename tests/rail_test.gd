extends Node
## Her rail (crew/player.gd), headless, in each kind of boat: no mode, just her collider. A jump at her side going
## nowhere is a jump (you're still on her deck); a jump walking into it gets your legs up it (eased, nothing jumping)
## and you're stood on her gunwale, your eyes higher, still in her deck space riding her as she heaves, steady there;
## A/D along it; S and you step back down onto her deck. Up there W and Space: a leap off it, in the air, in the
## world's frame once you're clear of her, and into the sea (SWIM, a splash). Walking off it outward: the same. A
## sprint and a jump at her rail: straight over it in one, never stood on it. A lurch with her rail dipping throws
## you off it.
## Run: godot --headless --fixed-fps 30 --path . res://tests/rail_test.tscn

const Sea := preload("res://sea/sea.gd")
const Player := preload("res://crew/player.gd")

var fails: Array[String] = []
var sea: Sea


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(150.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	hold.save_path = "user://bluefin_test.cfg"
	hold.owned = ["skiff", "sportfisher"]
	for kind: String in ["skiff", "sportfisher"]:
		if bool(hold.get("docked")):
			hold.head_out(kind)
		else:
			sea.boat.use_kind(kind)
		await get_tree().create_timer(0.5).timeout
		await _rail(kind)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(hold.save_path))
	_done()


func _rail(kind: String) -> void:
	var boat := sea.boat
	var me := sea.crew.me
	me.force_input = true
	var deck := float(boat.deck)
	var cap_y := float((boat.spec["ladder"] as Vector3).y)
	var x := float(boat.beam) * 0.5 - 0.6
	var z := 2.0 if kind == "skiff" else 4.0
	me.place(Vector3(x, deck + 0.02, z), -PI / 2.0)
	await _wait(0.5)
	var eye_deck := (boat.global_transform.affine_inverse() * me.cam.global_position).y
	_check(str(me.get("_prompt")) == "", "%s: at her rail, no prompt: it's just her rail (%s)" % [kind, me.get("_prompt")])
	# a jump going nowhere: just a jump, back down on her deck
	await _press_watch(["jump"], func() -> bool: return false, 1.0)
	_check(me.mode == Player.DECK and absf(me.local_position().y - deck) < 0.1 and me.on_rail() == Vector3.ZERO,
			"%s: a jump standing at her rail: a jump, still on her deck (%.2f)" % [kind, me.local_position().y])
	# walking into her side and a jump: up onto her gunwale
	var step := await _press_watch(["move_forward", "jump"], func() -> bool: return me.on_rail() != Vector3.ZERO, 1.5,
			0.25)
	await _wait(0.6)
	var on: Vector3 = me.local_position()
	_check(me.on_rail() != Vector3.ZERO and me.mode == Player.DECK and me.frame == boat,
			"%s: walking into her side, a jump: up on her gunwale, still aboard her" % kind)
	_check(absf(on.y - cap_y) < 0.12 and absf(on.x) > float(boat.beam) * 0.5 - 0.3,
			"%s: standing on it (%.2f, %.2f; her cap's at %.2f)" % [kind, on.x, on.y, cap_y])
	_check(step < 0.16, "%s: your legs get you up, nothing jumping (at most %.3f m a frame)" % [kind, step])
	var eye_cap := (boat.global_transform.affine_inverse() * me.cam.global_position).y
	_check(eye_cap > eye_deck + 0.45, "%s: your eyes higher up there (%.2f m, from %.2f)" % [kind, eye_cap, eye_deck])
	# riding her: in her frame you stay put while she heaves, and stay up there
	var w0 := me.global_position
	var l0 := boat.global_transform.affine_inverse() * me.global_position
	var heave := 0.0
	var drift := 0.0
	for i in 60:
		await get_tree().process_frame
		heave = maxf(heave, absf(me.global_position.y - w0.y))
		drift = maxf(drift, (boat.global_transform.affine_inverse() * me.global_position).distance_to(l0))
	_check(drift < 0.03 and me.on_rail() != Vector3.ZERO, "%s: steady up there riding her (%.3f m in her frame; "
			% [kind, drift] + "%.2f m up and down with her)" % heave)
	# along it
	step = 0.0
	var prev := me.local_position()
	Input.action_press("move_left")
	for i in 20:
		await get_tree().physics_frame
		step = maxf(step, me.local_position().distance_to(prev))
		prev = me.local_position()
	Input.action_release("move_left")
	await _wait(0.2)
	var along: Vector3 = me.local_position()
	_check(me.on_rail() != Vector3.ZERO and absf(along.z - on.z) > 0.3 and absf(along.y - on.y) < 0.2,
			"%s: A along it (%.2f m), still up there" % [kind, absf(along.z - on.z)])
	# S: back down onto her deck
	step = await _press_watch(["move_back"], func() -> bool: return false, 0.4)
	await _wait(0.6)
	var down: Vector3 = me.local_position()
	_check(me.on_rail() == Vector3.ZERO and me.mode == Player.DECK and me.body.is_on_floor()
			and absf(down.y - deck) < 0.15, "%s: S, you step back down onto her deck (%.2f)" % [kind, down.y])
	_check(step < 0.16, "%s: easy, nothing jumping (at most %.3f m a frame)" % [kind, step])
	# up again, and W and Space: a leap off into the sea
	await _up(me)
	var s0 := me.splashes
	var air := false
	var world := false
	step = 0.0
	prev = me.global_position
	Input.action_press("move_forward")
	Input.action_press("jump")
	for i in 30 * 3:
		await get_tree().process_frame
		if i == 1:
			Input.action_release("jump")
		step = maxf(step, me.global_position.distance_to(prev))
		prev = me.global_position
		if me.mode == Player.AIR:
			air = true
			world = world or me.frame == null      # (clear of her: in the world's frame)
		if me.mode == Player.SWIM:
			break
	Input.action_release("move_forward")
	_check(air and world, "%s: W and Space up there: a leap, in the air, the world's once you're clear of her" % kind)
	await _until(func() -> bool: return me.splashes > s0, 2.0)
	_check(me.mode == Player.SWIM and me.splashes > s0, "%s: and into the sea, a splash" % kind)
	_check(step < 0.4, "%s: the whole way, nothing jumping (at most %.2f m a frame)" % [kind, step])
	var off := boat.global_transform.affine_inverse() * me.global_position
	_check(absf(off.x) > float(boat.beam) * 0.5 + 0.8, "%s: well out from her side (%.1f m)" % [kind, absf(off.x)])
	# walking off it outward: the same
	await _up(me)
	Input.action_press("move_forward")
	await _until(func() -> bool: return me.mode != Player.DECK, 2.0)
	Input.action_release("move_forward")
	_check(me.mode == Player.AIR, "%s: walking out off it: you fall" % kind)
	await _until(func() -> bool: return me.mode == Player.SWIM, 3.0)
	_check(me.mode == Player.SWIM, "%s: into the sea" % kind)
	# a sprint at her rail and a jump: straight over it, never stood on it
	me.place(Vector3(0.0, deck + 0.02, z), -PI / 2.0, boat)
	await _wait(0.4)
	var stood := false
	step = 0.0
	prev = me.global_position
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var t := 0.0
	while me.mode == Player.DECK and t < 2.0:
		await get_tree().physics_frame
		t += get_process_delta_time()
		if absf(me.local_position().x) > float(boat.beam) * 0.5 - 0.75 and not Input.is_action_pressed("jump"):
			Input.action_press("jump")
		stood = stood or (me.on_rail() != Vector3.ZERO and me.get("_vault_t") <= 0.0)
		step = maxf(step, me.global_position.distance_to(prev))
		prev = me.global_position
	Input.action_release("jump")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _until(func() -> bool: return me.mode == Player.SWIM, 3.0)
	_check(me.mode == Player.SWIM and not stood, "%s: a sprint and a jump at her rail: straight over and in" % kind)
	_check(step < 0.4, "%s: nothing jumping going over (%.2f m a frame at most)" % [kind, step])
	# a lurch with her rail dipping: off it (thrown)
	await _up(me)
	await _wait(0.2)
	boat.rock = Vector2(0.0, -0.25)        # (her starboard rail down)
	me.set("_stumble_in", 0.0)
	me.set("_deck_vy", 30.0)
	await get_tree().process_frame
	await get_tree().process_frame
	boat.rock = Vector2.ZERO
	await _until(func() -> bool: return me.mode == Player.SWIM or (me.mode == Player.DECK and me.body.is_on_floor()
			and me.on_rail() == Vector3.ZERO), 3.0)
	_check(me.mode != Player.DECK or me.on_rail() == Vector3.ZERO, "%s: a lurch throws you off her rail" % kind)
	print("(%s: thrown %s)" % [kind, "into the sea" if me.mode == Player.SWIM else "onto her deck"])
	me.place(Vector3(0.0, deck + 0.02, z), 0.0, boat)
	await _wait(0.3)


## Put by her starboard rail, a walk into it and a jump: up on her gunwale.
func _up(me: Node3D) -> void:
	var boat := sea.boat
	me.place(Vector3(float(boat.beam) * 0.5 - 0.6, float(boat.deck) + 0.02, 2.0 if boat.kind == "skiff" else 4.0),
			-PI / 2.0, boat)
	await _wait(0.3)
	await _press_watch(["move_forward", "jump"], func() -> bool: return me.on_rail() != Vector3.ZERO, 1.5, 0.25)
	await _wait(0.6)


## Presses `actions` and holds them till `done` (or `s`; the jump let go after a moment, all of them after `hold`
## s if given), keeping the biggest one-frame step you took in her frame.
func _press_watch(actions: Array, done: Callable, s: float, hold := INF) -> float:
	var me := sea.crew.me
	var step := 0.0
	var prev: Vector3 = sea.boat.global_transform.affine_inverse() * me.global_position
	for a: String in actions:
		Input.action_press(a)
	var t := 0.0
	while not done.call() and t < s:
		await get_tree().process_frame
		if t > 0.05:
			Input.action_release("jump")
		if t > hold:
			for a: String in actions:
				Input.action_release(a)
		var here: Vector3 = sea.boat.global_transform.affine_inverse() * me.global_position
		step = maxf(step, here.distance_to(prev))
		prev = here
		t += get_process_delta_time()
	for a: String in actions:
		Input.action_release(a)
	await get_tree().process_frame
	return step


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(ok: Callable, s: float) -> void:
	var t := 0.0
	while not ok.call() and t < s:
		await get_tree().physics_frame
		t += get_process_delta_time()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("RAIL TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
