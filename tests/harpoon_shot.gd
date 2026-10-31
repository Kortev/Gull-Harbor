extends Node
## Screenshots of the harpoon and the fish alongside (to <dir>/harpoon_*.png, the first user arg, else docs/shots):
## the fish circling beside her, the harpoon in your hands, wound up with its aim's dots, in the air, stuck, a miss's
## splash, and a hooked fish swimming in the fight seen from the side. Run (needs a window):
## godot --path . res://tests/harpoon_shot.tscn -- <dir>

const Sea := preload("res://sea/sea.gd")

var sea: Sea
var _dir := "res://docs/shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_dir = args[0]
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await get_tree().create_timer(1.0).timeout
	sea.schools.set("_next", 9999.0)
	sea.fish_hold.head_out("skiff")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.4            # (midday, for the light)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for r in sea.rods.rods:
		sea.rods.host_cast(r.index)
	await get_tree().create_timer(2.0).timeout
	var me := sea.crew.me
	me.force_input = true
	var landing := sea.landing
	landing.escape_odds = [0.0]
	# a fish up alongside, held on its leader
	sea.rods.strike(0, 180.0)
	await get_tree().create_timer(0.2).timeout
	var rod = sea.rods.rods[0]
	landing.host_alongside(0, 180.0, float(rod.bearing), float(rod.hook_t))
	landing.fish[0]["wired_until"] = landing._now() + 9999.0
	await get_tree().create_timer(4.0).timeout
	var side := float(landing.fish[0]["side"])
	me.call("place", Vector3(0.9 * side, 0.6, 1.6), 0.0)
	await _face(landing.fish_point(0), -0.15)
	await _grab("harpoon_alongside")
	# from off her quarter, looking back at it circling
	var cam := Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	for k in 3:
		var at := landing.fish_point(0)
		cam.global_position = at + sea.boat.global_basis * Vector3(3.0 * side, 4.5, 3.0)
		cam.look_at(at, Vector3.UP)
		cam.make_current()
		await _grab("harpoon_circling_%d" % k)
		await get_tree().create_timer(1.3).timeout
	me.cam.make_current()
	landing._request_harpoon(true)
	await get_tree().create_timer(0.5).timeout
	await _face(landing.fish_point(0), -0.1)
	await _grab("harpoon_held")
	Input.action_press("use_primary")
	var e := InputEventAction.new()
	e.action = "use_primary"
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().create_timer(0.9).timeout
	await _grab("harpoon_wound")
	e = InputEventAction.new()
	e.action = "use_primary"
	e.pressed = false
	Input.action_release("use_primary")
	Input.parse_input_event(e)
	for k in 4:
		await get_tree().process_frame
	await _grab("harpoon_flying")
	await get_tree().create_timer(0.25).timeout
	await _grab("harpoon_landed")
	await get_tree().create_timer(0.6).timeout
	await _grab("harpoon_coming_home")
	await get_tree().create_timer(2.0).timeout
	# stuck: thrown straight onto it
	landing._request_harpoon(true)
	await get_tree().create_timer(0.3).timeout
	landing._ask_throw_as(1, 0, Vector3.ZERO, Vector3.FORWARD)
	await get_tree().create_timer(0.8).timeout
	await _face(landing.fish_point(0), -0.15)
	await _grab("harpoon_stuck")
	landing.host_clear()
	# a hooked fish in the fight, from the side
	sea.rods.strike(1, 220.0)
	await get_tree().create_timer(1.0).timeout
	var r1 = sea.rods.rods[1]
	for k in 4:
		var f := r1.fish_node as Node3D
		if f != null:
			f.visible = true
			cam.global_position = f.global_position + Vector3(3.5, 1.0, 3.5)
			cam.look_at(f.global_position, Vector3.UP)
			cam.make_current()
			await _grab("fight_fish_%d" % k)
		await get_tree().create_timer(1.5).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


## Turns you to look at `p` (yaw from her frame), and down by `pitch`.
func _face(p: Vector3, pitch: float) -> void:
	var me := sea.crew.me
	var best := 0.0
	var best_dot := -2.0
	for i in 72:
		me.set("_yaw", i * TAU / 72.0)
		await get_tree().process_frame
		var cam := me.get("cam") as Node3D
		var d := -cam.global_basis.z
		var to := p - cam.global_position
		var dot := Vector2(d.x, d.z).normalized().dot(Vector2(to.x, to.z).normalized())
		if dot > best_dot:
			best_dot = dot
			best = i * TAU / 72.0
	me.set("_yaw", best)
	var cam := me.get("cam") as Node3D
	var to := p - cam.global_position
	me.set("_pitch", atan2(to.y, Vector2(to.x, to.z).length()) + pitch * 0.0)
	await get_tree().process_frame


func _grab(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_dir, what]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path) if path.begins_with("res:") else path)
	print("SHOT ", path)
