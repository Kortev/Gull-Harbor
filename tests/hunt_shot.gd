extends Node
## What the hunt looks like to a player (docs/shots/hunt_*.png): a flock about FAR m off with the naked eye, the
## the spotter's read of it, and the skiff's dash (the radar) from the wheel.
## Run (needs a window): godot --path . res://tests/hunt_shot.tscn

const Sea := preload("res://sea/sea.gd")
const FAR := 1200.0

var sea: Sea


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await get_tree().create_timer(1.0).timeout
	sea.fish_hold.head_out("skiff")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.3
	sea.set_condition("sunny")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var school = null
	for i in 1800:
		await get_tree().process_frame
		if i % 30 == 0:
			sea.schools.start_far = FAR
			sea.schools.set("_next", 0.0)
		for s in sea.schools.schools:
			if not s.bait_only and school == null:
				school = s
		if school != null:
			break
	if school == null:
		print("no school")
		get_tree().quit()
		return
	await get_tree().create_timer(2.0).timeout
	var c: Vector2 = school.center(sea.schools.now())
	await _face(Vector3(c.x, 2.0, c.y))
	await _shot("hunt_eye")
	await get_tree().create_timer(0.5).timeout
	await _shot("hunt_eye_read")
	print("HUNT the flock is %.0f m off" % c.distance_to(sea.boat.helm.at))
	# the dash from the wheel
	sea.crew.me.force_input = true
	sea.boat.helm.request(true)
	await get_tree().create_timer(0.5).timeout
	sea.schools.call_out(school.id)
	sea.crew.me.set("_pitch", -0.55)
	sea.crew.me.set("_yaw", 0.0)
	await get_tree().create_timer(2.5).timeout
	await _shot("hunt_dash")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


func _face(p: Vector3) -> void:
	var me := sea.crew.me
	var best := 0.0
	var best_dot := -2.0
	for i in 144:
		me.set("_yaw", i * TAU / 144.0)
		await get_tree().process_frame
		var d := _dot(p)
		if d > best_dot:
			best_dot = d
			best = i * TAU / 144.0
	me.set("_yaw", best)
	var bp := 0.0
	best_dot = -2.0
	for i in 41:
		var pitch := -0.2 + i * 0.01
		me.set("_pitch", pitch)
		await get_tree().process_frame
		var d := _dot(p)
		if d > best_dot:
			best_dot = d
			bp = pitch
	me.set("_pitch", bp)
	await get_tree().process_frame


func _dot(p: Vector3) -> float:
	var cam := sea.crew.me.get("cam") as Camera3D
	return (-cam.global_transform.basis.z).normalized().dot((p - cam.global_position).normalized())


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://docs/shots/%s.png" % what
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)
