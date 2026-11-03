extends Node
## The spread: grabbing a rod (carried up out of its holder), not grabbing a second one, putting it back. And clearing
## the lines: with a fish on, E on an empty rod picks it up and left mouse winds it in by hand (nothing winds itself;
## no bites on it), a tangle in a running fish's line comes free once it's in someone's hands, and with nothing on, E
## picks it up to cast it. The sportfisher's wide lines run up through her outriggers' clips
## (rising to them, not in a frame); a strike pops one out and it falls straight to the rod in a moment.
## Run: godot --headless --path . res://tests/rods_test.tscn

const Sea := preload("res://sea/sea.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().process_frame
	await get_tree().process_frame
	var rods := sea.rods
	_check(rods.rods.size() == 5, "five rods out on the sportfisher")
	_check(rods.names[4] == "shotgun" and (rods.baits[4] as Vector3).z > 70.0 and absf((rods.baits[4] as Vector3).x) < 1.0,
			"the fifth's the shotgun, way back down the middle (%s)" % rods.baits[4])
	rods.request_grab(2)
	_check(rods.rods[2].holder == 1, "E on rod 2: it's yours")
	rods.request_grab(0)
	_check(rods.rods[0].holder == 0, "a second rod while holding one: no")
	await get_tree().create_timer(rods.GRAB + 0.15).timeout       # (carried up out of its holder)
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
	# the other lines: everyone's told to reel them in; his run toward one warns first, across it for FOUL_IN s
	# tangles it, every time
	_hold_fish(rods, 1.2)
	await get_tree().process_frame
	_check(int(rods.lines_out()[0]) == rods.rods.size() - 1 and str(rods.crew_says(false, 0.0)).begins_with("REEL THE OTHER LINES IN"),
			"a fish on, %d lines still out: %s" % [rods.rods.size() - 1, rods.crew_says(false, 0.0)])
	rods._host_line(3, true)          # (the port line in: rod 1's the one he goes for)
	rods._host_line(4, true)          # (and the shotgun, down the middle, near it)
	var bait1: Vector3 = rods.rods[1].spot - rods.stern
	var at1 := atan2(bait1.x, bait1.z)
	var held := 0.0
	var warned := ""
	while held < 1.0:
		_hold_fish(rods, at1 - 0.35)
		await get_tree().process_frame
		held += get_process_delta_time()
	warned = rods.crew_says(false, 0.0)
	_check(is_equal_approx(rods.rods[1].foul, 0.5) and warned.contains("HEADING FOR THE")
			and not rods.is_tangled(0), "he's heading for rod 1's line: everyone's warned first (%s)" % warned)
	held = 0.0
	while held < rods.FOUL_IN + 0.6 and not rods.is_tangled(0):
		_hold_fish(rods, at1)
		await get_tree().process_frame
		held += get_process_delta_time()
	_check(rods.is_tangled(0) and held > rods.FOUL_IN - 0.3
			and str(rods.rods[1].call("interact_prompt", null)).begins_with("Clear the tangle"),
			"across it for %.1f s: tangled (%s)" % [held, rods.rods[1].call("interact_prompt", null)])
	_hold_fish(rods, 0.0)
	rods.request_grab(1)
	await get_tree().process_frame
	_check(rods.rods[1].holder == 1 and not rods.is_tangled(0), "E on it: picked up to wind, his line's coming free")
	var was_out: float = rods.rods[1].out
	await get_tree().create_timer(1.0).timeout
	_check(not rods.rods[1].bait_in and was_out > 2.0 and absf(rods.rods[1].out - was_out) < 0.01,
			"nobody winding: its line stays out (%.0f m)" % rods.rods[1].out)
	me.force_input = true
	Input.action_press("use_primary")
	await get_tree().create_timer(1.0).timeout
	_check(not rods.rods[1].bait_in and rods.rods[1].out < was_out - 2.0,
			"left mouse: you wind it in, the bait coming back over the water (%.0f m, was %.0f)"
			% [rods.rods[1].out, was_out])
	for k in 60:
		if rods.rods[1].bait_in:
			break
		await get_tree().create_timer(0.5).timeout
	Input.action_release("use_primary")
	rods.request_return(1)
	rods.request_grab(2)
	Input.action_press("use_primary")
	for k in 60:
		if rods.rods[2].bait_in:
			break
		await get_tree().create_timer(0.5).timeout
	Input.action_release("use_primary")
	rods.request_return(2)
	me.force_input = false
	_check(rods.rods[1].tangled < 0 and rods.rods[1].bait_in and rods.rods[1].holder == 0,
			"rod 1: cleared, all the way in, back in its holder")
	_check(rods.rods[2].bait_in and rods.rods[2].holder == 0, "another empty rod while it fights: wound in by hand")
	rods.strike(2, 150.0)
	_check(not rods.rods[2].hooked, "nothing bites a reeled-in line")
	rods._host_off(0, "(the test lets it go)")
	_check(not rods.fighting(), "the fish gone")
	rods.request_grab(2)
	_check(rods.rods[2].holder == 1, "with nothing on, E picks it up (to cast it: tests/cast_test.tscn)")
	# the outriggers: a wide bait (rod 3, cast back out to its place) runs out through its clip, high and wide (not
	# rod 2's, reeled in, nor a corner rod's); a strike pops it
	rods.request_return(2)
	rods._host_line(3, false)          # (cast back out to its place in the spread)
	var r3: Node3D = rods.rods[3]
	while rods.flying(3):
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var k0 := float(r3.get("clip_k"))
	await get_tree().create_timer(1.6).timeout
	var c3: Vector3 = sea.boat.global_transform.affine_inverse() * (r3.get("clip") as Vector3)
	_check(bool(r3.get("clip_on")) and not bool(rods.rods[2].get("clip_on")) and not bool(rods.rods[0].get("clip_on"))
			and c3.y > 6.0 and absf(c3.x) > 5.0, "the wide lines run through the outrigger clips (%s)" % c3)
	_check(k0 < 0.5 and float(r3.get("clip_k")) > 0.99, "up to the clip as the bait settles (%.2f, then %.2f)"
			% [k0, r3.get("clip_k")])
	rods.strike(3, 150.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var falling := float(r3.get("clip_k"))
	await get_tree().create_timer(0.5).timeout
	_check(bool(r3.get("hooked")) and not bool(r3.get("clip_on")) and falling > 0.5 and float(r3.get("clip_k")) < 0.01,
			"a strike pops the line out of the clip, and it falls to the rod (%.2f, then %.2f)" % [falling, r3.get("clip_k")])
	# the shotgun: its line runs up to a clip high on the back of her tower, and from there way back down the middle
	var r4: Node3D = rods.rods[4]
	if r4.get("bait_in"):
		rods._host_line(4, false)
	while rods.flying(4):
		await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout
	var c4: Vector3 = sea.boat.global_transform.affine_inverse() * (r4.get("clip") as Vector3)
	var tower_top: Vector3 = sea.boat.spec["tower"]
	_check(bool(r4.get("clip_on")) and float(r4.get("clip_k")) > 0.99 and c4.y > tower_top.y and absf(c4.x) < 0.5,
			"the shotgun runs up through a clip high on the tower, on her centreline (%s)" % c4)
	var end4: Vector3 = sea.boat.global_transform.affine_inverse() * (r4.get("line_end") as Vector3)
	_check(end4.z > 60.0 and absf(end4.x) < 8.0, "and its bait's way back astern, down the middle (%s)" % end4)
	var pole: Array = r4.get("pole")
	_check(pole.size() == 2 and (pole[1] as Vector3).y > (pole[0] as Vector3).y + 3.0, "on a halyard up the tower")
	rods.strike(4, 150.0)
	await get_tree().create_timer(0.6).timeout
	_check(bool(r4.get("hooked")) and not bool(r4.get("clip_on")) and float(r4.get("clip_k")) < 0.01,
			"a strike pops the shotgun out of its clip too")
	for f in fails:
		print("FAIL ", f)
	print("RODS TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


## Rod 0's fish held at bearing `b` (it's in its holder: the host's fight, and the rod's synced state).
func _hold_fish(rods: Node, b: float) -> void:
	var r0: Node = rods.rods[0]
	r0.set("bearing", b)
	r0.set("line_out", 70.0)
	var f: RefCounted = r0.get("fight")
	if f != null:
		f.set("bearing", b)
		f.set("line_out", 70.0)
		f.set("grace", 999.0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
