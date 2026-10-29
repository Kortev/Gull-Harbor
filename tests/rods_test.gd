extends Node
## The spread: grabbing a rod, not grabbing a second one, putting it back. Run: godot --headless --path .
## res://tests/rods_test.tscn

const Sea := preload("res://sea/sea.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().process_frame
	await get_tree().process_frame
	var rods := sea.rods
	_check(rods.rods.size() == 4, "four rods out")
	rods.request_grab(2)
	_check(rods.rods[2].holder == 1, "E on rod 2: it's yours")
	rods.request_grab(0)
	_check(rods.rods[0].holder == 0, "a second rod while holding one: no")
	await get_tree().process_frame
	var me: Node3D = sea.crew.me
	var butt: Vector3 = rods.rods[2].global_position
	_check(butt.distance_to(me.global_position) < 1.5, "the rod is in your hands (%.2f m from you)" % butt.distance_to(me.global_position))
	var tip: Vector3 = rods.rods[2].tip_position()
	_check(tip.y > butt.y + 0.5, "held up ahead of you (tip %.2f m above the butt)" % (tip.y - butt.y))
	rods.request_return(2)
	_check(rods.rods[2].holder == 0, "Q: back in its holder")
	rods.request_grab(0)
	_check(rods.rods[0].holder == 1, "then another one: yours")
	for f in fails:
		print("FAIL ", f)
	print("RODS TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
