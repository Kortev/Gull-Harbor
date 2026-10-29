extends AnimatableBody3D
## The boat (art/boat.py -> boat.glb): a 41 ft tuna boat for a crew of four. It never goes anywhere: it sits at
## the origin and rides the swell, heaving, pitching and rolling with the sea under it. Its pose comes only from
## the ocean's wave clock, so every peer computes the same deck under the same feet. (The pattern is Gull Harbor's
## TunaBoat, on Fathom's ocean.)
##
## The crew don't walk on this moving body. They walk in the DECK SPACE: a separate, still physics world holding
## the same collider, never moving (the space game's "the ship never moves" rule). A crew member's position there
## IS their boat-local position, and what you see is that, carried by the boat's pose (crew/player.gd). So the
## deck is solid underfoot in any sea, nobody slides, and the network only needs boat-local positions.

const Ocean := preload("res://sea/ocean.gd")
const MODEL := preload("res://boat/boat.glb")

const LENGTH := 12.5
const BEAM := 4.3
const DECK := 0.55          # the cockpit sole above the model's origin (its waterline)
const SINK := 0.12          # loaded with ice, fuel and crew she sits a little below her painted waterline
## How much of the sea's slope the hull follows: a long, heavy hull bridges the short chop.
const PITCH_FOLLOW := 1.0
const ROLL_FOLLOW := 0.85

var ocean: Ocean
var spawns: Array[Transform3D] = []      # boat-local
var holders: Array[Transform3D] = []     # boat-local; see holder_transform()
var helm := Transform3D.IDENTITY
var floods: Array[Light3D] = []
var chair: Node3D
var wheel: Node3D
var _radar: Node3D
## The still world the crew walk in (see above): add crew bodies under deck_root.
var deck_space: SubViewport
var deck_root: Node3D
var _lights_on := false


func _ready() -> void:
	# Posed by hand every frame; this body is only for things in the world (lines, raycasts), not the crew.
	sync_to_physics = false
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
		_build_deck_space(shape, cs.transform)
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
	# a dim red night light in the wheelhouse, so the helm isn't a black hole
	var cabin := OmniLight3D.new()
	cabin.name = "CabinLight"
	cabin.position = Vector3(0.0, DECK + 1.9, -1.3)
	cabin.light_color = Color(1.0, 0.45, 0.32)
	cabin.light_energy = 1.4
	cabin.omni_range = 4.0
	cabin.visible = false
	add_child(cabin)
	floods.append(cabin)
	src.free()


func _build_deck_space(shape: Shape3D, at: Transform3D) -> void:
	deck_space = SubViewport.new()
	deck_space.name = "DeckSpace"
	deck_space.own_world_3d = true
	deck_space.size = Vector2i(2, 2)
	deck_space.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(deck_space)
	deck_root = Node3D.new()
	deck_root.name = "Deck"
	deck_space.add_child(deck_root)
	var still := StaticBody3D.new()
	still.name = "Hull"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = at
	still.add_child(cs)
	deck_root.add_child(still)


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


## Every frame (the ocean's clock moves per frame, so the pose does too; the crew ride it smoothly).
func _process(delta: float) -> void:
	if _radar:
		_radar.rotate_y(delta * 2.6)
	if ocean == null:
		return
	global_transform = pose()
	# her hull pushes the sea down where she sits: no crest shows up through her deck
	ocean.set_hull(global_transform)


## Where the hull sits on the swell right now: a plane fitted to the water under her (five stations along, three
## across), the waterline at its middle, its slopes her pitch and roll. A pure function of the wave clock, so every
## peer agrees.
func pose() -> Transform3D:
	var sum := 0.0
	var sx := 0.0
	var sz := 0.0
	var xx := 0.0
	var zz := 0.0
	for i in 5:
		var z := (i - 2) * LENGTH * 0.2
		for j in 3:
			var x := (j - 1) * BEAM * 0.4
			var h := ocean.height_at(Vector3(x, 0.0, z))
			sum += h
			sx += x * h
			sz += z * h
			xx += x * x
			zz += z * z
	var y := sum / 15.0 - SINK
	var pitch := atan(-sz / zz) * PITCH_FOLLOW
	var roll := atan(sx / xx) * ROLL_FOLLOW
	return Transform3D(Basis.from_euler(Vector3(pitch, 0.0, roll)), Vector3(0.0, y, 0.0))


## A rod holder's tube in world space: origin at the rim, +Z along the tube out of it.
func holder_transform(i: int) -> Transform3D:
	var t := holders[i]
	# The Blender empty's +Z became Godot +Y on export: turn that into +Z.
	var along := t.basis.y.normalized()
	var b := Basis.looking_at(-along, Vector3.UP if absf(along.y) < 0.99 else Vector3.FORWARD)
	return global_transform * Transform3D(b, t.origin)


## Spawn point `slot` on deck, boat-local (where the crew's deck space puts you).
func spawn_local(slot: int) -> Transform3D:
	if spawns.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(0, DECK + 0.05, 2.0))
	return spawns[slot % spawns.size()].translated(Vector3(0, 0.05, 0))


func spawn_point(slot: int) -> Transform3D:
	if spawns.is_empty():
		return global_transform * Transform3D(Basis.IDENTITY, Vector3(0, DECK + 0.1, 2.0))
	return global_transform * spawns[slot % spawns.size()].translated(Vector3(0, 0.1, 0))


## The eyes of someone standing on deck (for the camera until the crew exists).
func eye(local: Vector3) -> Vector3:
	return global_transform * local
