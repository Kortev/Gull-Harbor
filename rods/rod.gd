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
## A fish on (tuna/fight.gd): its weight, when it bit (sea clock), the line from the tip to it (m), where it is
## (bearing round the stern, 0 dead astern, + to port; depth, m), how fresh it is, what it's doing (a move).
var hooked := false
var fish_kg := 0.0
var hook_t := 0.0
var line_out := 0.0
var bearing := 0.0
var depth := 0.0
var energy := 1.0
var move := ""
## How far the holder has heaved the rod up, 0..1 (a pump).
var lift := 0.0
## The fight itself, on the holder's machine only.
var fight: RefCounted
## While nobody holds it: when it was let go (sea clock) and the line out then (it runs from there).
var free_t := 0.0
var free_out := 0.0
## How worn the line is from rubbing the hull (fight.gd), kept when the rod changes hands.
var wear := 0.0
var _scream: AudioStreamPlayer3D
var _whir: AudioStreamPlayer3D
var _sing: AudioStreamPlayer3D
var _last_out := 0.0
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
	_scream = AudioStreamPlayer3D.new()
	var wav := (preload("res://audio/fish/drag_scream.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = wav.data.size() / 2
	_scream.stream = wav
	_scream.unit_size = 6.0
	_scream.volume_db = 4.0
	_scream.position = Vector3(0, 0.1, 0.37)
	add_child(_scream)
	# the reel winding (while line comes in) and the line singing (bar-tight, near breaking)
	_whir = _looped(preload("res://audio/fish/reel_whir.wav"), -4.0)
	_sing = _looped(preload("res://audio/fish/line_sing.wav"), -10.0)
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
	# (a rod in your hands mustn't catch your own look; a crewmate's with a fish on, you can take over)
	_grab.collision_layer = 1 if holder == 0 or (hooked and holder != Net.my_id()) else 0
	_blank.set_instance_shader_parameter("bend", _bend)
	if _handle:
		_handle.rotate_object_local(Vector3.RIGHT, -reeling * delta * 12.0)
	# the drag screams while the fish takes line: louder and higher the faster it goes
	var paying := (line_out - _last_out) / maxf(delta, 1e-4)
	_last_out = line_out
	if hooked and paying > 0.6:
		if not _scream.playing:
			_scream.play()
		_scream.pitch_scale = clampf(0.75 + paying / 14.0, 0.75, 1.5)
		_scream.volume_db = lerpf(-6.0, 6.0, clampf(paying / 10.0, 0.0, 1.0))
	elif _scream.playing:
		_scream.stop()
	if reeling > 0.05 and not _whir.playing:
		_whir.play()
	elif reeling <= 0.05 and _whir.playing:
		_whir.stop()
	var singing := hooked and strain > 0.8 and paying <= 0.6
	if singing and not _sing.playing:
		_sing.play()
	elif not singing and _sing.playing:
		_sing.stop()
	if _sing.playing:
		_sing.pitch_scale = 0.9 + 0.4 * strain
	_draw_line()


func _looped(src: AudioStreamWAV, db: float) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	var wav := src.duplicate() as AudioStreamWAV
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = wav.data.size() / (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) \
			/ (2 if wav.stereo else 1)
	a.stream = wav
	a.unit_size = 5.0
	a.volume_db = db
	a.position = Vector3(0, 0.1, 0.37)
	add_child(a)
	return a


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
		return "GRAB IT! Fish on!" if hooked else "Grab the rod"
	if hooked and holder != Net.my_id():
		return "Take over the rod"
	return ""
