extends Node
## The sea and her wake, seen (QA): shots and short frame runs into --out=<dir>.
##   --mode=wake   flat out, a camera riding over her stern looking aft: a still, then a run of frames at 30 fps
##   --mode=still  a still eye at her deck's height beside her, fixed in the world: the water heaving round it, frames
##   --mode=swim   the same at a swimmer's eye, just over the water
##   --mode=aboard stopped, an eye on her deck riding her (as yours does) looking over her rail at the water beside her
##   --mode=beside stopped, a still eye fixed in the world off her quarter, looking at her and the water round her
## --carry=0 pins her where the helm has her (no carrying on the water's orbits, boat/boat.gd's carry: the before).
## --cond=sunny|storm|... the weather (pinned). --frames=N, --every=<s> between frames.
## Run (needs a window):
##   godot --path . --resolution 1280x720 --fixed-fps 30 res://tests/wake_shot.tscn -- --mode=wake --out=<dir>

const Sea := preload("res://sea/sea.gd")

var sea: Sea
var out := "res://docs/shots/wake/"
var mode := "wake"
var cond := "sunny"
var frames := 10
var every := 0.0
var carry := 1.0
var _cam: Camera3D
var _rig := Vector3.ZERO
var _look := Vector3.ZERO
var _wall := 0.0
var _still: Camera3D


func _ready() -> void:
	process_priority = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	# (other windows on this machine: kept on top, and the mouse kept, or the pause card comes up over the sea)
	get_window().always_on_top = true
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"mode": mode = kv[1]
			"cond": cond = kv[1]
			"frames": frames = int(kv[1])
			"every": every = float(kv[1])
			"carry": carry = float(kv[1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_wake_shot.cfg"
	await get_tree().create_timer(1.0).timeout
	sea.fish_hold.head_out("sportfisher")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.3
	sea.set_condition(cond)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	sea.boat.set("carry", carry)
	var helm: Node = sea.boat.get("helm")
	var me := sea.crew.me
	me.force_input = true
	# (out in open water, clear of the harbour and the shore)
	helm.set("at", Vector2(0.0, -900.0))
	helm.set("heading", 0.0)
	await get_tree().create_timer(0.5).timeout
	if mode == "wake":
		helm.call("request", true)
		await get_tree().create_timer(0.5).timeout
		Input.action_press("move_forward")
		_cam = Camera3D.new()
		_cam.fov = 70.0
		add_child(_cam)
		_cam.current = true
		_rig = Vector3(4.0, 9.0, 0.0)
		_look = Vector3(0.0, 0.0, 28.0)
		await get_tree().create_timer(9.0).timeout
		print("WAKE speed %.1f m/s" % float(helm.get("speed")))
		await _shot("wake_still")
		await _run("wake_f")
		_rig = Vector3(9.0, 4.0, -2.0)
		_look = Vector3(0.0, 0.0, 16.0)
		await get_tree().create_timer(0.3).timeout
		await _run("wake_side_f")
		Input.action_release("move_forward")
	elif mode == "aboard":
		# an eye standing in her cockpit, riding her, looking out over her starboard rail and down at the water
		await get_tree().create_timer(4.0).timeout
		_still = Camera3D.new()
		_still.fov = 70.0
		sea.boat.add_child(_still)
		var d := float(sea.boat.get("deck"))
		# (at her starboard quarter, leaning out over her rail: her topsides and the water along them, forward)
		var eye := Vector3(1.9, d + 1.9, 5.2)
		_still.transform = Transform3D(Basis.looking_at(Vector3(4.2, -0.6, -2.0) - eye, Vector3.UP), eye)
		_still.current = true
		await get_tree().create_timer(1.0).timeout
		await _shot("%s_%s" % [mode, cond])
		await _run("%s_%s_f" % [mode, cond])
	elif mode == "beside":
		await get_tree().create_timer(4.0).timeout
		_still = Camera3D.new()
		_still.fov = 60.0
		add_child(_still)
		_still.current = true
		var b: Vector3 = sea.boat.global_position
		_still.global_position = Vector3(b.x + 13.0, 4.0, b.z + 9.0)
		_still.look_at(Vector3(b.x, 0.3, b.z + 1.0), Vector3.UP)
		await get_tree().create_timer(1.0).timeout
		await _shot("%s_%s" % [mode, cond])
		await _run("%s_%s_f" % [mode, cond])
	else:
		# a still eye beside her, fixed in the world (not riding her): from her deck's height ("still") or a swimmer's
		# ("swim", just over the water): the water heaving round it, frame by frame
		await get_tree().create_timer(4.0).timeout
		_still = Camera3D.new()
		_still.fov = 70.0
		add_child(_still)
		_still.current = true
		var at := sea.boat.global_position + Vector3(12.0, 0.0, 0.0)
		var y := 3.2 if mode == "still" else 0.9
		_still.global_position = Vector3(at.x, y, at.z)
		_still.look_at(Vector3(at.x + 40.0, y - (6.0 if mode == "still" else 1.5), at.z - 10.0), Vector3.UP)
		await get_tree().create_timer(1.0).timeout
		await _shot("%s_%s" % [mode, cond])
		await _run("%s_%s_f" % [mode, cond])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


func _process(delta: float) -> void:
	# (the sea's clock is the wall clock: saving a shot every frame holds the frame up, so hold the sea's clock back
	# by as much, and the waves go at the game's pace, frame for frame)
	var wall := Time.get_ticks_msec() / 1000.0
	if _wall > 0.0 and sea != null:
		sea.ocean.clock_offset -= (wall - _wall) - delta
	_wall = wall
	if sea != null and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _cam != null and sea != null:
		var t := sea.boat.global_transform
		var flat := Transform3D(Basis(Vector3.UP, t.basis.get_euler().y), t.origin)
		_cam.global_position = flat * _rig
		_cam.look_at(flat * _look, Vector3.UP)


func _run(what: String) -> void:
	for i in frames:
		if every > 0.0:
			await get_tree().create_timer(every).timeout
		else:
			await get_tree().process_frame
		await _shot("%s%02d" % [what, i])


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out.path_join(what + ".png")
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)
