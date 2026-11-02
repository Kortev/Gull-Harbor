extends Node3D
## One stand-up tuna rod (art/rod.py -> rod.glb): in its stern holder with its bait out astern, or in someone's
## hands. rods.gd (the spread) decides where it is; this draws it: the blank bent toward the line's pull, the line
## from the tip out to where it meets the water, the spool turning with every metre on or off it (striped, so you see
## it go: a cast, a bait let back, a run), the crank turning only while it's wound, PER_TURN of line a turn (never in
## free spool), and in your own view your gloves on it: the left on the foregrip, the right on the crank's knob,
## going round with it.
##
## E on it: grab it (the host says yes or no). Q while holding it: put it back.

const MODEL := preload("res://rods/rod.glb")
const BEND := preload("res://rods/rod_bend.gdshader")
const LENGTH := 1.76
## Line one turn of the crank brings in (m: a big two-speed lever drag, in high), and the spool's own radius full (m).
const PER_TURN := 0.9
const SPOOL_R := 0.05
## Past this tension the tip shivers, and past SING the line sings, higher the nearer it is to going (the hook tears
## past tuna/fight.gd's HOOK_T, the line parts at 1).
const QUIVER := 0.5
const SING := 0.55
## Where your elbows are, from your eyes (m: crew/hands.gd's), for your sleeves.
const ELBOWS := {"r": Vector3(0.42, -0.72, 0.06), "l": Vector3(-0.42, -0.72, 0.02)}

const Kit := preload("res://crew/kit.gd")
const LineLook := preload("res://rods/line_look.gd")

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
## far it's laid over off the line (rad, + to the left), the drag lever (tuna/fight.gd: 0 free .. STRIKE_DRAG the
## strike detent .. 1 full; the lever on the reel shows it), the line's stretch (m; below 0 slack), how well the hook's
## holding (1 .. 0), and how twisted the line is from winding against the drag (0 .. 1).
var aim_pitch := 0.6
var aim_side := 0.0
var drag := 0.6
var twist := 0.0
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
## The arms of whoever's on it (tuna/fight.gd's `arms`, 1 fresh .. 0 gone), from their word: their crew see them go.
var arms := 1.0
## Its line, still out, in the way of another rod's fish (rods.gd's threat, every peer works it out): 0 clear, 0.5
## he's heading for it, 1 he's across it; and how long he's been across it (s: the host's, FOUL_IN and it's tangled).
var foul := 0.0
var foul_t := 0.0
## Who held it last (a fight that ended as it changed hands still counts: rods.gd's _report_end).
var last_holder := 0
## Its fish is beaten and up alongside (tuna/landing.gd): no more fighting, just the line to it till it's stuck.
var alongside := false
## Its line reeled in (cleared while another rod's fighting a fish: no bait out, nothing bites), and the rod whose
## running fish has its line tangled (-1: none).
var bait_in := false
var tangled := -1
## The bait on it: whether there is one (a fish takes it), when it went on (sea clock) and whether it's a live
## mackerel from the well (rods.gd's freshness; it always is now: nothing else gets taken).
var baited := true
var baited_t := 0.0
var live := false
## How well the bait's on (rods/rig.gd: 1 bridled clean, 0.5 hooked badly and swimming poorly), and whether it's
## being let back from its holder (the spool open, line going as it's towed out: rods.gd's _letting).
var bait_q := 1.0
var letting := false
## Taking it out of its holder or putting it back (rods.gd): where it was (her frame) and how far it's got (0..1).
var pose_from := Transform3D.IDENTITY
var pose_k := 1.0
## Line off the reel to the end of it as drawn (m, rods.gd every frame): the spool turns with it. The crank's turn
## (rad, from the line wound) and the spool's (rad).
var line_len := 0.0
var crank := 0.0
var spool_turn := 0.0
var _last_len := -1.0
var _len_v := 0.0
var _handle_base := Basis.IDENTITY
var _glove_r: Node3D
var _glove_l: Node3D
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
## The outrigger's release clip its line can run through (world; INF: it hasn't one), whether it's in it (rods.gd's
## _outrigger), and how far the line's up to it as drawn (0 straight from the tip .. 1 through the clip).
var clip := Vector3.INF
## Its outrigger pole's foot and tip (world; rods.gd's _outrigger): the clip rides a halyard between them.
var pole: Array = []
var clip_on := false
var clip_k := 0.0
var slack := 0.0
var _lure: Node3D
var _lure_back: StandardMaterial3D
## The fish on it, seen (rods.gd's _show_fish): its body in the water, the move it was last seen making, and the next
## splash it throws up.
var fish_node: Node3D
var seen_move := ""
var splash_in := 0.0
## The strike slamming the blank over (rods/fight_fx.gd: 1 at the hit, springing back to 0, a touch past), and how
## fast line's going off the reel (m/s, smoothed; - coming in).
var slam := 0.0
var paying := 0.0
## The clicker, the creak and the line's hiss (rods/reel_noise.gd), and how fast the line's slicing sideways through
## the water where it goes in (m/s, smoothed).
var noise: AudioStreamPlayer3D
var cutting := 0.0
var _last_cut := Vector3.INF
var _scream: AudioStreamPlayer3D
var _kick := 0.0
var _whir: AudioStreamPlayer3D
var _grind: AudioStreamPlayer3D
var _spool: MeshInstance3D
var _spool_mat: StandardMaterial3D
var _sing: AudioStreamPlayer3D
var _last_out := 0.0
var _paying := 0.0
var _blank: MeshInstance3D
## The drag lever on the reel's side plate (forward: tighter), and the rod springing back straight when he's gone.
var _lever: Node3D
var _recoil := 0.0
var _handle: Node3D
var _tip_local := Vector3(0, 0, LENGTH)
var _bend := Vector2.ZERO
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _line_mat: ShaderMaterial
var _clip_mesh: MeshInstance3D
var _cut_t := 0.0
var _cut_v := Vector3.ZERO
var _last_end := Vector3.INF
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
			_handle_base = t.basis
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
	# (the line laid on in turns: a few darker stripes round it, so you can see the spool go round)
	var img := Image.create_empty(8, 1, false, Image.FORMAT_RGB8)
	for x in 8:
		img.set_pixel(x, 0, Color(1, 1, 1) if x % 4 != 0 else Color(0.62, 0.62, 0.58))
	_spool_mat.albedo_texture = ImageTexture.create_from_image(img)
	_spool_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_spool.material_override = _spool_mat
	add_child(_spool)
	# the drag lever: a red-knobbed arm on the reel's side plate, swung forward to tighten it
	_lever = Node3D.new()
	_lever.position = Vector3(0.048, 0.1, 0.37)
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.008, 0.055, 0.012)
	arm.mesh = am
	arm.position = Vector3(0.0, 0.03, 0.0)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.62, 0.64, 0.66)
	steel.metallic = 0.6
	steel.roughness = 0.4
	arm.material_override = steel
	_lever.add_child(arm)
	var knob := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(0.016, 0.018, 0.02)
	knob.mesh = km
	knob.position = Vector3(0.002, 0.062, 0.0)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.78, 0.12, 0.08)
	red.roughness = 0.5
	knob.material_override = red
	_lever.add_child(knob)
	add_child(_lever)
	# your gloves on it (only in your own view: the others see crew/player.gd's arms)
	_glove_r = Kit.glove("r")
	_glove_l = Kit.glove("l")
	for g: Node3D in [_glove_r, _glove_l]:
		g.visible = false
		add_child(g)
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.top_level = true
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (thin mono: clear close to, a faint thread far off: rods/line_look.gd)
	_line_mat = LineLook.material()
	_line.material_override = _line_mat
	add_child(_line)
	# the outrigger's release clip, on its halyard out along the pole: a little red pinch clip the line runs through
	_clip_mesh = MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.035, 0.07, 0.03)
	_clip_mesh.mesh = cb
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.7, 0.16, 0.1)
	cm.roughness = 0.7
	_clip_mesh.material_override = cm
	_clip_mesh.top_level = true
	_clip_mesh.visible = false
	_clip_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_clip_mesh)
	# the bait on the end of it: a live mackerel, hooked through the lips
	_lure = Kit._mackerel()
	_lure.top_level = true
	for mi in _lure.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (its colour fades as it tires: a tint over the whole bait, whatever the model's made of)
	_lure_back = StandardMaterial3D.new()
	_lure_back.albedo_color = Color(0.18, 0.42, 0.4)
	_lure_back.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	_lure_back.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mi in _lure.find_children("*", "MeshInstance3D", true, false):
		var body := mi as MeshInstance3D
		if body.material_overlay == null:
			body.material_overlay = _lure_back
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
	noise = preload("res://rods/reel_noise.gd").new()
	add_child(noise)
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
	var pull := (_via() if clip_k > 0.01 else line_end) - global_position
	var local := global_transform.basis.inverse() * pull.normalized()
	# (a big rod loads up hard early, a strike drag's already a deep bend, and only creeps further toward parting:
	# past that it's the creak, the line singing and the tip shivering that say how near it is)
	var bend := 0.05 + 0.85 * (1.0 - exp(-maxf(strain, 0.0) * 3.2))
	var want := Vector2(local.x, local.y) * (bend + 0.5 * slam) * LENGTH * 0.45
	if _recoil > 0.0:
		# (he's gone: the blank springs back up past straight and shivers still)
		_recoil = maxf(_recoil - delta * 1.4, 0.0)
		want += Vector2(0.0, 0.09 * _recoil * cos((1.0 - _recoil) * 18.0))
	# near the limit the tip quivers: the line's about to go
	if strain > QUIVER:
		var t := Time.get_ticks_msec() * 0.001
		want += Vector2(sin(t * 23.0), sin(t * 17.0 + 1.3)) * (0.02 * (strain - QUIVER) / 0.3 + 0.005)
	# (a strike throws it over hard: it gets there in a few frames, not a quarter second)
	_bend = _bend.lerp(want, minf(1.0, delta * (12.0 + 40.0 * absf(slam))))
	# (a rod in your hands mustn't catch your own look; a crewmate's with a fish on, you can take over)
	_grab.collision_layer = 1 if holder == 0 or (hooked and holder != Net.my_id()) else 0
	_blank.set_instance_shader_parameter("bend", _bend)
	# the spool goes round with every bit of line on or off it; the crank only while it's wound (PER_TURN a turn), and
	# slow and heavy grinding against the drag
	if _last_len < 0.0:
		_last_len = line_len
	var dl := clampf(line_len - _last_len, -3.0, 3.0)
	_last_len = line_len
	_len_v = lerpf(_len_v, dl / maxf(delta, 1e-4), minf(delta * 8.0, 1.0))
	var left_k := clampf(1.0 - (line_out if hooked else 0.0) / 500.0, 0.0, 1.0)
	# (the drag lever: back for free spool, the strike detent upright, forward to full)
	_lever.rotation.x = lerp_angle(_lever.rotation.x, lerpf(0.9, -0.9, clampf(drag, 0.0, 1.0)), minf(1.0, delta * 14.0))
	spool_turn += dl / (SPOOL_R * (0.4 + 0.6 * left_k))
	if reeling > 0.05:
		crank += reeling / PER_TURN * TAU * delta
	elif grinding and hooked:
		crank += 0.45 * TAU * delta
	if _handle:
		_handle.basis = Basis(Vector3.RIGHT, -crank) * _handle_base
	_hands(delta)
	# the drag screams while the fish takes line: louder and higher the faster it goes
	# (smoothed: a crewmate's fish comes in ten updates a second, and the drag mustn't stutter with them)
	var raw := (line_out - _last_out) / maxf(delta, 1e-4)
	_last_out = line_out
	_paying = lerpf(_paying, raw, minf(delta * 6.0, 1.0))
	paying = _paying
	# the line slicing through the water where it goes in: how fast that point's swinging round, her own way taken off
	var rel := line_end - tip_position()
	if hooked and _last_cut != Vector3.INF:
		cutting = lerpf(cutting, (rel - _last_cut).length() / maxf(delta, 1e-4), minf(delta * 4.0, 1.0))
	else:
		cutting = 0.0
	_last_cut = rel if hooked else Vector3.INF
	# the clicker ticks for every few cm off the spool (a run's a blur of them); the hiss is the line in the water
	# (and a smaller spool turns more for each metre: the emptier it gets the faster it ticks and the higher it goes)
	var small := 1.0 / (0.45 + 0.55 * left_k)
	noise.arbor = clampf((small - 1.0) / 1.2, 0.0, 1.0) if hooked else 0.0
	noise.clicks = (maxf(paying, 0.0) * 14.0 * small + 140.0 * maxf(slam, 0.0)) if hooked \
			else (maxf(_len_v, 0.0) * 14.0 if letting else 0.0)     # (a bait let back: the clicker on)
	noise.strain = strain + 0.3 * maxf(slam, 0.0) if hooked else 0.0
	var hiss_k := clampf((maxf(paying, 0.0) + cutting) / 9.0, 0.0, 1.0) * clampf(strain * 1.4, 0.3, 1.0)
	noise.hiss = hiss_k if hooked else 0.0
	if hooked and paying > 0.6:
		if not _scream.playing:
			_scream.play()
		_scream.pitch_scale = clampf((0.75 + paying / 14.0) * lerpf(1.0, 1.6, noise.arbor), 0.75, 2.2)
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
	var singing := hooked and strain >= SING
	if singing and not _sing.playing:
		_sing.play()
	elif not singing and _sing.playing:
		_sing.stop()
	if _sing.playing:
		_sing.pitch_scale = 0.55 + 1.6 * (strain - SING)
	var k := 0.4 + 0.6 * left_k
	_spool.basis = Basis(Vector3.RIGHT, spool_turn) * Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(k, 1.0, k))
	var gone := line_out if hooked else 0.0
	# (the line on top, then the white backing under it past half the spool, and near the end the bare metal arbor)
	_spool_mat.albedo_color = Color(0.85, 0.86, 0.78) if gone <= 250.0 else (Color(0.97, 0.97, 0.95) if gone <= 430.0
			else Color(0.55, 0.57, 0.6))
	_draw_line()


## Your own gloves on it while it's in your hands: the left round the foregrip, the right on the crank's knob (going
## round with it), your sleeves back to your elbows.
func _hands(_delta: float) -> void:
	var mine := holder != 0 and holder == Net.my_id()
	_glove_r.visible = mine and _handle != null
	_glove_l.visible = mine
	if not mine:
		return
	_glove_l.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, -0.005, 0.52))
	if _handle:
		var knob := _handle.transform * Vector3(0.0325, -0.075, 0.0)
		_glove_r.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.FORWARD, 0.4), knob)
	var crew: Node = spread.get("sea").get("crew") if spread else null
	var me: Node = crew.get("me") if crew else null
	var cam: Camera3D = me.get("cam") if me else null
	if cam == null:
		return
	for g: Node3D in [_glove_r, _glove_l]:
		var sleeve := g.get_node_or_null("Sleeve") as Node3D
		if sleeve == null:
			continue
		var elbow := cam.global_transform * (ELBOWS["l" if g == _glove_l else "r"] as Vector3)
		var from := sleeve.global_position
		if from.distance_squared_to(elbow) > 0.0001:
			var up := cam.global_basis.y
			if absf((elbow - from).normalized().dot(up)) > 0.98:
				up = cam.global_basis.z
			sleeve.look_at(elbow, up)


## He's gone (rods.gd's _off, on every peer): everything on the reel stops at once, the rod springs back up straight,
## and the line goes: a crack if it parted, nothing but the sudden ease of it if the hook came out.
func lost_it(parted: bool) -> void:
	for a: AudioStreamPlayer3D in [_scream, _whir, _sing, _grind]:
		a.stop()
	noise.snap(parted)
	_recoil = 1.0


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
	# a fish on: the line bar-tight and catching the light, and the fighter needs to see its angle into the water
	var fighting := hooked and not alongside
	_line_mat.set_shader_parameter("floor_alpha", lerpf(0.2, 0.45, clampf(strain * 1.5, 0.0, 1.0)) if fighting else 0.03)
	_line_mat.set_shader_parameter("clear_to", 10.0 if fighting else 3.0)
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	_line_mesh.surface_set_color(LineLook.MONO)
	# a line always hangs in a belly between where it's held (the tip, the clip) and where it goes in; a slack one
	# (she's stopped, a fish come at you) a lot, down onto the water; a fish pulling draws it straight
	var tight := 1.0 - 0.9 * clampf(strain, 0.0, 1.0)
	var from := a
	if clip_k > 0.01:
		# up to the outrigger's clip (or falling from it), then out from there to the bait: up there it's light, just
		# its own weight between the two, so it sags a good deal
		var via := _via()
		_sag_line(a, via, 0.06 * tight, false)
		from = via
		_sag_line(via, b, (0.05 + 0.3 * slack) * tight, true)
	else:
		_sag_line(a, b, (0.04 + 0.3 * slack) * tight, false)
	# and on under the water, straight down to him (seen from below the top, or as he comes up close)
	if fighting and is_instance_valid(fish_node) and fish_node.visible:
		_line_mesh.surface_set_color(Color(LineLook.MONO, 0.6))
		_line_mesh.surface_add_vertex(fish_node.global_position)
	_line_mesh.surface_end()
	_draw_rigger()
	_draw_cut(from, b)
	a = from
	# the mackerel, nose toward the rod, swimming just under the top; or hanging off the tip by its lips with the line
	# in, kicking, or flying. Tiring, it kicks slower and goes pale.
	var flying := bool(spread.call("flying", index)) if spread else false
	var out := baited and not hooked and tangled < 0 and (bait_in or flying or bait_p != Vector3.INF)
	_lure.visible = out
	if out:
		var fresh := float(spread.call("freshness", index)) if spread else 1.0
		# (a dead one doesn't kick; a live one hooked badly swims lopsided)
		var swim := (0.12 + 0.25 * fresh) * (1.0 if live else 0.0)
		_kick += get_process_delta_time() * (3.0 + 9.0 * fresh) * (1.0 if bait_q >= 0.9 else 0.6)
		var wiggle := Basis(Vector3.UP, sin(_kick) * swim) * Basis(Vector3.FORWARD, 0.0 if bait_q >= 0.9 or not live
				else 0.9)
		var to := (a - b) * Vector3(1, 0, 1)
		var hang := Basis(Vector3.RIGHT, PI * 0.5) * wiggle
		# (coming up to the tip, it turns from swimming to hanging by its lips, a bit at a time)
		var tip := tip_position() + Vector3(0.0, -0.3, 0.0)
		var up := 1.0 if bait_in or flying else 1.0 - smoothstep(0.35, 2.5, b.distance_to(tip))
		if bait_in or flying or to.length() <= 0.01:
			_lure.global_transform = Transform3D(hang, b + Vector3(0.0, -0.14, 0.0))
		else:
			var swimming := Basis.looking_at(to.normalized(), Vector3.UP) * wiggle
			_lure.global_transform = Transform3D(swimming.slerp(hang, up), b + Vector3(0.0, lerpf(-0.06, -0.14, up), 0.0))
		var pale := Color(0.75, 0.78, 0.78) if live else Color(0.62, 0.6, 0.58)
		_lure_back.albedo_color = Color(1, 1, 1).lerp(pale, (1.0 - fresh) * 0.8 if live else 0.85)


## The outrigger's clip and its halyard: up the pole from its foot to the clip and on to the pulley at its tip (the
## clip stays out there after a strike pops the line out of it).
func _draw_rigger() -> void:
	var has := clip != Vector3.INF and pole.size() == 2
	_clip_mesh.visible = has
	if not has:
		return
	var foot: Vector3 = pole[0]
	var top: Vector3 = pole[1]
	var along := (top - foot).normalized()
	# (the clip hangs under the halyard, swinging a touch with the boat)
	_clip_mesh.global_transform = Transform3D(Basis.looking_at(along, Vector3.UP), clip + Vector3(0.0, -0.04, 0.0))
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	_line_mesh.surface_set_color(Color(0.86, 0.86, 0.82, 0.8))
	# (a halyard runs a hand under the pole, so it reads as its own line, not part of the steel)
	var drop := Vector3(0.0, -0.12, 0.0)
	_line_mesh.surface_add_vertex(foot + drop * 0.5)
	_line_mesh.surface_add_vertex(clip)
	_line_mesh.surface_add_vertex(top + drop * 0.3)
	_line_mesh.surface_end()


## Where the line goes in: at speed, a little V of spray thrown back off it, and a feather of white up its back,
## flickering. A bait towed at trolling speed makes one; a running fish dragging it through the water makes more.
func _draw_cut(from: Vector3, b: Vector3) -> void:
	var v := Vector3.ZERO
	if hooked and not alongside:
		v = (b - _last_end) / maxf(get_process_delta_time(), 1e-4) if _last_end != Vector3.INF else Vector3.ZERO
	elif bait_p != Vector3.INF and not bait_in:
		v = bait_v
	_last_end = b
	v.y = 0.0
	var speed := v.length() if v.length() < 30.0 else 0.0
	_cut_v = _cut_v.lerp(v, minf(get_process_delta_time() * 4.0, 1.0)) if speed > 0.0 else _cut_v * 0.9
	var k := clampf((_cut_v.length() - 1.0) / 4.0, 0.0, 1.0)
	if k <= 0.02 or tangled >= 0 or (spread != null and bool(spread.call("flying", index))):
		return
	_cut_t += get_process_delta_time() * (9.0 + 3.0 * index)
	var back := -_cut_v.normalized()       # (the water streams past it astern of where it's going)
	var side := back.cross(Vector3.UP)
	var reach := (0.35 + 0.8 * k) * (0.85 + 0.15 * sin(_cut_t))
	var at := b + Vector3(0.0, 0.03, 0.0)
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_line_mesh.surface_set_color(Color(1.0, 1.0, 1.0, 0.5 + 0.4 * k))
	for s: float in [-1.0, 1.0]:
		var spread_k := 0.35 + 0.08 * sin(_cut_t * 1.3 + s)
		_line_mesh.surface_add_vertex(at)
		_line_mesh.surface_add_vertex(at + (back + side * s * spread_k).normalized() * reach)
	# (the feather: up the line's back a little, falling away astern)
	var up := (from - b).normalized()
	var h := (0.08 + 0.18 * k) * (0.7 + 0.3 * sin(_cut_t * 1.7))
	_line_mesh.surface_add_vertex(at)
	_line_mesh.surface_add_vertex(at + up * h * 0.6 + back * h * 0.8 + Vector3(0.0, h * 0.5, 0.0))
	_line_mesh.surface_end()


## Where the line bends: at the outrigger's clip, or on its way down from it to the straight line (clip_k).
func _via() -> Vector3:
	var straight := tip_position().lerp(line_end, 0.25)
	return straight.lerp(clip, smoothstep(0.0, 1.0, clip_k)) if clip != Vector3.INF else straight


## A drooping stretch of line from a to b (`droop`: how far it sags, for its length), into the strip being drawn.
## Going down to the water it's held from above and pulled from below: it falls away steeply under the tip and lays
## in at a shallow angle, its lowest point where it goes in (no belly lying along the top), unless it's gone slack.
func _sag_line(a: Vector3, b: Vector3, droop: float, skip_first: bool) -> void:
	var sag := droop * a.distance_to(b)
	if a.y > b.y:
		sag = lerpf(minf(sag, (a.y - b.y) * 0.22), sag, slack)
	for i in range(1 if skip_first else 0, 17):
		var f := i / 16.0
		var p := a.lerp(b, f)
		p.y -= sag * 4.0 * f * (1.0 - f)
		p.y = maxf(p.y, minf(b.y, a.y) - 0.05)       # (not through the water)
		_line_mesh.surface_add_vertex(p)


func interact_prompt(player: Node) -> String:
	if holder == 0:
		if alongside:
			return "Hold it"   # (keep it up alongside for the harpoon: tuna/landing.gd)
		if hooked:
			return "Grab it!"
		if tangled >= 0:
			return "Clear the tangle"
		if bool(spread.call("fighting")):
			return "" if bait_in else "Pick it up: wind it in"
		var carrying := str(player.get("hands").call("carrying")) if player != null else ""
		if not carrying.is_empty():
			if not bait_in:
				return "Wind it in first: pick it up"
			return "Hook it on" if not baited else "Swap the bait"
		if bait_in and not baited:
			return "Pick it up (a bare hook)"
		return "Pick it up"
	if hooked and holder != Net.my_id():
		return "Take over"
	return ""
