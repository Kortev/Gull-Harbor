extends Node
## Screenshots (to <dir>/rail_*.png, the first user arg, else docs/shots), Rivals, two skiffs: up on B's rail with the
## harpoon, looking down at a fish alongside, wound up with the aim's arc on it; then A lying 2 m off and a leap
## across, mid-air, from your eyes and from off her bow. Run (needs a window):
## godot --path . res://tests/rail_shot.tscn -- <dir>

const Sea := preload("res://sea/sea.gd")
const Player := preload("res://crew/player.gd")

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
	sea.set_condition("sunny")
	sea.vs.host_set_on(true)
	await get_tree().process_frame
	sea.vs.ask_team(1)
	await get_tree().process_frame
	sea.fish_hold.head_out("skiff")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.4            # (midday, for the light)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var a_boat := sea.vs.sides[0].get("boat") as Node3D
	var b_boat := sea.vs.sides[1].get("boat") as Node3D
	var at := Vector2(300.0, -600.0)
	for b: Node3D in [a_boat, b_boat]:
		var h: Node = b.get("helm")
		h.set("speed", 0.0)
		h.set("drift", Vector2.ZERO)
		h.set("heading", 0.0)
	(b_boat.get("helm") as Node).set("at", at)
	(a_boat.get("helm") as Node).set("at", at + Vector2(-40.0, 0.0))     # (out of the way for now)
	for r in sea.rods.rods:
		sea.rods.host_cast(r.index)
	await get_tree().create_timer(1.5).timeout
	var me := sea.crew.me
	me.force_input = true
	var landing := sea.landing
	landing.escape_odds = [0.0]
	sea.rods.strike(0, 180.0)
	await get_tree().create_timer(0.2).timeout
	var rod = sea.rods.rods[0]
	landing.host_alongside(0, 180.0, float(rod.bearing), float(rod.hook_t))
	landing.fish[0]["wired_until"] = landing._now() + 9999.0
	await get_tree().create_timer(4.0).timeout
	var side := float(landing.fish[0]["side"])
	var z := float((b_boat.spec["fish_water"] as Vector3).z)
	me.place(Vector3((float(b_boat.beam) * 0.5 - 0.6) * side, float(b_boat.deck) + 0.02, z), -PI * 0.5 * side, b_boat)
	await get_tree().create_timer(0.4).timeout
	await _tap("jump")
	await get_tree().create_timer(0.8).timeout
	landing._request_harpoon(true)
	await get_tree().create_timer(0.4).timeout
	Input.action_press("use_secondary")
	await _look_at(landing.fish_point(0), 20)
	var e := InputEventAction.new()
	e.action = "use_primary"
	e.pressed = true
	Input.parse_input_event(e)
	Input.action_press("use_primary")
	for k in 25:
		await _look_at(landing.fish_point(0), 1)
	await _grab("rail_aim")
	Input.action_release("use_primary")
	Input.action_release("use_secondary")
	landing.call("_set_harpoon", 0)
	landing.set("_drawing", false)
	landing.host_clear()
	await get_tree().create_timer(0.5).timeout
	# A 2 m off B's starboard side: up on the rail, a leap across
	(a_boat.get("helm") as Node).set("at", at + Vector2(float(b_boat.beam) + 2.0, 0.0))
	await get_tree().create_timer(0.5).timeout
	me.place(Vector3(float(b_boat.beam) * 0.5 - 0.6, float(b_boat.deck) + 0.02, 1.5), -PI * 0.5, b_boat)
	me.set("_pitch", -0.15)
	await get_tree().create_timer(0.4).timeout
	await _tap("jump")
	await get_tree().create_timer(0.7).timeout
	await _grab("rail_before_leap")
	await _tap("jump")
	for k in 5:
		await get_tree().process_frame
	await _grab("rail_mid_leap")
	# again, from off their bows
	await get_tree().create_timer(2.0).timeout
	me.place(Vector3(float(b_boat.beam) * 0.5 - 0.6, float(b_boat.deck) + 0.02, 1.5), -PI * 0.5, b_boat)
	await get_tree().create_timer(0.4).timeout
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	var mid := (a_boat.global_position + b_boat.global_position) * 0.5
	cam.global_position = mid + Vector3(0.0, 3.5, -9.0)
	cam.look_at(mid + Vector3(0.0, 1.5, 1.5), Vector3.UP)
	cam.make_current()
	await _tap("jump")
	await get_tree().create_timer(0.7).timeout
	await _tap("jump")
	for k in 9:
		await get_tree().process_frame
	await _grab("rail_mid_leap_side")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


## Turns you till the middle of your view is on `at`.
func _look_at(at: Vector3, frames := 6) -> void:
	var me := sea.crew.me
	for k in frames:
		await get_tree().process_frame
		var cam := me.get("cam") as Camera3D
		var d := -cam.global_basis.z
		var to := (at - cam.global_position).normalized()
		me.set("_yaw", float(me.get("_yaw")) - Vector2(d.x, d.z).angle_to(Vector2(to.x, to.z)))
		me.set("_pitch", clampf(float(me.get("_pitch")) + asin(to.y) - asin(d.y), -1.45, 1.45))


func _grab(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_dir, what]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path) if path.begins_with("res:") else path)
	print("SHOT ", path)
