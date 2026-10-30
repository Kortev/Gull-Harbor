class_name Leads
extends RefCounted
## Leads to a school besides its birds (tuna/schools.gd): a whale feeding on the same bait, or a pod of dolphins working
## through it. Like the birds they're there whether or not there are bluefin under them (a bait-only school has them
## too): a lead says there's bait, not that there's tuna. Purely a function of the sea clock and the school's seed, so
## every peer sees the same whale blow at the same moment.
##
## A whale: up a few times, a breath apart (BREATHS, BREATH s), each time a tall blow you can see a long way off (drawn
## no smaller than a few pixels, like the birds), its back rolling over; then its flukes up and it's gone down for the
## rest of its DIVE s. Dolphins: a pod leaping along in arcs round the school, white water where they go in. Only
## close enough to pick out the splashes (POD_SEEN m).

const BLOW := preload("res://audio/bank/b_geyser.ogg")
const PUFF := preload("res://sea/textures/steam_puff.png")
## Of the schools: how many have a whale on them, how many dolphins (from the seed, after the whale's share).
const WHALE_SHARE := 0.3
const POD_SHARE := 0.3
## A whale's breathing: breaths a surfacing, seconds between them, and the whole cycle (the rest is the dive).
const BREATHS := 3
const BREATH := 13.0
const DIVE := 85.0
## How long the back's up a breath (s), how far it swims along meanwhile (m), its length (m).
const ROLL := 6.0
const WHALE_LEN := 13.0
## How far off a pod's splashes can be picked out (m) and the smallest a far blow's drawn (pixels across).
const POD_SEEN := 1600.0
const BLOW_PX := 6.0

enum { NONE, WHALE, DOLPHINS }

## (screenshots and tests: every school gets this lead, a whale starting on its first breath; -1: as the seed says)
static var force := -1


## What's on school `seed` (everyone agrees).
static func kind_of(seed: int) -> int:
	var h := fposmod(sin(float(seed % 971) * 12.9898 + 9.1 * 78.233) * 43758.5453, 1.0)
	if h < WHALE_SHARE:
		return WHALE
	return DOLPHINS if h < WHALE_SHARE + POD_SHARE else NONE


static func make(seed: int) -> Node3D:
	match kind_of(seed) if force < 0 else force:
		WHALE:
			return Whale.new()
		DOLPHINS:
			return Pod.new()
	return null


## What you'd see of it from far off (crew/spotter.gd), or "" when there's nothing to see right now.
static func far_text(lead: Node3D, dist: float) -> String:
	if lead is Whale and (lead as Whale).blowing > 0.0:
		return "A whale blowing"
	if lead is Pod and dist < POD_SEEN:
		return "Splashes"
	return ""


## What it says about the school close up (put before the birds' story).
static func near_text(lead: Node3D) -> String:
	if lead is Whale:
		return "Whale feeding."
	if lead is Pod:
		return "Dolphins."
	return ""


## Drawn no smaller than `px` pixels across `size` m at p (a far whale or pod still reads on the horizon).
static func speck(node: Node3D, p: Vector3, size: float, px: float) -> float:
	var cam := node.get_viewport().get_camera_3d()
	if cam == null:
		return 1.0
	var per := 2.0 * tan(deg_to_rad(cam.fov) * 0.5) * cam.global_position.distance_to(p) \
			/ maxf(node.get_viewport().get_visible_rect().size.y, 1.0)
	return maxf(1.0, px * per / size)


static func _puffs(amount: int, life: float, up: Vector2, size: float, spread: float) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = up.x
	pm.initial_velocity_max = up.y
	pm.gravity = Vector3(0, -2.5, 0)
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.scale_min = 0.8
	pm.scale_max = 1.8
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = PUFF
	mat.albedo_color = Color(0.93, 0.95, 0.97)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# (the scene's fog would wipe a blow out a few hundred metres off: a blow on the horizon is what you look for)
	mat.disable_fog = true
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.85
	p.emitting = false
	p.local_coords = true
	p.process_material = pm
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-15, -5, -15), Vector3(30, 30, 30))
	return p


## A low-poly body along -z (nose), `len` m, round in section, from a profile of (u along it 0 nose .. 1 tail,
## half width, half height, centre height) samples; dark above.
static func _body(len: float, profile: Array, ring: int, top: Color, belly: Color) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for s: Vector4 in profile:
		var pts := PackedVector3Array()
		for j in ring:
			var a := TAU * j / ring
			pts.append(Vector3(cos(a) * s.y, s.w + sin(a) * s.z, (s.x - 0.5) * len))
		rings.append(pts)
	for i in rings.size() - 1:
		for j in ring:
			var j1 := (j + 1) % ring
			var quad := [rings[i][j], rings[i][j1], rings[i + 1][j1], rings[i + 1][j]]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = quad[k]
				st.set_color(top if v.y > profile[i].w - 0.1 else belly)
				st.add_vertex(v)
	return st


static func _tri(st: SurfaceTool, c: Color, a: Vector3, b: Vector3, d: Vector3) -> void:
	st.set_color(c)
	for v: Vector3 in [a, b, d, a, d, b]:
		st.add_vertex(v)


static func _mesh(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	return m


## A humpback-ish whale: up to breathe on the school's bait, blowing, then down with its flukes up.
class Whale extends Node3D:
	var school: Node3D
	var ocean: Node
	## The blow now (0 none .. 1 just up: crew/spotter.gd says so), and where it was last (world).
	var blowing := 0.0
	var _body_i: MeshInstance3D
	var _spout: GPUParticles3D
	var _sound: AudioStreamPlayer3D
	var _breath := -1
	var _off := Vector2.ZERO
	var _phase := 0.0

	func _ready() -> void:
		var sd := float(school.get("seed"))
		_phase = fposmod(sd * 0.37, 1.0) * (BREATHS * BREATH + DIVE)
		if Leads.force == WHALE:
			_phase = -float(ocean.get("wave_time")) + 0.5
		var a := fposmod(sd * 1.7, TAU)
		_off = Vector2(cos(a), sin(a)) * (18.0 + fposmod(sd, 15.0))
		_body_i = MeshInstance3D.new()
		_body_i.mesh = _whale_mesh()
		_body_i.top_level = true
		add_child(_body_i)
		_spout = Leads._puffs(26, 3.2, Vector2(6.0, 10.0), 1.6, 9.0)
		_spout.top_level = true
		add_child(_spout)
		_sound = AudioStreamPlayer3D.new()
		_sound.stream = BLOW
		_sound.unit_size = 40.0
		_sound.max_distance = 900.0
		_sound.pitch_scale = 0.55
		_sound.volume_db = -2.0
		_sound.top_level = true
		add_child(_sound)

	func _process(_delta: float) -> void:
		var t := float(ocean.get("wave_time"))
		var cyc := BREATHS * BREATH + DIVE
		var u := fposmod(t + _phase, cyc)
		var breath := int(floorf(u / BREATH))
		var in_b := u - breath * BREATH
		var heading: Vector2 = school.get("heading")
		if heading == Vector2.ZERO:
			heading = Vector2(0, -1)
		var c: Vector2 = school.call("center", t) + _off
		var fwd := Vector3(heading.x, 0.0, heading.y)
		var fluke := breath == BREATHS - 1 and in_b < ROLL
		if breath < BREATHS and in_b < ROLL:
			# its back rolling up over the swell and down again, swimming on as it goes; the last time steeply, flukes up
			var k := in_b / ROLL
			var along := (k - 0.5) * 9.0
			var p := Vector3(c.x, 0.0, c.y) + fwd * along
			var sea := float(ocean.call("height_at", p))
			var rise := sin(PI * k)
			p.y = sea - 2.3 + 2.8 * rise - (smoothstep(0.55, 1.0, k) * 1.5 if fluke else 0.0)
			var pitch := -cos(PI * k) * (0.22 if not fluke else lerpf(0.22, 1.1, smoothstep(0.35, 0.9, k)))
			var basis := Basis.looking_at(fwd, Vector3.UP)
			basis = basis.rotated(basis.x, pitch)
			var s := Leads.speck(self, p, WHALE_LEN, 10.0)
			_body_i.global_transform = Transform3D(basis.scaled(Vector3.ONE * s), p)
			_body_i.visible = true
			if breath != _breath and k < 0.4:
				# the blow, as soon as the blowhole's out
				_breath = breath
				var hole := p + fwd * (WHALE_LEN * 0.18 * s) + Vector3.UP * 0.6 * s
				var sp := Leads.speck(self, hole, 5.0, BLOW_PX)
				_spout.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * sp), hole)
				_spout.restart()
				_spout.emitting = true
				_sound.global_position = hole
				_sound.play()
		else:
			_body_i.visible = false
		var since := in_b if breath < BREATHS else 99.0
		blowing = clampf(1.0 - since / 4.0, 0.0, 1.0)

	static func _whale_mesh() -> ArrayMesh:
		var top := Color(0.1, 0.11, 0.13)
		var belly := Color(0.42, 0.44, 0.46)
		# (u, half width, half height, centre height)
		var prof := [Vector4(0.0, 0.05, 0.05, 0.0), Vector4(0.06, 0.9, 0.6, 0.0), Vector4(0.2, 1.5, 1.15, 0.05),
				Vector4(0.42, 1.55, 1.25, 0.1), Vector4(0.62, 1.15, 0.95, 0.15), Vector4(0.8, 0.6, 0.55, 0.15),
				Vector4(0.94, 0.25, 0.3, 0.1), Vector4(1.0, 0.12, 0.15, 0.1)]
		var st := Leads._body(WHALE_LEN, prof, 8, top, belly)
		var z := func(u: float) -> float: return (u - 0.5) * WHALE_LEN
		# flukes, wide and flat, at the tail
		Leads._tri(st, top, Vector3(0, 0.1, z.call(0.97)), Vector3(-2.3, 0.15, z.call(1.08)), Vector3(-0.3, 0.1, z.call(1.0)))
		Leads._tri(st, top, Vector3(0, 0.1, z.call(0.97)), Vector3(2.3, 0.15, z.call(1.08)), Vector3(0.3, 0.1, z.call(1.0)))
		# long flippers, a small dorsal fin
		Leads._tri(st, belly, Vector3(-1.3, -0.4, z.call(0.24)), Vector3(-4.0, -1.2, z.call(0.42)), Vector3(-1.3, -0.5, z.call(0.33)))
		Leads._tri(st, belly, Vector3(1.3, -0.4, z.call(0.24)), Vector3(4.0, -1.2, z.call(0.42)), Vector3(1.3, -0.5, z.call(0.33)))
		Leads._tri(st, top, Vector3(0, 0.95, z.call(0.62)), Vector3(0, 1.45, z.call(0.68)), Vector3(0, 0.85, z.call(0.72)))
		return Leads._mesh(st)


## A pod of dolphins leaping along round the school, each going in with a little white water.
class Pod extends Node3D:
	var school: Node3D
	var ocean: Node
	var _bodies: Array[MeshInstance3D] = []
	var _seed: Array[Vector4] = []       # angle round, distance out, leap period, phase
	var _was_up: Array[bool] = []
	var _splash: Array[GPUParticles3D] = []
	var _next := 0

	func _ready() -> void:
		var sd := int(school.get("seed"))
		var mesh := _dolphin_mesh()
		var n := 6 + sd % 5
		for i in n:
			var b := MeshInstance3D.new()
			b.mesh = mesh
			b.top_level = true
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(b)
			_bodies.append(b)
			var h := func(k: float) -> float: return fposmod(sin(float(sd % 991 + i) * 12.9898 + k * 78.233) * 43758.5453, 1.0)
			_seed.append(Vector4(TAU * h.call(1.0), 8.0 + 22.0 * h.call(2.0), 2.2 + 1.6 * h.call(3.0), 10.0 * h.call(4.0)))
			_was_up.append(false)
		for i in 4:
			var p := Leads._puffs(18, 0.9, Vector2(2.0, 4.0), 0.9, 30.0)
			p.top_level = true
			add_child(p)
			_splash.append(p)

	func _process(_delta: float) -> void:
		var t := float(ocean.get("wave_time"))
		var c: Vector2 = school.call("center", t)
		var heading: Vector2 = school.get("heading")
		if heading == Vector2.ZERO:
			heading = Vector2(0, -1)
		for i in _bodies.size():
			var sd := _seed[i]
			var b := _bodies[i]
			# each goes round the school its own way, leaping clear part of each stroke
			var a := sd.x + t * 0.12 * (1.0 if i % 2 == 0 else -1.0)
			var tangent := Vector2(-sin(a), cos(a)) * (1.0 if i % 2 == 0 else -1.0)
			var dir := (tangent * 0.6 + heading * 0.4).normalized()
			var at := c + Vector2(cos(a), sin(a)) * sd.y
			var k := fposmod(t + sd.w, sd.z) / sd.z
			var up := k < 0.42
			if up:
				var u := k / 0.42
				var fwd := Vector3(dir.x, 0.0, dir.y)
				var p := Vector3(at.x, 0.0, at.y) + fwd * (u - 0.5) * 3.5
				p.y = float(ocean.call("height_at", p)) - 0.6 + 1.7 * sin(PI * u)
				var basis := Basis.looking_at(fwd, Vector3.UP)
				basis = basis.rotated(basis.x, -cos(PI * u) * 0.75)
				var s := Leads.speck(self, p, 2.2, 3.0)
				b.global_transform = Transform3D(basis.scaled(Vector3.ONE * s), p)
			elif _was_up[i]:
				# in again: white water (drawn bigger far off, so a pod reads as splashes on the horizon)
				var sp := _splash[_next % _splash.size()]
				_next += 1
				var q := b.global_position
				q.y = float(ocean.call("height_at", q))
				var s2 := Leads.speck(self, q, 2.5, 4.0)
				sp.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * minf(s2, 8.0)), q)
				sp.restart()
				sp.emitting = true
			b.visible = up
			_was_up[i] = up

	static func _dolphin_mesh() -> ArrayMesh:
		var top := Color(0.2, 0.23, 0.27)
		var belly := Color(0.7, 0.72, 0.74)
		var len := 2.2
		var prof := [Vector4(0.0, 0.03, 0.03, -0.02), Vector4(0.08, 0.07, 0.07, -0.02), Vector4(0.16, 0.18, 0.2, 0.0),
				Vector4(0.4, 0.24, 0.27, 0.02), Vector4(0.65, 0.17, 0.2, 0.02), Vector4(0.88, 0.07, 0.09, 0.02),
				Vector4(1.0, 0.03, 0.04, 0.02)]
		var st := Leads._body(len, prof, 7, top, belly)
		var z := func(u: float) -> float: return (u - 0.5) * len
		Leads._tri(st, top, Vector3(0, 0.25, z.call(0.4)), Vector3(0, 0.55, z.call(0.55)), Vector3(0, 0.22, z.call(0.58)))
		Leads._tri(st, top, Vector3(0, 0.02, z.call(0.97)), Vector3(-0.38, 0.02, z.call(1.08)), Vector3(0, 0.02, z.call(1.02)))
		Leads._tri(st, top, Vector3(0, 0.02, z.call(0.97)), Vector3(0.38, 0.02, z.call(1.08)), Vector3(0, 0.02, z.call(1.02)))
		Leads._tri(st, top, Vector3(-0.2, -0.08, z.call(0.3)), Vector3(-0.45, -0.2, z.call(0.42)), Vector3(-0.2, -0.1, z.call(0.4)))
		Leads._tri(st, top, Vector3(0.2, -0.08, z.call(0.3)), Vector3(0.45, -0.2, z.call(0.42)), Vector3(0.2, -0.1, z.call(0.4)))
		return Leads._mesh(st)
