extends Node
## Screenshots of the kit in your hands (crew/hands.gd, crew/kit.gd), to judge how each thing looks, sits and moves:
## each item in first person and in a crewmate's eye view of you, then the moves (the knife's stroke on a fish, the
## gaff dug in and dragging, the jig rod snatched up and knocked down, the scoop wound up and flung, a change of item
## halfway down). Run (needs a window): godot --path . res://tests/kit_shot.tscn -- --out=<folder>

const Sea := preload("res://sea/sea.gd")
const Kit := preload("res://crew/kit.gd")

var sea: Sea
var out := "user://kit_shots"
var me: Node3D
var side: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await _wait(1.0)
	sea.schools.set("_next", 9999.0)
	sea.fish_hold.head_out("skiff")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.4            # (midday, for the light)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(2.0)
	me = sea.crew.me
	me.force_input = true
	side = Camera3D.new()
	side.fov = 40.0
	side.cull_mask &= ~(1 << 18)              # (not your own first-person view: what the others see)
	add_child(side)
	var deck := float(sea.boat.spec["deck"])
	me.place(Vector3(0.0, deck + 0.05, 1.8), PI)
	me.set("_pitch", -0.1)
	for item in Kit.ITEMS:
		me.hands.pick(item)
		await _wait(0.6)
		await _grab("fp_" + item)
		await _seen("tp_" + item)
	# a change halfway: the knife going down, then the gaff coming up
	me.hands.pick("knife")
	await _wait(0.5)
	me.hands.pick("gaff")
	while me.hands._lower < 0.5:
		await get_tree().process_frame
	await _grab("swap_down")
	while me.hands._shown != "gaff" or me.hands._lower > 0.5:
		await get_tree().process_frame
	await _grab("swap_up")
	# a fish on deck: the knife's stroke, the gaff dug in
	var hold = sea.fish_hold
	hold.host_add(60.0, 60.0)
	await _wait(0.3)
	var f: Dictionary = hold.fish[hold.fish.size() - 1]
	var node: Node3D = hold._deck[int(f["id"])]
	var at: Vector3 = sea.boat.global_transform.affine_inverse() * node.global_position
	me.place(Vector3(at.x, deck + 0.05, at.z + 1.3), 0.0)
	me.set("_pitch", -0.75)
	me.hands.pick("knife")
	await _wait(0.5)
	me.hands._target = node.get_node("Handle")
	node.get_node("Handle").call("use_item", me, "knife", true)
	await _wait(0.5)
	await _grab("knife_stroke_a")
	await _wait(0.12)
	await _grab("knife_stroke_b")
	await _seen("tp_knife_bleed")
	me.hands.press(false)
	me.hands.pick("gaff")
	await _wait(0.5)
	me.hands._target = node.get_node("Handle")
	node.get_node("Handle").call("use_item", me, "gaff", true)
	me.hands._move("gaff")
	await _wait(0.2)
	await _grab("gaff_strike")
	await _wait(0.6)
	await _grab("gaff_drag")
	await _seen("tp_gaff_drag")
	me.hands.press(false)
	# the jig at the rail: snatched up, knocked down
	var beam := float(sea.boat.spec["beam"])
	me.place(Vector3(beam * 0.5 - 0.55, deck + 0.05, 1.0), -PI * 0.5)
	me.set("_pitch", -0.3)
	me.hands.pick("jig")
	await _wait(0.6)
	await _grab("jig_hanging")
	me.hands.press(true)
	me.hands.press(false)
	await _wait(1.2)
	me.hands.press(true)
	me.hands.press(false)
	await _wait(0.06)
	await _grab("jig_lift")
	sea.jig.set("_knock_in", 0.01)
	await _wait(0.1)
	await _grab("jig_knock")
	await _seen("tp_jig")
	# the scoop: wound up, flung
	me.place(Vector3(0.0, deck + 0.05, 2.0), PI * 0.5)
	me.set("_pitch", 0.0)
	me.hands.pick("scoop")
	me.hands.scoop_full = true
	await _wait(0.6)
	await _grab("scoop_full")
	me.hands.press(true)
	await _wait(0.7)
	await _grab("scoop_wound")
	me.hands.press(false)
	await _wait(0.15)
	await _grab("scoop_throw")
	await _wait(0.12)
	await _grab("scoop_throw_b")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## A crewmate's eye view of you: from ahead and to your right, a few metres off.
func _seen(what: String) -> void:
	side.make_current()
	for i in 3:
		var b := me.global_transform.basis
		side.global_position = me.global_position + b * Vector3(1.4, 1.5, -2.2)
		side.look_at(me.global_position + b.y * 1.1, b.y)
		await get_tree().process_frame
	await _grab(what)
	me.cam.make_current()


func _grab(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out.path_join(what + ".png")
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path)
	print("SHOT ", path)
