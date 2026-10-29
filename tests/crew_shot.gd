extends Node
## Screenshots of the crew model in the game (docs/shots/crew_*.png): you, seen from a second camera on deck, standing
## and with a rod in your hands, so the model, its colours and its poses can be checked in the game's own light.
## Run (needs a window): godot --path . res://tests/crew_shot.tscn

const Sea := preload("res://sea/sea.gd")

var sea: Sea


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await get_tree().create_timer(1.0).timeout
	sea.fish_hold.head_out("skiff")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.4            # (midday, for the light)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED                  # (the menu shut)
	await get_tree().create_timer(2.0).timeout
	var me := sea.crew.me
	var cam := Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	cam.make_current()
	await _shot(me, cam, "crew_standing", Vector3(0.0, 1.35, -2.4), 1.0)
	await _shot(me, cam, "crew_face", Vector3(0.0, 1.6, -0.9), 1.55)
	await _shot(me, cam, "crew_back", Vector3(0.6, 1.4, 2.4), 1.0)
	sea.rods.request_grab(0)
	await get_tree().create_timer(1.5).timeout
	await _shot(me, cam, "crew_rod", Vector3(1.4, 1.4, -1.8), 1.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


## From `off` (in the player's own frame: -z ahead of them) looking at their body at height `at_y`.
func _shot(me: Node3D, cam: Camera3D, what: String, off: Vector3, at_y: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 20:
		var basis := me.global_transform.basis
		var feet := me.global_position
		cam.global_position = feet + basis * off
		cam.look_at(feet + basis.y * at_y, basis.y)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/shots/%s.png" % what
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)
