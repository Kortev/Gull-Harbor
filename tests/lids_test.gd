extends Node
## The lids (boat/lids.gd), on both boats: the fish box's hatch swings up as a fish goes in on ice and shuts again;
## the live well's lid swings up as a mackerel goes in (or out for a bait), and E on it opens it for a look at the
## mackerel swimming in there (as many as the well has). The chum bucket stands on deck by it, in reach. Run: godot --headless --path . res://tests/lids_test.tscn

const Sea := preload("res://sea/sea.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	hold.save_path = "user://bluefin_test.cfg"
	hold.owned = ["skiff", "sportfisher"]
	if not hold.gear.has("bait"):
		hold.gear.append("bait")
	for kind: String in ["skiff", "sportfisher"]:
		hold.head_in()
		hold.head_out(kind)
		await get_tree().create_timer(0.2).timeout
		var lids: Node = sea.boat.get("lids")
		_check(lids != null and lids.get("box_lid") != null and lids.get("well_lid") != null,
				"%s: her fish box and live well have lids" % kind)
		if lids == null:
			continue
		# a fish on deck, bled and iced: the hatch swings up, then shuts
		await get_tree().create_timer(2.5).timeout      # (the well's lid from heading out: shut again)
		hold.host_add(150.0, 200.0)
		var id := int(hold.fish.back()["id"])
		hold._work(id)
		hold._work(id)
		await get_tree().create_timer(0.5).timeout
		_check(float(lids.get("box_open")) > 1.0, "%s: a fish in on ice, the hatch up (%.2f rad)" % [kind, lids.get("box_open")])
		await get_tree().create_timer(2.5).timeout
		_check(float(lids.get("box_open")) < 0.05, "%s: and shut again" % kind)
		# a mackerel jigged into the well: its lid swings up, and you can see them in there
		_check(not _any_fish(lids), "%s: lid shut, no mackerel to see" % kind)
		hold.host_add_live()
		await get_tree().create_timer(0.5).timeout
		var seen := _seen(lids)
		_check(float(lids.get("well_open")) > 1.0 and seen == mini(hold.well, 6),
				"%s: a mackerel in, the well's lid up, %d mackerel swimming in it (%d in the well)" % [kind, seen, hold.well])
		await get_tree().create_timer(2.5).timeout
		_check(float(lids.get("well_open")) < 0.05, "%s: and shut again" % kind)
		# E on the well: a look in
		var look: Node = lids.get_node("LiveWell")
		_check(str(look.call("interact_prompt")) == "Look in the live well (%d mackerel)" % hold.well,
				"%s: it says: %s" % [kind, look.call("interact_prompt")])
		var stand := sea.boat.to_local((look as Node3D).global_position) + Vector3(0.0, 0.0, -1.1)
		stand.y = float(sea.boat.deck) + 0.05
		_check(await _can_look_at(sea.crew.me, stand, look, 0.0 + PI), "%s: from the cockpit you can put the crosshair on it" % kind)
		var act := (sea.chum.get("_bucket") as Node).get_node("Scoop")
		var at := sea.boat.to_local((act as Node3D).global_position)
		_check(at.y < float(sea.boat.deck) + 0.6 and await _can_look_at(sea.crew.me,
				Vector3(at.x * 0.8, float(sea.boat.deck) + 0.05, at.z - 1.0), act, PI),
				"%s: the chum bucket's on deck (%.2f m up) and in reach" % [kind, at.y - float(sea.boat.deck)])
		look.call("interact", sea.crew.me)
		await get_tree().create_timer(0.6).timeout
		_check(float(lids.get("well_open")) > 1.0 and _any_fish(lids), "%s: E, the lid up for a look" % kind)
		# (really up: its free edge well above where it lay)
		var lid := lids.get("well_lid") as MeshInstance3D
		var free_edge: Vector3 = lid.transform * lid.get_aabb().get_center()
		_check(free_edge.y > lid.position.y + 0.1, "%s: the lid's free edge is up (%.2f m over its hinge)" % [kind, free_edge.y - lid.position.y])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(hold.save_path))
	_done()


func _seen(lids: Node) -> int:
	var n := 0
	for f: Node3D in lids.get("_fish"):
		if f.visible:
			n += 1
	return n


func _any_fish(lids: Node) -> bool:
	return _seen(lids) > 0


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
