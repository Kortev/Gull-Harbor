extends Node
## A short clip to show the game off: the sportfisher running through the swells, three shots and the
## name. Vertical, for a phone. Recorded frame by frame by Godot's movie maker, then put together by tools/promo.sh.
## Run (needs a window):
##   (the movie maker keeps the project's window: tools/promo.sh sets it tall with an override.cfg for the run)
##   godot --path . --fixed-fps 30 --write-movie <dir>/f.png res://tests/promo_shot.tscn

const Sea := preload("res://sea/sea.gd")
## The clip's length (s) and where each shot starts.
const LENGTH := 14.0
const CUTS: Array[float] = [0.0, 5.0, 9.5]

var sea: Sea
var _cam: Camera3D
var _t := -1.0
var _wall := 0.0
var _fixed := Vector3.ZERO
## --day=<0..1>: the time of day; --peek: a still of each shot at that time, no clip (for picking the light).
var day := 0.12
var peek := false
## --cond=<sunny|calm|fog|rain|heavy|storm>: the weather (pinned).
var cond := "sunny"


func _ready() -> void:
	process_priority = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().always_on_top = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--day="):
			day = float(a.trim_prefix("--day="))
		if a.begins_with("--cond="):
			cond = a.trim_prefix("--cond=")
		peek = peek or a == "--peek"
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_promo_shot.cfg"
	await get_tree().create_timer(1.0).timeout
	sea.fish_hold.head_out("sportfisher")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * day          # (mid-morning: the sun up, the sea blue)
	sea.set_condition(cond)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var helm: Node = sea.boat.get("helm")
	sea.crew.me.force_input = true
	helm.set("at", Vector2(0.0, -900.0))
	helm.set("heading", 0.0)
	await get_tree().create_timer(0.5).timeout
	helm.call("request", true)
	await get_tree().create_timer(0.5).timeout
	Input.action_press("move_forward")
	_cam = Camera3D.new()
	_cam.fov = 62.0
	add_child(_cam)
	_cam.current = true
	await get_tree().create_timer(8.0).timeout                 # (up to speed, her wake laid out behind her)
	_t = 0.0
	if peek:
		for k in [2.0, 7.0, 12.0]:
			_t = k
			await get_tree().create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir().path_join("peek_%s_%.2f_%d.png" % [cond, day, int(k)]))
		get_tree().quit()
		return
	await get_tree().create_timer(LENGTH).timeout
	Input.action_release("move_forward")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


func _process(delta: float) -> void:
	# (the sea's clock is the wall clock; the movie maker's frames aren't: held to the game's pace, frame for frame)
	var wall := Time.get_ticks_msec() / 1000.0
	if _wall > 0.0 and sea != null:
		sea.ocean.clock_offset -= (wall - _wall) - delta
	_wall = wall
	if sea == null:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hide_hud()
	if _cam == null:
		return
	var t := sea.boat.global_transform
	var yaw := t.basis.get_euler().y
	var flat := Transform3D(Basis(Vector3.UP, yaw), t.origin)
	var k := maxf(_t, 0.0)
	if _t >= 0.0:
		_t += delta
	if k < CUTS[1]:
		# low on the water ahead of her and off her bow, still in the world: she comes on through the swells and past
		if _fixed == Vector3.ZERO or _t < delta * 1.5:
			_fixed = flat * Vector3(-11.0, 0.0, -52.0)
		var h := float(sea.ocean.height_at(_fixed))
		_cam.global_position = Vector3(_fixed.x, h + 2.6, _fixed.z)
		_cam.look_at(t.origin + Vector3(0.0, 2.0, 0.0), Vector3.UP)
	elif k < CUTS[2]:
		# off her quarter and a little above, drifting aft: the wake laid out behind her, the low sun beyond
		var u := (k - CUTS[1]) / (CUTS[2] - CUTS[1])
		_cam.global_position = flat * Vector3(6.5 - u * 1.5, 3.2 + u * 0.8, 9.0 + u * 5.0)
		_cam.look_at(flat * Vector3(-1.0, 1.4, -4.0), Vector3.UP)
	else:
		# up and back, high over her: small in a big sea (the name laid over after: tools/promo_title.py)
		var u := clampf((k - CUTS[2]) / (LENGTH - CUTS[2]), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - u, 2.0)
		_cam.global_position = flat * Vector3(10.0 + e * 14.0, 6.0 + e * 30.0, 18.0 + e * 34.0)
		_cam.look_at(flat * Vector3(0.0, 0.0, -10.0 - e * 20.0), Vector3.UP)


## Everything the game draws over the sea (HUD, notes, tips) kept out of the shot.
func _hide_hud() -> void:
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.get_parent() != self and (n as CanvasLayer).layer >= 0:     # (the screen's look, on -1, kept)
			(n as CanvasLayer).visible = false
