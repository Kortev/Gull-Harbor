extends Node
## The live well (boat/live_well.gd), on both boats: its lid's the model's own piece; it swings up as a mackerel goes
## in (or out for a bait) and shuts again, never jumping; E on it holds it open (the fish hold's word), and you see the
## mackerel swimming in there (as many as the well has, up to a handful); E again shuts it. The chum bucket stands on
## deck beside it, not on the lid, and in reach. (The fish box's lid is the fish hold's own: tests/landing_test.)
## Run: godot --headless --fixed-fps 30 --path . res://tests/lids_test.tscn

const Sea := preload("res://sea/sea.gd")
const LiveWell := preload("res://boat/live_well.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	hold.owned = ["skiff", "sportfisher"]
	for kind: String in ["skiff", "sportfisher"]:
		hold.head_in()
		await get_tree().process_frame
		hold.head_out(kind)
		await get_tree().create_timer(2.5).timeout      # (the lid from heading out with a fresh well: shut again)
		var well: LiveWell = sea.boat.get("live_well")
		_check(well != null and well.lid != null, "%s: her live well has a lid of its own" % kind)
		if well == null:
			continue
		_check(well.open < 0.01 and _seen(well) == 0, "%s: shut, no mackerel to see" % kind)
		# a mackerel jigged into the well: its lid swings up, and you can see them in there
		hold.host_add_live()
		var worst := await _watch(well, 0.6)
		_check(well.open > 1.0 and _seen(well) == mini(hold.well, LiveWell.SHOWN),
				"%s: a mackerel in, the lid up, %d mackerel swimming in it (%d in the well)" % [kind, _seen(well), hold.well])
		_check(worst <= LiveWell.SPEED / 30.0 + 0.01, "%s: it swings up (%.2f rad a frame at most)" % [kind, worst])
		await get_tree().create_timer(2.0).timeout
		_check(well.open < 0.01, "%s: and shuts again" % kind)
		# E on it: held open for a look
		var act: Node = well.get_node("LiveWell")
		_check(str(act.call("interact_prompt")) == "Live well: %d mackerel" % hold.well,
				"%s: it says: %s" % [kind, act.call("interact_prompt")])
		var stand := sea.boat.to_local((act as Node3D).global_position) + Vector3(0.0, 0.0, -1.1)
		stand.y = float(sea.boat.deck) + 0.05
		_check(await _can_look_at(sea.crew.me, stand, act, PI), "%s: from the cockpit you can put the crosshair on it" % kind)
		act.call("interact", sea.crew.me)
		await get_tree().create_timer(3.0).timeout
		_check(hold.well_open and well.open > 1.0 and _seen(well) > 0, "%s: E, the lid held up for a look" % kind)
		var lid := well.lid as MeshInstance3D
		var free_edge: Vector3 = lid.transform * lid.get_aabb().get_center()
		_check(free_edge.y > lid.position.y + 0.1, "%s: its free edge is up (%.2f m over its hinge)"
				% [kind, free_edge.y - lid.position.y])
		_check(str(act.call("interact_prompt")) == "Shut the live well", "%s: it says: %s" % [kind, act.call("interact_prompt")])
		act.call("interact", sea.crew.me)
		await get_tree().create_timer(0.8).timeout
		_check(not hold.well_open and well.open < 0.01, "%s: E again, shut" % kind)
		# the chum bucket: on deck beside the well, not on its lid
		var scoop := (sea.chum.get("_bucket") as Node).get_node("Scoop") as Node3D
		var at := sea.boat.to_local(scoop.global_position)
		var lid_at := lid.position + lid.basis * lid.get_aabb().get_center()
		var off_lid := absf(at.x - lid_at.x) > lid.get_aabb().size.x * 0.5 + 0.1
		_check(off_lid and at.y < float(sea.boat.deck) + 0.6 and await _can_look_at(sea.crew.me,
				Vector3(at.x * 0.8, float(sea.boat.deck) + 0.05, at.z - 1.0), scoop, PI),
				"%s: the chum bucket's on deck beside the well (%.2f m up) and in reach" % [kind, at.y - float(sea.boat.deck)])
	_done()


func _seen(well: LiveWell) -> int:
	var n := 0
	for f: Node3D in well.get("_fish"):
		if f.is_visible_in_tree():
			n += 1
	return n


## `secs` of frames, and the most the lid swung in one of them (rad).
func _watch(well: LiveWell, secs: float) -> float:
	var worst := 0.0
	var last := well.open
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()
		worst = maxf(worst, absf(well.open - last))
		last = well.open
	return worst


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
	print("LIDS TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
