extends Node
## The fighting chair (boat/chair.gd), headless: the sportfisher has one, the skiff doesn't; E on it takes you down
## into the seat (a step at a time: never more than a little a frame) and holds you there; it swivels as you look
## round; E (or a jump) gets you up. With a fish on, the rod's butt goes down in its gimbal (no fighting advantage:
## it's for sitting in). And every other seat on both boats (the benches, the skipper's seat, the skiff's cooler seat
## and leaning post): in view from a step away, E sits you (or leans you), E gets you up and walking again. And the
## sportfisher's cooler: E on it and you swig a drink. The bank's kept in a test file, not yours.
## Run: godot --headless --path . res://tests/chair_test.tscn

const Sea := preload("res://sea/sea.gd")
const Chair := preload("res://boat/chair.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	hold.save_path = "user://bluefin_test.cfg"
	hold.owned = ["skiff", "sportfisher"]
	hold.head_out("skiff")
	await get_tree().create_timer(0.3).timeout
	_check(sea.boat.get("seat") == null, "the skiff has no fighting chair")
	hold.head_in()
	await get_tree().create_timer(0.3).timeout
	hold.head_out("sportfisher")
	await get_tree().create_timer(0.5).timeout
	var seat := sea.boat.get("seat") as Chair
	_check(seat != null, "the sportfisher has a fighting chair to sit in")
	if seat == null:
		_done()
		return
	var me := sea.crew.me
	me.force_input = true
	_check(seat.interact_prompt() == "Sit", "it says: %s" % seat.interact_prompt())
	me.call("place", seat.seat() + Vector3(0.6, 0.0, 1.2), PI)
	await get_tree().process_frame
	seat.interact(me)
	var worst := await _watch(me, 2.0)
	_check(bool(me.get("seated")) and seat.sitter == 1, "E on it: sat down")
	_check(worst < 0.15, "into it a step at a time (never more than %.2f m a frame)" % worst)
	_check(me.local_position().distance_to(seat.seat()) < 0.05, "held in the seat (%.2f m off it)"
			% me.local_position().distance_to(seat.seat()))
	Input.action_press("move_forward")
	await get_tree().create_timer(0.5).timeout
	Input.action_release("move_forward")
	_check(me.local_position().distance_to(seat.seat()) < 0.05, "walking doesn't take you out of it")
	var before := seat.chair.rotation.y
	me.set("_yaw", float(me.get("_yaw")) + 0.8)
	await get_tree().create_timer(0.8).timeout
	_check(absf(angle_difference(seat.chair.rotation.y, before)) > 0.5, "it swivels as you look round (%.2f rad)"
			% angle_difference(seat.chair.rotation.y, before))
	Input.action_release("use_primary")
	seat.request(false)
	await get_tree().create_timer(0.3).timeout
	Input.action_press("use_primary")
	await get_tree().create_timer(0.3).timeout
	Input.action_release("use_primary")
	_check(not bool(me.get("seated")) and seat.sitter == 0, "got up")
	# a fish on: into the chair with the rod, its butt down in the gimbal
	sea.rods.host_cast(0)
	sea.rods.strike(0, 250.0)
	await get_tree().process_frame
	sea.rods.request_grab(0)
	var rod = sea.rods.rods[0]
	_check(rod.holder == 1, "a fish on, the rod in your hands")
	_check(seat.interact_prompt() == "Fight it from the chair", "it says: %s" % seat.interact_prompt())
	var before_butt: Vector3 = sea.boat.to_local(rod.global_position)
	seat.interact(me)
	await get_tree().create_timer(1.5).timeout
	var gimbal := seat.chair.position + Vector3(0.0, 0.55, 0.0)
	var butt: Vector3 = sea.boat.to_local(rod.global_position)
	_check(bool(me.get("seated")) and rod.holder == 1 and rod.hooked, "fighting it from the chair")
	_check(Vector2(butt.x - gimbal.x, butt.z - gimbal.z).length() < 0.6 and absf(butt.y - gimbal.y) < 0.4,
			"the rod's butt down in the gimbal (%s, from %s)" % [butt, before_butt])
	seat.request(false)
	await get_tree().create_timer(1.0).timeout
	_check(not bool(me.get("seated")) and rod.holder == 1, "up again, the rod still in your hands")
	sea.rods.request_return(0)
	sea.rods.host_clear()
	await get_tree().process_frame
	hold.head_in()
	await get_tree().create_timer(0.3).timeout
	hold.head_out("skiff")
	await get_tree().create_timer(0.3).timeout
	await _seats(sea, "skiff")
	hold.head_in()
	await get_tree().create_timer(0.3).timeout
	hold.head_out("sportfisher")
	await get_tree().create_timer(0.3).timeout
	await _seats(sea, "sportfisher")
	# her skipper's seat stands in front of her wheel: it mustn't hide the wheel from the cockpit
	var helm: Node = sea.boat.get("helm")
	var spot: Transform3D = sea.boat.get("helm_spot")
	_check(await _can_look_at(me, Vector3(spot.origin.x, 0.6, spot.origin.z + 1.6), helm, 0.0),
			"sportfisher: past the skipper's seat you can still put the crosshair on the wheel")
	# her cooler: E on it and you swig a drink (not with a rod in your hands)
	var cooler: Node = sea.boat.get_node_or_null("Cooler")
	_check(cooler != null, "sportfisher: a cooler")
	if cooler != null:
		var top := sea.boat.to_local((cooler as Node3D).global_position)
		_check(await _can_look_at(me, Vector3(top.x + 1.0, 0.6, top.z), cooler, PI * 0.5),
				"sportfisher: from the cockpit you can put the crosshair on the cooler")
		_check(str(cooler.call("interact_prompt")) == "Grab a drink", "it says: %s" % cooler.call("interact_prompt"))
		cooler.call("interact", me)
		await get_tree().process_frame
		var said := str(sea.crew.hud._note.text)
		_check(str(me.get("_gesture")) == "drink" and said in cooler.DRINKS, "E: a swig (%s)" % said)
		sea.rods.request_grab(1)
		_check(str(cooler.call("interact_prompt")) == "", "no drink with a rod in your hands")
		sea.rods.request_return(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(hold.save_path))
	_done()


## Each of her plain seats: look at it from a step in front, sit (a step at a time), get up, walk off.
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
		var worst := await _watch(me, 1.5)
		_check(bool(me.get("seated")) and me.get("sat_in") == s and prompt == ("Lean" if s.get("lean") else "Sit"),
				"%s: E (\"%s\"), a step at a time (%.2f m a frame at most)" % [title, prompt, worst])
		_check(me.local_position().distance_to(s.call("seat")) < 0.05, "%s: in it" % title)
		_check(worst < 0.15, "%s: no jump into it" % title)
		_press("interact")
		worst = await _watch(me, 1.0)
		var up: Vector3 = me.local_position()
		_check(not bool(me.get("seated")) and worst < 0.15, "%s: up off it (%.2f m a frame at most)" % [title, worst])
		me.set("_yaw", face)
		for a: String in ["move_forward", "move_right"]:      # (off the seat the way it faces, then aside)
			Input.action_press(a)
			await get_tree().create_timer(0.4).timeout
			Input.action_release(a)
		_check(me.local_position().distance_to(up) > 0.3,
				"%s: and walking (%.1f m)" % [title, me.local_position().distance_to(up)])


## `secs` of frames, and the furthest you moved on her deck in one of them.
func _watch(me: Node, secs: float) -> float:
	var worst := 0.0
	var last: Vector3 = me.local_position()
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()
		worst = maxf(worst, (me.local_position() as Vector3).distance_to(last))
		last = me.local_position()
	return worst


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
