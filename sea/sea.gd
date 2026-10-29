extends Node3D
## The whole world: open ocean to the horizon, the weather over it, and the boat parked at the
## origin riding the swell. The ocean, its weather effects, the rain on your eyes and the sky come
## from Fathom in the space fishing game (ocean.gd, sea_fx.gd, visor_rain.gd, sky.gdshader).
##
## The weather comes and goes on its own (sea/weather.gd): sunny, calm, fog, rain, heavy, storm. Nobody picks it.
## Screenshots: <godot> --path . -- --shot=<png> [--weather=calm|sunny|fog|rain|heavy|storm (pinned)] [--night]
##   [--frames=<n>] [--cam=x,y,z,lookx,looky,lookz] [--look=<degrees round from aft>]
## Without --cam you're one of the crew, standing in the cockpit: WASD, mouse, Shift, Space, E; Esc for the menu.
## Co-op: --host, or --join=<address> (or from the Esc menu).

const Ocean := preload("res://sea/ocean.gd")
const SeaFx := preload("res://sea/sea_fx.gd")
const VisorRain := preload("res://sea/visor_rain.gd")
const SKY_SHADER := preload("res://sea/sky.gdshader")
const NOISE := preload("res://sea/textures/sky_noise.png")
const SCREEN_LOOK := preload("res://screen/screen_look.tscn")
const Boat := preload("res://boat/boat.gd")
const Crew := preload("res://crew/crew.gd")
const Menu := preload("res://ui/menu.gd")
const Rods := preload("res://rods/rods.gd")
const Schools := preload("res://tuna/schools.gd")
const Sonar := preload("res://tuna/sonar.gd")
const Weather := preload("res://sea/weather.gd")

## How rough the sea is (ocean.gd: 0 calm, 0.5 rain, 1 storm), the sun, and how thick the fog.
const CONDITIONS := {
	"calm": {"sea": 0.12, "rain": 0.0, "sun": 0.55, "fog": 0.002, "sky": [Color(0.36, 0.42, 0.5), Color(0.62, 0.66, 0.7)]},
	"sunny": {"sea": 0.25, "rain": 0.0, "sun": 1.3, "fog": 0.0012, "sky": [Color(0.22, 0.38, 0.6), Color(0.66, 0.74, 0.8)]},
	"fog": {"sea": 0.08, "rain": 0.0, "sun": 0.15, "fog": 0.045, "sky": [Color(0.42, 0.45, 0.47), Color(0.5, 0.53, 0.55)]},
	"rain": {"sea": 0.5, "rain": 0.6, "sun": 0.3, "fog": 0.0065, "sky": [Color(0.24, 0.27, 0.3), Color(0.42, 0.45, 0.48)]},
	"heavy": {"sea": 0.75, "rain": 0.85, "sun": 0.2, "fog": 0.01, "sky": [Color(0.18, 0.2, 0.23), Color(0.33, 0.36, 0.39)]},
	"storm": {"sea": 1.0, "rain": 1.0, "sun": 0.12, "fog": 0.0, "sky": [Color(0.13, 0.15, 0.17), Color(0.25, 0.28, 0.3)]},
}
const WIND := Vector2(-0.8, -0.6)

## The weather's kind right now (the nearer of the two it's between), and its blend [from, to, 0..1].
var condition := "rain"
var weather := Weather.new()
var _mix: Array = ["", "", -1.0]
var night := false
var ocean: Ocean
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var sea_fx: SeaFx
var visor: VisorRain
var rain: GPUParticles3D
var cam: Camera3D
var boat: Boat
var crew: Crew
var rods: Rods
var schools: Schools
var _args := {}
var _frames := 0
var _reported := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_build_world()
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 6000.0
	add_child(cam)
	cam.make_current()
	add_child(SCREEN_LOOK.instantiate())
	crew = Crew.new()
	crew.name = "Crew"
	crew.sea = self
	add_child(crew)
	rods = Rods.new()
	rods.name = "Rods"
	rods.sea = self
	add_child(rods)
	schools = Schools.new()
	schools.name = "Schools"
	schools.sea = self
	add_child(schools)
	var sonar := Sonar.new()
	sonar.name = "Sonar"
	sonar.schools = schools
	add_child(sonar)
	sonar.attach(boat)
	var look := deg_to_rad(float(_args.get("look", "0")))
	if look != 0.0:
		crew.me_changed.connect(func(me: Node) -> void:
			me.call("place", me.call("local_position"), float(me.get("_yaw")) + look))
	if not _args.has("cam"):
		crew.start_solo()
	night = _args.has("night")
	weather.seed = randi() % 1000000
	if _args.has("weather"):
		set_condition(str(_args["weather"]))
	else:
		_follow_weather()
	add_child(Menu.new())
	if _args.has("school"):    # (screenshots and tests: a school starts right away, <n> m off and closing)
		schools.set("_next", 0.0)
		if not str(_args["school"]).is_empty():
			schools.start_far = float(_args["school"])
	if _args.has("strike"):    # (screenshots: a fish on rod <n> right away)
		rods.strike(int(_args["strike"]), 220.0)
	if _args.has("hold"):      # (screenshots: start with rod <n> in your hands)
		rods.request_grab(int(_args["hold"]))
	if _args.has("host"):
		Net.host()
	elif _args.has("join"):
		Net.join(str(_args["join"]))
	for n in str(_args.get("hide", "")).split(",", false):   # (dev: --hide=Rain,SeaFx,... to find what's what)
		for found in find_children(n, "", true, false):
			if found is Node3D:
				(found as Node3D).visible = false
			elif found is CanvasLayer:
				(found as CanvasLayer).visible = false


func _process(_delta: float) -> void:
	_frames += 1
	_follow_weather()
	if _args.has("watch") and not schools.schools.is_empty():
		# (screenshots: from 28 m off the nearest school, on the boat's side of it, looking at it)
		var c: Vector2 = schools.schools[0].center(ocean.wave_time)
		var at := Vector3(c.x, 0.0, c.y)
		var from := at + (Vector3.ZERO - at).normalized() * 28.0 + Vector3(0, 5.0, 0)
		cam.make_current()
		cam.global_position = from
		cam.look_at(at + Vector3(0, 2.0, 0))
	elif _args.has("cam"):
		var v := str(_args["cam"]).split_floats(",")
		var at := Vector3(v[0], v[1], v[2])
		at.y += ocean.height_at(Vector3(at.x, 0.0, at.z))
		cam.global_position = at
		cam.look_at(Vector3(v[3], v[4], v[5]))
	if _args.has("net-report") and Time.get_ticks_msec() > int(float(_args["net-report"]) * 1000.0) \
			and not _reported:
		_reported = true
		# (tests/net_test.sh: who's aboard, and the sea clock, then quit)
		var ids: Array = crew.slots.keys()
		ids.sort()
		print("NET fps=%d me=%d host=%s crew=%s clock=%.2f cond=%s mix=%s skew=%.3f" % [Engine.get_frames_per_second(), Net.my_id(), Net.is_host(), ids,
				ocean.wave_time, condition, "%s>%s@%.2f" % _mix,
				Time.get_ticks_msec() / 1000.0 + ocean.clock_offset - Time.get_unix_time_from_system()])
		for id: int in ids:
			var p := crew.get_player(id)
			print("  crew %d at %s (on deck %s) visible=%s layers=%d" % [id, p.global_position, p.local_position(),
					p.body_mesh.is_visible_in_tree(), p.body_mesh.layers])
		get_tree().create_timer(3.0).timeout.connect(get_tree().quit)
	if _args.has("shot") and _frames == int(_args.get("frames", "120")):
		var img := get_viewport().get_texture().get_image()
		img.save_png(str(_args["shot"]))
		print("SHOT ", _args["shot"])
		get_tree().quit()


## The weather now: a mix of two kinds ("rain" turning into "heavy", 0.3 of the way), every number blended.
func set_weather(from: String, to: String, m: float) -> void:
	if not CONDITIONS.has(from):
		from = "rain"
	if not CONDITIONS.has(to):
		to = from
	if from == _mix[0] and to == _mix[1] and absf(m - float(_mix[2])) < 0.002:
		return
	_mix = [from, to, m]
	condition = to if m > 0.5 else from
	var a: Dictionary = CONDITIONS[from]
	var b: Dictionary = CONDITIONS[to]
	var w := lerpf(a["sea"], b["sea"], m)
	var wet := lerpf(a["rain"], b["rain"], m)
	ocean.weather = w
	ocean.rain = wet
	rain.emitting = wet > 0.0 and w < 0.9
	rain.amount_ratio = clampf(wet, 0.05, 1.0)
	var pm := rain.process_material as ParticleProcessMaterial
	var gust := 0.15 + 0.6 * w
	pm.direction = Vector3(ocean.wind.x * gust, -1.0, ocean.wind.y * gust)
	pm.initial_velocity_min = 13.0 + 6.0 * w
	pm.initial_velocity_max = 16.0 + 8.0 * w
	visor.visible = wet > 0.0
	_apply_look()


func _follow_weather() -> void:
	var now := weather.at(ocean.wave_time)
	set_weather(str(now[0]), str(now[1]), float(now[2]))


## Dev and screenshots: this weather and no other.
func set_condition(c: String) -> void:
	weather.pinned = c if CONDITIONS.has(c) else "rain"
	set_weather(weather.pinned, weather.pinned, 0.0)


func set_night(on: bool) -> void:
	night = on
	var m := float(_mix[2])
	_mix[2] = -1.0
	set_weather(str(_mix[0]), str(_mix[1]), m)


## How much of kind c is in the weather now (0..1).
func _share(c: String) -> float:
	var m := float(_mix[2])
	return (1.0 - m if _mix[0] == c else 0.0) + (m if _mix[1] == c else 0.0)


func _apply_look() -> void:
	var a: Dictionary = CONDITIONS[_mix[0]]
	var b: Dictionary = CONDITIONS[_mix[1]]
	var m := float(_mix[2])
	var w := lerpf(a["sea"], b["sea"], m)
	var wet := lerpf(a["rain"], b["rain"], m)
	var day_top := (a["sky"][0] as Color).lerp(b["sky"][0], m)
	var day_hor := (a["sky"][1] as Color).lerp(b["sky"][1], m)
	var top := Color(0.015, 0.02, 0.025) if night else day_top
	var hor := Color(0.05, 0.06, 0.07) if night else day_hor
	var fog := Color(0.045, 0.055, 0.065) if night else day_hor.lerp(Color(0.3, 0.33, 0.36), 0.4 * w)
	sky_mat.set_shader_parameter("sky_top", top)
	sky_mat.set_shader_parameter("sky_horizon", hor)
	sky_mat.set_shader_parameter("ground_horizon", fog)
	sky_mat.set_shader_parameter("ground_bottom", fog.darkened(0.15))
	sky_mat.set_shader_parameter("cloud_low", 0.6 + 0.4 * w)
	sky_mat.set_shader_parameter("clouds", 1.0 - 0.5 * _share("sunny"))
	sky_mat.set_shader_parameter("cloud_tint", Color(0.85, 0.88, 0.92).lerp(Color(0.55, 0.58, 0.62), w))
	sky_mat.set_shader_parameter("curtains", (0.15 + 0.45 * w) * clampf(wet * 4.0, 0.0, 1.0))
	env.fog_light_color = fog
	var storm := _share("storm")
	if storm > 0.9:
		# a wall of fog about 20 m out (Fathom's storm)
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_depth_begin = 8.0
		env.fog_depth_end = 24.0
		env.fog_depth_curve = 1.25
		env.fog_density = 1.0
	else:
		# (as a storm comes in, the fog closes in toward that wall)
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = lerpf(a["fog"], b["fog"], m) + 0.13 * storm
	env.ambient_light_energy = 0.35 if night else 0.9
	sun.light_energy = 0.0 if night else lerpf(a["sun"], b["sun"], m)
	sun.visible = not night
	ocean.set_sky_color(hor.lerp(fog, 0.5))
	sea_fx.night = 1.0 if night else 0.0
	boat.set_lights(night or storm + _share("fog") > 0.5)
	var rain_mat := (rain.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	rain_mat.albedo_color = Color(0.75, 0.8, 0.86, 0.22 if night else 0.38)


func _build_world() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("cloud_noise", NOISE)
	sky_mat.set_shader_parameter("clouds", 1.0)
	sky_mat.set_shader_parameter("curtain_top", 12.0)
	sky_mat.set_shader_parameter("curtain_light", 0.3)
	sky_mat.set_shader_parameter("curtain_streaks", 1.0)
	sky_mat.set_shader_parameter("curtain_fall", 0.9)
	sky_mat.set_shader_parameter("curtain_sweep", 0.003)
	sky_mat.set_shader_parameter("sun_energy", 0.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_sky_affect = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.shadow_enabled = true
	add_child(sun)
	ocean = Ocean.new()
	ocean.name = "Ocean"
	ocean.wind = WIND
	add_child(ocean)
	# rain round whoever's looking (sea_fx moves it)
	rain = _particles(Vector3(0, 22, 0), Vector3(40, 1, 40), 5000, 3.6, Vector3(0, -1, 0), 2.0,
		Vector2(13, 16), Vector3(0, -2, 0), Color(0.75, 0.8, 0.86, 0.38), Vector2(0.035, 0.85))
	(rain.process_material as ParticleProcessMaterial).particle_flag_align_y = true
	rain.name = "Rain"
	add_child(rain)
	sea_fx = SeaFx.new()
	sea_fx.name = "SeaFx"
	sea_fx.ocean_path = NodePath("../Ocean")
	sea_fx.rig_center = Vector2.ZERO
	sea_fx.crown = Vector3(0.0, 9.0, 0.0)
	add_child(sea_fx)
	visor = VisorRain.new()
	add_child(visor)
	boat = Boat.new()
	boat.name = "Boat"
	boat.ocean = ocean
	add_child(boat)


func _particles(at: Vector3, box: Vector3, amount: int, life: float, dir: Vector3, spread: float,
		speed: Vector2, gravity: Vector3, color: Color, quad: Vector2) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = gravity
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var q := QuadMesh.new()
	q.size = quad
	q.material = mat
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.process_material = pm
	p.draw_pass_1 = q
	p.position = at
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(-box - Vector3(20, 60, 20), box * 2.0 + Vector3(40, 120, 40))
	return p
