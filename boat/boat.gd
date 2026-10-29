extends AnimatableBody3D
## The boat (art/boat.py -> boat.glb): a 41 ft tuna boat for a crew of four. It never goes anywhere: it sits at
## the origin and rides the swell, heaving, pitching and rolling with the sea under it. Its pose comes only from
## the ocean's wave clock, so every peer computes the same deck under the same feet. Being an AnimatableBody3D,
## it carries whoever stands on it. (The pattern is Gull Harbor's TunaBoat, on Fathom's ocean.)

const Ocean := preload("res://sea/ocean.gd")
const MODEL := preload("res://boat/boat.glb")

const LENGTH := 12.5
const BEAM := 4.3
const DECK := 0.55          # the cockpit sole above the model's origin (its waterline)
const SINK := 0.12          # loaded with ice, fuel and crew she sits a little below her painted waterline
## How much of the sea's slope the hull follows: a long, heavy hull bridges the short chop.
const PITCH_FOLLOW := 0.75
const ROLL_FOLLOW := 0.7

var ocean: Ocean
var spawns: Array[Transform3D] = []      # boat-local
var holders: Array[Transform3D] = []     # boat-local; see holder_transform()
var helm := Transform3D.IDENTITY
var floods: Array[SpotLight3D] = []
var chair: Node3D
var wheel: Node3D
var _radar: Node3D
var _lights_on := false


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	_build()


func _build() -> void:
	var src := MODEL.instantiate() as Node3D
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	for n: String in ["boat", "chair", "wheel", "radar"]:
		var mi := src.find_child(n, true, false) as Node3D
		if mi:
			var t := _src_transform(mi, src)
			mi.owner = null
			mi.get_parent().remove_child(mi)
			mi.transform = t
			visual.add_child(mi)
	chair = visual.get_node_or_null("chair") as Node3D
	wheel = visual.get_node_or_null("wheel") as Node3D
	_radar = visual.get_node_or_null("radar") as Node3D
	var col_mesh := src.find_child("collider", true, false) as MeshInstance3D
	if col_mesh:
		var shape := col_mesh.mesh.create_trimesh_shape()
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = _src_transform(col_mesh, src)
		add_child(cs)
	for i in 4:
		var e := src.find_child("spawn_%d" % i, true, false) as Node3D
		if e:
			spawns.append(_src_transform(e, src))
	for i in 8:
		var e := src.find_child("holder_%d" % i, true, false) as Node3D
		if e:
			holders.append(_src_transform(e, src))
	var h := src.find_child("helm", true, false) as Node3D
	if h:
		helm = _src_transform(h, src)
	# The tower floodlights and the cockpit lights: each empty's Blender -Z (Godot -Y) is where its light points.
	for n: String in ["flood_0", "flood_1", "deck_light_0", "deck_light_1"]:
		var e := src.find_child(n, true, false) as Node3D
		if e == null:
			continue
		var t := _src_transform(e, src)
		var l := SpotLight3D.new()
		l.name = n
		var aim := t.basis.y.normalized() * -1.0
		l.transform = Transform3D(Basis.looking_at(aim, Vector3.UP if absf(aim.y) < 0.99 else Vector3.FORWARD),
				t.origin)
		var big := n.begins_with("flood")
		l.light_color = Color(1.0, 0.86, 0.62)
		l.light_energy = 6.0 if big else 2.5
		l.spot_range = 22.0 if big else 7.0
		l.spot_angle = 48.0 if big else 70.0
		l.spot_attenuation = 0.8
		l.shadow_enabled = big
		l.visible = false
		add_child(l)
		floods.append(l)
	src.free()


## A node's transform relative to the imported scene root (before it's in the tree).
static func _src_transform(n: Node3D, root: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func set_lights(on: bool) -> void:
	_lights_on = on
	for l in floods:
		l.visible = on


func _process(delta: float) -> void:
	if _radar:
		_radar.rotate_y(delta * 2.6)


func _physics_process(_delta: float) -> void:
	if ocean == null:
		return
	global_transform = pose()
	# Keep the sea from being drawn inside the hull when a crest rises past the waterline.
	# A flat cut a little under the deck's lowest corner, so it still holds when she rolls.
	var fwd := -global_transform.basis.z
	var low := INF
	for c: Vector3 in [Vector3(-1.9, DECK, -4.0), Vector3(1.9, DECK, -4.0), Vector3(-1.9, DECK, 5.8),
			Vector3(1.9, DECK, 5.8)]:
		low = minf(low, (global_transform * c).y)
	ocean.set_dry(Vector2.ZERO, Vector2(LENGTH * 0.46, BEAM * 0.48), Vector2(fwd.x, fwd.z), low - 0.1)


## Where the hull sits on the swell right now: the waterline from the mean of the water under it, pitch from bow
## vs stern, roll from port vs starboard. A pure function of the wave clock, so every peer agrees.
func pose() -> Transform3D:
	var hl := LENGTH * 0.42
	var hb := BEAM * 0.45
	var bow := ocean.height_at(Vector3(0.0, 0.0, -hl))
	var stern := ocean.height_at(Vector3(0.0, 0.0, hl))
	var port := ocean.height_at(Vector3(-hb, 0.0, 0.0))
	var stbd := ocean.height_at(Vector3(hb, 0.0, 0.0))
	var mid := ocean.height_at(Vector3.ZERO)
	var y := (bow + stern + port + stbd + mid * 2.0) / 6.0 - SINK
	var pitch := atan2(bow - stern, hl * 2.0) * PITCH_FOLLOW
	var roll := atan2(stbd - port, hb * 2.0) * ROLL_FOLLOW
	return Transform3D(Basis.from_euler(Vector3(pitch, 0.0, roll)), Vector3(0.0, y, 0.0))


## A rod holder's tube in world space: origin at the rim, +Z along the tube out of it.
func holder_transform(i: int) -> Transform3D:
	var t := holders[i]
	# The Blender empty's +Z became Godot +Y on export: turn that into +Z.
	var along := t.basis.y.normalized()
	var b := Basis.looking_at(-along, Vector3.UP if absf(along.y) < 0.99 else Vector3.FORWARD)
	return global_transform * Transform3D(b, t.origin)


func spawn_point(slot: int) -> Transform3D:
	if spawns.is_empty():
		return global_transform * Transform3D(Basis.IDENTITY, Vector3(0, DECK + 0.1, 2.0))
	return global_transform * spawns[slot % spawns.size()].translated(Vector3(0, 0.1, 0))


## The eyes of someone standing on deck (for the camera until the crew exists).
func eye(local: Vector3) -> Vector3:
	return global_transform * local
