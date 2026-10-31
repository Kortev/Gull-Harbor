extends Node
## The strike and the fight's water, seen (docs/shots/strike_*.png): the hit-stop with the white water hanging, the
## burst let go, the line spraying under load, and a beaten fish showing himself close astern (rods/fight_fx.gd).
## Run (needs a window): godot --path . res://tests/strike_shot.tscn

const Sea := preload("res://sea/sea.gd")
const FightBot := preload("res://tests/fight_bot.gd")

var sea: Sea
var cam: Camera3D
var look_at_p := Vector3.ZERO


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await get_tree().create_timer(1.0).timeout
	sea.fish_hold.head_out("sportfisher")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.3
	sea.set_condition("sunny")
	sea.schools.set("_next", 9999.0)
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	sea.crew.me.force_input = true
	sea.rods.host_cast(0, Vector3(1.5, 0.0, 30.0))
	while sea.rods.flying(0):
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	cam = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.current = true
	var rod = sea.rods.rods[0]
	_aim(Vector3(-1.0, 2.4, 13.0), rod.line_end)
	await get_tree().process_frame
	sea.rods.strike(0, 260.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("strike_hit")
	await get_tree().create_timer(0.3).timeout
	await _shot("strike_burst")
	# into the fight: him running, the line hissing through the water, then late and close, him showing himself
	sea.rods.request_grab(0)
	await _play(rod, 2.0, {"energy": 0.8, "depth": 3.0, "run": true})
	_aim(Vector3(-1.0, 2.6, 10.0), rod.line_end)
	await _shot("strike_line")
	var t := 0.0
	while t < 20.0 and sea.rods.fx.showing(0) < 0.42:
		await _play(rod, 0.05, {"out": 14.0, "energy": 0.2, "depth": 2.0, "bearing": 0.35})
		t += 0.05
	if is_instance_valid(rod.fish_node):
		_aim(Vector3(-1.5, 3.0, 8.0), rod.fish_node.global_position)
	await _shot("strike_show")
	if is_instance_valid(rod.fish_node):
		var f := rod.fish_node as Node3D
		cam.global_position = f.global_position + f.global_basis.x * 5.0 + Vector3(0.0, 2.2, 0.0)
		cam.look_at(f.global_position, Vector3.UP)
	await _shot("strike_flank")
	await _play(rod, 0.25, {"out": 14.0, "energy": 0.2, "depth": 2.0, "bearing": 0.35})
	await _shot("strike_thrash")
	Input.action_release("use_primary")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


## A camera in her frame at `from` (boat-local), looking at `to` (world).
func _aim(from: Vector3, to: Vector3) -> void:
	var b := sea.boat as Node3D
	cam.global_position = b.global_transform * from
	cam.look_at(to, Vector3.UP)


func _play(rod: Node, s: float, hold: Dictionary) -> void:
	var mem := {}
	var t := 0.0
	while t < s and rod.hooked:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var f: RefCounted = rod.fight
		if f == null:
			continue
		f.set("grace", 999.0)
		if hold.has("run"):
			if f.get("move") != "run":
				f.call("carry_on", "run", float(f.get("stretch")), 0.0, 1.0)
		elif f.get("move") in ["run", "surge", "jump", "charge", "spiral"]:
			f.call("carry_on", "dog", float(f.get("stretch")), 0.0, 1.0)
		for k: String in ["bearing", "depth", "energy"]:
			if hold.has(k):
				f.set(k, float(hold[k]))
		if hold.has("out"):
			f.set("line_out", float(hold["out"]))
		var act := FightBot.act(f.call("cues"), dt, "good", mem)
		if float(act["crank"]) > 0.5:
			Input.action_press("use_primary")
		else:
			Input.action_release("use_primary")


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://docs/shots/%s.png" % what
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)
