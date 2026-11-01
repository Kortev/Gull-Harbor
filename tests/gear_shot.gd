extends Node
## Screenshots of the gear worked by hand (docs/shots/gear_*.png): the jig going down on its metered line, your left
## hand on the crank winding it up, a mackerel off the tip; netting one out of the live well and hooking it on; a
## rod in your hands, your gloves on the foregrip and the crank, winding a bait back in; one let back off the stern.
## Run (needs a window): godot --path . res://tests/gear_shot.tscn

const Sea := preload("res://sea/sea.gd")

var sea: Sea


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await _wait(1.0)
	sea.fish_hold.head_out("skiff")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.4            # (midday, for the light)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(2.0)
	sea.boat.helm.set("speed", 0.0)
	var me := sea.crew.me
	me.force_input = true
	var jig = sea.jig
	# the jig: dropped, going down the metered line; wound up, your hand on the crank; a mackerel off the tip
	var beam := float(sea.boat.spec["beam"])
	me.place(Vector3(beam * 0.5 - 0.55, float(sea.boat.spec["deck"]) + 0.05, 1.0), -PI * 0.5)
	me.set("_pitch", -0.75)
	me.hands.pick("jig")
	await _wait(0.6)
	me.hands.press(true)
	me.hands.press(false)
	await _wait(0.35)
	await _grab("gear_jig_drop")
	while jig.depth < 12.0:
		await get_tree().process_frame
	await _grab("gear_jig_down")
	me.hands.press(true)
	me.hands.press(false)
	jig.set("_knock_in", 0.01)
	await _wait(0.1)
	me.hands.press(true)
	me.hands.press(false)
	me.set("_pitch", -0.35)
	Input.action_press("use_primary")
	me.hands.press(true)
	await _wait(1.2)
	await _grab("gear_jig_wind")
	while jig.state == "on":
		await get_tree().process_frame
	Input.action_release("use_primary")
	me.hands.press(false)
	me.set("_pitch", -0.1)
	await _wait(0.4)
	await _grab("gear_jig_hang")
	# the live well: netted out, hooked on
	var mouth: Vector3 = sea.boat.live_well.mouth()
	var local: Vector3 = sea.boat.global_transform.affine_inverse() * mouth
	me.place(Vector3(local.x, float(sea.boat.spec["deck"]) + 0.05, local.z - 1.0), 0.0)
	me.set("_pitch", -0.9)
	await _wait(0.3)
	me.hands.press(true)
	me.hands.press(false)
	await _wait(0.4)
	await _grab("gear_jig_swing")
	await _wait(1.0)
	me.hands.pick("")
	var act: Node = sea.boat.live_well.get("_act")
	act.call("interact", me)
	await _wait(0.8)
	act.call("interact", me)
	await _wait(0.6)
	await _grab("gear_bait_in_hand")
	var r = sea.rods.rods[0]
	var rp: Vector3 = sea.boat.global_transform.affine_inverse() * r.global_position
	me.place(Vector3(rp.x * 0.6, float(sea.boat.spec["deck"]) + 0.05, rp.z - 1.2), PI if rp.x < 0.0 else 0.0)
	me.set("_pitch", -0.3)
	await _wait(0.3)
	sea.rods.rig.begin(0, me.hands.carrying())
	while sea.rods.rig.phase != "aim":
		await get_tree().process_frame
	await _wait(0.3)
	await _grab("gear_rig_aim")
	sea.rods.rig.point = sea.rods.rig.NOSE
	sea.rods.rig.press()
	await _wait(0.2)
	await _grab("gear_rig_send")
	await _wait(0.6)
	# a rod in your hands: your gloves on it, winding it in
	me.set("_yaw", -PI * 0.8)
	me.set("_pitch", -0.55)
	sea.rods.request_grab(0)
	await _wait(0.6)
	await _grab("gear_rod_hands")
	sea.rods.cast_mine(0.5)
	while sea.rods.flying(0):
		await get_tree().process_frame
	await _wait(0.5)
	Input.action_press("use_primary")
	await _wait(1.0)
	await _grab("gear_rod_wind")
	while not r.bait_in:
		await get_tree().process_frame
	Input.action_release("use_primary")
	await _wait(0.3)
	# let back off the stern
	me.set("_pitch", -0.35)
	Input.action_press("use_secondary")
	await _wait(1.6)
	await _grab("gear_let_back")
	Input.action_release("use_secondary")
	await _wait(0.3)
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _grab(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://docs/shots/%s.png" % what
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)
