extends Node3D
## A bluefin tuna (art/bluefin.py -> bluefin.glb), 30 to 400 kg. The model is unit length; this scales it to the
## fish's size and makes it swim: the tail beats faster the faster it goes (tuna_swim.gdshader bends the body),
## the body curves and banks into turns, yaws a touch against each stroke of the tail and surges on it, and noses up
## or down where it's heading. Moving it is up to whoever owns it (a school, a fight): set `velocity` (m/s, world)
## every frame, or call steer(); or, `posed` and `swimming`, put it where it goes yourself each frame: it reads how
## it's moving off that and swims to match.

const MODEL := preload("res://tuna/bluefin.glb")
const SWIM := preload("res://tuna/tuna_swim.gdshader")
const MIN_KG := 30.0
const MAX_KG := 400.0
## The steepest it noses up or down swimming (radians).
const PITCH := 0.7

## The model's materials, each turned into the swim shader once and shared by every tuna (they batch).
static var _materials := {}

var kg := 150.0
## Snout to the tips of the tail, m.
var length := 2.0
var velocity := Vector3.ZERO
## How hard it's working, 0..1 on top of its speed (a fish on the line beats hard even while held).
var effort := 0.0
## Rolled over on its side on top of its bank (rad): a beaten fish showing its flank (rods/fight_fx.gd).
var roll := 0.0
## Placed by hand (tuna/landing.gd, boat/catch.gd: alongside, or on deck): it stays where it's put, facing how it's
## put, and only its tail moves.
var posed := false
## Posed but in the water (alongside): its tail, its bank and its curve follow how it's being moved.
var swimming := false
var mesh: MeshInstance3D
var _phase := 0.0
var _bend := 0.0
var _heading := Vector3.FORWARD
var _last_p := Vector3.INF
var _last_fwd := Vector3.FORWARD
var _yaw_rate := 0.0
var _speed := 0.0
var _idle := 0.0


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
	if delta <= 0.0:
		return
	if posed and not swimming:
		# (lying on deck: only the tail, slapping as hard as it's working)
		_phase += TAU * (0.4 + effort) * delta
		mesh.rotation = Vector3.ZERO
		mesh.position = Vector3.ZERO
		mesh.set_instance_shader_parameter("swim_phase", _phase)
		mesh.set_instance_shader_parameter("swim_amp", 0.01 + 0.04 * effort)
		mesh.set_instance_shader_parameter("bend", 0.0)
		return
	if not posed:
		_free_swim(delta)
	# how it's moving, read off where it's got to (moved by velocity, or placed by hand): its speed, how fast it's
	# turning and climbing, for the tail, the bank, the body's curve
	var p := global_position
	var fwd := -global_basis.z
	if _last_p == Vector3.INF or p.distance_to(_last_p) > 6.0:
		_last_p = p
		_last_fwd = fwd
	var flat_was := Vector3(_last_fwd.x, 0.0, _last_fwd.z)
	var flat_now := Vector3(fwd.x, 0.0, fwd.z)
	var yaw := flat_was.signed_angle_to(flat_now, Vector3.UP) / delta 			if flat_was.length_squared() > 1e-4 and flat_now.length_squared() > 1e-4 else 0.0
	_yaw_rate = lerpf(_yaw_rate, clampf(yaw, -3.0, 3.0), minf(1.0, delta * 4.0))
	_speed = lerpf(_speed, (p - _last_p).length() / delta, minf(1.0, delta * 3.0))
	_last_p = p
	_last_fwd = fwd
	# the tail: a big fish beats slower; faster swimming, faster beats (about a body length per beat cruising); placed
	# by hand it still beats to keep up, and harder the harder it's working
	var beat := (0.45 + minf(_speed, length * 3.0) / length * 0.9) * (1.0 + effort)
	_phase += TAU * beat * delta
	var amp := 0.035 + 0.035 * clampf(_speed / (length * 2.0) + effort, 0.0, 1.0)
	_bend = lerpf(_bend, clampf(-_yaw_rate * 0.07, -0.14, 0.14), minf(1.0, delta * 5.0))
	# the whole body answers its tail: a little yaw against each stroke and a push forward on it, and it leans into a
	# turn; idling, it noses one way and the other so it's never a statue
	_idle += delta * (0.6 + 0.3 * effort)
	var weave := 0.0 if posed else 0.22 * clampf(1.0 - _speed / 1.2, 0.0, 1.0) * sin(_idle)
	var bank := clampf(_yaw_rate * 0.35, -0.55, 0.55)
	mesh.rotation = Vector3(0.0, weave - amp * 0.6 * sin(_phase), bank + roll)
	mesh.position = Vector3(0.0, 0.0, -0.012 * length * absf(sin(_phase)) * (0.3 + effort))
	mesh.set_instance_shader_parameter("swim_phase", _phase)
	mesh.set_instance_shader_parameter("swim_amp", amp)
	mesh.set_instance_shader_parameter("bend", _bend)


## Moving by `velocity`: along it, turning toward where it's going at a big fish's pace (a giant swings round slower
## than a schoolie), its nose never more than PITCH up or down.
func _free_swim(delta: float) -> void:
	position += velocity * delta
	var speed := velocity.length()
	var dir := velocity / speed if speed > 0.05 else _heading
	_heading = dir
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 1e-4:
		flat = -basis.z * Vector3(1, 0, 1)
	if flat.length_squared() < 1e-4:
		return
	var pitch := clampf(atan2(dir.y, Vector3(dir.x, 0.0, dir.z).length()), -PITCH, PITCH)
	var b := Basis.looking_at(flat.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, pitch)
	var rate := (2.0 + speed * 0.8) * clampf(2.5 / length, 0.6, 1.4)
	basis = basis.slerp(b, minf(1.0, delta * rate)).orthonormalized()
