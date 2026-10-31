extends Node
## Up on her rail (crew/player.gd), headless, in each kind of boat: Space at her side steps you up onto the cap (eased,
## nothing jumping), your eyes higher, still in her deck space riding her as she heaves; A/D along it; S back down onto
## her deck. Up again and Space looking out: a leap off it, in the air in the world's space going her way, and into
## the sea (SWIM, a splash). Walking off it outward: the same. A lurch with her rail dipping throws you off it.
## Run: godot --headless --fixed-fps 30 --path . res://tests/rail_test.tscn

const Sea := preload("res://sea/sea.gd")
const Player := preload("res://crew/player.gd")

var fails: Array[String] = []
var sea: Sea


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
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
	_check(str(me.get("_prompt")).begins_with("SPACE|Up on the rail"), "%s: at her rail it says so: %s"
			% [kind, me.get("_prompt")])
	# Space: up onto the cap
	var step := await _press_watch("jump", func() -> bool: return int(me.get("_cap")) == Player.CAP_ON, 1.5)
	var on: Vector3 = me.local_position()
	_check(int(me.get("_cap")) == Player.CAP_ON and me.mode == Player.DECK and me.frame == boat,
			"%s: Space at her rail: up on its cap, still aboard her" % kind)
	_check(absf(on.y - cap_y) < 0.12 and absf(on.x) > float(boat.beam) * 0.5 - 0.3,
			"%s: standing on the cap (%.2f, %.2f; her cap's at %.2f)" % [kind, on.x, on.y, cap_y])
	_check(step < 0.16, "%s: an eased step up, nothing jumping (at most %.3f m a frame)" % [kind, step])
	await _wait(0.3)
	var eye_cap := (boat.global_transform.affine_inverse() * me.cam.global_position).y
	_check(eye_cap > eye_deck + 0.45, "%s: your eyes higher up there (%.2f m, from %.2f)" % [kind, eye_cap, eye_deck])
	# riding her: in her frame you stay put while she heaves
	var w0 := me.global_position
	var l0 := boat.global_transform.affine_inverse() * me.global_position
	var heave := 0.0
	var drift := 0.0
	for i in 30:
		await get_tree().process_frame
		heave = maxf(heave, absf(me.global_position.y - w0.y))
		drift = maxf(drift, (boat.global_transform.affine_inverse() * me.global_position).distance_to(l0))
	_check(drift < 0.03, "%s: riding her up there (%.3f m in her frame; %.2f m up and down with her)"
			% [kind, drift, heave])
	_check(str(me.get("_prompt")).begins_with("SPACE|Leap"), "%s: up there it says what Space does: %s"
			% [kind, me.get("_prompt")])
	# along it
	Input.action_press("move_left")
	step = 0.0
	var prev := me.local_position()
	for i in 40:
		await get_tree().physics_frame
		step = maxf(step, me.local_position().distance_to(prev))
		prev = me.local_position()
	Input.action_release("move_left")
	var along: Vector3 = me.local_position()
	_check(int(me.get("_cap")) == Player.CAP_ON and absf(along.z - on.z) > 0.4 and absf(along.y - on.y) < 0.2,
			"%s: A along the cap (%.2f m)" % [kind, absf(along.z - on.z)])
	# S: back down onto her deck
	step = await _press_watch("move_back", func() -> bool: return int(me.get("_cap")) == Player.CAP_OFF, 1.5)
	await _wait(0.4)
	var down: Vector3 = me.local_position()
	_check(int(me.get("_cap")) == Player.CAP_OFF and me.mode == Player.DECK and me.body.is_on_floor()
			and absf(down.y - deck) < 0.15, "%s: S steps you back down onto her deck (%.2f)" % [kind, down.y])
	_check(step < 0.16, "%s: easy, nothing jumping (at most %.3f m a frame)" % [kind, step])
	# up again, and Space looking out: a leap off into the sea
	me.place(Vector3(x, deck + 0.02, z), -PI / 2.0)
	await _wait(0.3)
	await _press_watch("jump", func() -> bool: return int(me.get("_cap")) == Player.CAP_ON, 1.5)
	var s0 := me.splashes
	var air := false
	var flew := false
	step = 0.0
	prev = me.global_position
	Input.action_press("jump")
	for i in 30 * 3:
		await get_tree().process_frame
		if i == 1:
			Input.action_release("jump")
		step = maxf(step, me.global_position.distance_to(prev))
		prev = me.global_position
		if me.mode == Player.AIR:
			air = true
			flew = flew or me.frame == null
		if me.mode == Player.SWIM:
			break
	Input.action_release("jump")
	_check(air and flew, "%s: Space looking out: a leap, in the air in the world's space" % kind)
	await _until(func() -> bool: return me.splashes > s0, 2.0)
	_check(me.mode == Player.SWIM and me.splashes > s0, "%s: and into the sea, a splash" % kind)
	_check(step < 0.4, "%s: the whole way, nothing jumping (at most %.2f m a frame)" % [kind, step])
	var off := boat.global_transform.affine_inverse() * me.global_position
	_check(absf(off.x) > float(boat.beam) * 0.5 + 0.5, "%s: well out from her side (%.1f m)" % [kind, absf(off.x)])
	# walking off it outward: the same
	me.place(Vector3(x, deck + 0.02, z), -PI / 2.0)
	await _wait(0.3)
	await _press_watch("jump", func() -> bool: return int(me.get("_cap")) == Player.CAP_ON, 1.5)
	Input.action_press("move_forward")
	await _until(func() -> bool: return me.mode != Player.DECK, 1.5)
	Input.action_release("move_forward")
	_check(me.mode == Player.AIR, "%s: walking out off the cap: you fall" % kind)
	await _until(func() -> bool: return me.mode == Player.SWIM, 3.0)
	_check(me.mode == Player.SWIM, "%s: into the sea" % kind)
	# a lurch with her rail dipping: off it (thrown)
	me.place(Vector3(x, deck + 0.02, z), -PI / 2.0)
	await _wait(0.3)
	await _press_watch("jump", func() -> bool: return int(me.get("_cap")) == Player.CAP_ON, 1.5)
	await _wait(0.2)
	boat.rock = Vector2(0.0, -0.25)        # (her starboard rail down)
	me.set("_stumble_in", 0.0)
	me.set("_deck_vy", 30.0)
	await get_tree().process_frame
	await get_tree().process_frame
	boat.rock = Vector2.ZERO
	_check(me.mode != Player.DECK or int(me.get("_cap")) != Player.CAP_ON, "%s: a lurch throws you off her rail" % kind)
	await _until(func() -> bool: return me.mode == Player.SWIM or (me.mode == Player.DECK and me.body.is_on_floor()), 3.0)
	print("(%s: thrown %s)" % [kind, "into the sea" if me.mode == Player.SWIM else "onto her deck"])
	me.place(Vector3(0.0, deck + 0.02, z), 0.0, boat)
	await _wait(0.3)


## Presses `action` and holds it till `done` (or `s`), keeping the biggest one-frame step you took in her frame.
func _press_watch(action: String, done: Callable, s: float) -> float:
	var me := sea.crew.me
	var step := 0.0
	var prev: Vector3 = sea.boat.global_transform.affine_inverse() * me.global_position
	Input.action_press(action)
	var t := 0.0
	while not done.call() and t < s:
		await get_tree().process_frame
		if t > 0.05 and action == "jump":
			Input.action_release(action)
		var here: Vector3 = sea.boat.global_transform.affine_inverse() * me.global_position
		step = maxf(step, here.distance_to(prev))
		prev = here
		t += 1.0 / 30.0
	Input.action_release(action)
	await get_tree().process_frame
	return step


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(ok: Callable, s: float) -> void:
	var t := 0.0
	while not ok.call() and t < s:
		await get_tree().physics_frame
		t += 1.0 / 30.0


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("RAIL TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
