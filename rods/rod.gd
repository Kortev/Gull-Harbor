extends Node3D
## One stand-up tuna rod (art/rod.py -> rod.glb): in its stern holder with its bait out astern, or in someone's
## hands. rods.gd (the spread) decides where it is; this draws it: the blank bent toward the line's pull, the line
## from the tip out to where it meets the water, the crank turning while line comes in.
##
## E on it: grab it (the host says yes or no). Q while holding it: put it back.

const MODEL := preload("res://rods/rod.glb")
const BEND := preload("res://rods/rod_bend.gdshader")
const LENGTH := 1.76

static var _materials := {}

var index := 0
## Peer id of whoever holds it, 0 while it sits in its holder.
var holder := 0
## How hard the line pulls, 0 (slack, just the bait's drag) .. 1 (a big fish running, drag screaming).
var strain := 0.05
## Where the line goes into the water (world), set by rods.gd every frame.
var line_end := Vector3.ZERO
## Line coming in (m/s): turns the crank.
var reeling := 0.0
var spread: Node              # rods.gd
var _blank: MeshInstance3D
var _handle: Node3D
var _tip_local := Vector3(0, 0, LENGTH)
var _bend := Vector2.ZERO
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _grab: Area3D


func _ready() -> void:
	var src := MODEL.instantiate() as Node3D
	for n: String in ["butt", "blank", "handle"]:
		var mi := src.find_child(n, true, false) as MeshInstance3D
		if mi == null:
			continue
		var t := mi.transform
		mi.owner = null
		mi.get_parent().remove_child(mi)
		mi.transform = t
		add_child(mi)
		if n == "blank":
			_blank = mi
			for i in mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, _bend_material(mi.mesh.surface_get_material(i)))
		elif n == "handle":
			_handle = mi
	var tip := src.find_child("tip", true, false) as Node3D
	if tip:
		_tip_local = tip.transform.origin
	src.free()
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.top_level = true
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.85, 0.86, 0.78)
	_line.material_override = lm
	add_child(_line)
	# what you press E on: the butt and the foregrip
	_grab = Area3D.new()
	_grab.add_to_group("interactable")
	_grab.set_meta("rod", self)
	_grab.set_script(preload("res://rods/rod_grab.gd"))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.35, 0.9)
	cs.shape = box
	cs.position = Vector3(0, 0.05, 0.4)
	_grab.add_child(cs)
	add_child(_grab)


static func _bend_material(m: Material) -> Material:
	if _materials.has(m):
		return _materials[m]
	var out := ShaderMaterial.new()
	out.shader = BEND
	var base := m as BaseMaterial3D
	if base:
		out.set_shader_parameter("albedo_color", base.albedo_color)
		if base.albedo_texture:
			out.set_shader_parameter("albedo_texture", base.albedo_texture)
			out.set_shader_parameter("use_texture", true)
	_materials[m] = out
	return out


## The rod tip in the world, bent as drawn.
func tip_position() -> Vector3:
	var s := 1.0
	return global_transform * (_tip_local + Vector3(_bend.x * s, _bend.y * s, -_bend.length() * 0.35))


func _process(delta: float) -> void:
	# bend toward the line: the pull's direction seen from the rod, scaled by how hard it pulls
	var pull := line_end - global_position
	var local := global_transform.basis.inverse() * pull.normalized()
	var want := Vector2(local.x, local.y) * (0.05 + 0.55 * strain) * LENGTH * 0.45
	# a heavy load makes the tip buck (a fish's head shakes and the drag slips)
	if strain > 0.3:
		var t := Time.get_ticks_msec() * 0.001
		want += Vector2(sin(t * 23.0), sin(t * 17.0 + 1.3)) * 0.02 * strain
	_bend = _bend.lerp(want, minf(1.0, delta * 12.0))
	_grab.collision_layer = 1 if holder == 0 else 0     # (a rod in your hands mustn't catch your own look)
	_blank.set_instance_shader_parameter("bend", _bend)
	if _handle:
		_handle.rotate_object_local(Vector3.RIGHT, -reeling * delta * 12.0)
	_draw_line()


func _draw_line() -> void:
	var a := tip_position()
	var b := line_end
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var sag := (1.0 - strain) * clampf(a.distance_to(b) * 0.04, 0.0, 1.5)
	for i in 13:
		var f := i / 12.0
		var p := a.lerp(b, f)
		p.y -= sag * 4.0 * f * (1.0 - f)
		_line_mesh.surface_add_vertex(p)
	_line_mesh.surface_end()


func interact_prompt(player: Node) -> String:
	if holder == 0:
		return "Grab the rod" if strain < 0.3 else "GRAB IT!"
	return ""
