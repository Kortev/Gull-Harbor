extends Node
## The fighting chair (the sportfisher's): from the cockpit you can put the crosshair on it; E and you sit, where W
## doesn't walk you anywhere and the chair swings round with your look; E gets you up. With a fish on, E with the rod
## and you fight it from the chair: the rod's butt in the gimbal, your arms wearing half as fast as standing (the
## same fish, the same fight). The skiff has no chair. Run: godot --headless --path . res://tests/chair_test.tscn

const Sea := preload("res://sea/sea.gd")
const Fight := preload("res://tuna/fight.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	sea.fish_hold.owned = ["skiff", "sportfisher"]
	sea.fish_hold.head_out("sportfisher")
	await get_tree().process_frame
	var me := sea.crew.me
	me.force_input = true
	var seat: Node = sea.boat.get("seat")
	_check(seat != null, "the sportfisher has a fighting chair")
	if seat == null:
		_done()
		return
	_check(await _can_look_at(me, Vector3(0.0, 0.6, 3.2), seat, PI), "from the cockpit you can put the crosshair on it")
	_check(str(seat.call("interact_prompt")) == "Sit in the chair", "it says: %s" % seat.call("interact_prompt"))
	seat.call("interact", me)
	await get_tree().create_timer(0.3).timeout
	_check(bool(me.call("is_seated")), "E: sitting in it")
	var at: Vector3 = me.local_position()
	Input.action_press("move_forward")
	await get_tree().create_timer(0.5).timeout
	Input.action_release("move_forward")
	_check(me.local_position().distance_to(at) < 0.05, "W doesn't walk you out of it")
	var chair := sea.boat.chair
	var b0 := chair.basis
	me.set("_yaw", float(me.get("_yaw")) + 0.8)
	await get_tree().process_frame
	await get_tree().process_frame      # (process_frame comes before the nodes' _process: the chair's turned by the next)
	var turned := absf((chair.basis * b0.inverse()).get_euler().y)
	_check(turned > 0.6, "the chair swings round with your look (%.2f rad)" % turned)
	_press("interact")
	await get_tree().create_timer(0.3).timeout
	_check(not bool(me.call("is_seated")), "E: up again")
	Input.action_press("move_forward")
	await get_tree().create_timer(0.5).timeout
	Input.action_release("move_forward")
	_check(me.local_position().distance_to(at) > 0.2, "and walking")
	# a fish on: into the chair with the rod
	sea.rods.strike(0, 250.0)
	await get_tree().process_frame
	sea.rods.request_grab(0)
	var rod = sea.rods.rods[0]
	_check(rod.holder == 1, "a fish on, the rod in your hands")
	_check(str(seat.call("interact_prompt")) == "Fight it from the chair", "it says: %s" % seat.call("interact_prompt"))
	seat.call("interact", me)
	Input.action_press("use_primary")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("use_primary")
	_check(bool(me.call("is_seated")) and rod.holder == 1 and rod.hooked, "fighting it from the chair")
	_check(rod.fight != null and bool(rod.fight.seated), "the fight knows you're in the chair")
	var gimbal: Vector3 = sea.boat.global_transform * Vector3(0.0, 1.1, 4.7)
	var butt: Vector3 = rod.global_position
	_check(butt.distance_to(gimbal) < 0.45, "the rod's butt is in the gimbal (%.2f m off it)" % butt.distance_to(gimbal))
	# the same fish fought the same way, standing and in the chair: the chair spares your arms
	var spent := []
	for in_chair: bool in [false, true]:
		var f := Fight.new(250.0, 120.0, 0.6, 42)
		f.seated = in_chair
		for i in 600:
			f.step(1.0 / 60.0, true, 0.0)
		spent.append(1.0 - f.arms)
	_check(spent[1] < spent[0] * 0.6 and spent[1] > 0.0,
			"10 s cranking a giant: arms down %.0f%% standing, %.0f%% in the chair" % [spent[0] * 100.0, spent[1] * 100.0])
	_press("interact")
	await get_tree().create_timer(0.3).timeout
	_check(not bool(me.call("is_seated")) and rod.holder == 1, "E: up again, the rod still in your hands")
	sea.fish_hold.head_in()
	sea.fish_hold.head_out("skiff")
	await get_tree().process_frame
	_check(sea.boat.get("seat") == null, "the skiff has no chair")
	_done()


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _can_look_at(me: Node, stand: Vector3, target: Node, face: float) -> bool:
	me.call("place", stand, face)
	for p in 13:
		for dy in range(-6, 7):
			me.set("_yaw", face + dy * 0.08)
			me.set("_pitch", 0.2 - p * 0.1)
			await get_tree().process_frame
			if me.call("looking_at") == target:
				return true
	return false


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("CHAIR TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
