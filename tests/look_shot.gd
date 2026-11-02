extends Node
## The look of the world, judged as a picky player would (QA): the sportfisher trolling her spread, shot from a set of
## places round her (aboard, alongside, overhead, low astern on her lines, far off), in any light and weather; or,
## with --harbour, tied up at the quay. Stills into --out=<dir> as look_<cond>_<day>_<view>.png.
## Run (needs a window):
##   godot --path . --resolution 1280x720 res://tests/look_shot.tscn -- --out=<dir> [--cond=sunny|fog|storm|rain|calm]
##       [--day=<0..1>] [--harbour] [--views=a,b,...]

const Sea := preload("res://sea/sea.gd")
## Where each view's eye is and what it looks at (her frame, level: +z astern, +x starboard).
const VIEWS := {
	"deck_aft": [Vector3(0.6, 2.2, 3.0), Vector3(0.0, 0.8, 30.0)],
	"deck_up": [Vector3(0.6, 1.9, 4.0), Vector3(4.0, 8.0, 2.0)],
	"alongside": [Vector3(11.0, 2.2, 1.0), Vector3(0.0, 2.5, 0.0)],
	"overhead": [Vector3(4.0, 34.0, 30.0), Vector3(0.0, 0.0, 14.0)],
	"bow_low": [Vector3(-5.0, 2.0, -32.0), Vector3(0.0, 3.0, 0.0)],
	"lines_low": [Vector3(9.0, 1.6, 30.0), Vector3(14.0, 0.0, 52.0)],
	"quarter": [Vector3(7.0, 3.5, 12.0), Vector3(-1.0, 2.0, -2.0)],
	"far": [Vector3(70.0, 9.0, -50.0), Vector3(0.0, 4.0, 0.0)],
}
const HARBOUR := {
	"quay_low": [Vector3(9.0, 2.0, 10.0), Vector3(0.0, 2.0, 0.0)],
	"quay_high": [Vector3(-14.0, 14.0, 22.0), Vector3(0.0, 0.0, 0.0)],
	"quay_deck": [Vector3(0.5, 2.0, 4.5), Vector3(-6.0, 1.0, -10.0)],
}

var sea: Sea
var _cam: Camera3D
var _pose: Array = []
var day := 0.12
var cond := "sunny"
var out := "user://look"
var harbour := false
var only: PackedStringArray = []


func _ready() -> void:
	process_priority = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--day="):
			day = float(a.trim_prefix("--day="))
		elif a.begins_with("--cond="):
			cond = a.trim_prefix("--cond=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--views="):
			only = a.trim_prefix("--views=").split(",")
		harbour = harbour or a == "--harbour"
	DirAccess.make_dir_recursive_absolute(out)
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_look_shot.cfg"
	await get_tree().create_timer(1.0).timeout
	if not harbour:
		sea.fish_hold.head_out("sportfisher")
	else:
		# (sea.gd's moor, which only runs for the game itself: her alongside the float at her berth, lines fast)
		var helm: Node = sea.boat.get("helm")
		helm.set("at", sea.harbour.call("berth", float(sea.boat.get("beam")) * 0.5, float(sea.boat.get("length"))))
		helm.set("heading", 0.0)
		helm.set("speed", 0.0)
		sea.boat.global_transform = sea.boat.call("pose")
		var lines: Node = sea.boat.get("lines")
		if lines != null:
			lines.call("host_make_fast_here")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * day
	sea.set_condition(cond)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	sea.crew.me.force_input = true
	if not harbour:
		var helm: Node = sea.boat.get("helm")
		helm.set("at", Vector2(0.0, -900.0))
		helm.set("heading", 0.0)
		await get_tree().create_timer(0.5).timeout
		helm.call("request", true)
		await get_tree().create_timer(0.5).timeout
		Input.action_press("move_forward", 0.4)        # (trolling speed, her spread out behind her)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 6000.0
	add_child(_cam)
	_cam.current = true
	await get_tree().create_timer(9.0 if not harbour else 3.0).timeout
	var views: Dictionary = HARBOUR if harbour else VIEWS
	for v: String in views:
		if not only.is_empty() and not only.has(v):
			continue
		_pose = views[v]
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(out.path_join("look_%s_%.2f_%s.png" % [cond, day, v]))
	Input.action_release("move_forward")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


func _process(_delta: float) -> void:
	if sea == null or _cam == null:
		return
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.get_parent() != self and (n as CanvasLayer).layer >= 0:
			(n as CanvasLayer).visible = false
	if _pose.is_empty():
		return
	var t := sea.boat.global_transform
	var flat := Transform3D(Basis(Vector3.UP, t.basis.get_euler().y), t.origin)
	var at := flat * (_pose[0] as Vector3)
	at.y = maxf(at.y, float(sea.ocean.height_at(at)) + 1.2)      # (never under a swell)
	_cam.global_position = at
	_cam.look_at(flat * (_pose[1] as Vector3), Vector3.UP)
