extends Node
## The fighting chair (the sportfisher's): from the cockpit you can put the crosshair on it; E and you sit, where W
## doesn't walk you anywhere and the chair swings round with your look; E gets you up. With a fish on, E with the rod
## and you fight it from the chair: the rod's butt in the gimbal, your arms wearing half as fast as standing (the
## same fish, the same fight). The skiff has no chair. And every other seat on both boats (the benches, the skipper's
## seat, the skiff's cooler seat and leaning post): in view from a step away, E sits you (or leans you), E gets you
## up and walking again. And the sportfisher's cooler: E on it and you swig a drink (not with a rod in your hands). Run: godot --headless --path . res://tests/chair_test.tscn

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
	await _seats(sea, "skiff")
	sea.fish_hold.head_in()
	sea.fish_hold.head_out("sportfisher")
	await get_tree().process_frame
	await _seats(sea, "sportfisher")
	# her skipper's seat stands in front of her wheel: it mustn't hide the wheel from the cockpit
	var helm: Node = sea.boat.get("helm")
	var spot: Transform3D = sea.boat.get("helm_spot")
	_check(await _can_look_at(sea.crew.me, Vector3(spot.origin.x, 0.6, spot.origin.z + 1.6), helm, 0.0),
			"sportfisher: past the skipper's seat you can still put the crosshair on the wheel")
	var cooler: Node = sea.boat.get_node_or_null("Cooler")
	_check(cooler != null, "sportfisher: a cooler")
	if cooler != null:
		var top := sea.boat.to_local((cooler as Node3D).global_position)
		_check(await _can_look_at(me, Vector3(top.x + 1.0, 0.6, top.z), cooler, -PI * 0.5 + PI),
				"sportfisher: from the cockpit you can put the crosshair on the cooler")
		_check(str(cooler.call("interact_prompt")) == "Grab a drink", "it says: %s" % cooler.call("interact_prompt"))
		cooler.call("interact", me)
		await get_tree().process_frame
		var said := str(sea.crew.hud._note.text)
		_check(str(me.get("_gesture")) == "drink" and said in cooler.DRINKS, "E: a swig (%s)" % said)
		sea.rods.request_grab(1)
		_check(str(cooler.call("interact_prompt")) == "", "no drink with a rod in your hands")
		sea.rods.request_return(1)
	_done()


## Each of her plain seats: look at it from a step in front, sit, get up, walk off.
func _seats(sea: Sea, kind: String) -> void:
	var me := sea.crew.me
	for s: Node in sea.boat.seats:
		if s.get("chair") != null:
			continue
		var feet: Vector3 = s.get("feet")
		var face := float(s.get("face"))
		var fwd := Vector3(-sin(face), 0.0, -cos(face))
		var stand := feet + fwd * 0.9
		stand.y = float(sea.boat.deck) + 0.05
		var title := "%s: %s" % [kind, s.get("title")]
		_check(await _can_look_at(me, stand, s, face + PI), "%s: in view from a step away" % title)
		var prompt := str(s.call("interact_prompt"))
		s.call("interact", me)
		await get_tree().create_timer(0.2).timeout
		_check(bool(me.call("is_seated")) and prompt.ends_with(str(s.get("title"))), "%s: E (\"%s\")" % [title, prompt])
		_press("interact")
		await get_tree().create_timer(0.3).timeout
		var up: Vector3 = me.local_position()
		me.set("_yaw", face)
		for a: String in ["move_forward", "move_right"]:      # (off the seat the way it faces, then aside)
			Input.action_press(a)
			await get_tree().create_timer(0.4).timeout
			Input.action_release(a)
		_check(not bool(me.call("is_seated")) and me.local_position().distance_to(up) > 0.3,
				"%s: up and walking (%.1f m)" % [title, me.local_position().distance_to(up)])


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
