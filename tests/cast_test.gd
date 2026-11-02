extends Node
## Sending the baits out by hand (rods/rods.gd): she heads out with every line in and the hooks bare (a bare hook won't
## cast); baited, pick a rod up, hold left mouse to wind up and let go, and the bait flies out where you look, as far
## as you wound it, and lands; holding left mouse with it out winds it back in; a fish takes the bait off the hook
## and the slack line lies out till someone winds it in (nothing winds itself); a mackerel in your fist (E on the rod,
## its line in) goes on; and holding right mouse lets one back off the stern, the line paying off with the clicker, till
## you let go and it's fished there. Run: godot --headless --fixed-fps 30 --path . res://tests/cast_test.tscn

const Sea := preload("res://sea/sea.gd")
const Rods := preload("res://rods/rods.gd")

var fails: Array[String] = []


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Till rod i's cast has been flying `part` of its flight (the flight's on the sea clock, the wall's: a headless
## run's frames go faster than that).
func _flown(rods: Rods, i: int, part := 1.0) -> void:
	for n in 2000:
		if rods._now() - rods.rods[i].cast_t > rods.fly_time(i) * part + (0.1 if part >= 1.0 else 0.0):
			break
		await get_tree().process_frame
	await get_tree().process_frame


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await _wait(0.3)
	sea.schools.set("_next", 9999.0)
	var rods := sea.rods
	var hold := sea.fish_hold
	# (at the dock in the game every line's in, as she's tied up: rods.gd; a test's sea starts with them out)
	for r in rods.rods:
		rods._host_line(r.index, true)
	hold.head_out("skiff")
	await _wait(0.3)
	for r in rods.rods:
		rods._host_line(r.index, true)       # (the skiff's rods, made for her)
		rods._unbaited(r.index)
	await _wait(0.1)
	var all_in := true
	for r in rods.rods:
		all_in = all_in and r.bait_in and not r.baited
	_check(all_in, "heading out: every line in, every hook bare")
	var me: Node3D = sea.crew.me
	me.force_input = true
	# face out over her starboard quarter
	me.set("_yaw", -PI * 0.75)
	rods.request_grab(0)
	await _wait(0.1)
	_check(rods.held_by(1) == rods.rods[0], "picked the rod up")
	var r: Node = rods.rods[0]
	Input.action_press("use_primary")
	await _wait(0.4)
	_check(r.wind == 0.0 and r.bait_in, "a bare hook: nothing to cast")
	Input.action_release("use_primary")
	await get_tree().process_frame
	rods._baited(0, rods._now(), true)        # (rods/rig.gd hooks one on: tests/bait_test)
	_check(rods.bite_odds(0) == 0.0, "nothing bites a bait hanging off the rod tip")
	# wind up: hold left mouse
	Input.action_press("use_primary")
	await _wait(0.5)
	var wound: float = r.wind
	_check(wound > 0.25 and wound < 0.75, "holding left mouse winds it up (%.2f after half a second)" % wound)
	_check(r.bait_in, "and it's still on the tip till you let go")
	Input.action_release("use_primary")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not r.bait_in and rods.flying(0), "let go: it's away")
	_check(rods.bite_odds(0) == 0.0, "nothing takes it in the air")
	var boat: Node3D = sea.boat
	var tip: Vector3 = r.tip_position()
	await _flown(rods, 0, 0.5)
	_check(r.line_end.y > tip.y - 0.5, "it flies up in an arc (%.1f m up, the tip at %.1f)" % [r.line_end.y, tip.y])
	await _flown(rods, 0)
	_check(not rods.flying(0) and rods.bite_odds(0) > 0.0, "it's landed and fishing")
	var land: Vector3 = r.land
	var tip_local := boat.global_transform.affine_inverse() * tip
	var went := Vector2(land.x - tip_local.x, land.z - tip_local.z)
	_check(went.x > 0.0 and went.y > 0.0, "out where you looked: over her starboard quarter (%.0f, %.0f)" % [went.x, went.y])
	var short := went.length()
	_check(absf(short - lerpf(Rods.CAST.x, Rods.CAST.y, wound)) < 4.0,
			"as far as you wound it (%.0f m)" % short)
	var landed: Vector3 = boat.global_transform * land
	_check(Vector2(r.line_end.x, r.line_end.z).distance_to(Vector2(landed.x, landed.z)) < 3.0,
			"the bait's where it landed")
	# wind it back in: hold left mouse, and it comes back over the water the whole way, no jump
	Input.action_press("use_primary")
	await _wait(1.0)
	var mid := Vector2(r.line_end.x - tip.x, r.line_end.z - tip.z).length()
	_check(not r.bait_in and mid < short - 2.0 and mid > short - 9.0,
			"a second's winding brings it in a few metres (%.0f m out, from %.0f)" % [mid, short])
	await _wait(short / Rods.REEL_SPEED + 0.5)
	Input.action_release("use_primary")
	await get_tree().process_frame
	_check(r.bait_in, "holding left mouse winds it all the way back in")
	await get_tree().process_frame
	# all you've got this time
	Input.action_press("use_primary")
	await _wait(Rods.WIND + 0.2)
	_check(r.wind >= 1.0, "wound all the way")
	Input.action_release("use_primary")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(rods.flying(0), "and away")
	await _flown(rods, 0)
	var far := Vector2(r.land.x - tip_local.x, r.land.z - tip_local.z).length()
	_check(far > short + 15.0, "a full wind-up goes further (%.0f m against %.0f)" % [far, short])
	# back in the holder, it trolls from there
	rods.request_return(0)
	await _wait(0.2)
	_check(r.holder == 0 and not r.bait_in and rods.bite_odds(0) > 0.0, "Q: in its holder, fishing")
	# a fish takes the bait
	rods.strike(0, 120.0)
	_check(r.hooked and not r.baited, "a fish on: it's got the bait")
	rods._host_off(0, Rods.WHY["pulled"])
	var lying: float = r.out
	await _wait(1.5)
	_check(not r.bait_in and r.auto_in == 0 and absf(r.out - lying) < 0.01,
			"the hook pulled: the slack line lies out there, nobody winding it (%.0f m)" % r.out)
	# a mackerel in your fist: the line has to come in first, by hand
	me.hands.carry("live")
	_check(str(r.call("interact_prompt", me)).begins_with("Wind it in first"), "a bait in your fist, the line out: "
			+ "wind it in first (%s)" % r.call("interact_prompt", me))
	me.hands.carry("")
	rods.request_grab(0)
	await _wait(0.1)
	var crank0: float = r.crank
	var out0: float = r.out
	Input.action_press("use_primary")
	await _wait(1.0)
	var turns: float = (r.crank - crank0) / TAU
	_check(absf(turns - (out0 - r.out) / r.PER_TURN) < 0.3, "the crank goes round with the line it brings in "
			+ "(%.1f turns for %.1f m)" % [turns, out0 - r.out])
	await _wait(r.out / Rods.REEL_SPEED + 0.6)
	Input.action_release("use_primary")
	await get_tree().process_frame
	_check(r.bait_in and not r.baited, "wound in by hand, a bare hook")
	rods.request_return(0)
	await _wait(0.5)
	me.place(Vector3(0.0, float(sea.boat.spec["deck"]) + 0.05, float(rods.stern.z) - 1.2), 0.0)
	await _wait(0.1)
	me.hands.carry("live")
	_check(str(r.call("interact_prompt", me)) == "Hook it on", "with it in, the rod wants the bait")
	(r._grab as Node).call("interact", me)
	for k in 90:
		if rods.rig.phase == "aim":
			break
		await get_tree().process_frame
	rods.rig.point = rods.rig.NOSE
	rods.rig.press()
	for k in 90:
		if r.baited:
			break
		await get_tree().process_frame
	_check(r.bait_in and r.baited and rods.freshness(0) > 0.99, "hooked on fresh, line in to send out again")
	rods.request_grab(0)
	await _wait(0.5)
	rods.cast_mine(0.5)
	await _flown(rods, 0)
	_check(rods.bite_odds(0) > 0.0, "and out it goes again")
	# letting one back: right mouse, the spool open
	Input.action_press("use_primary")
	await _wait(short / Rods.REEL_SPEED + 3.0)
	Input.action_release("use_primary")
	await get_tree().process_frame
	_check(r.bait_in, "(wound in again)")
	Input.action_press("use_secondary")
	await _wait(0.5)
	_check(r.letting and not r.bait_in, "right mouse: thumb off, the bait dropped over")
	await _wait(3.0)
	var let_out: float = r.out
	_check(let_out > 2.0 and r.noise.clicks > 0.0, "it goes back, taking line, the clicker going (%.1f m)" % let_out)
	_check(rods.bite_odds(0) == 0.0, "(nothing takes it while it's going back)")
	Input.action_release("use_secondary")
	await _wait(0.2)
	_check(not r.letting and rods.bite_odds(0) > 0.0, "let go: thumbed, it's fishing there")
	var spot_d := Vector2(r.spot.x - rods.stern.x, r.spot.z - rods.stern.z).length()
	_check(spot_d < let_out + 3.0, "where it got to (%.0f m back)" % spot_d)
	for f in fails:
		print("FAIL ", f)
	print("CAST TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)
