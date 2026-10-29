extends Node3D
## A bluefin tuna (art/bluefin.py -> bluefin.glb), 30 to 400 kg. The model is unit length; this scales it to the
## fish's size and makes it swim: the tail beats faster the faster it goes (tuna_swim.gdshader bends the body),
## it banks into turns and noses up or down where it's heading. Moving it is up to whoever owns it (a school, a
## fight): set `velocity` (m/s, world) every frame, or call steer().

const MODEL := preload("res://tuna/bluefin.glb")
const SWIM := preload("res://tuna/tuna_swim.gdshader")
const MIN_KG := 30.0
const MAX_KG := 400.0

## The model's materials, each turned into the swim shader once and shared by every tuna (they batch).
static var _materials := {}

var kg := 150.0
## Snout to the tips of the tail, m.
var length := 2.0
var velocity := Vector3.ZERO
## How hard it's working, 0..1 on top of its speed (a fish on the line beats hard even while held).
var effort := 0.0
## Placed by hand (tuna/landing.gd, boat/catch.gd: alongside, or on deck): it stays where it's put, facing how it's
## put, and only its tail moves.
var posed := false
var mesh: MeshInstance3D
var _phase := 0.0
var _bend := 0.0
var _heading := Vector3.FORWARD


## Fork length (cm) from weight for Atlantic bluefin (ICCAT: W = 1.96e-5 * FL^3.009); the tail tips add ~10 %.
static func length_for(weight_kg: float) -> float:
	return pow(weight_kg / 1.96e-5, 1.0 / 3.009) / 100.0 * 1.1


func _init(weight_kg := 150.0) -> void:
	kg = clampf(weight_kg, MIN_KG, MAX_KG)
	length = length_for(kg)


func _ready() -> void:
	var src := MODEL.instantiate()
	var found := src.find_child("bluefin", true, false) as MeshInstance3D
	mesh = MeshInstance3D.new()
	mesh.name = "Body"
	mesh.mesh = found.mesh
	src.free()
	for i in mesh.mesh.get_surface_count():
		mesh.set_surface_override_material(i, _swim_material(mesh.mesh.surface_get_material(i)))
	mesh.scale = Vector3.ONE * length
	add_child(mesh)
	_phase = randf() * TAU


static func _swim_material(m: Material) -> Material:
	if _materials.has(m):
		return _materials[m]
	var out := ShaderMaterial.new()
	out.shader = SWIM
	var base := m as BaseMaterial3D
	if base:
		out.set_shader_parameter("albedo_color", base.albedo_color)
		if base.albedo_texture:
			out.set_shader_parameter("albedo_texture", base.albedo_texture)
			out.set_shader_parameter("use_texture", true)
		if base.resource_name == "eye":
			out.set_shader_parameter("roughness", 0.15)
			out.set_shader_parameter("specular", 0.8)
	_materials[m] = out
	return out


## Turns toward a direction (world) at a tuna's turn rate, cruising at `speed` m/s.
func steer(dir: Vector3, speed: float, delta: float, turn := 1.6) -> void:
	if dir.length_squared() < 1e-6:
		return
	var want := dir.normalized()
	var now := velocity.normalized() if velocity.length_squared() > 1e-4 else _heading
	var ang := now.angle_to(want)
	var step := minf(1.0, turn * delta / maxf(ang, 1e-4))
	var d := now.slerp(want, step) if ang > 1e-3 else want
	velocity = d * move_toward(velocity.length(), speed, 3.0 * delta)


func _process(delta: float) -> void:
	if posed:
		_phase += TAU * (0.4 + effort) * delta
		mesh.set_instance_shader_parameter("swim_phase", _phase)
		mesh.set_instance_shader_parameter("swim_amp", 0.01 + 0.04 * effort)
		mesh.set_instance_shader_parameter("bend", 0.0)
		return
	position += velocity * delta
	var speed := velocity.length()
	var dir := velocity / speed if speed > 0.05 else _heading
	# turning: how fast the heading swings, for the bank and the body's curve
	var yaw_rate := _heading.signed_angle_to(dir, Vector3.UP) / maxf(delta, 1e-4) if speed > 0.05 else 0.0
	_heading = dir
	_bend = lerpf(_bend, clampf(-yaw_rate * 0.05, -0.12, 0.12), minf(1.0, delta * 6.0))
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 1e-4:
		var b := Basis.looking_at(dir, Vector3.UP)
		b = b * Basis(Vector3.FORWARD, clampf(yaw_rate * 0.25, -0.6, 0.6))
		basis = basis.slerp(b, minf(1.0, delta * 5.0)).orthonormalized()
	# the tail: a big fish beats slower; faster swimming, faster beats (about a body length per beat cruising)
	var beat := (0.45 + speed / length * 0.9) * (1.0 + effort)
	_phase += TAU * beat * delta
	mesh.set_instance_shader_parameter("swim_phase", _phase)
	mesh.set_instance_shader_parameter("swim_amp", 0.035 + 0.03 * clampf(speed / (length * 2.0) + effort, 0.0, 1.0))
	mesh.set_instance_shader_parameter("bend", _bend)
