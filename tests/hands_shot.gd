extends Node
## Screenshots of the hands-on kit (docs/shots/hands_*.png): each item in first person with the hotbar, and a
## crewmate's eye view of you holding it. Run (needs a window): godot --path . res://tests/hands_shot.tscn

const Sea := preload("res://sea/sea.gd")
const Kit := preload("res://crew/kit.gd")

var sea: Sea


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await get_tree().create_timer(1.0).timeout
	sea.fish_hold.head_out("skiff")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.4            # (midday, for the light)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().create_timer(2.0).timeout
	var me := sea.crew.me
	var only := OS.get_cmdline_user_args()
	for item in Kit.ITEMS:
		me.hands.pick(item)
		await get_tree().create_timer(0.4).timeout
		await _grab("hands_" + item)
	var cam := Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	me.hands.pick("gaff")
	await get_tree().create_timer(0.4).timeout
	cam.make_current()
	for i in 20:
		var b := me.global_transform.basis
		cam.global_position = me.global_position + b * Vector3(1.2, 1.4, -1.8)
		cam.look_at(me.global_position + b.y * 1.0, b.y)
		await get_tree().process_frame
	await _grab("hands_seen")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


func _grab(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://docs/shots/%s.png" % what
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)
