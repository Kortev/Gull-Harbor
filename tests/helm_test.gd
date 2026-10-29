extends Node
## The captain: E on the wheel takes it; A swings her bow to port (her heading, the boat's pose, the wheel) and
## every fish on swings the other way round her; the captain can't grab a rod; S backs her down; Q leaves the wheel.
## Run: godot --headless --path . res://tests/helm_test.tscn

const Sea := preload("res://sea/sea.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	var helm: Node = sea.boat.get("helm")
	var me := sea.crew.me
	me.force_input = true
	helm.call("interact", me)
	_check(int(helm.get("captain")) == 1 and bool(me.get("steering")), "took the wheel")
	var spot: Transform3D = sea.boat.get("helm_spot")
	_check(me.local_position().distance_to(spot.origin) < 0.3, "standing at the helm")
	sea.rods.strike(0, 200.0)
	await get_tree().process_frame
	var b0: float = sea.rods.rods[0].bearing
	var fwd0 := -sea.boat.global_basis.z
	Input.action_press("move_left")
	await get_tree().create_timer(2.0).timeout
	Input.action_release("move_left")
	var h: float = helm.get("heading")
	var fwd := -sea.boat.global_basis.z
	_check(h > 0.3, "A swings her round (heading %.2f rad after 2 s)" % h)
	_check(fwd.signed_angle_to(fwd0, Vector3.UP) < -0.2 or fwd0.cross(fwd).y > 0.1,
			"the boat turned her bow to port")
	var b1: float = sea.rods.rods[0].bearing
	_check(b1 < b0 - 0.25, "the fish swung the other way round her (%.2f -> %.2f)" % [b0, b1])
	_check(absf(float(sea.boat.get("_wheel_turn"))) > 0.2, "the wheel turned")
	sea.rods.request_grab(1)
	_check(sea.rods.rods[1].holder == 0, "the captain can't grab a rod")
	Input.action_press("move_back")
	await get_tree().create_timer(1.0).timeout
	_check(float(helm.get("throttle")) < -0.9, "S backs her down (throttle %.2f)" % float(helm.get("throttle")))
	Input.action_release("move_back")
	var ev := InputEventAction.new()
	ev.action = "drop"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.3).timeout
	_check(int(helm.get("captain")) == 0 and not bool(me.get("steering")), "Q leaves the wheel")
	Input.action_press("move_forward")
	await get_tree().create_timer(0.5).timeout
	Input.action_release("move_forward")
	_check(me.local_position().distance_to(spot.origin) > 0.3, "and walks off again")
	for f in fails:
		print("FAIL ", f)
	print("HELM TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
