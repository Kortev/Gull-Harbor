extends Node3D
## Fathom's weather at sea, from the ocean (ocean.gd, `ocean_path`): spray bursting off the rig's
## legs when a crest hits them, spray torn off the crests round the rig in a blow, lightning in a
## storm (a bolt coming down close, out at sea or onto the derrick's crown, through the fog; the flash
## lights everything, the fog and the sky with it, so the rig stands out black for a moment; more of
## them as the sea rises). The rain (the planet's Rain and RainStorm, beside this node) follows
## whoever's looking and stops on roofs (a height field over the rig and the ship), so it pours round
## you out on a deck and not under one. And the night's moment, "the deep wakes":
## something huge and glowing circles slowly under the rig (the ocean's glow_spot) while the rig's
## lights stutter (rig.gd). Reads the planet's `moment` (planet.gd up the tree), or `moment_override`
## in a lab. Every peer runs its own: nothing here is synced (the waves it reads are).
## The hurricane (a storm, Kevin 2026-10-16: "the winds and rain to just be insane"): the gale, rain blown sideways
## round whoever's looking (rain_streak.gdshader), splashing where it hits a deck or a roof; and the ocean's gusts
## (ocean.gd's `gust`, the same on every peer), each one flattening the rain, sweeping grey sheets of it past,
## pulling the wall of fog in from about 20 m to about 8 (the planet's `set_fog_wall`, a lab reads `fog_wall`),
## tearing more spray off the crests round you and blowing spindrift low over the sea.
## Worse through the night (the ocean's `fury`, Kevin 2026-10-16: "ALWAYS dense but even more insane later"): dense
## between the gusts too and denser late, squalls on top of the gusts, the rain faster, the fog closer (about 22 m
## to 17 between the gusts, 8 to 7 at a peak), curtains of rain sweeping across the sea out in the fog, lightning
## more often, closer, flickering in restrikes, onto the derrick more.
## Really rough (Kevin, 2026-10-17: "more dense with fog always and just make it really REALLY rough"): moving fog
## (StormFog, storm_fog.gdshader: volumetric banks and torn cloud racing past downwind, a layer of spray over the sea,
## lit by the lamps and the lightning, none in the ship), and spray hitting your visor (VisorRain's `splash`: a leg's
## slam or a crest's spray close by, the sea over your feet). Not while the planet's `tame` (the dev panel's compare).

const Ocean := preload("res://sea/ocean.gd")
const Sfx := preload("res://audio/sfx.gd")
const PlanetSounds := preload("res://audio/sea_sounds.gd")
## The sound of spray torn off a crest near you: only this close (m), at most every SPRAY_GAP s.
const SPRAY_NEAR := 40.0
const SPRAY_GAP := 1.5
## The speed of sound (m/s): the thunder comes after the flash. A strike nearer than CRACK_NEAR m cracks, a farther one rolls.
const SOUND_SPEED := 343.0
const CRACK_NEAR := 70.0
const PUFF := preload("res://sea/textures/steam_puff.png")
const STREAK := preload("res://sea/rain_streak.gdshader")
const CURTAIN := preload("res://sea/rain_curtain.gdshader")
const STORM_FOG := preload("res://sea/storm_fog.gdshader")
## The moving fog's thickness (extinction per m) between its banks, in them, and the spray over the sea: at landing,
## late in the night (`fury`); more in a gust. It blows past at FOG_SPEED x the gale's speed, out to FOG_LENGTH m.
const FOG_THIN := Vector2(0.025, 0.04)
const FOG_THICK := Vector2(0.11, 0.16)
const FOG_SPRAY := Vector2(0.1, 0.16)
const FOG_SPEED := 0.8
const FOG_LENGTH := 40.0
## The moving fog's pocket round your eyes (m): none of it inside x, all of it past y, so the sea where your line goes
## still reads (Kevin, 2026-10-17: "you can BARELY see the ocean anymore at the bottom, where the player fishes");
## at a gust's peak x POCKET_PEAK (the whiteout).
const POCKET := Vector2(6.0, 18.0)
const POCKET_PEAK := 0.3
## Spray on your visor: a leg's slam this close (m), a crest's spray this close.
const SPLASH_SLAM := 15.0
const SPLASH_CREST := 9.0
## How close the wall of fog comes (x the night's) between the gusts and at a gust's peak: at landing, late in
## the night (the ocean's `fury`).
const FOG_CALM := Vector2(0.9, 0.7)
const FOG_PEAK := Vector2(0.34, 0.28)
## The gale's speed sideways and down (m/s): between the gusts, at a gust's peak; late in the night x LATE_SPEED.
const GALE_SIDE := Vector2(14.0, 32.0)
const GALE_DOWN := Vector2(13.0, 8.0)
const LATE_SPEED := 1.25
## How much of the gale (GALE_AMOUNT streaks) falls between the gusts, and at a gust's peak: at landing, late.
const GALE_AMOUNT := 24000
const GALE_CALM := Vector2(0.55, 0.8)
const GALE_PEAK := Vector2(0.8, 1.0)

@export var ocean_path: NodePath
## The rig's middle (x, z): crest spray and the moment circle round it.
@export var rig_center := Vector2(0.0, 34.0)
## The derrick's crown: now and then a bolt hits it.
@export var crown := Vector3(0.0, 30.0, 33.1)
## A lab can play the night's moment: 0..1, -1 = follow the planet.
var moment_override := -1.0
## 0 day .. 1 night: the spray goes dark with the sky (the planet's `dark` on a planet, else a lab's).
@export var night := 0.0
## The moving fog allowed (the perf tools switch it off to see what it costs).
var moving_fog := true

var ocean: Ocean
var _planet: Node
var _legs: Array[GPUParticles3D] = []
var _leg_was: Array[bool] = []
var _crests: Array[GPUParticles3D] = []
var _spray_mats: Array[StandardMaterial3D] = []
var _night_was := -1.0
var _crest_in := 0.0
var _flash := 0.0
var _spray_at := -100.0
var _lightning_in := 4.0
var _lightning: DirectionalLight3D
var _bolt: MeshInstance3D
var _bolt_mat: StandardMaterial3D
var _rain: Array[GPUParticles3D] = []
var _moment_t := 0.0
var _t := 0.0
## The wall of fog now, x the night's (FOG_CALM between the gusts .. FOG_PEAK at a peak).
var fog_wall := 1.0
var _gale: GPUParticles3D
var _gale_mat: ShaderMaterial
var _sheets: GPUParticles3D
var _sheet_mat: ShaderMaterial
var _splash: GPUParticles3D
var _drift: GPUParticles3D
var _curtains: GPUParticles3D
var _curtain_mat: ShaderMaterial
var _restrike_in := 0.0
var _fog: FogVolume
var _fog_mat: ShaderMaterial
var _fog_drift := Vector2.ZERO
var _visor: Node


func _ready() -> void:
	ocean = get_node(ocean_path) as Ocean
	_planet = get_parent()
	while _planet != null and not ("weather_strength" in _planet):
		_planet = _planet.get_parent()
	for _leg in ocean.legs:
		var burst := _puffs(40, 1.8, Vector3(1.2, 0.3, 1.2), 28.0, Vector2(6, 10), Vector3(0, -9.8, 0), 1.6, 0.55)
		_legs.append(burst)
		_leg_was.append(false)
	for i in 8:
		_crests.append(_puffs(24, 1.6, Vector3(2.5, 0.2, 2.5), 35.0, Vector2(2, 5), Vector3(8, -5, 6), 1.4, 0.45))
	_lightning = DirectionalLight3D.new()
	_lightning.rotation_degrees = Vector3(-60, -120, 0)
	_lightning.light_color = Color(0.8, 0.85, 1.0)
	_lightning.visible = false
	# (shadowed, as the sun is: the flash lights the cabin only through the windows and the doorway; it's only drawn
	# while a flash is up, so its shadow pass costs only then)
	_lightning.shadow_enabled = true
	_lightning.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_lightning.directional_shadow_max_distance = 90.0
	add_child(_lightning)
	_bolt_mat = StandardMaterial3D.new()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bolt_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt_mat.vertex_color_use_as_albedo = true
	_bolt_mat.disable_fog = true
	_bolt = MeshInstance3D.new()
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.top_level = true
	_bolt.visible = false
	add_child(_bolt)
	_rain_follows()
	_build_gale()
	_build_fog()
	_visor = get_parent().get_node_or_null("VisorRain")


func _process(delta: float) -> void:
	_t += delta
	if _planet != null and "dark" in _planet:
		night = float(_planet.get("dark"))
	if absf(night - _night_was) > 0.01:
		_night_was = night
		for mat in _spray_mats:
			var c := Color(0.85, 0.9, 0.92).lerp(Color(0.13, 0.15, 0.17), night)
			mat.albedo_color = Color(c.r, c.g, c.b, mat.albedo_color.a)
	var weather := ocean.weather
	var sea_y := ocean.global_position.y
	var wind := ocean.wind.normalized()
	# spray where a crest slams a leg (on the leg's windward side)
	for i in ocean.legs.size():
		var leg := ocean.legs[i]
		var face := ocean.to_global(Vector3(leg.x - wind.x * leg.z, 0.0, leg.y - wind.y * leg.z))
		var high := ocean.height_at(face) - sea_y > ocean.swell * 0.28
		if high and not _leg_was[i]:
			var spm := _legs[i].process_material as ParticleProcessMaterial
			spm.initial_velocity_min = 5.0 + 9.0 * weather
			spm.initial_velocity_max = 8.0 + 16.0 * weather
			spm.scale_max = 1.6 + 2.5 * weather
			_legs[i].global_position = Vector3(face.x, sea_y + 0.5, face.z)
			_legs[i].restart()
			Sfx.play_point(self, _legs[i].global_position, "sea.slam",
				(0.35 + 0.65 * weather) * PlanetSounds.outside(get_tree()))
			_spray_near(_legs[i].global_position, SPLASH_SLAM, 0.95)
		_leg_was[i] = high
	# in a blow, spray torn off the crests: round the rig, round you (upwind of you) in the gale, more in a gust
	var gust := ocean.gust
	var gale := maxf(ocean.gusty, gust)
	var cam := get_viewport().get_camera_3d()
	_crest_in -= delta
	if (weather > 0.6 or gale > 0.05) and _crest_in <= 0.0:
		_crest_in = lerpf(0.5, 0.12, clampf((weather - 0.6) / 0.4, 0.0, 1.0)) * lerpf(1.0, 0.35, gust) \
			* lerpf(1.0, 0.6, ocean.fury)
		var around := rig_center
		var reach := Vector2(22.0, 90.0)
		if gale > 0.05 and cam != null:
			var c := ocean.to_local(cam.global_position)
			around = Vector2(c.x, c.z) - wind * 14.0
			reach = Vector2(6.0, 40.0)
		for _try in 6:
			var a := randf() * TAU
			var r := randf_range(reach.x, reach.y)
			var p := ocean.to_global(Vector3(around.x + cos(a) * r, 0.0, around.y + sin(a) * r))
			var h := ocean.height_at(p)
			if h - sea_y > ocean.swell * lerpf(0.3, 0.15, gale):
				var burst := _crests[randi() % _crests.size()]
				var push := 9.0 + 16.0 * gust
				(burst.process_material as ParticleProcessMaterial).gravity = Vector3(wind.x * push, -5.0 + 2.0 * gust,
					wind.y * push)
				burst.global_position = Vector3(p.x, h + 0.3, p.z)
				burst.restart()
				_spray_near(burst.global_position, SPLASH_CREST, 0.5)
				if cam != null and cam.global_position.distance_to(burst.global_position) < SPRAY_NEAR \
						and _t - _spray_at > SPRAY_GAP:
					_spray_at = _t
					Sfx.play_point(self, burst.global_position, "sea.spray",
						lerpf(0.6, 1.0, gust) * PlanetSounds.outside(get_tree()))
				break
	_blow_gale(cam, gale, gust)
	_storm_fog(delta, gale, gust)
	# the sea over your feet (a wash, the water): the visor's under it
	if cam != null and not ocean.tame and cam.global_position.y - ocean.height_at(cam.global_position) < 1.5:
		_wet_visor(1.0)
	_storm_light(delta, weather)
	_rain_round_camera()
	_moment(delta)


## Lightning in a storm (the planet's weather, or a lab's rough sea): a bolt every few seconds, more often as
## the sea rises, flickering out over a few tenths of a second.
func _storm_light(delta: float, weather: float) -> void:
	_flash = maxf(_flash - delta * 5.0, 0.0)
	var storm := weather > 0.85
	if _planet != null and str(_planet.get("weather")) != "":
		storm = str(_planet.get("weather")) == "storm"
	if storm:
		_lightning_in -= delta
		if _lightning_in <= 0.0:
			var rage := clampf((weather - 0.5) * 2.0, 0.0, 1.0)
			_lightning_in = randf_range(lerpf(3.0, 1.5, rage), lerpf(9.0, 5.0, rage)) * lerpf(1.0, 0.55, ocean.fury)
			strike()
	# a restrike: the same bolt flaring again a moment later
	if _restrike_in > 0.0:
		_restrike_in -= delta
		if _restrike_in <= 0.0:
			_flash = maxf(_flash, randf_range(0.7, 1.0))
	var f := _flash * (0.55 + 0.45 * sin(_t * 47.0) * sin(_t * 23.0))
	_lightning.light_energy = f * 3.0
	_lightning.visible = f > 0.01
	_bolt.visible = _flash > 0.08
	if _bolt.visible:
		_bolt_mat.albedo_color = Color(1, 1, 1, clampf(f * 1.6, 0.0, 1.0))
	var env := get_world_3d().environment
	if env != null:
		env.background_energy_multiplier = 1.0 + f * 3.0
		env.fog_light_energy = 1.0 + f * 4.0


## A bolt now (and the dev panels' "lightning"): out at sea 30 to 140 m from whoever's looking, mostly the
## nearer, or now and then onto the derrick's crown; later in the night (`fury`) closer, onto the crown more, and
## more often flaring again in a restrike.
func strike() -> void:
	_flash = 1.0
	var fury := ocean.fury
	_restrike_in = randf_range(0.09, 0.22) if randf() < lerpf(0.25, 0.65, fury) else 0.0
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else global_position
	var sea_y := ocean.global_position.y
	var hit: Vector3
	if randf() < lerpf(0.18, 0.35, fury) and eye.distance_to(to_global(crown)) < 160.0:
		hit = to_global(crown)
	else:
		var a := randf() * TAU
		var r := lerpf(lerpf(30.0, 20.0, fury), 140.0, pow(randf(), lerpf(1.6, 2.3, fury)))
		hit = Vector3(eye.x + cos(a) * r, sea_y, eye.z + sin(a) * r)
	var top := hit + Vector3(randf_range(-25.0, 25.0), 180.0, randf_range(-25.0, 25.0))
	_bolt.mesh = _bolt_mesh(top, hit, eye)
	_thunder(eye.distance_to(hit))
	var flat := Vector3(eye.x - hit.x, 0.0, eye.z - hit.z)
	flat = flat.normalized() if flat.length() > 1.0 else Vector3(0.3, 0.0, 0.2)
	_lightning.global_basis = Basis.looking_at((flat + Vector3.DOWN).normalized())


## The thunder of a strike `d` m off, after the flash by the speed of sound: a near one cracks, a far one rolls.
func _thunder(d: float) -> void:
	var event := "sea.crack" if d < CRACK_NEAR else "sea.roll"
	var volume := lerpf(1.0, 0.55, clampf((d - 20.0) / 140.0, 0.0, 1.0)) * lerpf(1.0, 0.6, 1.0 - PlanetSounds.outside(get_tree()))
	get_tree().create_timer(d / SOUND_SPEED).timeout.connect(func() -> void: Sfx.play(event, volume))


## The bolt: a jagged path down from `top` to `hit` with a few forks, each a ribbon turned to the eye, a thin
## white core in a wide faint glow.
func _bolt_mesh(top: Vector3, hit: Vector3, eye: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var path := _jag(top, hit, 22, 9.0)
	_ribbon(st, path, eye, 0.5, Color(1.0, 1.0, 1.0))
	_ribbon(st, path, eye, 5.0, Color(0.35, 0.4, 0.6))
	for _fork in randi_range(2, 4):
		var from: Vector3 = path[randi_range(3, 14)]
		var to := from + Vector3(randf_range(-30.0, 30.0), -randf_range(20.0, 60.0), randf_range(-30.0, 30.0))
		_ribbon(st, _jag(from, to, 8, 5.0), eye, 0.25, Color(0.7, 0.75, 0.95))
	st.set_material(_bolt_mat)
	return st.commit()


func _jag(a: Vector3, b: Vector3, steps: int, wander: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in steps + 1:
		var k := float(i) / float(steps)
		var p := a.lerp(b, k)
		if i > 0 and i < steps:
			p += Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0)) * wander * (1.0 - k * 0.6)
		pts.append(p)
	return pts


func _ribbon(st: SurfaceTool, pts: PackedVector3Array, eye: Vector3, width: float, c: Color) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var side := (b - a).cross(eye - a).normalized() * width * 0.5
		var w := 1.0 - 0.5 * float(i) / float(pts.size())
		st.set_color(c * w)
		for v: Vector3 in [a - side, a + side, b + side, a - side, b + side, b - side]:
			st.add_vertex(v)


## The rain falls in world space from boxes over whoever's looking (moved every frame), and stops on what's
## above: a height field over the rig and the ship (both stand still), so it doesn't pour under a deck or in
## the ship.
func _rain_follows() -> void:
	for name: String in ["Rain", "RainStorm"]:
		var p := get_parent().get_node_or_null(name) as GPUParticles3D
		if p == null:
			continue
		p.local_coords = false
		p.visibility_aabb = AABB(Vector3(-45, -80, -45), Vector3(90, 100, 90))
		(p.process_material as ParticleProcessMaterial).collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
		_rain.append(p)
	var roofs := GPUParticlesCollisionHeightField3D.new()
	roofs.position = Vector3(rig_center.x, 5.0, rig_center.y * 0.5)
	roofs.size = Vector3(130, 100, 130)
	roofs.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_1024
	roofs.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	add_child(roofs)


func _rain_round_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for p in _rain:
		var d := (p.process_material as ParticleProcessMaterial).direction.normalized()
		var up := 16.0
		p.global_position = cam.global_position + Vector3(0, up, 0) - Vector3(d.x, 0, d.z) * up / maxf(-d.y, 0.3)


## The hurricane, every frame: the gale and its sheets blowing through round whoever's looking (from upwind of
## them, so they're flying past by the time they get there), flatter and faster in a gust; the spindrift; the fog.
func _blow_gale(cam: Camera3D, gale: float, gust: float) -> void:
	var fury := ocean.fury
	var calm := lerpf(1.0, lerpf(FOG_CALM.x, FOG_CALM.y, fury), gale)
	fog_wall = lerpf(calm, lerpf(FOG_PEAK.x, FOG_PEAK.y, fury), gust)
	if _planet != null and _planet.has_method("set_fog_wall"):
		_planet.call("set_fog_wall", fog_wall)
	_turn_on(_gale, gale * lerpf(lerpf(GALE_CALM.x, GALE_CALM.y, fury), lerpf(GALE_PEAK.x, GALE_PEAK.y, fury), gust))
	_turn_on(_sheets, gale * lerpf(lerpf(0.2, 0.45, fury), 1.0, gust))
	_turn_on(_drift, gale * lerpf(lerpf(0.35, 0.6, fury), 1.0, gust))
	_turn_on(_curtains, gale * lerpf(0.6, 1.0, fury))
	if cam == null or gale <= 0.02:
		return
	var wind := ocean.wind.normalized()
	var w3 := Vector3(wind.x, 0.0, wind.y)
	var side := lerpf(GALE_SIDE.x, GALE_SIDE.y, gust) * lerpf(1.0, LATE_SPEED, fury)
	var down := lerpf(GALE_DOWN.x, GALE_DOWN.y, gust) * lerpf(1.0, 1.1, fury)
	var eye := cam.global_position
	for p: GPUParticles3D in [_gale, _sheets]:
		var fast := 1.0 if p == _gale else 1.15
		var vel := (w3 * side + Vector3.DOWN * down) * fast
		var pm := p.process_material as ParticleProcessMaterial
		pm.direction = vel.normalized()
		pm.initial_velocity_min = vel.length() * 0.9
		pm.initial_velocity_max = vel.length() * 1.1
		var half := p.lifetime * 0.5
		p.global_position = eye + Vector3.UP * (down * fast * half) - w3 * (side * fast * half)
	var dark := Color(0.82, 0.86, 0.9).lerp(Color(0.3, 0.33, 0.36), night)
	_gale_mat.set_shader_parameter("stretch", lerpf(1.0, lerpf(1.6, 2.0, fury), gust))
	_gale_mat.set_shader_parameter("alpha", lerpf(0.36, 0.24, night) * lerpf(1.0, 1.15, fury))
	var spm := _sheets.process_material as ParticleProcessMaterial
	spm.scale_min = lerpf(0.8, 1.1, fury)
	spm.scale_max = lerpf(1.2, 1.6, fury)
	_gale_mat.set_shader_parameter("color", dark)
	_gale_mat.set_shader_parameter("glow", lerpf(0.18, 0.02, night))
	_sheet_mat.set_shader_parameter("glow", lerpf(0.2, 0.02, night))
	_sheet_mat.set_shader_parameter("color", Color(0.62, 0.66, 0.7).lerp(Color(0.08, 0.09, 0.1), night))
	var dpm := _drift.process_material as ParticleProcessMaterial
	dpm.direction = w3
	dpm.initial_velocity_min = side * 0.6
	dpm.initial_velocity_max = side * 0.9
	_drift.global_position = Vector3(eye.x, ocean.global_position.y + 1.2, eye.z) - w3 * 25.0
	# the curtains: stood on the sea round you, upwind, sweeping past downwind, leaning with the wind
	var cpm := _curtains.process_material as ParticleProcessMaterial
	cpm.direction = w3
	cpm.initial_velocity_min = side * 0.35
	cpm.initial_velocity_max = side * 0.55
	_curtains.global_position = Vector3(eye.x, ocean.global_position.y + 16.0, eye.z) - w3 * 12.0
	_curtain_mat.set_shader_parameter("lean", -wind * clampf(side / down * 0.35, 0.2, 1.2))
	_curtain_mat.set_shader_parameter("fall", down + 6.0)
	_curtain_mat.set_shader_parameter("alpha", lerpf(0.4, 0.58, fury))
	_curtain_mat.set_shader_parameter("color", Color(0.27, 0.3, 0.33).lerp(Color(0.06, 0.07, 0.08), night))
	_curtain_mat.set_shader_parameter("glow", lerpf(0.04, 0.0, night))


## The moving fog, every frame: on in a hurricane (not `tame`), its banks blown downwind at the gale's speed, thicker
## in a gust and late in the night. Volumetric fog on the planet's environments (not space's, once the ship's gone up).
func _storm_fog(delta: float, gale: float, gust: float) -> void:
	var on := gale > 0.02 and not ocean.tame and moving_fog
	# the planet's own environment and, while the ship's down, the one the universe shows (the autopilot's copy of it;
	# never space's); a lab's
	var shown := get_world_3d().environment
	var envs: Array[Environment] = []
	if _planet == null:
		envs.append(shown)
	else:
		envs.append(_planet.get("environment") as Environment)
		if bool(_planet.call("is_live")) and shown != envs[0]:
			envs.append(shown)
	for env: Environment in envs:
		if env == null or env.volumetric_fog_enabled == on:
			continue
		env.volumetric_fog_enabled = on
		if on:
			env.volumetric_fog_density = 0.0  # (only StormFog's)
			env.volumetric_fog_albedo = Color.WHITE
			env.volumetric_fog_emission = Color.BLACK
			env.volumetric_fog_anisotropy = 0.3
			env.volumetric_fog_length = FOG_LENGTH
			env.volumetric_fog_detail_spread = 1.6
			env.volumetric_fog_gi_inject = 0.0
			env.volumetric_fog_ambient_inject = 1.0
			env.volumetric_fog_sky_affect = 0.6
			env.volumetric_fog_temporal_reprojection_enabled = true
			env.volumetric_fog_temporal_reprojection_amount = 0.6
	_fog.visible = on
	if not on:
		return
	var fury := ocean.fury
	var side := lerpf(GALE_SIDE.x, GALE_SIDE.y, gust) * lerpf(1.0, LATE_SPEED, fury)
	var wind := ocean.wind.normalized()
	_fog_drift += wind * side * FOG_SPEED * delta
	_fog_mat.set_shader_parameter("drift", _fog_drift)
	_fog_mat.set_shader_parameter("wind", wind)
	_fog_mat.set_shader_parameter("sea_y", ocean.global_position.y)
	if shown != null:
		_fog_mat.set_shader_parameter("tone", shown.fog_light_color * shown.fog_light_energy)
	_fog_mat.set_shader_parameter("thin", gale * lerpf(FOG_THIN.x, FOG_THIN.y, fury) * lerpf(1.0, 2.2, gust))
	_fog_mat.set_shader_parameter("thick", gale * lerpf(FOG_THICK.x, FOG_THICK.y, fury) * lerpf(1.0, 1.8, gust))
	_fog_mat.set_shader_parameter("spray", gale * lerpf(FOG_SPRAY.x, FOG_SPRAY.y, fury) * lerpf(1.0, 1.5, gust))
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_fog_mat.set_shader_parameter("eye", cam.global_position)
	_fog_mat.set_shader_parameter("pocket", POCKET * lerpf(1.0, POCKET_PEAK, gust))


## The moving fog: a FogVolume over the whole world (storm_fog.gdshader; the planet's HullMask keeps it out of the ship).
func _build_fog() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.06
	noise.fractal_octaves = 3
	var tex := NoiseTexture3D.new()
	tex.width = 64
	tex.height = 32
	tex.depth = 64
	tex.seamless = true
	tex.noise = noise
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = STORM_FOG
	_fog_mat.set_shader_parameter("churn", tex)
	_fog = FogVolume.new()
	_fog.name = "StormFog"
	_fog.shape = RenderingServer.FOG_VOLUME_SHAPE_WORLD
	_fog.material = _fog_mat
	_fog.visible = false
	add_child(_fog)


## Spray at `at` hits your visor if you're within `reach` m of it (harder the nearer), out in it.
func _spray_near(at: Vector3, reach: float, k: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position.distance_to(at)
	if d < reach:
		_wet_visor(k * lerpf(1.0, 0.4, d / reach))


func _wet_visor(k: float) -> void:
	if _visor != null and not ocean.tame:
		_visor.call("splash", k)


func _turn_on(p: GPUParticles3D, amount: float) -> void:
	p.amount_ratio = clampf(amount, 0.0, 1.0)
	var on := amount > 0.02
	if p.emitting != on:
		p.emitting = on


## The hurricane's rain: the gale (fine streaks), its grey sheets (gusts only), the splashes where the gale hits
## a deck or a roof (the height field's tops: a sub-emitter), the spindrift low over the sea. All in world space.
func _build_gale() -> void:
	_splash = _splashes()
	_gale = _streaks("RainGale", GALE_AMOUNT, 1.1, Vector3(16, 7, 16), Vector2(0.035, 0.7), 0.36, null)
	_gale_mat = (_gale.draw_pass_1 as QuadMesh).material as ShaderMaterial
	var gpm := _gale.process_material as ParticleProcessMaterial
	gpm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	gpm.sub_emitter_amount_at_collision = 1
	_gale.sub_emitter = _gale.get_path_to(_splash)
	_sheets = _streaks("RainSheets", 120, 1.6, Vector3(26, 5, 26), Vector2(7.0, 18.0), 0.16, PUFF)
	_sheet_mat = (_sheets.draw_pass_1 as QuadMesh).material as ShaderMaterial
	_sheet_mat.set_shader_parameter("near", Vector2(3.0, 10.0))
	_drift = _spindrift()
	_curtains = _rain_curtains()


## Curtains of rain out in the fog: tall bands stood on the sea in a ring 20 to 46 m round you, drifting downwind
## (rain_curtain.gdshader).
func _rain_curtains() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_height = 0.0
	pm.emission_ring_radius = 46.0
	pm.emission_ring_inner_radius = 20.0
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 12.0
	pm.flatness = 1.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 8.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.35
	_curtain_mat = ShaderMaterial.new()
	_curtain_mat.shader = CURTAIN
	var q := QuadMesh.new()  # (only its corners: the shader stands it up and sizes it)
	q.material = _curtain_mat
	var p := GPUParticles3D.new()
	p.name = "RainCurtains"
	p.amount = 18
	p.lifetime = 6.0
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-90, -40, -90), Vector3(180, 90, 180))
	p.emitting = false
	p.set_meta("own_fx", true)
	add_child(p)
	return p


func _streaks(node_name: String, amount: int, life: float, box: Vector3, size: Vector2, alpha: float,
		tex: Texture2D) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3.DOWN
	pm.spread = 3.0
	pm.initial_velocity_min = 15.0
	pm.initial_velocity_max = 18.0
	pm.gravity = Vector3(0, -2.0, 0)
	pm.particle_flag_align_y = true
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	var mat := ShaderMaterial.new()
	mat.shader = STREAK
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("alpha", alpha)
	if tex != null:
		mat.set_shader_parameter("tex", tex)
	var q := QuadMesh.new()  # (only its corners: the shader sizes it along the way it flies)
	q.material = mat
	var p := GPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-70, -45, -70), Vector3(140, 90, 140))
	p.emitting = false
	# (the planet leaves particles marked like this alone)
	p.set_meta("own_fx", true)
	add_child(p)
	return p


func _splashes() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 55.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.84, 0.88, 0.5)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.roughness = 0.3
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	q.material = mat
	var p := GPUParticles3D.new()
	p.name = "RainSplash"
	p.amount = 1500
	p.lifetime = 0.35
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-70, -45, -70), Vector3(140, 90, 140))
	p.set_meta("own_fx", true)
	add_child(p)
	return p


## Spindrift: white haze blown low and fast over the sea.
func _spindrift() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(45, 1.0, 45)
	pm.spread = 6.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.7
	pm.scale_max = 1.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.add_point(0.3, Color(1, 1, 1, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	pm.color_ramp = fade_tex
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.92, 0.95, 0.96, 0.13)
	mat.albedo_texture = PUFF
	# (streaks of blown foam, long along the wind and thin, not clouds: each turned to the way it's flying)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_spray_mats.append(mat)
	pm.particle_flag_align_y = true
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 8.0)
	q.material = mat
	var p := GPUParticles3D.new()
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	p.name = "Spindrift"
	p.amount = 70
	p.lifetime = 3.0
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-110, -10, -110), Vector3(220, 30, 220))
	p.emitting = false
	p.set_meta("own_fx", true)
	add_child(p)
	return p


## The night's moment: the glow under the rig, circling.
func _moment(delta: float) -> void:
	var m := moment_override
	if m < 0.0:
		m = float(_planet.get("moment")) if _planet != null else 0.0
	if m <= 0.001:
		if ocean.glow_spot.w != 0.0:
			ocean.glow_spot = Vector4.ZERO
		_moment_t = 0.0
		return
	_moment_t += delta
	var a := _moment_t * 0.09
	var at := rig_center + Vector2(cos(a), sin(a)) * 55.0
	ocean.glow_spot = Vector4(at.x, at.y, 28.0, m * 3.0)
	ocean.glow_heading = Vector2(-sin(a), cos(a))


func _puffs(amount: int, life: float, box: Vector3, spread: float, speed: Vector2, gravity: Vector3, size: float,
		alpha: float) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = gravity
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.94, 0.96, minf(alpha * 1.4, 0.9))
	mat.albedo_texture = PUFF
	# (thrown water: droplets streaked along their flight, not puffs of smoke)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pm.particle_flag_align_y = true
	var q := QuadMesh.new()
	q.size = Vector2(size * 0.22, size * 0.9)
	q.material = mat
	_spray_mats.append(mat)
	var p := GPUParticles3D.new()
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.8
	p.emitting = false
	p.process_material = pm
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-25, -10, -25), Vector3(50, 40, 50))
	# (the planet leaves particles marked like this alone)
	p.set_meta("own_fx", true)
	add_child(p)
	return p
