extends Node3D
## Green water (a child of boat/boat.gd): in a big sea a crest now and then tops her rail. Where it does, a sheet of
## white water bursts in over the rail with a crash, and for a while after the deck streams with foam running aft to
## the scuppers. The sea's the same on every peer (sea/ocean.gd's wave clock), so everyone sees the same crests come
## aboard. Her rail comes from her kind (boat/kinds.gd's "rail": points on her starboard rail; port mirrors it).

const Sfx := preload("res://audio/sfx.gd")
const PUFF := preload("res://sea/textures/steam_puff.png")
## How often a spot on the rail can take another sea (s), and how long the deck streams after one.
const AGAIN := 1.2
const STREAM_S := 6.0

var boat: Node3D              # boat/boat.gd
## Times a sea's come aboard (tests), and how much the deck's streaming now (0..1).
var bursts := 0
var streaming := 0.0
var _rail: Array[Vector3] = []
var _wait: Array[float] = []
var _sheets: Array[GPUParticles3D] = []
var _next_sheet := 0
var _deck_wash: GPUParticles3D


func _ready() -> void:
	boat.connect("rebuilt", _place)
	for i in 3:
		var s := _sheet()
		s.name = "Sheet%d" % i
		add_child(s)
		_sheets.append(s)
	_deck_wash = _wash()
	add_child(_deck_wash)
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
	_deck_wash.emitting = streaming > 0.05
	_deck_wash.amount_ratio = clampf(streaming, 0.2, 1.0)


## A sea comes aboard at a spot on her rail (boat-local), `over` m deep: the sheet over the rail, the crash, the deck
## awash.
func _aboard(at: Vector3, over: float) -> void:
	bursts += 1
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
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
