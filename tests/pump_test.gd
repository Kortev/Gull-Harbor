extends Node
## The live well's pump (boat/live_well.gd, boat/fish_hold.gd's WELL_STALE): left alone the well's water goes stale and
## a mackerel in it dies every WELL_STALE s (onto the ice in the bait box), the water going murky as it goes; hold E on
## the pump by the well and you work its handle up and down, each stroke gulping and a gush of water pouring into the
## well (and a sound), and the water's fresh again: nothing dies while someone keeps it pumped. On both boats.
## Run: godot --headless --fixed-fps 30 --path . res://tests/pump_test.tscn

const Sea := preload("res://sea/sea.gd")
const FishHold := preload("res://boat/fish_hold.gd")

var fails: Array[String] = []


func _ready() -> void:
	_check(is_equal_approx(FishHold.WELL_STALE, 240.0), "a mackerel lost about every 4 min unpumped (%.0f s)"
			% FishHold.WELL_STALE)
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	hold.owned = ["skiff", "sportfisher"]
	for kind: String in ["sportfisher", "skiff"]:
		hold.head_in()
		await get_tree().process_frame
		hold.head_out(kind)
		await get_tree().process_frame
		hold.well = 6
		hold.dead = 0
		var well: Node3D = sea.boat.get("live_well")
		var pump: Node3D = well.get("pump_act")
		_check(pump != null and pump.is_in_group("interactable"), "%s: a pump by her well" % kind)
		if pump == null:
			continue
		_check(pump.global_position.distance_to((well.call("mouth") as Vector3)) < 0.8, "%s: right by it (%.2f m)"
				% [kind, pump.global_position.distance_to(well.call("mouth"))])
		# left alone: the water going stale, murky, and one dies
		var fresh_col: Color = (well.get("_water_mat") as StandardMaterial3D).albedo_color
		hold.well_stale = FishHold.WELL_STALE * 0.9
		await get_tree().process_frame
		var murky: Color = (well.get("_water_mat") as StandardMaterial3D).albedo_color
		_check(murky.g > fresh_col.g and murky.b < fresh_col.b, "%s: the water goes murky as it goes stale (%s -> %s)"
				% [kind, fresh_col, murky])
		_check(str(pump.call("interact_prompt")).contains("stale"), "%s: the pump says so: %s" % [kind,
				pump.call("interact_prompt")])
		hold.well_stale = FishHold.WELL_STALE - 0.05
		await get_tree().create_timer(0.2).timeout
		_check(hold.well == 5 and hold.dead == 1, "%s: a mackerel dies in it (%d live, %d dead on ice)" % [kind,
				hold.well, hold.dead])
		# pumping: the handle going, a gush into the well each stroke, the water fresh again
		hold.well_stale = FishHold.WELL_STALE * 0.8
		well.set("hold_pump", true)
		var swung := 0.0
		var gushed := false
		var handle: Node3D = well.get("_handle")
		var gush: Node3D = well.get("_gush")
		for k in 90:
			await get_tree().process_frame
			swung = maxf(swung, absf(handle.rotation.z))
			gushed = gushed or gush.visible
		well.set("hold_pump", false)
		_check(int(well.get("strokes")) >= 3, "%s: hold E: it pumps, a stroke at a time (%d strokes in 3 s)" % [kind,
				well.get("strokes")])
		_check(swung > 0.3, "%s: the handle working up and down (%.2f rad)" % [kind, swung])
		_check(gushed, "%s: water gushing into the well" % kind)
		_check(hold.well_stale < FishHold.WELL_STALE * 0.8 - 2.0 * FishHold.PUMP_STROKE,
				"%s: fresh water in (%.0f s stale, was %.0f)" % [kind, hold.well_stale, FishHold.WELL_STALE * 0.8])
		# kept pumped, nothing dies
		hold.well_stale = FishHold.WELL_STALE * 0.95
		well.set("hold_pump", true)
		await get_tree().create_timer(1.0).timeout
		well.set("hold_pump", false)
		hold.well_stale = minf(hold.well_stale, FishHold.WELL_STALE - 30.0)
		var n := hold.well
		await get_tree().create_timer(0.5).timeout
		_check(hold.well == n and n == 5, "%s: kept pumped, they live (%d)" % [kind, hold.well])
	_done()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("PUMP TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
