extends Node3D
## One stand-up tuna rod (art/rod.py -> rod.glb): in its stern holder with its bait out astern, or in someone's
## hands. rods.gd (the spread) decides where it is; this draws it: the blank bent toward the line's pull, the line
## from the tip out to where it meets the water, the crank turning while line comes in.
##
## E on it: grab it (the host says yes or no). Q while holding it: put it back.

const MODEL := preload("res://rods/rod.glb")
const BEND := preload("res://rods/rod_bend.gdshader")
const LENGTH := 1.76

const LURES := [Color(0.95, 0.35, 0.6), Color(0.2, 0.55, 0.95), Color(0.95, 0.8, 0.2), Color(0.3, 0.85, 0.4)]

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
## (bearing round the stern, 0 dead astern, + to starboard; depth, m), how fresh it is, what it's doing (a move).
var hooked := false
var fish_kg := 0.0
var hook_t := 0.0
var line_out := 0.0
var bearing := 0.0
var depth := 0.0
var energy := 1.0
var move := ""
## How far the holder has heaved the rod up, 0..1 (a pump; how the angler's arms are drawn).
var lift := 0.0
## With a fish on, the rod as the angler holds it: its elevation (0.15 tip at the water .. 1.35 near upright) and how
## far it's laid over off the line (rad, + to the left), the drag lever (fight.gd's DETENTS), the spring's stretch (m;
## below 0 slack), how well the hook's holding (1 .. 0).
var aim_pitch := 0.6
var aim_side := 0.0
var drag := 0.72
var stretch := 0.0
var hold := 1.0
## Cranking with the rod loaded: the reel grinds and wins nothing (the angler's machine: pump instead).
var grinding := false
## The fight itself: on the holder's machine, or the host's while it sits in its holder (fight.gd's in_holder).
var fight: RefCounted
## When it last changed hands (sea clock): seeds the fight picked up from there.
var free_t := 0.0
## How worn the line is from rubbing the hull (fight.gd), kept when the rod changes hands.
var wear := 0.0
## Which way round the fish is swinging, kept when the rod changes hands too.
var turn_sign := 0.0
## Who held it last (a fight that ended as it changed hands still counts: rods.gd's _report_end).
var last_holder := 0
## Its fish is beaten and up alongside (tuna/landing.gd): no more fighting, just the line to it till it's stuck.
var alongside := false
## Its line reeled in (cleared while another rod's fighting a fish: no bait out, nothing bites), and the rod whose
## running fish has its line tangled (-1: none).
var bait_in := false
var tangled := -1
## The bait on it: whether there is one (a fish takes it), when it went on (sea clock) and whether it's a live
## mackerel from the well (rods.gd's freshness).
var baited := true
var baited_t := 0.0
var live := false
## Where its bait is fished (boat-local, rods.gd's spread: where the last cast put it), and the cast: where it landed
## (boat-local), when it went (sea clock; -INF: not flying) and the tip it went from (world).
var spot := Vector3.ZERO
var land := Vector3.ZERO
## Line out from the tip to the bait (m) while someone's wound some of it back (-1: as long as the cast left it). The
## bait's held no further out than this, so winding drags it back over the water to the tip.
var out := -1.0
## Being wound in by whoever pressed E on it (no one's holding it): 0 not, 1 to clear its line, 2 to put a fresh bait
## on once it's in (`wind_live`: a live one). Everyone sees the bait come back over the water.
var auto_in := 0
var wind_live := false
var cast_t := -INF
var cast_from := Vector3.ZERO
## Winding up a cast, 0..1 (the holder's; the others see it too), and the whip of the rod through the cast (1 -> 0).
var wind := 0.0
var whip := 0.0
## The bait being towed (rods.gd's _tow): where it is and its way through the water (world; INF: not out), and how
## slack its line is (0 bar-tight .. 1: she's stopped and it's dropped back).
var bait_p := Vector3.INF
var bait_v := Vector3.ZERO
var slack := 0.0
var _lure: MeshInstance3D
## The fish on it, seen (rods.gd's _show_fish): its body in the water, the move it was last seen making, and the next
## splash it throws up.
var fish_node: Node3D
var seen_move := ""
var splash_in := 0.0
var _scream: AudioStreamPlayer3D
var _whir: AudioStreamPlayer3D
var _grind: AudioStreamPlayer3D
var _spool: MeshInstance3D
var _spool_mat: StandardMaterial3D
var _sing: AudioStreamPlayer3D
var _last_out := 0.0
var _paying := 0.0
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
	# the line on the spool, between the reel's plates: it shrinks as line goes out, white backing under it, then
	# bare metal (you can see a giant's run emptying it)
	_spool = MeshInstance3D.new()
	var sp := CylinderMesh.new()
	sp.top_radius = 0.05
	sp.bottom_radius = 0.05
	sp.height = 0.075
	sp.radial_segments = 10
	sp.rings = 1
	_spool.mesh = sp
	_spool.position = Vector3(0, 0.1, 0.37)
	_spool.rotation = Vector3(0, 0, PI * 0.5)
	_spool_mat = StandardMaterial3D.new()
	_spool_mat.roughness = 0.8
	_spool.material_override = _spool_mat
	add_child(_spool)
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
	# the bait on the end of it: a skirted trolling lure (a live mackerel's a dark one)
	_lure = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.012
	cone.bottom_radius = 0.05
	cone.height = 0.28
	cone.radial_segments = 6
	cone.rings = 1
	_lure.mesh = cone
	_lure.top_level = true
	_lure.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lure.material_override = StandardMaterial3D.new()
	add_child(_lure)
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
	# the reel under load: the same works, slow and heavy, going nowhere
	_grind = _looped(preload("res://audio/fish/reel_whir.wav"), -2.0)
	_grind.pitch_scale = 0.5
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
	# near the limit the tip quivers: the line's about to go
	if strain > 0.85:
		var t := Time.get_ticks_msec() * 0.001
		want += Vector2(sin(t * 23.0), sin(t * 17.0 + 1.3)) * (0.02 * (strain - 0.85) / 0.15 + 0.005)
	_bend = _bend.lerp(want, minf(1.0, delta * 12.0))
	# (a rod in your hands mustn't catch your own look; a crewmate's with a fish on, you can take over)
	_grab.collision_layer = 1 if holder == 0 or (hooked and holder != Net.my_id()) else 0
	_blank.set_instance_shader_parameter("bend", _bend)
	if _handle:
		_handle.rotate_object_local(Vector3.RIGHT, -reeling * delta * 12.0)
	# the drag screams while the fish takes line: louder and higher the faster it goes
	# (smoothed: a crewmate's fish comes in ten updates a second, and the drag mustn't stutter with them)
	var raw := (line_out - _last_out) / maxf(delta, 1e-4)
	_last_out = line_out
	_paying = lerpf(_paying, raw, minf(delta * 6.0, 1.0))
	var paying := _paying
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
	var grind := hooked and grinding
	if grind and not _grind.playing:
		_grind.play()
	elif not grind and _grind.playing:
		_grind.stop()
	# the creak: only right at the edge, higher the worse it gets (your one warning before the line goes)
	var singing := hooked and strain >= 0.92
	if singing and not _sing.playing:
		_sing.play()
	elif not singing and _sing.playing:
		_sing.stop()
	if _sing.playing:
		_sing.pitch_scale = 0.55 + 2.5 * (strain - 0.92)
	var left := clampf(1.0 - (line_out if hooked else 0.0) / 500.0, 0.0, 1.0)
	var r := 0.05 * (0.4 + 0.6 * left)
	_spool.scale = Vector3(r / 0.05, 1.0, r / 0.05)
	var gone := line_out if hooked else 0.0
	_spool_mat.albedo_color = Color(0.85, 0.86, 0.78) if gone <= 400.0 else (Color(0.97, 0.97, 0.95) if gone <= 425.0
			else Color(0.55, 0.57, 0.6))
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
	# a line always droops a little; a slack one (she's stopped) a lot, down onto the water; a fish on pulls it
	# straight
	var d := a.distance_to(b)
	var sag := (0.02 + 0.3 * slack) * d * (1.0 - 0.85 * strain)
	for i in 17:
		var f := i / 16.0
		var p := a.lerp(b, f)
		p.y -= sag * 4.0 * f * (1.0 - f)
		p.y = maxf(p.y, minf(b.y, a.y) - 0.05)       # (not through the water)
		_line_mesh.surface_add_vertex(p)
	_line_mesh.surface_end()
	# the lure, nose toward the rod, riding just in the water; or hanging off the tip with the line in, or flying
	var flying := bool(spread.call("flying", index)) if spread else false
	var out := baited and not hooked and tangled < 0 and (bait_in or flying or bait_p != Vector3.INF)
	_lure.visible = out
	if out:
		var to := (a - b) * Vector3(1, 0, 1)
		if bait_in:
			_lure.global_transform = Transform3D(Basis.IDENTITY, b + Vector3(0.0, -0.12, 0.0))
		elif to.length() > 0.01:
			_lure.global_transform = Transform3D(Basis.looking_at(to.normalized(), Vector3.UP)
					* Basis(Vector3.RIGHT, -PI * 0.5), b + Vector3(0.0, 0.02, 0.0))
		# (washing out as it goes off: the colour leaves it)
		var lm := _lure.material_override as StandardMaterial3D
		var fresh := float(spread.call("freshness", index)) if spread else 1.0
		var col: Color = Color(0.15, 0.25, 0.3) if live else LURES[index % LURES.size()]
		lm.albedo_color = col.lerp(Color(0.62, 0.6, 0.55), (1.0 - fresh) * 0.85)


func interact_prompt(player: Node) -> String:
	if holder == 0:
		if alongside:
			return "Hold it"   # (keep it up alongside for the harpoon: tuna/landing.gd)
		if hooked:
			return "Grab it!"
		if tangled >= 0:
			return "Clear the tangle"
		if bool(spread.call("fighting")):
			return "" if bait_in else "Reel in"
		if player != null and str(player.get("hands").get("item")) == "bait":
			return "Bait it"
		return "Pick it up"
	if hooked and holder != Net.my_id():
		return "Take over"
	return ""
