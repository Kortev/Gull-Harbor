extends Node3D
## A splash you can set off anywhere (world): white water thrown up and falling back, and its sound. A few of them
## take turns (POOL), so splashes in a row overlap. For a fish breaking the surface: a boil at the line on a run,
## a head shake, a tail thrashing alongside, the last circles near the top.

const PUFF := preload("res://sea/textures/steam_puff.png")
const SPLASH := preload("res://audio/fish/splash.wav")
const THRASH := preload("res://audio/fish/thrash.wav")
const POOL := 4

var _bursts: Array[GPUParticles3D] = []
var _sounds: Array[AudioStreamPlayer3D] = []
var _next := 0


func _ready() -> void:
	for i in POOL:
		var p := _particles()
		add_child(p)
		_bursts.append(p)
		var a := AudioStreamPlayer3D.new()
		a.unit_size = 10.0
		a.max_distance = 200.0
		a.top_level = true
		add_child(a)
		_sounds.append(a)


## White water at `at` (world), `size` 0.5 (a flick) .. 2 (a big fish thrashing); `thrash` the slapping sound, else a
## plain splash.
func burst(at: Vector3, size := 1.0, thrash := false) -> void:
	var k := _next % POOL
	_next += 1
	var p := _bursts[k]
	var pm := p.process_material as ParticleProcessMaterial
	pm.initial_velocity_min = 2.5 * size
	pm.initial_velocity_max = 5.5 * size
	pm.scale_min = 0.6 * size
	pm.scale_max = 1.6 * size
	p.global_position = at
	p.restart()
	p.emitting = true
	var a := _sounds[k]
	a.stream = THRASH if thrash else SPLASH
	a.global_position = at
	a.volume_db = linear_to_db(clampf(size, 0.3, 1.5))
	a.pitch_scale = randf_range(0.85, 1.15) / sqrt(maxf(size, 0.3))
	a.play()


static func _particles() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.gravity = Vector3(0, -9.8, 0)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.95))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = PUFF
	mat.albedo_color = Color(0.92, 0.95, 0.97)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.material = mat
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.2
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	p.local_coords = false
	p.top_level = true
	p.process_material = pm
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 16, 16))
	return p
