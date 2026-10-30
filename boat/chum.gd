extends Node3D
## The chum bucket on her transom: cut-up bait to throw over the side while you wait. The scoop in your hands
## (crew/hands.gd's kit, key 4), left mouse on the bucket dips it full; then hold left mouse to wind up and let go to
## throw it, where you're looking, as far as you wound it. Where it lands it lays a slick that a school smells from a
## long way off and comes up (tuna/schools.gd's host_chum), staying on it, working, while the chum keeps coming: put
## it back among your baits. A bucket's CHUM scoops a trip (boat/fish_hold.gd's chum), one every EVERY s or so: keep
## it going, a scoop a minute or so, and they'll stay.
##
## The host keeps the bucket (asked with _ask_throw) and tells everyone where each scoop went (_scooped): the chum
## flying from the thrower's hand, a splash, and a brown-red slick spreading on the water that fades as it goes.

const Action := preload("res://core/action.gd")
const Sfx := preload("res://audio/sfx.gd")
const SPLASH := preload("res://audio/fish/splash.wav")
## The quickest one scoop follows another (s), how far astern of her transom it lands (m), and how long a patch of
## the slick shows (s) as it spreads (m across, from .. to).
const EVERY := 1.5
const THROW := 3.0
const FADE := 120.0
const SPREAD := Vector2(2.5, 9.0)
const PATCHES := 10

var sea: Node                 # sea/sea.gd
var _bucket: Node3D
var _last := -1e9             # (host: when the last scoop went)
var _patches: Array[MeshInstance3D] = []
var _born: Array[float] = []
var _next := 0
var _splash: AudioStreamPlayer3D
## Scoops in the air: [from, to (world), when thrown (s, real), its pieces].
var _flying: Array = []


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.36, 0.16, 0.1, 0.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in PATCHES:
		var p := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2.ONE
		p.mesh = q
		p.material_override = mat.duplicate()
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.top_level = true
		p.visible = false
		add_child(p)
		_patches.append(p)
		_born.append(-1e9)
	_splash = AudioStreamPlayer3D.new()
	_splash.stream = SPLASH
	_splash.unit_size = 6.0
	_splash.volume_db = -6.0
	_splash.top_level = true
	add_child(_splash)
	_attach()
	(sea.get("boat") as Node).connect("rebuilt", _attach)


## The bucket, where her kind keeps it (again whenever she's rebuilt as another).
func _attach() -> void:
	var boat := sea.get("boat") as Node3D
	if is_instance_valid(_bucket):
		_bucket.get_parent().remove_child(_bucket)
		_bucket.queue_free()
	_bucket = _make_bucket()
	_bucket.position = (boat.get("spec") as Dictionary).get("chum", Vector3(-0.3, 1.3, 6.6))
	boat.add_child(_bucket)
	var act := Action.new(Vector3(0.45, 0.6, 0.45))
	act.name = "Scoop"
	act.position = Vector3(0.0, 0.2, 0.0)
	act.prompt = func() -> String: return ""
	act.use_with = _dip
	_bucket.add_child(act)


## Left mouse on the bucket with the scoop in your hands: an empty scoop comes up full (if there's any left). A full
## one isn't taken: that press winds up the throw (crew/hands.gd).
func _dip(p: Node, item: String, pressed: bool) -> bool:
	var hands: Node = p.get("hands") if p else null
	if item != "scoop" or hands == null or bool(hands.get("scoop_full")):
		return false
	if pressed and int((sea.get("fish_hold") as Node).get("chum")) > 0:
		hands.set("scoop_full", true)
		p.call("gesture", "scoop")
		Sfx.play_point(self, _bucket.global_position, "dock.slap", 0.45, 0.7)
	return true


## A full scoop let go by `p`, out along `dir` (flat, world) `dist` metres from them: it lands on the water there
## (never on her deck: past her side if it'd fall short).
func throw(p: Node3D, dir: Vector3, dist: float) -> void:
	var boat := sea.get("boat") as Node3D
	var spec: Dictionary = boat.get("spec")
	var from: Vector3 = p.global_position + Vector3.UP * 1.4
	var inv := boat.global_transform.affine_inverse()
	var aft := (spec.get("transom", Vector3(0, 0, 7.0)) as Vector3).z
	var at := from + dir * dist
	for i in 40:
		var l := inv * at
		if absf(l.x) > float(spec["beam"]) * 0.5 + 0.5 or l.z > aft + 0.5 or l.z < aft - float(spec["length"]) - 0.5:
			break
		at += dir * 0.5
	if Net.is_host():
		_ask_throw_as(Vector2(at.x, at.z), from)
	else:
		_ask_throw.rpc_id(1, Vector2(at.x, at.z), from)


@rpc("any_peer", "call_remote", "reliable")
func _ask_throw(at: Vector2, from: Vector3) -> void:
	_ask_throw_as(at, from)


## Host: a scoop thrown from `from` to land at `at` (world x, z), if there's chum and it isn't too soon after the
## last: the slick's there.
func _ask_throw_as(at: Vector2, from: Vector3) -> void:
	var t := _now()
	if t - _last < EVERY:
		return
	var hold: Node = sea.get("fish_hold")
	if hold == null or not bool(hold.call("host_take_chum")):
		return
	_last = t
	(sea.get("schools") as Node).call("host_chum", at)
	if Net.in_session():
		_scooped.rpc(at, from)
	else:
		_scooped(at, from)


## Host (the tests): a scoop thrown THROW m astern of her transom.
func _ask_scoop_as(_who: int) -> void:
	var boat := sea.get("boat") as Node3D
	var stern: Vector3 = (boat.get("spec") as Dictionary).get("stern", Vector3(0.0, 0.0, 7.05))
	var lands := boat.global_transform * (stern + Vector3(randf_range(-1.0, 1.0), 0.0, THROW))
	_ask_throw_as(Vector2(lands.x, lands.z), boat.global_transform * stern + Vector3.UP * 1.5)


@rpc("authority", "call_local", "reliable")
func _scooped(at: Vector2, from := Vector3.INF) -> void:
	var ocean := sea.get("ocean") as Node
	var p := Vector3(at.x, 0.0, at.y)
	p.y = float(ocean.call("height_at", p))
	if from == Vector3.INF:
		from = p + Vector3.UP
	# the chum flying out of the scoop: a handful of pieces in an arc, then the splash and the slick (_process)
	var pieces: Array[MeshInstance3D] = []
	for i in 5:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE * randf_range(0.05, 0.09)
		m.mesh = b
		m.material_override = _chum_mat()
		m.top_level = true
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		m.global_position = from
		pieces.append(m)
	_flying.append([from, p, Time.get_ticks_msec() * 0.001, pieces])


func _chum_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 0.13, 0.09)
	m.roughness = 0.4
	return m


## A scoop come down on the water: the splash, and a patch of slick there.
func _lands(p: Vector3) -> void:
	_splash.global_position = p
	_splash.pitch_scale = randf_range(1.3, 1.7)
	_splash.play()
	var k := _next % PATCHES
	_next += 1
	_patches[k].global_position = p
	_patches[k].rotation = Vector3(0.0, randf_range(0.0, TAU), 0.0)
	_patches[k].visible = true
	_born[k] = _now()


## The scoops in the air, and the slick's patches: riding the swell, spreading, fading.
func _process(_delta: float) -> void:
	var ocean := sea.get("ocean") as Node
	var now := Time.get_ticks_msec() * 0.001
	for f: Array in _flying.duplicate():
		var from: Vector3 = f[0]
		var to: Vector3 = f[1]
		var fly := 0.25 + from.distance_to(to) / 18.0
		var k := (now - float(f[2])) / fly
		var pieces: Array = f[3]
		if k >= 1.0:
			for m: MeshInstance3D in pieces:
				m.queue_free()
			_flying.erase(f)
			_lands(to)
			continue
		for i in pieces.size():
			var kk := clampf(k * (1.0 - 0.06 * i), 0.0, 1.0)
			var at := from.lerp(to, kk) + Vector3(sin(i * 2.1), 0.0, cos(i * 1.7)) * 0.25 * kk
			at.y += from.distance_to(to) * 0.3 * 4.0 * kk * (1.0 - kk)
			(pieces[i] as MeshInstance3D).global_position = at
			(pieces[i] as MeshInstance3D).rotation += Vector3(0.2, 0.3, 0.1)
	var t := _now()
	for i in PATCHES:
		var p := _patches[i]
		if not p.visible:
			continue
		var age := (t - _born[i]) / FADE
		if age >= 1.0 or age < 0.0:
			p.visible = false
			continue
		var at := p.global_position
		at.y = float(ocean.call("height_at", at)) + 0.04
		p.global_position = at
		var size := lerpf(SPREAD.x, SPREAD.y, sqrt(age))
		p.scale = Vector3(size, 1.0, size * 0.7)
		var m := p.material_override as StandardMaterial3D
		var col := m.albedo_color
		col.a = 0.45 * (1.0 - age) * minf(age * 20.0, 1.0)
		m.albedo_color = col


func _now() -> float:
	return float((sea.get("ocean") as Node).get("wave_time"))


## A white 5-gallon bucket, half full of chum, with a scoop in it.
static func _make_bucket() -> Node3D:
	var root := Node3D.new()
	root.name = "ChumBucket"
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.86, 0.85, 0.8)
	white.roughness = 0.8
	var chum := StandardMaterial3D.new()
	chum.albedo_color = Color(0.38, 0.14, 0.1)
	chum.roughness = 0.4
	var body := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.15
	c.bottom_radius = 0.13
	c.height = 0.37
	c.radial_segments = 8
	c.rings = 1
	body.mesh = c
	body.material_override = white
	body.position = Vector3(0.0, 0.185, 0.0)
	root.add_child(body)
	var top := MeshInstance3D.new()
	var d := CylinderMesh.new()
	d.top_radius = 0.14
	d.bottom_radius = 0.14
	d.height = 0.01
	d.radial_segments = 8
	d.rings = 1
	top.mesh = d
	top.material_override = chum
	top.position = Vector3(0.0, 0.3, 0.0)
	root.add_child(top)
	var scoop := MeshInstance3D.new()
	var s := BoxMesh.new()
	s.size = Vector3(0.03, 0.03, 0.36)
	scoop.mesh = s
	scoop.material_override = white
	scoop.position = Vector3(0.04, 0.38, 0.0)
	scoop.rotation = Vector3(0.9, 0.3, 0.0)
	root.add_child(scoop)
	return root
