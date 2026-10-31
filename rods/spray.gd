extends MultiMeshInstance3D
## Flying water as chunky pixels (rods/fight_fx.gd's): square flecks thrown where you say, falling under gravity and
## shrinking a step at a time till they're gone or back down on what they fell from. Run on the CPU in one multimesh,
## so a test can count them and the hit-stop can slow them (`slow`). Nothing here touches the fight: it only draws.

const MAX := 480
const GRAVITY := 9.8
## Sizes come in whole steps (m): a fleck shrinks by a step, never smoothly (it reads as pixels at 640x360).
const STEP := 0.05

## Time's rate for the flecks, 0..1 (the strike's hit-stop holds them hanging, then lets them go).
var slow := 1.0
var _p := PackedVector3Array()
var _v := PackedVector3Array()
## size (m), life left (s), life at birth (s), the floor it dies on (world y)
var _s := PackedFloat32Array()
var _life := PackedFloat32Array()
var _born := PackedFloat32Array()
var _floor := PackedFloat32Array()
var _c := PackedColorArray()
var _n := 0


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	q.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	multimesh = mm
	custom_aabb = AABB(Vector3(-1e4, -1e3, -1e4), Vector3(2e4, 2e3, 2e4))
	_p.resize(MAX)
	_v.resize(MAX)
	_c.resize(MAX)
	_s.resize(MAX)
	_life.resize(MAX)
	_born.resize(MAX)
	_floor.resize(MAX)


## One fleck at `at` (world) going `vel`, `size` m, living `life` s, gone when it falls back under `floor_y`.
func emit(at: Vector3, vel: Vector3, size: float, life: float, floor_y: float, color := Color(0.93, 0.96, 0.98)) -> void:
	if _n >= MAX:
		return
	_p[_n] = at
	_v[_n] = vel
	_s[_n] = maxf(snappedf(size, STEP), STEP)
	_life[_n] = life
	_born[_n] = life
	_floor[_n] = floor_y
	_c[_n] = color
	_n += 1


## How many flecks are flying (tests).
func count() -> int:
	return _n


func _process(delta: float) -> void:
	var dt := delta * slow
	var i := 0
	while i < _n:
		_life[i] -= dt
		_v[i].y -= GRAVITY * dt
		_v[i] *= 1.0 - 0.6 * dt          # (air drag: spray hangs, then drops)
		_p[i] += _v[i] * dt
		if _life[i] <= 0.0 or (_p[i].y < _floor[i] and _v[i].y < 0.0):
			_n -= 1
			_p[i] = _p[_n]
			_v[i] = _v[_n]
			_s[i] = _s[_n]
			_life[i] = _life[_n]
			_born[i] = _born[_n]
			_floor[i] = _floor[_n]
			_c[i] = _c[_n]
			continue
		i += 1
	var mm := multimesh
	mm.visible_instance_count = _n
	for k in _n:
		# (shrinking in whole steps over its last half)
		var left := clampf(_life[k] / maxf(_born[k] * 0.5, 0.01), 0.0, 1.0)
		var s := maxf(snappedf(_s[k] * left, STEP), STEP)
		mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(s, s, s)), _p[k]))
		mm.set_instance_color(k, _c[k])
