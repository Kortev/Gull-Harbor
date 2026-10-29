extends Node3D
## The chum bucket on her transom: cut-up bait to throw over the side while you wait. E on it throws a scoop; the
## pieces sink back through the baits and lay a slick there that a school smells from a long way off and comes up
## (tuna/schools.gd's host_chum), staying on it, working, while the chum keeps coming. A bucket's CHUM scoops a trip
## (boat/fish_hold.gd's chum), one every EVERY s or so: keep it going, a scoop a minute or so, and they'll stay.
##
## The host keeps the bucket (asked with _ask_scoop) and tells everyone where each scoop went (_scooped): a splash
## astern, and a brown-red slick spreading on the water that fades as it goes.

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
	act.use = func(_p: Node) -> void:
		if Net.is_host():
			_ask_scoop_as(Net.my_id())
		else:
			_ask_scoop.rpc_id(1)
	act.prompt = _prompt
	_bucket.add_child(act)


func _prompt() -> String:
	var hold: Node = sea.get("fish_hold")
	if hold == null or bool(hold.get("docked")):
		return ""
	var left := int(hold.get("chum"))
	if left <= 0:
		return "The chum bucket's empty"
	return "Throw chum (%d scoops left): a slick back through the baits brings the tuna up it" % left


@rpc("any_peer", "call_remote", "reliable")
func _ask_scoop() -> void:
	_ask_scoop_as(multiplayer.get_remote_sender_id())


## Host: a scoop if there's chum and it isn't too soon after the last.
func _ask_scoop_as(_who: int) -> void:
	var t := _now()
	if t - _last < EVERY:
		return
	var hold: Node = sea.get("fish_hold")
	if hold == null or not bool(hold.call("host_take_chum")):
		return
	_last = t
	var boat := sea.get("boat") as Node3D
	var spec: Dictionary = boat.get("spec")
	var stern: Vector3 = spec.get("stern", Vector3(0.0, 0.0, 7.05))
	var lands := boat.global_transform * (stern + Vector3(randf_range(-1.0, 1.0), 0.0, THROW))
	# the slick's heart: it sinks back through the middle of the spread
	var heart := Vector3.ZERO
	var baits: Array = spec.get("baits", [])
	for b: Vector3 in baits:
		heart += b / float(maxi(baits.size(), 1))
	var h := boat.global_transform * heart
	(sea.get("schools") as Node).call("host_chum", Vector2(h.x, h.z))
	if Net.in_session():
		_scooped.rpc(Vector2(lands.x, lands.z))
	else:
		_scooped(Vector2(lands.x, lands.z))


@rpc("authority", "call_local", "reliable")
func _scooped(at: Vector2) -> void:
	var ocean := sea.get("ocean") as Node
	var p := Vector3(at.x, 0.0, at.y)
	p.y = float(ocean.call("height_at", p))
	_splash.global_position = p
	_splash.pitch_scale = randf_range(1.3, 1.7)
	_splash.play()
	Sfx.play_point(self, _bucket.global_position if is_instance_valid(_bucket) else p, "dock.slap", 0.5, 0.8)
	var k := _next % PATCHES
	_next += 1
	_patches[k].global_position = p
	_patches[k].rotation = Vector3(0.0, randf_range(0.0, TAU), 0.0)
	_patches[k].visible = true
	_born[k] = _now()


## The slick's patches: riding the swell, spreading, fading.
func _process(_delta: float) -> void:
	var ocean := sea.get("ocean") as Node
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
