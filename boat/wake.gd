extends Node3D
## Her going, seen, heard and felt (a child of boat/boat.gd): the engines' rumble rising with the throttle, her wake
## painted on the water behind her (sea/ocean.gd's add_wake: the churn, the V's arms spreading out, riding every
## wave), the water churning white astern of the transom when the screws bite, spray thrown off her bow at speed,
## and backing down hard, the sea slopping in over the transom. All of it from the helm's word
## (boat/helm.gd: her speed and throttle), so every peer sees and hears the same.

const Helm := preload("res://boat/helm.gd")
const Sfx := preload("res://audio/sfx.gd")
const PUFF := preload("res://sea/textures/steam_puff.png")
var boat: Node3D              # boat/boat.gd
## Boat-local, from her kind (boat/kinds.gd): her transom (where the wash boils up), her engines, her bow's flare.
var _transom := Vector3(0.0, 0.0, 7.3)
var _wash: GPUParticles3D
var _wake_in := 0.0
var _spray: Array[GPUParticles3D] = []
var _over: GPUParticles3D
var _engine: Node
var _rumble: Node
var _over_in := 0.0


func _ready() -> void:
	boat.connect("rebuilt", _place)
	_wash = _particles(140, 1.6, true, Vector3(0.0, 1.0, 0.0), 40.0, Vector2(0.5, 2.0), Vector3(0, -6.0, 0), 1.3, 0.8)
	_wash.name = "PropWash"
	add_child(_wash)
	for side: float in [1.0, -1.0]:
		var s := _particles(220, 0.8, true, Vector3(side, 0.55, -0.25), 22.0, Vector2(3.5, 7.5), Vector3(0, -9.8, 0),
				0.35, 0.85, true)
		s.name = "BowSpray" + ("Starboard" if side > 0.0 else "Port")
		s.set_meta("side", side)
		add_child(s)
		_spray.append(s)
	_over = _particles(80, 1.4, true, Vector3(0.0, 1.0, -0.8), 30.0, Vector2(3.0, 5.5), Vector3(0, -9.8, 0), 1.0, 0.9)
	_over.name = "OverTheTransom"
	_over.one_shot = true
	_over.explosiveness = 0.85
	add_child(_over)
	# the engines: a motor loop pitched down to a diesel's grumble, and a low rumble under it
	var room := Node3D.new()
	room.name = "Engines"
	add_child(room)
	_engine = Sfx.loop(room, "kit.motor", true, 0.3)
	_rumble = Sfx.loop(room, "kit.rumble", false, 0.15)
	_place()


## Her spots from her kind (and again whenever she's rebuilt as another).
func _place() -> void:
	var spec: Dictionary = boat.get("spec")
	_transom = spec.get("transom", _transom)
	var bow: Vector3 = spec.get("bow", Vector3(1.7, 0.6, -5.0))
	for s in _spray:
		s.position = Vector3(bow.x * float(s.get_meta("side")), bow.y, bow.z)
	_over.position = Vector3(0.0, 0.9, float(spec.get("stern", Vector3(0, 0, 7.05)).z))
	(get_node("Engines") as Node3D).position = spec.get("engines", Vector3(0.0, 0.3, 3.5))


func _process(delta: float) -> void:
	var helm: Node = boat.get("helm")
	var ocean: Node = boat.get("ocean")
	if helm == null or ocean == null:
		return
	var v := float(helm.get("speed"))
	var gas := float(helm.get("throttle"))
	var going := absf(v)
	# the engines: idling, rising with the throttle and her speed
	var work := absf(gas)
	Sfx.level(_engine, 0.3 + 0.7 * work, 0.55 + 0.4 * work + 0.02 * going)
	Sfx.level(_rumble, 0.15 + 0.35 * work, 0.7 + 0.3 * work)
	# the wake: a point of it every few metres she goes (and every so often when she's slow), painted on the water
	var stern := boat.global_transform * _transom
	stern.y = float(ocean.call("height_at", stern)) + 0.05
	_wake_in -= delta
	# (the sea paints one trail: VS, the boat you're on; two boats' points in one trail would streak between them)
	var follow: Variant = ocean.get("follow")
	if _wake_in <= 0.0 and (follow == null or follow == boat):
		_wake_in = clampf(2.5 / maxf(going, 0.5), 0.12, 0.6)
		ocean.call("add_wake", stern, clampf(going / 8.0, 0.0, 1.0) if going > 0.3 else 0.0)
	# the screws biting: white water boiling up astern of her
	_wash.global_position = stern + boat.global_basis.z * 0.6
	_wash.emitting = work > 0.15
	_wash.amount_ratio = clampf(work, 0.2, 1.0)
	# her bow throwing spray, flat out
	var top := float(helm.get("ahead"))
	for s in _spray:
		s.emitting = v > top * 0.45
		s.amount_ratio = clampf((v - top * 0.45) / (top * 0.4), 0.2, 1.0)
	# backing down hard: the sea slops in over the transom now and then, with a slap
	_over_in -= delta
	if gas < -0.6 and v < -float(helm.get("astern")) * 0.5 and _over_in <= 0.0:
		_over_in = randf_range(1.2, 2.6)
		_over.restart()
		_over.emitting = true
		Sfx.play_point(self, _over.global_position, "sea.back", 0.8)


## Particles in the world (they stay where they were thrown, so she leaves them behind): white puffs. `upright` false
## lays them flat on the water (the wake's foam), true stands them up facing you (spray).
func _particles(amount: int, life: float, upright: bool, dir: Vector3, spread: float, speed: Vector2,
		gravity: Vector3, size: float, alpha: float, drops := false) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.8
	pm.direction = dir if dir != Vector3.ZERO else Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = gravity
	pm.scale_min = 0.7
	pm.scale_max = 1.5
	if not upright:
		# foam on the water: drifting flat on it, spreading slowly as it fades
		pm.flatness = 1.0
		pm.scale_curve = _ramp(0.6, 1.8)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, alpha))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = PUFF
	mat.albedo_color = Color(0.9, 0.94, 0.96)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var p := GPUParticles3D.new()
	if drops:
		# spray: droplets, streaked along the way they're flying, a few big blobs among many fine ones
		pm.scale_min = 0.4
		pm.scale_max = 1.6
		pm.particle_flag_align_y = true
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.billboard_keep_scale = true
		var dq := QuadMesh.new()
		dq.size = Vector2(size * 0.35, size * 1.6)
		dq.material = mat
		p.draw_pass_1 = dq
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	elif upright:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		q.material = mat
		p.draw_pass_1 = q
	else:
		var flat := PlaneMesh.new()
		flat.size = Vector2(size, size)
		flat.material = mat
		p.draw_pass_1 = flat
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.process_material = pm
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 30, 120))
	return p


static func _ramp(from: float, to: float) -> CurveTexture:
	var c := Curve.new()
	c.max_value = maxf(from, to)
	c.add_point(Vector2(0.0, from))
	c.add_point(Vector2(1.0, to))
	var t := CurveTexture.new()
	t.curve = c
	return t
