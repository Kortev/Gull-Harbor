extends Node
## Where the sea meets her hull (QA): close stills of her waterline from round her, riding her, to judge whether the
## water hugs her topsides as water would (no dent pressed into it beside her, no water in her cockpit, nothing
## poking through her transom). Stills into --out=<dir> as wl_<kind>_<cond>_<speed>_<view>_<n>.png.
##   --kind=sportfisher|skiff  --cond=sunny|heavy|storm|...  --speed=0..1 (the throttle; 0 stopped)
##   --views=a,b,...  --takes=N (stills per view, a second and a half apart)
##   --as-other  her water drawn as the other boat's in Rivals is (ocean.gd's set_other_hull), not as yours
## Run (needs a window):
##   godot --path . --resolution 1280x720 res://tests/waterline_shot.tscn -- --out=<dir> --cond=heavy --speed=0.6

const Sea := preload("res://sea/sea.gd")
## Each view's eye and what it looks at, in her frame (level, turned with her: +z astern, +x starboard), or "deck"
## for an eye riding her (her own frame, pitch and roll and all).
const VIEWS := {
	"quarter": [Vector3(6.5, 3.0, 11.0), Vector3(1.2, 0.4, 0.0), false],
	"side_low": [Vector3(7.0, 0.9, 1.5), Vector3(0.0, 0.5, -1.0), false],
	"overhead": [Vector3(3.5, 15.0, 7.0), Vector3(0.0, 0.0, 0.5), false],
	"transom": [Vector3(3.0, 2.2, 15.0), Vector3(0.0, 0.5, 5.0), false],
	"bow": [Vector3(6.0, 2.0, -13.0), Vector3(0.0, 0.6, -4.0), false],
	"cockpit": [Vector3(0.0, 7.0, 12.0), Vector3(0.0, 0.5, 3.0), false],
	"rail": [Vector3(1.9, 2.45, 4.6), Vector3(4.2, -0.6, -2.0), true],
}

var sea: Sea
var out := "user://waterline"
var kind := "sportfisher"
var cond := "sunny"
var speed := 0.0
var takes := 2
var only: PackedStringArray = []
var _cam: Camera3D
var _pose: Array = []
var _wall := 0.0
var as_other := false
## (--green: a sea comes over her rail every few seconds, and the skiff half full: the water on her deck)
var green := false
var _green_t := 0.0


func _ready() -> void:
	process_priority = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().always_on_top = true
	for a in OS.get_cmdline_user_args():
		as_other = as_other or a == "--as-other"
		green = green or a == "--green"
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"kind": kind = kv[1]
			"cond": cond = kv[1]
			"speed": speed = float(kv[1])
			"takes": takes = int(kv[1])
			"views": only = kv[1].split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_waterline_shot.cfg"
	await get_tree().create_timer(1.0).timeout
	sea.fish_hold.head_out(kind)
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.2
	sea.set_condition(cond)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	sea.crew.me.force_input = true
	var helm: Node = sea.boat.get("helm")
	helm.set("at", Vector2(0.0, -900.0))
	helm.set("heading", 0.0)
	await get_tree().create_timer(0.5).timeout
	if speed > 0.0:
		helm.call("request", true)
		await get_tree().create_timer(0.5).timeout
		Input.action_press("move_forward", speed)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 6000.0
	add_child(_cam)
	_cam.current = true
	await get_tree().create_timer(8.0).timeout
	print("WATERLINE %s %s speed %.1f m/s" % [kind, cond, float(helm.get("speed"))])
	for v: String in VIEWS:
		if not only.is_empty() and not only.has(v):
			continue
		_pose = VIEWS[v]
		for n in takes:
			await get_tree().create_timer(0.4 if n == 0 else 1.5).timeout
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path(out).path_join(
					"wl_%s_%s_%.1f_%s_%d.png" % [kind, cond, speed, v, n]))
	Input.action_release("move_forward")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


func _process(delta: float) -> void:
	# (saving a still holds the frame up: the sea's clock held back by as much, so the waves go at the game's pace)
	var wall := Time.get_ticks_msec() / 1000.0
	if _wall > 0.0 and sea != null:
		sea.ocean.clock_offset -= (wall - _wall) - delta
	_wall = wall
	if sea == null or _cam == null:
		return
	if as_other:
		_as_other.call_deferred()
	if green and _pose.size() > 0:
		_green_t -= delta
		var g: Node = sea.boat.get("green")
		if _green_t <= 0.0:
			_green_t = 3.0
			g.call("_aboard", (sea.boat.get("spec")["rail"] as Array)[1], 0.4)
		if kind == "skiff":
			g.set("water", maxf(float(g.get("water")), 0.5))
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.get_parent() != self and (n as CanvasLayer).layer >= 0:
			(n as CanvasLayer).visible = false
	if _pose.is_empty():
		return
	var t := sea.boat.global_transform
	if _pose[2]:
		var d := float(sea.boat.get("deck"))
		var eye: Vector3 = _pose[0] + Vector3(0.0, d - 0.55, 0.0)
		if kind == "skiff":
			eye = Vector3(1.0, d + 1.7, 3.0)
		_cam.global_transform = t * Transform3D(Basis.looking_at((_pose[1] as Vector3) - eye, Vector3.UP), eye)
		return
	var flat := Transform3D(Basis(Vector3.UP, t.basis.get_euler().y), t.origin)
	var s := 1.0 if kind == "sportfisher" else 0.65
	var at := flat * ((_pose[0] as Vector3) * Vector3(s, 1.0, s))
	at.y = maxf(at.y, float(sea.ocean.height_at(at)) + 0.6)
	_cam.global_position = at
	_cam.look_at(flat * ((_pose[1] as Vector3) * Vector3(s, 1.0, s)), Vector3.UP)


## (after her own frame's set_hull: hers off, the other boat's on where she is)
func _as_other() -> void:
	var b: Node3D = sea.boat
	var mat := (sea.ocean.get_node("Sea") as MeshInstance3D).material_override as ShaderMaterial
	mat.set_shader_parameter("hull_on", false)
	sea.ocean.call("set_other_hull", b.global_transform, float(b.get("length")), float(b.get("beam")), true,
			float(b.get("deck")), float(b.get("helm").get("speed")), b.get("floating").get("sheer"))
