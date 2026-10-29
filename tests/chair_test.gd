extends Node
## The fighting chair (boat/chair.gd), headless: the sportfisher has one, the skiff doesn't; E on it sits you down
## and holds you in the seat; it swivels as you look round; E (or a jump) gets you up. (No fighting advantage: it's
## for sitting in.) The bank's kept in a test file, not yours.
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
	_check(seat.interact_prompt() == "Sit in the fighting chair", "it says: %s" % seat.interact_prompt())
	seat.interact(me)
	await get_tree().create_timer(0.5).timeout
	_check(bool(me.get("seated")) and seat.sitter == 1, "E on it: sat down")
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(hold.save_path))
	_done()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("CHAIR TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
