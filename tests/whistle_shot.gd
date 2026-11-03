extends Node
## The tin whistle as you see it and as the others do: in your hands, then up at your lips blowing it (first person and
## from a crewmate's eye). Run (needs a window): godot --path . res://tests/whistle_shot.tscn -- --out=<folder>

const Sea := preload("res://sea/sea.gd")

var sea: Sea
var out := "user://whistle_shots"
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
	sea.set_condition("sunny")
	sea.fish_hold.head_out("skiff")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.4
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(2.0)
	me = sea.crew.me
	me.force_input = true
	side = Camera3D.new()
	side.fov = 40.0
	side.cull_mask &= ~(1 << 18)
	add_child(side)
	me.place(Vector3(0.0, float(sea.boat.spec["deck"]) + 0.05, 1.8), PI)
	me.set("_pitch", -0.1)
	me.hands.pick("whistle")
	await _wait(0.8)
	await _grab("whistle_held")
	me.hands.press(true)
	await _wait(0.6)
	await _grab("whistle_blowing")
	await _seen("whistle_blowing_seen")
	me.hands.press(false)
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


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
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
