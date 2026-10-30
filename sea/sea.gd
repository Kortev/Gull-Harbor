extends Node3D
## The whole world: open ocean to the horizon, the weather over it, and the boat parked at the
## origin riding the swell. The ocean, its weather effects, the rain on your eyes and the sky come
## from Fathom in the space fishing game (ocean.gd, sea_fx.gd, visor_rain.gd, sky.gdshader).
##
## The weather comes and goes on its own (sea/weather.gd): sunny, calm, fog, rain, heavy, storm. Nobody picks it.
## Screenshots: <godot> --path . -- --shot=<png> [--weather=calm|sunny|fog|rain|heavy|storm (pinned)] [--night|--noon|
## --day=<0 dawn .. 1 dusk, 1.2 dark>]
##   [--frames=<n>] [--cam=x,y,z,lookx,looky,lookz] [--look=<degrees round from aft>] [--wheel] [--strike=<rod>]
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
const Radar := preload("res://tuna/radar.gd")
const Weather := preload("res://sea/weather.gd")
const Landing := preload("res://tuna/landing.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const Chum := preload("res://boat/chum.gd")
const Jig := preload("res://boat/jig.gd")
const Spotter := preload("res://crew/spotter.gd")
const Tips := preload("res://ui/tips.gd")
const Landmarks := preload("res://sea/landmarks.gd")
const Harbour := preload("res://sea/harbour.gd")
const Sfx := preload("res://audio/sfx.gd")
const Vs := preload("res://vs/vs.gd")

## How rough the sea is (ocean.gd: 0 calm, 0.5 rain, 1 storm), the sun, how thick the fog, and how far you can see
## the land and the rig (far, m: sea/landmarks.gd's haze).
const CONDITIONS := {
	"calm": {"sea": 0.12, "rain": 0.0, "sun": 0.55, "fog": 0.002, "far": 2600.0, "sky": [Color(0.36, 0.42, 0.5), Color(0.62, 0.66, 0.7)]},
	"sunny": {"sea": 0.25, "rain": 0.0, "sun": 1.3, "fog": 0.0012, "far": 4500.0, "sky": [Color(0.22, 0.38, 0.6), Color(0.66, 0.74, 0.8)]},
	"fog": {"sea": 0.08, "rain": 0.0, "sun": 0.15, "fog": 0.045, "far": 200.0, "sky": [Color(0.42, 0.45, 0.47), Color(0.5, 0.53, 0.55)]},
	"rain": {"sea": 0.5, "rain": 0.6, "sun": 0.3, "fog": 0.0065, "far": 1300.0, "sky": [Color(0.24, 0.27, 0.3), Color(0.42, 0.45, 0.48)]},
	"heavy": {"sea": 0.75, "rain": 0.85, "sun": 0.2, "fog": 0.01, "far": 800.0, "sky": [Color(0.18, 0.2, 0.23), Color(0.33, 0.36, 0.39)]},
	"storm": {"sea": 1.0, "rain": 1.0, "sun": 0.12, "fog": 0.0, "far": 450.0, "sky": [Color(0.13, 0.15, 0.17), Color(0.25, 0.28, 0.3)]},
}
const WIND := Vector2(-0.8, -0.6)

## The weather's kind right now (the nearer of the two it's between), and its blend [from, to, 0..1].
var condition := "rain"
var weather := Weather.new()
var _mix: Array = ["", "", -1.0]
var night := false
var ocean: Ocean
var env: Environment
var landmarks: Landmarks
## How far you can see now (m): the weather's and the night's (the schools turn up within it).
var seeing := 4500.0
## Gull Harbor up close: the quay, the fish pier and her berth.
var harbour: Harbour
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
## Boatside to the deck (the harpoon, the tuna door), and the catch (on deck, in the hold, the money).
var landing: Landing
var fish_hold: FishHold
## While you wait: the chum bucket, and the mackerel jig for the live well.
var chum: Chum
var jig: Jig
var spotter: Spotter
## Dale from the bank on the radio: the first-time tips.
var tips: Tips
## Two boats racing for the same birds (vs/vs.gd); off, it's the one boat.
var vs: Vs
var _args := {}
var _frames := 0
var _steered := false
var _took := false
var _cast := false
var _reported := false
var _last_dark := -1.0


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
	if _args.has("screen"):
		add_child(SCREEN_LOOK.instantiate())      # (the old PS1 screen look, only if asked: --screen=psx_360)
	crew = Crew.new()
	crew.name = "Crew"
	crew.sea = self
	add_child(crew)
	rods = Rods.new()
	rods.name = "Rods"
	rods.sea = self
	add_child(rods)
	landing = Landing.new()
	landing.name = "Landing"
	landing.sea = self
	add_child(landing)
	fish_hold = FishHold.new()
	fish_hold.name = "FishHold"
	fish_hold.sea = self
	add_child(fish_hold)
	schools = Schools.new()
	schools.name = "Schools"
	schools.sea = self
	add_child(schools)
	chum = Chum.new()
	chum.name = "Chum"
	chum.sea = self
	add_child(chum)
	jig = Jig.new()
	jig.name = "Jig"
	jig.sea = self
	add_child(jig)
	spotter = Spotter.new()
	spotter.name = "Spotter"
	spotter.sea = self
	add_child(spotter)
	tips = Tips.new()
	tips.name = "Tips"
	tips.sea = self
	add_child(tips)
	vs = Vs.new()
	vs.name = "Vs"
	vs.sea = self
	add_child(vs)
	var sonar := Sonar.new()
	sonar.name = "Sonar"
	sonar.schools = schools
	add_child(sonar)
	sonar.attach(boat)
	var radar := Radar.new()
	radar.name = "Radar"
	radar.schools = schools
	add_child(radar)
	radar.attach(boat)
	# (another boat at the dock: the screens are on her new dash)
	boat.rebuilt.connect(func() -> void:
		sonar.attach(boat)
		radar.attach(boat))
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
	# the game itself (not a test, which builds the sea under its own node): the boat you last took, at the dock
	if get_parent() == get_tree().root:
		boat.use_kind(fish_hold.kind)
		moor()
	if _args.has("vs"):        # (tests: two boats from the start; --team=b puts you on boat B)
		vs.host_set_on(true)
		if str(_args.get("team", "")) == "b":
			vs.ask_team(1)
	if _args.has("school"):    # (screenshots and tests: out on the grounds, a school starting right away, <n> m off)
		if fish_hold.docked:
			fish_hold.head_out()
			boat.helm.at = Vector2.ZERO        # (out on the grounds, not at the pier)
		schools.set("_next", 0.0)
		if not str(_args["school"]).is_empty():
			schools.start_far = float(_args["school"])
	if _args.has("lead"):      # (screenshots: every school has a whale, or dolphins)
		Leads.force = {"whale": Leads.WHALE, "dolphins": Leads.DOLPHINS}.get(str(_args["lead"]), -1)
	if _args.has("strike"):    # (screenshots: a fish on rod <n> right away, its bait cast out first)
		rods.host_cast(int(_args["strike"]))
		rods.strike(int(_args["strike"]), 220.0)
	if _args.has("wheel"):     # (screenshots: start at the wheel)
		boat.helm.request(true)
	if _args.has("hold"):      # (screenshots: start with rod <n> in your hands)
		rods.request_grab(int(_args["hold"]))
	# (--port=: another port than Net.PORT, for running the tests beside another game that has it)
	var port := int(_args.get("port", Net.PORT))
	if _args.has("host"):
		Net.host(port)
	elif _args.has("join"):
		Net.join(str(_args["join"]), port)
	for n in str(_args.get("hide", "")).split(",", false):   # (dev: --hide=Rain,SeaFx,... to find what's what)
		for found in find_children(n, "", true, false):
			if found is Node3D:
				(found as Node3D).visible = false
			elif found is CanvasLayer:
				(found as CanvasLayer).visible = false


## Host: her alongside the fish pier at her berth (sea/harbour.gd), bow out, still. Only in the game itself (tests
## and VS keep where they put her).
func moor() -> void:
	if not Net.is_host() or get_parent() != get_tree().root or harbour == null or (vs != null and vs.on):
		return
	var helm := boat.helm
	var at: Vector2 = harbour.berth(float(boat.beam) * 0.5, float(boat.length))
	helm.at = at
	helm.heading = 0.0
	helm.speed = 0.0
	helm.throttle = 0.0
	if Net.in_session():
		helm.rpc("_sync", helm.captain, 0.0, at, 0.0)


## Coming in: the screen cuts to black and fades up on her alongside the pier (every peer, as the trip ends); not
## when you brought her in alongside yourself.
func arrive() -> void:
	if _came_alongside:
		_came_alongside = false
		return
	if _fade == null:
		_fade = CanvasLayer.new()
		_fade.layer = 20
		var black := ColorRect.new()
		black.color = Color.BLACK
		black.set_anchors_preset(Control.PRESET_FULL_RECT)
		black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.add_child(black)
		add_child(_fade)
	var black := _fade.get_child(0) as ColorRect
	black.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_property(black, "modulate:a", 0.0, 1.8).set_trans(Tween.TRANS_SINE)


var _fade: CanvasLayer
var _came_alongside := false
var _alongside_for := 0.0
var _been_out := false        # (this trip she's been out past the breakwaters: coming back in alongside ties her up)
## Brought in alongside her berth this slow for this long (s), she's tied up and the catch is sold there.
const TIE_UP := 2.0


## Host: she's been brought in alongside the fish pier and stopped: tie her up, sell.
func _tie_up(delta: float) -> void:
	if not Net.is_host() or fish_hold.docked or get_parent() != get_tree().root or (vs != null and vs.on):
		_alongside_for = 0.0
		_been_out = false
		return
	var berth: Vector2 = harbour.berth(float(boat.beam) * 0.5, float(boat.length))
	_been_out = _been_out or boat.helm.at.distance_to(berth) > 400.0
	if not _been_out:
		return
	var near := boat.helm.at.distance_to(berth) < 9.0 and absf(boat.helm.speed) < 0.8
	_alongside_for = _alongside_for + delta if near else 0.0
	if _alongside_for > TIE_UP:
		_alongside_for = 0.0
		_came_alongside = true
		Sfx.play_point(boat, boat.global_position, "kit.thud", 0.6, 0.6)
		fish_hold.head_in()


func _process(_delta: float) -> void:
	_frames += 1
	_tie_up(_delta)
	_follow_weather()
	# the day going by: the light redone as it changes, the sun moved
	var dark := _dark()
	if absf(dark - _last_dark) > 0.01:
		_last_dark = dark
		_apply_look()
	_move_sun()
	# in a storm the lightning goes for her highest point, the tower or the T-top (sea_fx's crown, in its space: the world's)
	sea_fx.crown = boat.global_transform * (boat.spec.get("crown", Vector3(0.0, 7.6, -1.3)) as Vector3)
	if _args.has("watch") and not schools.schools.is_empty():
		# (screenshots: from 28 m off the nearest school, on the boat's side of it, looking at it)
		var c: Vector2 = schools.schools[0].center(ocean.wave_time)
		var here: Vector2 = boat.helm.at
		var at := Vector3(c.x, 0.0, c.y)
		var back := float(_args["watch"]) if str(_args["watch"]).is_valid_float() else 28.0
		var from := at + (Vector3(here.x, 0.0, here.y) - at).normalized() * back + Vector3(0, 5.0, 0)
		cam.make_current()
		cam.global_position = from
		cam.look_at(at + Vector3(0, 2.0, 0))
	elif _args.has("cam"):
		var v := str(_args["cam"]).split_floats(",")
		var at := Vector3(v[0], v[1], v[2])
		at.y += ocean.height_at(Vector3(at.x, 0.0, at.z))
		cam.global_position = at
		cam.look_at(Vector3(v[3], v[4], v[5]))
	if _args.has("run") and crew.me != null:
		# (screenshots: out on open water at the wheel, throttle up (--run=0..1), a chase camera astern and above her;
		# --turn=-1..1 holds the wheel over)
		if fish_hold.docked:
			fish_hold.head_out()
			boat.helm.at = Vector2.ZERO
		crew.me.force_input = true
		if boat.helm.captain == 0:
			boat.helm.request(true)
		Input.action_press("move_forward", float(_args["run"]) if str(_args["run"]).is_valid_float() else 1.0)
		if _args.has("turn"):
			Input.action_press("move_left" if float(_args["turn"]) > 0.0 else "move_right", absf(float(_args["turn"])))
		var chase := boat.global_transform * Vector3(9.0, 7.0, 26.0)
		cam.make_current()
		cam.global_position = chase
		cam.look_at(boat.global_transform * Vector3(0.0, 0.0, 4.0))
	if _args.has("helm") and crew.me != null and not _steered:
		# (tests/net_test.sh: once aboard, take the wheel and swing her to port for a second and a half)
		if boat.helm.captain == 0 and Time.get_ticks_msec() > 2500:
			crew.me.force_input = true
			boat.helm.request(true)
		elif boat.helm.is_mine():
			_steered = true
			Input.action_press("move_left")
			get_tree().create_timer(1.5).timeout.connect(func() -> void: Input.action_release("move_left"))
	if _args.has("take") and crew.me != null and not _took and Time.get_ticks_msec() > 2500:
		# (tests/net_test.sh: once aboard, take over the crewmate's rod)
		var i := int(_args["take"])
		if i < rods.rods.size() and rods.rods[i].holder != 0 and rods.rods[i].hooked:
			_took = true
			rods.request_grab(i)
	if _args.has("cast") and crew.me != null and not _cast and Time.get_ticks_msec() > 2500:
		# (tests/net_test.sh: once aboard, pick up a rod, wind its line in if it's out, and cast it)
		var r: Node = rods.rods[int(_args["cast"])]
		if r.get("holder") == 0:
			rods.request_grab(int(_args["cast"]))
		elif r.get("holder") == Net.my_id():
			if not r.get("bait_in"):
				rods.wind_in(r, get_process_delta_time())
			else:
				_cast = true
				rods.cast_mine(0.6)
	if _args.has("net-report") and Time.get_ticks_msec() > int(float(_args["net-report"]) * 1000.0) \
			and not _reported:
		_reported = true
		# (tests/net_test.sh: who's aboard, and the sea clock, then quit)
		var ids: Array = crew.slots.keys()
		ids.sort()
		print("NET fps=%d me=%d host=%s crew=%s clock=%.2f cond=%s mix=%s skew=%.3f captain=%d heading=%.2f" % [
				Engine.get_frames_per_second(), Net.my_id(), Net.is_host(), ids, ocean.wave_time, condition,
				"%s>%s@%.2f" % _mix, Time.get_ticks_msec() / 1000.0 + ocean.clock_offset - Time.get_unix_time_from_system(),
				int(boat.helm.captain), boat.helm.heading])
		print("NET rods holders=%s" % ",".join(rods.rods.map(func(r: Node) -> String: return str(r.get("holder")))))
		print("NET casts %s" % " ".join(rods.rods.map(func(r: Node) -> String:
				return "%s:%.1f,%.1f" % ["in" if r.get("bait_in") else "out", r.get("land").x, r.get("land").z])))
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
	weather.day = int(fish_hold.day) + 1000 * int(fish_hold.quota_n)
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
	# the day (boat/fish_hold.gd: dawn, day, dusk, night; --night pins night): night's colours blended in as it
	# gets dark, and at dawn and dusk a warm low light, less of it the thicker the weather
	var dark := _dark()
	var warm := (1.0 - absf(dark - 0.45) / 0.45) * 0.45 * (1.0 - w) if dark > 0.02 and dark < 0.9 else 0.0
	day_hor = day_hor.lerp(Color(0.92, 0.58, 0.36), clampf(warm, 0.0, 1.0))
	var top := day_top.lerp(Color(0.015, 0.02, 0.025), dark)
	var hor := day_hor.lerp(Color(0.05, 0.06, 0.07), dark)
	var fog := day_hor.lerp(Color(0.3, 0.33, 0.36), 0.4 * w).lerp(Color(0.045, 0.055, 0.065), dark)
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
		# the storm closing in: the seas round her clear, gone grey a hundred metres or so out
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_depth_begin = 35.0
		env.fog_depth_end = 150.0
		env.fog_depth_curve = 1.25
		env.fog_density = 1.0
	else:
		# (as a storm comes in, the fog closes in toward that wall)
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = lerpf(a["fog"], b["fog"], m) + 0.025 * storm
	env.ambient_light_energy = lerpf(0.9, 0.35, dark)
	sun.light_energy = lerpf(a["sun"], b["sun"], m) * (1.0 - dark)
	sun.light_color = Color(1.0, 0.93, 0.82).lerp(Color(1.0, 0.62, 0.38), clampf(warm * 2.0, 0.0, 1.0))
	sun.visible = dark < 0.98
	ocean.set_sky_color(hor.lerp(fog, 0.5))
	sea_fx.night = dark
	boat.set_lights(dark > 0.45 or storm + _share("fog") > 0.5)
	# the land and the rig fade into the same colour as the sea's haze; their lights come on with the boat's
	var far := lerpf(a["far"], b["far"], m) * (1.0 - 0.5 * dark)
	seeing = far
	landmarks.set_look(fog, far, dark, dark > 0.4 or storm + _share("fog") > 0.5)
	var rain_mat := (rain.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	rain_mat.albedo_color = Color(0.75, 0.8, 0.86, lerpf(0.38, 0.22, dark))


## How dark it is, 0 (full day) .. 1 (night): the day out there, or night pinned.
func _dark() -> float:
	if night:
		return 1.0
	if _args.has("noon"):
		return 0.0         # (screenshots: --noon pins the middle of the day)
	if _args.has("day"):
		return 1.0 - FishHold.daylight_at(float(_args["day"]))
	return 1.0 - float(fish_hold.daylight()) if fish_hold != null else 0.0


## The sun across the sky with the day: low in the east at dawn, high at noon, low in the west at dusk.
func _move_sun() -> void:
	if fish_hold == null:
		return
	if night:
		_light_sky_and_sea()
		return
	var t := clampf(float(fish_hold.day_fraction()), 0.0, 1.0) if not fish_hold.docked else 0.04
	if _args.has("noon"):
		t = 0.4
	if _args.has("day"):
		t = clampf(float(_args["day"]), 0.0, 1.0)
	var up := sin(PI * t)
	sun.rotation_degrees = Vector3(-(5.0 + 55.0 * up), lerpf(80.0, -80.0, t), 0.0)
	_light_sky_and_sea()


func _light_sky_and_sea() -> void:
	# the sky's sun where the light comes from (a disc and a glow round it, the clouds lit from that side), hidden by
	# thick weather; the sea's light from the same side, and its colours with the day
	var toward := sun.global_transform.basis.z
	var dark := _dark()
	var thick := clampf(1.0 - _share("sunny") - 0.5 * _share("calm"), 0.0, 1.0)
	sky_mat.set_shader_parameter("sun_dir", toward)
	sky_mat.set_shader_parameter("sun_color", sun.light_color)
	sky_mat.set_shader_parameter("sun_energy", (1.0 - dark) * (1.0 - 0.85 * thick))
	sky_mat.set_shader_parameter("stars", smoothstep(0.6, 1.0, dark) * (1.0 - thick))
	ocean.set_light(toward, sun.light_color, dark)


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
	# the look: stylized, a bit painterly, rich colour (Sea of Thieves', more or less): ACES for contrast, the colour
	# pushed a little, a soft bloom, and ambient occlusion so the boats' corners and the crew sit in their shade
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 5.0
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.04
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 1.1
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_light_affect = 0.15
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
	ocean.follow_camera = true      # (the boat goes places: the sea's mesh goes along under you, its waves stay put)
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
	landmarks = Landmarks.new()
	landmarks.name = "Landmarks"
	landmarks.ocean = ocean
	add_child(landmarks)
	harbour = Harbour.new()
	harbour.name = "Harbour"
	harbour.marks = landmarks
	landmarks.harbour = harbour
	add_child(harbour)
	boat = Boat.new()
	boat.name = "Boat"
	boat.ocean = ocean
	boat.sea = self
	add_child(boat)
	ocean.follow = boat


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
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
