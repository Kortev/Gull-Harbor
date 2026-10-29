extends Node3D
## The tuna lab (F6): three bluefin, 30, 150 and 400 kg, swimming laps in a grey test space, so you can see the
## model, the sizes and the swimming. Minus: the dev panel (spawn one of each size, speed them up, sprint).
## Screenshot: <godot> --path . res://tuna/tuna_lab.tscn -- --shot=<png> [--frames=<n>] [--side | --still]

const Tuna := preload("res://tuna/tuna.gd")
const SCREEN_LOOK := preload("res://screen/screen_look.tscn")

var fish: Array[Tuna] = []
var cam: Camera3D
var _t := 0.0
var _frames := 0
var _args := {}
var _sprint := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.14, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.55, 0.62)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.16, 0.2)
	env.fog_density = 0.02
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 20, 0)
	sun.light_energy = 1.4
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	add_child(SCREEN_LOOK.instantiate())
	for i in 3:
		var kg: float = [30.0, 150.0, 400.0][i]
		var t := Tuna.new(kg)
		add_child(t)
		t.position = Vector3(-4.0 + i * 4.0, 0.0, 0.0)
		fish.append(t)
		print("tuna %.0f kg: %.2f m" % [kg, t.length])


func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	_sprint = maxf(_sprint - delta, 0.0)
	for i in fish.size():
		var t := fish[i]
		if _args.has("still"):
			# broadside, swimming in place: the model and the tail beat
			t.velocity = Vector3.ZERO
			t._heading = Vector3.RIGHT
			t.effort = 0.5
			t.position = Vector3(-0.6, 1.9 - i * 1.9, 0.0) * Vector3(1, 1, 1)
			continue
		# laps round its own lane, a little up and down
		var c := Vector3(-4.0 + i * 4.0, 0.0, 0.0)
		var a := _t * 0.35 + i
		var target := c + Vector3(sin(a) * 1.5, sin(a * 0.7) * 0.4, cos(a) * 3.0)
		t.steer(target - t.position, (2.0 if _sprint <= 0.0 else 7.0) + i * 0.2, delta)
	if _args.has("still"):
		cam.position = Vector3(0, 0, 8.5)
		cam.look_at(Vector3(0, 0, 0))
	elif _args.has("side"):
		cam.position = Vector3(0, 0.3, 11)
		cam.look_at(Vector3(0, 0, 0))
	else:
		cam.position = Vector3(sin(_t * 0.1) * 12.0, 3.0, cos(_t * 0.1) * 12.0)
		cam.look_at(Vector3(0, 0, 0))
	if _args.has("shot") and _frames == int(_args.get("frames", "90")):
		get_viewport().get_texture().get_image().save_png(str(_args["shot"]))
		print("SHOT ", _args["shot"])
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_panel"):
		_sprint = 3.0      # (the full dev panel comes with hooking up: for now Minus makes them sprint)
