extends Node3D
## Green water (a child of boat/boat.gd): in a big sea a crest now and then tops her rail. Where it does, a sheet of
## white water bursts in over the rail with a crash, and for a while after the deck streams with foam running aft to
## the scuppers. The sea's the same on every peer (sea/ocean.gd's wave clock), so everyone sees the same crests come
## aboard. Her rail comes from her kind (boat/kinds.gd's "rail": points on her starboard rail; port mirrors it).
## It doesn't knock anyone down or wash anything over (both Rivals boats ride the same sea), but it stays aboard: a
## small open boat fills (`water`, of what she can take: each sea her kind's "swamp" of it, a deep sea more) faster
## than her bilge pump clears it ("bilge" a second), and with water in her she's heavy and slow (boat/helm.gd's
## top_speed). The sportfisher's self-bailing cockpit and high rail hardly notice.

const Sfx := preload("res://audio/sfx.gd")
const PUFF := preload("res://sea/textures/steam_puff.png")
## How often a spot on the rail can take another sea (s), and how long the deck streams after one.
const AGAIN := 1.2
const STREAM_S := 6.0

var boat: Node3D              # boat/boat.gd
## Times a sea's come aboard (tests), and how much the deck's streaming now (0..1).
var bursts := 0
var streaming := 0.0
## Water aboard her (0 dry .. 1 as much as she can take), and whether she's been told she's taking it.
var water := 0.0
var _told := false
var _rail: Array[Vector3] = []
var _wait: Array[float] = []
var _sheets: Array[GPUParticles3D] = []
var _next_sheet := 0
var _deck_wash: GPUParticles3D
## The water itself on her deck (a sheet over her sole, _show_water), and her scuppers pouring it out over her transom.
var _deck_water: MeshInstance3D
var _drains: Array[GPUParticles3D] = []
var _flow := Vector3.ZERO
## How deep (m) the sheet runs over her deck just after a sea, and stands in her when she's as full as she can be.
const STREAM_DEEP := 0.05
const FULL_DEEP := 0.3


func _ready() -> void:
	boat.connect("rebuilt", _place)
	for i in 3:
		var s := _sheet()
		s.name = "Sheet%d" % i
		add_child(s)
		_sheets.append(s)
	_deck_wash = _wash()
	add_child(_deck_wash)
	_deck_water = _water_sheet()
	add_child(_deck_water)
	for i in 2:
		var d := _drain()
		d.name = "Scupper%d" % i
		add_child(d)
		_drains.append(d)
	_place()


## Her rail and deck from her kind (and again whenever she's rebuilt as another).
func _place() -> void:
	var spec: Dictionary = boat.get("spec")
	_rail.clear()
	for p: Vector3 in spec.get("rail", []):
		_rail.append(p)
		if p.x != 0.0:
			_rail.append(Vector3(-p.x, p.y, p.z))
	_wait.resize(_rail.size())
	_wait.fill(0.0)
	var half := Vector3(float(spec["beam"]) * 0.32, 0.0, float(spec["length"]) * 0.28)
	var pm := _deck_wash.process_material as ParticleProcessMaterial
	pm.emission_box_extents = Vector3(half.x, 0.01, half.z)
	_deck_wash.position = Vector3(0.0, float(spec["deck"]) + 0.04, float(spec["length"]) * 0.12)
	(_deck_water.mesh as PlaneMesh).size = Vector2(half.x * 2.0, half.z * 2.0)
	_deck_water.position = Vector3(0.0, float(spec["deck"]), float(spec["length"]) * 0.12)
	# (her scuppers: low in her transom's corners, just inside her topsides)
	var stern := float(spec["length"]) * 0.5 - 0.05
	for i in _drains.size():
		_drains[i].position = Vector3((1.0 if i == 0 else -1.0) * half.x, float(spec["deck"]) + 0.03, stern)


func _process(delta: float) -> void:
	var ocean: Node = boat.get("ocean")
	if ocean == null or _rail.is_empty():
		return
	var xf := boat.global_transform
	for i in _rail.size():
		_wait[i] -= delta
		if _wait[i] > 0.0:
			continue
		var p := xf * _rail[i]
		var over := float(ocean.call("height_at", p)) - p.y
		if over > 0.0:
			_wait[i] = AGAIN
			_aboard(_rail[i], over)
	streaming = maxf(streaming - delta / STREAM_S, 0.0)
	var spec: Dictionary = boat.get("spec")
	water = maxf(water - float(spec.get("bilge", 0.05)) * delta, 0.0)
	if water > 0.4 and not _told:
		_told = true
		var crew: Node = boat.get("sea").get("crew") if boat.get("sea") != null else null
		# (another boat's view of the crew, vs/side.gd, has no boat_of: she isn't yours to be told of)
		if crew != null and crew.get("hud") != null and crew.has_method("boat_of") \
				and crew.call("boat_of", Net.my_id()) == boat:
			(crew.get("hud") as Node).call("notify", "She's taking water: heavy and slow. Get her in out of it")
	elif water < 0.1:
		_told = false
	_deck_wash.emitting = streaming > 0.05
	_deck_wash.amount_ratio = clampf(streaming, 0.2, 1.0)
	_show_water(delta)


## The water on her deck: a sheet of it running aft just after a sea, as deep as what's in her (a skiff filling), and
## pouring out of her scuppers at her transom corners while there's any.
func _show_water(delta: float) -> void:
	var depth := maxf(streaming * STREAM_DEEP, water * FULL_DEEP)
	_deck_water.visible = depth > 0.004
	for d in _drains:
		d.emitting = depth > 0.01
		d.amount_ratio = clampf(depth * 12.0, 0.25, 1.0)
	if not _deck_water.visible:
		return
	var spec: Dictionary = boat.get("spec")
	_deck_water.position.y = float(spec["deck"]) + depth
	var m := _deck_water.material_override as StandardMaterial3D
	m.albedo_color.a = clampf(0.35 + depth * 4.0, 0.35, 0.8)
	# (running aft to the scuppers, sloshing side to side as she rolls)
	var roll := boat.global_basis.get_euler().z
	_flow += Vector3(-roll * 0.6, -(0.25 + streaming * 0.6), 0.0) * delta
	m.uv1_offset = _flow


## A sea comes aboard at a spot on her rail (boat-local), `over` m deep: the sheet over the rail, the crash, the deck
## awash.
func _aboard(at: Vector3, over: float) -> void:
	bursts += 1
	water = minf(water + float((boat.get("spec") as Dictionary).get("swamp", 0.0)) * (0.6 + over), 1.0)
	var s := _sheets[_next_sheet]
	_next_sheet = (_next_sheet + 1) % _sheets.size()
	s.position = at
	# inboard and up: from the side toward her middle, from the transom forward
	var inboard := Vector3(-signf(at.x), 0.0, 0.0) if absf(at.x) > 0.3 else Vector3(0.0, 0.0, -1.0)
	var pm := s.process_material as ParticleProcessMaterial
	pm.direction = (inboard + Vector3(0.0, 0.9, 0.0)).normalized()
	pm.initial_velocity_min = 2.0 + over * 3.0
	pm.initial_velocity_max = 3.5 + over * 5.0
	s.amount_ratio = clampf(0.4 + over, 0.4, 1.0)
	s.restart()
	s.emitting = true
	streaming = minf(streaming + 0.5 + over, 1.0)
	Sfx.play_point(self, boat.global_transform * at, "sea.wave", clampf(0.6 + over, 0.6, 1.4))
	Sfx.play_point(self, boat.global_transform * at, "sea.spray", 0.8)


## A burst of white water thrown in over the rail (riding with her: her deck's where it lands).
func _sheet() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.15, 0.1, 1.1)
	pm.spread = 35.0
	pm.gravity = Vector3(0.0, -9.8, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.color_ramp = _fade(0.85)
	var p := _puffs(pm, true, 0.45, Color(0.82, 0.93, 0.92))
	p.amount = 180
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 0.8
	return p


## The water over her deck: sea-green, see-through, the noise's grain in it (big pixels, the sea's look) running aft.
func _water_sheet() -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.36, 0.55, 0.56, 0.5)
	mat.albedo_texture = _grain()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(0.6, 1.4, 1.0)
	mat.roughness = 0.15
	mat.metallic_specular = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 4.0)
	var mi := MeshInstance3D.new()
	mi.name = "DeckWater"
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


## The water's grain: a coarse noise, 24 pixels a tile (the pixel look), light streaks and dark.
static func _grain() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = 7
	n.frequency = 0.12
	var t := NoiseTexture2D.new()
	t.width = 24
	t.height = 24
	t.seamless = true
	t.noise = n
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.72, 0.8, 0.82))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	t.color_ramp = ramp
	return t


## A scupper pouring the deck's water out over her transom: a spout falling into her wake.
func _drain() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.06, 0.02, 0.02)
	pm.direction = Vector3(0.0, -0.2, 1.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0.0, -9.8, 0.0)
	pm.scale_min = 0.4
	pm.scale_max = 0.8
	pm.color_ramp = _fade(0.8)
	var p := _puffs(pm, true, 0.18, Color(0.7, 0.85, 0.86))
	p.amount = 40
	p.lifetime = 0.7
	return p


## Foam streaming over her deck, aft to the scuppers.
func _wash() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.direction = Vector3(0.0, 0.0, 1.0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3.ZERO
	pm.flatness = 1.0
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color_ramp = _fade(0.6)
	var p := _puffs(pm, false, 0.9, Color(0.45, 0.58, 0.62))
	p.name = "DeckWash"
	p.amount = 120
	p.lifetime = 2.2
	return p


func _puffs(pm: ParticleProcessMaterial, upright: bool, size: float, tint: Color) -> GPUParticles3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = PUFF
	mat.albedo_color = tint
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST     # (the pixel look: no smoothing)
	var p := GPUParticles3D.new()
	if upright:
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
	p.process_material = pm
	p.local_coords = true          # (on her deck: it goes where she goes)
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-10, -4, -10), Vector3(20, 10, 20))
	return p


static func _fade(alpha: float) -> GradientTexture1D:
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, alpha))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var t := GradientTexture1D.new()
	t.gradient = fade
	return t
