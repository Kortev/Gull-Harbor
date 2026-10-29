extends Node3D
## Bluefin schools passing the boat. The host starts one every minute or so, somewhere out on the horizon, heading
## to cross the spread astern; from then on where it is, when it's feeding and where it busts are all worked out
## from the shared sea clock and the school's seed, so every peer sees the same birds and the same busting water.
##
## How you find them: birds working over them (wheeling, diving when the tuna push bait up), the water busting
## white where they feed, tuna clearing the water, and marks on the helm's sonar when they're close. A feeding
## school crossing a bait gets it eaten: rods.gd hooks the fish (host only, strike()).

const Tuna := preload("res://tuna/tuna.gd")
const GULLS: Array[AudioStream] = [preload("res://audio/fish/gull_1.wav"), preload("res://audio/fish/gull_2.wav"),
		preload("res://audio/fish/gull_3.wav")]
const SPLASH := preload("res://audio/fish/splash.wav")
const PUFF := preload("res://sea/textures/steam_puff.png")
## Where the schools aim to cross, boat-local: astern, through the spread.
const AIM := Vector3(0.0, 0.0, 45.0)
const FAR := 230.0
const MAX_SCHOOLS := 2

var sea: Node                       # sea/sea.gd
var schools: Array[School] = []
## Seconds until the host starts the next school (the first comes quickly).
var _next := 8.0
## How far out the next school shows up (m): FAR, or closer for screenshots and tests.
var start_far := FAR
var _ids := 0


static func hash1(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)


func ocean() -> Node:
	return sea.get("ocean") as Node


func now() -> float:
	return float(ocean().get("wave_time"))


func _ready() -> void:
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			for s in schools:
				_start.rpc_id(id, s.id, s.seed, s.t0, s.start, s.heading, s.speed, s.kg))


func _process(delta: float) -> void:
	if Net.is_host():
		_next -= delta
		if _next <= 0.0:
			_next = randf_range(45.0, 100.0)
			if schools.size() < MAX_SCHOOLS:
				_host_start()
	for s in schools.duplicate():
		if s.done(now()):
			schools.erase(s)
			s.queue_free()
	if Net.is_host():
		_strikes(delta)


## Host: a feeding school over a bait eats it now and then (more than one rod can go: a double header).
func _strikes(delta: float) -> void:
	var spread := sea.get("rods") as Node
	if spread == null:
		return
	var t := now()
	# a second fish while one's on happens, but rarely: a double is a story, not the routine
	var on := 0
	for r: Node3D in spread.get("rods"):
		on += 1 if bool(r.get("hooked")) else 0
	var chance := 0.3 * (1.0 if on == 0 else 0.015)
	for s in schools:
		if not s.feeding(t):
			continue
		var c := s.center(t)
		for r: Node3D in spread.get("rods"):
			if bool(r.get("hooked")):
				continue
			var bait: Vector3 = r.get("line_end")
			if Vector2(bait.x, bait.z).distance_to(c) < s.radius + 6.0 and randf() < delta * chance:
				spread.call("strike", int(r.get("index")), clampf(s.kg * randf_range(0.8, 1.2), Tuna.MIN_KG,
						Tuna.MAX_KG))


## Host: a new school out on the horizon, aimed to cross astern.
func _host_start() -> void:
	_ids += 1
	var bearing := randf_range(-PI, PI)
	var aim := AIM + Vector3(randf_range(-20, 20), 0, randf_range(-12, 15))
	var start := aim + Vector3(cos(bearing), 0, sin(bearing)) * start_far
	start_far = FAR
	var heading := (aim - start).normalized().rotated(Vector3.UP, randf_range(-0.12, 0.12))
	var kg := randf_range(60.0, 330.0) if randf() < 0.85 else randf_range(330.0, 400.0)
	var args := [_ids, randi(), now() + 0.5, Vector2(start.x, start.z), Vector2(heading.x, heading.z),
			randf_range(3.0, 5.5), kg]
	if Net.in_session():
		_start.rpc.callv(args)
	else:
		_start.callv(args)


@rpc("authority", "call_local", "reliable")
func _start(id: int, seed: int, t0: float, start: Vector2, heading: Vector2, speed: float, kg: float) -> void:
	var s := School.new()
	s.id = id
	s.seed = seed
	s.t0 = t0
	s.start = start
	s.heading = heading.normalized()
	s.speed = speed
	s.kg = kg
	s.owner_node = self
	add_child(s)
	schools.append(s)


## The schools within `reach` m of a point (world), for the sonar and the strikes.
func near(p: Vector3, reach: float) -> Array[School]:
	var out: Array[School] = []
	var t := now()
	for s in schools:
		var c := s.center(t)
		if Vector2(p.x, p.z).distance_to(c) < reach:
			out.append(s)
	return out


## One school: its path, its birds, its busting. Purely a function of the clock (and its seed) after it starts.
class School extends Node3D:
	var id := 0
	var seed := 0
	var t0 := 0.0
	var start := Vector2.ZERO
	var heading := Vector2.ZERO
	var speed := 4.0
	var kg := 150.0
	var radius := 14.0
	var owner_node: Node
	var _birds: Array[MeshInstance3D] = []
	var _bird_seed: Array[Vector4] = []
	var _jumpers: Array[Node3D] = []
	var _jump_v: Array[Vector3] = []
	var _splashes: Array[GPUParticles3D] = []
	var _sounds: Array[AudioStreamPlayer3D] = []
	var _gull: AudioStreamPlayer3D
	var _bust_slot := -1
	var _next_splash := 0
	var _gull_in := 2.0

	func center(t: float) -> Vector2:
		var d := maxf(t - t0, 0.0)
		var side := Vector2(-heading.y, heading.x)
		return start + heading * speed * d + side * sin(d * 0.07 + seed) * 6.0

	## Feeding: in spells of a few seconds, more often than not, and nearly always near the boat (the baits drew it).
	func feeding(t: float) -> bool:
		var spell := floorf((t - t0) / 7.0)
		var near := center(t0 + spell * 7.0).length() < 90.0
		return (owner_node as Node).call("hash1", float(seed % 1000), spell) > (0.15 if near else 0.45)

	func done(t: float) -> bool:
		return t - t0 > 2.0 * 230.0 / speed + 10.0

	func _ready() -> void:
		var bird_mesh := _bird_mesh()
		var n := 12 + seed % 9
		for i in n:
			var b := MeshInstance3D.new()
			b.mesh = bird_mesh
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(b)
			_birds.append(b)
			var h := func(k: float) -> float: return owner_node.call("hash1", float(seed % 997) + i, k)
			# radius, height, speed (rad/s, signed), phase
			_bird_seed.append(Vector4(5.0 + 12.0 * h.call(1.0), 3.0 + 7.0 * h.call(2.0),
					(0.5 + 0.6 * h.call(3.0)) * (1.0 if h.call(4.0) > 0.5 else -1.0), TAU * h.call(5.0)))
		for i in 3:
			var j := Tuna.new(kg * randf_range(0.75, 1.25))
			j.visible = false
			add_child(j)
			_jumpers.append(j)
			_jump_v.append(Vector3.ZERO)
		for i in 4:
			var p := _splash_particles()
			add_child(p)
			_splashes.append(p)
			var a := AudioStreamPlayer3D.new()
			a.stream = SPLASH
			a.unit_size = 18.0
			a.max_distance = 300.0
			a.volume_db = 2.0
			add_child(a)
			_sounds.append(a)
		_gull = AudioStreamPlayer3D.new()
		_gull.unit_size = 25.0
		_gull.max_distance = 350.0
		add_child(_gull)

	func _process(delta: float) -> void:
		var o := owner_node.get("sea").get("ocean") as Node
		var t := float(o.get("wave_time"))
		var c2 := center(t)
		var c := Vector3(c2.x, 0.0, c2.y)
		var feed := feeding(t)
		# the birds: wheeling over the school, low and diving when it feeds
		for i in _birds.size():
			var bs := _bird_seed[i]
			var a := bs.w + t * bs.z
			var low := 1.0 if feed else 0.0
			var h := lerpf(bs.y, 1.2 + bs.y * 0.25, low * (0.5 + 0.5 * sin(t * 1.3 + i)))
			var p := c + Vector3(cos(a) * bs.x, 0.0, sin(a) * bs.x)
			p.y = float(o.call("height_at", p)) + h
			var b := _birds[i]
			b.position = p
			var fwd := Vector3(-sin(a), 0.0, cos(a)) * signf(bs.z)
			b.basis = Basis.looking_at(fwd, Vector3.UP).rotated(fwd, -0.5 * signf(bs.z)) \
					.scaled(Vector3(1.0, 0.4 + 0.6 * absf(sin(t * 9.0 + i * 1.7)), 1.0))
		_gull_in -= delta
		if _gull_in <= 0.0:
			_gull_in = randf_range(2.0, 6.0) if feed else randf_range(6.0, 14.0)
			_gull.stream = GULLS[randi() % GULLS.size()]
			_gull.pitch_scale = randf_range(0.85, 1.15)
			_gull.position = _birds[randi() % _birds.size()].position
			_gull.play()
		# busting: a burst of white water every half second or so while it feeds; every third, a tuna clears it
		var slot := int(floorf((t - t0) / 0.45))
		if feed and slot != _bust_slot:
			_bust_slot = slot
			var r := radius * sqrt(owner_node.call("hash1", float(seed % 991), float(slot)))
			var ang := TAU * float(owner_node.call("hash1", float(slot), float(seed % 983)))
			var p := c + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			p.y = float(o.call("height_at", p))
			_bust(p, slot % 3 == 0)
		for i in _jumpers.size():
			var j := _jumpers[i]
			if not j.visible:
				continue
			_jump_v[i].y -= 9.8 * delta
			j.velocity = _jump_v[i]
			if j.position.y < float(o.call("height_at", j.position)) - 0.5 and _jump_v[i].y < 0.0:
				j.visible = false
				_bust(j.position, false)

	func _bust(p: Vector3, leap: bool) -> void:
		var k := _next_splash % _splashes.size()
		_next_splash += 1
		var s := _splashes[k]
		s.global_position = p
		s.restart()
		s.emitting = true
		_sounds[k].global_position = p
		_sounds[k].pitch_scale = randf_range(0.7, 1.1)
		_sounds[k].play()
		if leap:
			for i in _jumpers.size():
				var j := _jumpers[i]
				if j.visible:
					continue
				var dir := Vector3(heading.x, 0.0, heading.y).rotated(Vector3.UP, randf_range(-1.2, 1.2))
				j.position = p
				_jump_v[i] = dir * randf_range(4.0, 7.0) + Vector3.UP * randf_range(4.0, 6.0)
				j.velocity = _jump_v[i]
				j.effort = 1.0
				j.visible = true
				break

	func _splash_particles() -> GPUParticles3D:
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.8
		pm.direction = Vector3.UP
		pm.spread = 35.0
		pm.initial_velocity_min = 4.0
		pm.initial_velocity_max = 9.0
		pm.gravity = Vector3(0, -9.8, 0)
		pm.scale_min = 0.8
		pm.scale_max = 2.2
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
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var q := QuadMesh.new()
		q.size = Vector2(1.4, 1.4)
		q.material = mat
		var p := GPUParticles3D.new()
		p.amount = 60
		p.lifetime = 1.3
		p.one_shot = true
		p.explosiveness = 0.9
		p.emitting = false
		p.local_coords = false
		p.process_material = pm
		p.draw_pass_1 = q
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_aabb = AABB(Vector3(-10, -5, -10), Vector3(20, 20, 20))
		return p

	## A shearwater (they work the bluefin schools): a shallow W, dark, a metre and a half across, bigger than life so
	## it reads against a grey sky from the boat.
	static func _bird_mesh() -> ArrayMesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts := [Vector3(-0.8, 0.12, 0.08), Vector3(-0.36, 0.0, -0.12), Vector3(0, 0.03, -0.36),
				Vector3(0.36, 0.0, -0.12), Vector3(0.8, 0.12, 0.08), Vector3(0, -0.03, 0.3)]
		for tri: Array in [[0, 1, 5], [1, 2, 5], [2, 3, 5], [3, 4, 5]]:
			for k: int in tri:
				st.add_vertex(pts[k])
			for k: int in [tri[2], tri[1], tri[0]]:
				st.add_vertex(pts[k])
		st.generate_normals()
		var m := st.commit()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.19, 0.18)
		mat.roughness = 1.0
		m.surface_set_material(0, mat)
		return m
