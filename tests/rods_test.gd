extends Node
## The spread: grabbing a rod, not grabbing a second one, putting it back. And clearing the lines: with a fish on,
## E on an empty rod reels its line in (no bites on it), a tangle in a running fish's line is cleared the same way,
## and with nothing on, E picks it up to cast it. Run: godot --headless --path . res://tests/rods_test.tscn

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
	# (in the boat's frame: in a storm she pitches, and the rod with her)
	var deck := sea.boat.global_transform.affine_inverse()
	var up := (deck * rods.rods[2].tip_position()).y - (deck * butt).y
	_check(up > 0.5, "held up ahead of you (tip %.2f m above the butt)" % up)
	rods.request_return(2)
	_check(rods.rods[2].holder == 0, "Q: back in its holder")
	rods.request_grab(0)
	_check(rods.rods[0].holder == 1, "then another one: yours")
	rods.request_return(0)
	# clearing the lines: a fish on rod 0, a line tangled in it
	sea.schools.set("_next", 9999.0)
	rods.strike(0, 150.0)
	await get_tree().process_frame
	_check(rods.fighting(), "a fish on")
	# the line rubs where it really lies on her hull (ray-cast against her shape), not just by where the fish is
	await get_tree().physics_frame
	var r0: Node3D = rods.rods[0]
	r0.set("line_out", 60.0)
	r0.set("depth", 8.0)
	r0.set("bearing", 0.0)
	var astern := float(rods.rub_on_hull(r0))
	_check(astern < 0.05, "a fish dead astern: the line clears her (rub %.2f)" % astern)
	r0.set("bearing", PI)
	r0.set("depth", 2.0)
	var ahead := float(rods.rub_on_hull(r0))
	_check(ahead > 0.5, "a fish dead ahead near the top: the line lies over her (rub %.2f)" % ahead)
	await get_tree().process_frame
	var drawn: Vector3 = r0.get("line_end")
	var fish: Vector3 = rods.fish_point(r0, sea.boat)
	_check(drawn.distance_to(r0.call("tip_position")) < fish.distance_to(r0.call("tip_position")),
			"the line's drawn into the water on its way to the fish")
	r0.set("bearing", 0.0)
	r0.set("depth", 8.0)
	rods._tangle(1, 0)
	_check(rods.is_tangled(0) and str(rods.rods[1].call("interact_prompt", null)).begins_with("Clear the tangle"),
			"tangled: rod 1's line across its run (%s)" % rods.rods[1].call("interact_prompt", null))
	rods.request_grab(1)
	_check(not rods.is_tangled(0) and rods.rods[1].bait_in and rods.rods[1].holder == 0, "E on rod 1: cleared, reeled in")
	rods.request_grab(2)
	_check(rods.rods[2].bait_in and rods.rods[2].holder == 0, "E on another empty rod while it fights: reeled in")
	rods.strike(2, 150.0)
	_check(not rods.rods[2].hooked, "nothing bites a reeled-in line")
	rods._host_off(0, "(the test lets it go)")
	_check(not rods.fighting(), "the fish gone")
	rods.request_grab(2)
	_check(rods.rods[2].holder == 1, "with nothing on, E picks it up (to cast it: tests/cast_test.tscn)")
	for f in fails:
		print("FAIL ", f)
	print("RODS TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
