extends Node
## The tuna tower (the sportfisher's): from the cockpit you can put the crosshair on its ladder; E on it and you're up
## top, five metres up, where W doesn't walk you off; through the binoculars you can read the water under a flock about
## twice as far off as from the deck; E climbs down to the foot of the ladder. Not with a rod in your hands. The skiff
## has no tower. Run: godot --headless --path . res://tests/tower_test.tscn

const Sea := preload("res://sea/sea.gd")
const Binoculars := preload("res://crew/binoculars.gd")

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
	var tower: Node = sea.boat.get("tower")
	_check(tower != null, "the sportfisher has a tower")
	if tower == null:
		_done()
		return
	var cam := me.get("cam") as Camera3D
	var deck_read := Binoculars.read_range(cam)
	_check(await _can_look_at(me, Vector3(-1.2, 0.6, 3.6), tower, 0.0), "from the cockpit you can put the crosshair on the ladder")
	_check(str(tower.call("interact_prompt")) == "Climb the tower", "it says: %s" % tower.call("interact_prompt"))
	# not with a rod in your hands
	sea.rods.request_grab(0)
	tower.call("interact", me)
	_check(not bool(me.get("aloft")), "not with a rod in your hands")
	sea.rods.request_return(0)
	tower.call("interact", me)
	await get_tree().create_timer(0.2).timeout
	_check(bool(me.get("aloft")) and me.local_position().y > 5.0, "E: up the tower (%.1f m up)" % me.local_position().y)
	var at: Vector3 = me.local_position()
	Input.action_press("move_forward")
	await get_tree().create_timer(0.6).timeout
	Input.action_release("move_forward")
	_check(me.local_position().distance_to(at) < 0.05, "W doesn't walk you off it")
	var top_read := Binoculars.read_range(cam)
	# (your eye rides up and down with the swell, a metre or more in a big sea: these move with it)
	_check(deck_read > 600.0 and deck_read < 1700.0 and top_read > 1800.0 and top_read > deck_read * 1.35,
			"you can read the water under a flock %.0f m off from the deck, %.0f m from up here" % [deck_read, top_read])
	# a feeding school between the two: what's under the birds only from up here
	var c: Vector3 = sea.boat.global_position
	sea.schools._start(1, 7, sea.schools.now(), Vector2(c.x, c.z - 1600.0), Vector2(1, 0), 0.4, 200.0)
	var s: Node = sea.schools.schools.back()
	var far := str(sea.schools.spot_text(s, false))
	_check(far.contains("too far off"), "from the deck: %s" % far)
	_check(not str(sea.schools.spot_text(s, true)).contains("too far off"), "from the tower: %s" % sea.schools.spot_text(s, true))
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.3).timeout
	_check(not bool(me.get("aloft")) and me.local_position().y < 1.5, "E: back down on deck (%.1f m up)" % me.local_position().y)
	Input.action_press("move_forward")
	await get_tree().create_timer(0.5).timeout
	Input.action_release("move_forward")
	_check(me.local_position().distance_to(Vector3(-1.2, 0.6, 2.6)) > 0.2, "and walking again")
	sea.fish_hold.head_in()
	sea.fish_hold.head_out("skiff")
	await get_tree().process_frame
	_check(sea.boat.get("tower") == null, "the skiff has no tower")
	_done()


## Whether, standing at `stand` (boat-local) facing `face` (yaw), some look in a fan around it puts the crosshair on
## `target`.
func _can_look_at(me: Node, stand: Vector3, target: Node, face: float) -> bool:
	me.call("place", stand, face)
	for p in 13:
		for dy in range(-6, 7):
			me.set("_yaw", face + dy * 0.08)
			me.set("_pitch", 0.4 - p * 0.1)
			await get_tree().process_frame
			if me.call("looking_at") == target:
				return true
	return false


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("TOWER TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
