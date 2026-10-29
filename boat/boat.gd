extends AnimatableBody3D
## The boat: one of the kinds in boat/kinds.gd (the skiff, the 46 ft sportfisher), built from her Blender model. She goes
## where the helm takes her (boat/helm.gd: where she is, her heading, her speed) and rides the swell there, heaving,
## pitching and rolling with the sea under her; under way her bow lifts and her stern squats, and backing down hard
## her stern digs in. Her pose comes from the ocean's wave clock and the helm's word, so every peer computes the same
## deck under the same feet. (The pattern is Gull Harbor's TunaBoat, on Fathom's ocean.)
##
## The crew don't walk on this moving body. They walk in the DECK SPACE: a separate, still physics world holding
## the same collider, never moving (the space game's "the ship never moves" rule). A crew member's position there
## IS their boat-local position, and what you see is that, carried by the boat's pose (crew/player.gd). So the
## deck is solid underfoot in any sea, nobody slides, and the network only needs boat-local positions.
##
## The skipper picks her at the dock (use_kind): every peer rebuilds her in place (the model, the collider, the deck
## the crew walk on, the lights), and `rebuilt` tells the rods, the landing, the fish hold and the crew to follow.

const Ocean := preload("res://sea/ocean.gd")
const Helm := preload("res://boat/helm.gd")
const Wake := preload("res://boat/wake.gd")
const Kinds := preload("res://boat/kinds.gd")
const Tower := preload("res://boat/tower.gd")

## Under way: her bow up (rad) flat out ahead, and how far her stern digs in (rad, m down) backing down flat out.
const SQUAT := 0.07
const DIG := 0.035
const DIG_SINK := 0.1
const WHEEL_AXIS := Vector3(0.0, 0.48191875, -0.87621591)

## She's been rebuilt as another kind (use_kind): everything placed on her must be placed again.
signal rebuilt

var ocean: Ocean
var sea: Node            # sea/sea.gd
## Which boat she is (boat/kinds.gd), and its numbers.
var kind := Kinds.DEFAULT
var spec: Dictionary = Kinds.spec(Kinds.DEFAULT)
var length := 14.0
var beam := 4.8
var deck := 0.55          # her sole above the model's origin (its waterline)
var sink := 0.12          # loaded, she sits a little below her painted waterline
var pitch_follow := 1.0   # how much of the sea's slope she follows (a long, heavy hull bridges the short chop)
var roll_follow := 0.85
var spawns: Array[Transform3D] = []      # boat-local
var holders: Array[Transform3D] = []     # boat-local; see holder_transform()
var helm_spot := Transform3D.IDENTITY   # where the captain stands (boat-local)
## The wheel and the captain at it (boat/helm.gd): her heading.
var helm: Helm
## Her tuna tower's ladder, if she has one (boat/tower.gd).
var tower: Tower
var floods: Array[Light3D] = []
var chair: Node3D
var wheel: Node3D
var _radar: Node3D
## The still world the crew walk in (see above): add crew bodies under deck_root.
var deck_space: SubViewport
var deck_root: Node3D
var _lights_on := false
var _wheel_turn := 0.0
var _wheel_base := Basis.IDENTITY
## What _build made (freed by the next one): the model, her collider here and in the deck space, the lights.
var _built: Array[Node] = []


func _ready() -> void:
	# Posed by hand every frame; this body is only for things in the world (lines, raycasts), not the crew.
	sync_to_physics = false
	collision_layer = 1
	collision_mask = 0
	deck_space = SubViewport.new()
	deck_space.name = "DeckSpace"
	deck_space.own_world_3d = true
	deck_space.size = Vector2i(2, 2)
	deck_space.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(deck_space)
	deck_root = Node3D.new()
	deck_root.name = "Deck"
	deck_space.add_child(deck_root)
	# (a late joiner hears which boat she is before the helm tells it who has her wheel: rebuilding her lets go of it)
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_use_kind.rpc_id(id, kind))
	helm = Helm.new()
	helm.name = "Helm"
	helm.boat = self
	add_child(helm)
	# her going: the engines, the wake, the wash, the spray (boat/wake.gd)
	var wake := Wake.new()
	wake.name = "Wake"
	wake.boat = self
	add_child(wake)
	_build()


## The skipper picks her (the dock, ui/menu.gd): the host tells everyone, and every peer rebuilds her.
func use_kind(k: String) -> void:
	if not Kinds.KINDS.has(k) or not Net.is_host():
		return
	if Net.in_session():
		_use_kind.rpc(k)
	else:
		_use_kind(k)


@rpc("authority", "call_local", "reliable")
func _use_kind(k: String) -> void:
	if k == kind or not Kinds.KINDS.has(k):
		return
	kind = k
	if helm.captain != 0:
		helm._set_captain(0, helm.heading)      # (off the old wheel: there's a new one)
	_build()
	rebuilt.emit()


func _build() -> void:
	for n in _built:
		if is_instance_valid(n):
			n.queue_free()
	_built.clear()
	floods.clear()
	spawns.clear()
	holders.clear()
	spec = Kinds.spec(kind)
	length = float(spec["length"])
	beam = float(spec["beam"])
	deck = float(spec["deck"])
	sink = float(spec["sink"])
	pitch_follow = float(spec["pitch_follow"])
	roll_follow = float(spec["roll_follow"])
	var src := (load(str(spec["model"])) as PackedScene).instantiate() as Node3D
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_built.append(visual)
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
	if wheel:
		_wheel_base = wheel.basis
	_radar = visual.get_node_or_null("radar") as Node3D
	var col_mesh := src.find_child("collider", true, false) as MeshInstance3D
	if col_mesh:
		var shape := col_mesh.mesh.create_trimesh_shape()
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = _src_transform(col_mesh, src)
		add_child(cs)
		_built.append(cs)
		# the same hull in the still deck space the crew walk in
		var still := StaticBody3D.new()
		still.name = "Hull"
		var dcs := CollisionShape3D.new()
		dcs.shape = shape
		dcs.transform = cs.transform
		still.add_child(dcs)
		deck_root.add_child(still)
		_built.append(still)
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
		helm_spot = _src_transform(h, src)
	helm.position = wheel.position if wheel else helm_spot.origin + Vector3(0, 1.0, -0.6)
	helm.configure(spec)
	tower = null
	if spec.has("tower"):
		tower = Tower.new()
		tower.name = "Tower"
		tower.boat = self
		tower.setup(spec)
		add_child(tower)
		_built.append(tower)
	# The floodlights and the cockpit lights: each empty's Blender -Z (Godot -Y) is where its light points.
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
		l.visible = _lights_on
		add_child(l)
		_built.append(l)
		floods.append(l)
	# a dim red night light at the helm, so it isn't a black hole
	var cabin := OmniLight3D.new()
	cabin.name = "CabinLight"
	cabin.position = spec["cabin_light"]
	cabin.light_color = Color(1.0, 0.45, 0.32)
	cabin.light_energy = 1.4
	cabin.omni_range = 4.0
	cabin.visible = _lights_on
	add_child(cabin)
	_built.append(cabin)
	floods.append(cabin)
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


## Every frame (the ocean's clock moves per frame, so the pose does too; the crew ride it smoothly).
func _process(delta: float) -> void:
	if _radar and ocean:
		# (in step with the screen's sweep, tuna/radar.gd: clockwise from above, on the sea clock)
		_radar.rotation.y = -fposmod(float(ocean.wave_time) * 2.6, TAU)
	if wheel:
		# the wheel turns with the captain's hands (art/boat.py: its shaft leans up toward the dash)
		# (to port is anticlockwise from where the captain stands)
		_wheel_turn = lerpf(_wheel_turn, -helm.steer * 2.4, minf(delta * 8.0, 1.0))
		wheel.basis = Basis(WHEEL_AXIS, _wheel_turn) * _wheel_base
	if ocean == null:
		return
	global_transform = pose()
	# her hull pushes the sea down where she sits: no crest shows up through her deck
	ocean.set_hull(global_transform, length, beam)


## Where the hull sits on the swell right now: a plane fitted to the water under her (five stations along, three
## across, turned to her heading, where she is), the waterline at its middle, its slopes her pitch and roll, and the
## lift of her bow under way. A pure function of the wave clock and the helm's word, so every peer agrees.
func pose() -> Transform3D:
	var turn := Basis(Vector3.UP, helm.heading if helm else 0.0)
	var mid := Vector3(helm.at.x, 0.0, helm.at.y) if helm else Vector3.ZERO
	var sum := 0.0
	var sx := 0.0
	var sz := 0.0
	var xx := 0.0
	var zz := 0.0
	for i in 5:
		var z := (i - 2) * length * 0.2
		for j in 3:
			var x := (j - 1) * beam * 0.4
			var h := ocean.height_at(mid + turn * Vector3(x, 0.0, z))
			sum += h
			sx += x * h
			sz += z * h
			xx += x * x
			zz += z * z
	var y := sum / 15.0 - sink
	var pitch := atan(-sz / zz) * pitch_follow
	var roll := atan(sx / xx) * roll_follow
	# under way her bow comes up; backing down hard her stern digs into the water
	var v: float = helm.speed if helm else 0.0
	var ahead := clampf(v / helm.ahead, 0.0, 1.0) if helm else 0.0
	var astern := clampf(-v / helm.astern, 0.0, 1.0) if helm else 0.0
	pitch += SQUAT * smoothstep(0.0, 0.6, ahead) + DIG * astern
	y -= DIG_SINK * astern
	return Transform3D(turn * Basis.from_euler(Vector3(pitch, 0.0, roll)), Vector3(mid.x, y, mid.z))


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
		return Transform3D(Basis.IDENTITY, Vector3(0, deck + 0.05, 2.0))
	return spawns[slot % spawns.size()].translated(Vector3(0, 0.05, 0))


func spawn_point(slot: int) -> Transform3D:
	if spawns.is_empty():
		return global_transform * Transform3D(Basis.IDENTITY, Vector3(0, deck + 0.1, 2.0))
	return global_transform * spawns[slot % spawns.size()].translated(Vector3(0, 0.1, 0))


## The eyes of someone standing on deck (for the camera until the crew exists).
func eye(local: Vector3) -> Vector3:
	return global_transform * local
