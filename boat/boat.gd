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
const Chair := preload("res://boat/chair.gd")
const Wake := preload("res://boat/wake.gd")
const Kinds := preload("res://boat/kinds.gd")
const Ladder := preload("res://boat/ladder.gd")
const Tower := preload("res://boat/tower.gd")
const GreenWater := preload("res://boat/green_water.gd")
const Cooler := preload("res://boat/cooler.gd")
const LiveWell := preload("res://boat/live_well.gd")
const Lines := preload("res://boat/lines.gd")
const PixFont := preload("res://ui/pixfont.gd")
const Buoyancy := preload("res://boat/buoyancy.gd")

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
var spawns: Array[Transform3D] = []      # boat-local
var holders: Array[Transform3D] = []     # boat-local; see holder_transform()
var helm_spot := Transform3D.IDENTITY   # where the captain stands (boat-local)
## The wheel and the captain at it (boat/helm.gd): her heading.
var helm: Helm
## A knock on top of what the sea does to her (rad: pitch, roll): VS, the other boat bumping her or her wake
## (vs/contact.gd), rocking and dying away.
var rock := Vector2.ZERO
var floods: Array[Light3D] = []
var chair: Node3D
## The fighting chair you can sit in (boat/chair.gd), if she has one, and all her seats (the chair among them).
var seat: Chair
var seats: Array[Chair] = []
var wheel: Node3D
## The boarding ladder over her transom (boat/ladder.gd): up it out of the sea.
var ladder: Ladder
## Her tuna tower's ladder, if she has one (boat/tower.gd): up it to spot flocks from higher.
var tower: Tower
## Big seas coming aboard over her rail (boat/green_water.gd).
var green: GreenWater
## Her live well, its lid that opens and the mackerel in it (boat/live_well.gd).
var live_well: LiveWell
var _radar: Node3D
## The still world the crew walk in (see above): add crew bodies under deck_root.
var deck_space: SubViewport
var deck_root: Node3D
var _lights_on := false
## Her lamps' glass (the model's "lamp" faces): lit only while the floods are on, dark glass by day.
var _lamps: Array[BaseMaterial3D] = []
var _night := false
var _cabin: OmniLight3D
var _wheel_turn := 0.0
var _wheel_base := Basis.IDENTITY
## What _build made (freed by the next one): the model, her collider here and in the deck space, the lights.
var _built: Array[Node] = []
## Her pose the frame before, and that frame's length (s): how any spot of her is going (point_velocity).
var _was := Transform3D.IDENTITY
var _was_dt := 0.0
## How much the water's orbits carry her (pose): 1, all of it; 0 she sits where the helm has her (a test's before).
var carry := 1.0
## Where the water's carried her off where the helm has her (world m, y 0), her slew from it (rad), and how fast
## they're going (x, z m/s; y the slew, rad/s). Every peer works it out from the sea clock: it's never sent.
var carried := Vector3.ZERO
var carried_yaw := 0.0
var carried_rate := Vector3.ZERO
## How she floats (boat/buoyancy.gd): her heave, pitch and roll, a body on the water.
var floating := Buoyancy.new()


func _ready() -> void:
	# Posed by hand every frame; this body is only for things in the world (lines, raycasts), not the crew.
	sync_to_physics = false
	add_to_group("boats")
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
	green = GreenWater.new()
	green.name = "GreenWater"
	green.boat = self
	add_child(green)
	# her dock lines (boat/lines.gd), and the fuel gauge on her dash
	lines = Lines.new()
	lines.name = "Lines"
	lines.boat = self
	add_child(lines)
	_gauge()


## Her fuel gauge, by the wheel: FUEL and a bar of blocks, lit from behind (boat/fish_hold.gd's fuel).
func _gauge() -> void:
	if is_instance_valid(_fuel_label):
		_fuel_label.queue_free()
	_fuel_label = Label3D.new()
	_fuel_label.name = "FuelGauge"
	_fuel_label.font = PixFont.font()
	_fuel_label.font_size = 24
	_fuel_label.pixel_size = 0.0022
	_fuel_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_fuel_label.modulate = Color(1.0, 0.78, 0.34)
	_fuel_label.outline_size = 0
	_fuel_label.no_depth_test = false
	var at := (wheel.position if wheel else helm_spot.origin + Vector3(0, 1.0, -0.5)) + Vector3(0.32, 0.16, 0.02)
	_fuel_label.position = at
	add_child(_fuel_label)


var _fuel_label: Label3D
var lines: Node3D


func _show_fuel() -> void:
	if not is_instance_valid(_fuel_label) or sea == null:
		return
	var hold: Node = sea.get("fish_hold")
	if hold == null:
		return
	var f := float(hold.get("fuel"))
	var n := clampi(ceili(f * 8.0), 0, 8)
	var text := "FUEL " + "#".repeat(n) + ".".repeat(8 - n)
	if _fuel_label.text != text:
		_fuel_label.text = text
		_fuel_label.modulate = Color(1.0, 0.45, 0.3) if f < 0.15 else Color(1.0, 0.78, 0.34)


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
	if lines:
		lines.call("rebuilt")
	_gauge()
	rebuilt.emit()


func _build() -> void:
	for n in _built:
		if is_instance_valid(n):
			# (out of the tree now, not at the frame's end: her new seats take their names, "Seat0" ..., not
			# "@Area3D@701", so their RPCs find them on every peer, however many times she's rebuilt this frame)
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
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
	floating.configure(kind, spec)
	var src := (load(str(spec["model"])) as PackedScene).instantiate() as Node3D
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_built.append(visual)
	for n: String in ["boat", "chair", "wheel", "radar", "well_lid"]:
		var mi := src.find_child(n, true, false) as Node3D
		if mi:
			var t := _src_transform(mi, src)
			mi.owner = null
			mi.get_parent().remove_child(mi)
			mi.transform = t
			visual.add_child(mi)
	_upholster(visual)
	chair = visual.get_node_or_null("chair") as Node3D
	seats.clear()
	if chair:
		seat = Chair.new()
		seat.name = "FightingChair"
		add_child(seat)
		seat.setup(self, chair)
		_built.append(seat)
		seats.append(seat)
	else:
		seat = null
	# her other seats: the benches, the skipper's seat, the cooler seat, the leaning post (boat/kinds.gd's "seats")
	for i in (spec.get("seats", []) as Array).size():
		var s := Chair.new()
		s.name = "Seat%d" % i
		add_child(s)
		s.setup_seat(self, spec["seats"][i])
		_built.append(s)
		seats.append(s)
	wheel = visual.get_node_or_null("wheel") as Node3D
	if wheel:
		_wheel_base = wheel.basis
	_radar = visual.get_node_or_null("radar") as Node3D
	if _radar == null and spec.has("radar_bar"):
		_radar = _radar_bar(visual, spec["radar_bar"])
	var col_mesh := src.find_child("collider", true, false) as MeshInstance3D
	if col_mesh:
		var shape := col_mesh.mesh.create_trimesh_shape()
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = _src_transform(col_mesh, src)
		add_child(cs)
		_built.append(cs)
		# the same hull in the still deck space the crew walk in, but her rail as she's built (_deck_shape)
		var still := StaticBody3D.new()
		still.name = "Hull"
		var dcs := CollisionShape3D.new()
		dcs.shape = _deck_shape(col_mesh.mesh.get_faces(), cs.transform, visual.get_node_or_null("boat"))
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
	ladder = null
	if spec.has("ladder"):
		ladder = Ladder.new()
		ladder.name = "Ladder"
		ladder.boat = self
		ladder.spot = spec["ladder"]
		add_child(ladder)
		_built.append(ladder)
	live_well = null
	var well_lid := visual.get_node_or_null("well_lid") as Node3D
	if well_lid:
		live_well = LiveWell.new()
		live_well.name = "LiveWell"
		live_well.boat = self
		add_child(live_well)
		live_well.setup(well_lid)
		_built.append(live_well)
	if spec.has("cooler"):
		var c := Cooler.new()
		c.name = "Cooler"
		c.boat = self
		c.setup(spec["cooler"])
		add_child(c)
		_built.append(c)
	tower = null
	if spec.has("tower"):
		tower = Tower.new()
		tower.name = "Tower"
		tower.boat = self
		tower.setup(spec)
		add_child(tower)
		_built.append(tower)
	# a dim red night light at the helm, so it isn't a black hole
	var cabin := OmniLight3D.new()
	cabin.name = "CabinLight"
	cabin.position = spec["cabin_light"]
	cabin.light_color = Color(1.0, 0.45, 0.32)
	cabin.light_energy = 0.5
	cabin.omni_range = 1.8          # (round the skipper's feet and the dash: not up into the canvas over them)
	cabin.visible = _night
	add_child(cabin)
	_built.append(cabin)
	_cabin = cabin
	src.free()


## The "rubber" in her model (the leaning post's pad and backrest, the cooler cushion, the wheel's rim) is near black:
## right under your eyes at the wheel it read as a hole in the picture, a flat black slab. Lifted to a dark slate
## vinyl, its pixels and its shading still there.
const VINYL := Color(2.4, 2.6, 3.0)


func _upholster(visual: Node3D) -> void:
	_lamps.clear()
	for mi: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(i) as BaseMaterial3D
			if sm != null and sm.resource_name == "rubber":
				var v := sm.duplicate() as BaseMaterial3D
				v.albedo_color = sm.albedo_color * VINYL
				m.set_surface_override_material(i, v)
			elif sm != null and sm.resource_name.begins_with("lamp"):
				# (a floodlight switched off by day is grey glass, not a glowing panel)
				var v := sm.duplicate() as BaseMaterial3D
				v.set_meta("glow", v.emission_energy_multiplier)
				m.set_surface_override_material(i, v)
				_lamps.append(v)
	_show_lamps()


func _show_lamps() -> void:
	for v in _lamps:
		v.emission_energy_multiplier = float(v.get_meta("glow", 1.0)) if _lights_on else 0.0
		v.albedo_color = Color(1, 1, 1) if _lights_on else Color(0.55, 0.56, 0.55)


## The radar's bar on a little pedestal (a boat whose model hasn't one: the skiff's T-top).
func _radar_bar(visual: Node3D, at: Vector3) -> Node3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.87, 0.86)
	mat.roughness = 0.5
	var ped := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.08
	cyl.height = 0.2
	cyl.radial_segments = 10
	ped.mesh = cyl
	ped.material_override = mat
	ped.position = at + Vector3(0.0, 0.1, 0.0)
	visual.add_child(ped)
	var bar := MeshInstance3D.new()
	bar.name = "radar"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.1, 0.14)
	bar.mesh = bm
	bar.material_override = mat
	bar.position = at + Vector3(0.0, 0.25, 0.0)
	visual.add_child(bar)
	return bar


## A node's transform relative to the imported scene root (before it's in the tree).
## The deck space's hull (boat-local): her collider (`faces`, placed by `xf`) with its bulwark (the wall raised
## kinds.gd's `bulwark` m over her rail, so nobody walks off her) brought back down to her rail's cap, and her cap
## and topsides from her model (`model`, its "cap" and "topsides") added: her gunwale's just there to climb up on
## and stand on, or go over.
func _deck_shape(faces: PackedVector3Array, xf: Transform3D, model: MeshInstance3D) -> ConcavePolygonShape3D:
	var out := PackedVector3Array()
	var tops := {}           # (her liner's top edge, the cap's inner edge: on a 2 cm grid)
	var mesh := model.mesh if model else null
	var mx := model.transform if model else Transform3D.IDENTITY
	if mesh:
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var band := mat.resource_name if mat else ""
			if band != "cap" and band != "topsides" and band != "liner":
				continue
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if band == "liner":
				for p in v:
					tops[Vector3i((mx * p / 0.02).round())] = mx * p
				continue
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				for p in v:
					out.append(mx * p)
			else:
				for i in idx:
					out.append(mx * v[i])
	var bw := float(spec.get("bulwark", 0.0))
	for p in faces:
		var q := xf * p
		var under := q - Vector3(0.0, bw, 0.0)
		var key := Vector3i((under / 0.02).round())
		var near := 0.025
		for k in 27:
			var at := key + Vector3i(k % 3 - 1, k / 3 % 3 - 1, k / 9 - 1)
			if tops.has(at) and (tops[at] as Vector3).distance_to(under) < near:
				near = (tops[at] as Vector3).distance_to(under)
				q = tops[at]
		out.append(q)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(out)
	return shape


static func _src_transform(n: Node3D, root: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


## The floods and deck lights on (dark, a storm, fog); the helm's red night light only in the dark.
func set_lights(on: bool, night := on) -> void:
	_lights_on = on
	_night = night
	for l in floods:
		l.visible = on
	_show_lamps()
	if is_instance_valid(_cabin):
		_cabin.visible = night


## Every frame (the ocean's clock moves per frame, so the pose does too; the crew ride it smoothly).
func _process(delta: float) -> void:
	_show_fuel()
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
	_was = global_transform
	_was_dt = delta
	global_transform = pose()
	# the sea meets her hull where she is (carried, pitched and rolled, this frame's pose): left as it is outside her,
	# heaped along her by her way, held under her deck inside her, so no crest shows up through it (the boat you're
	# on; in Rivals the other boat the same)
	var way: float = helm.speed if helm else 0.0
	if ocean.follow == self or ocean.follow == null:
		ocean.set_hull(global_transform, length, beam, deck, way, floating.sheer)
	else:
		ocean.set_other_hull(global_transform, length, beam, true, deck, way, floating.sheer)


## Where the hull sits on the swell right now: floating (boat/buoyancy.gd: a body with her mass on the water under
## her, heaving, pitching and rolling to it, stepped on the shared wave clock from the helm's word, so every peer
## agrees), turned to her heading, where she is, and the lift of her bow under way.
## And the water carries her (ocean.gd's carry): its orbits take her to and fro, surging and swaying, slewing a little,
## round and back with each wave, on top of where the helm has her. So she goes with the water round her instead of
## the sea sliding past a hull pinned to the spot.
func pose() -> Transform3D:
	var heading: float = helm.heading if helm else 0.0
	var mid := Vector3(helm.at.x, 0.0, helm.at.y) if helm else Vector3.ZERO
	var c := ocean.carry(mid, heading, length, beam) if carry > 0.0 else PackedFloat64Array([0, 0, 0, 0, 0, 0])
	var give := _fendered(mid, heading, c[0] * carry)
	carried = Vector3(c[0] * give, 0.0, c[1]) * carry
	carried_yaw = c[2] * carry
	carried_rate = Vector3(c[3], c[5], c[4]) * carry
	mid += carried
	var turn := Basis(Vector3.UP, heading + carried_yaw)
	floating.ocean = ocean
	var f := floating.at(float(ocean.wave_time), Vector2(mid.x, mid.z), heading + carried_yaw)
	var y := f.x
	var pitch := f.y
	var roll := f.z
	# under way her bow comes up; backing down hard her stern digs into the water
	var v: float = helm.speed if helm else 0.0
	var ahead := clampf(v / helm.ahead, 0.0, 1.0) if helm else 0.0
	var astern := clampf(-v / helm.astern, 0.0, 1.0) if helm else 0.0
	pitch += SQUAT * smoothstep(0.0, 0.6, ahead) + DIG * astern + rock.x
	roll += rock.y
	y -= DIG_SINK * astern
	return Transform3D(turn * Basis.from_euler(Vector3(pitch, 0.0, roll)), Vector3(mid.x, y, mid.z))


## Alongside a float (sea/quay.gd's floats, their edges running along z), her fenders on its edge: the water carrying
## her in toward it squeezes them only a little (FENDER_GIVE m past where she lies on them, softly), where the lines
## and the fenders (boat/lines.gd) can't keep her helm's word from it; off it, or carried away from it, all of it.
## What share of the carry `cx` (world x, m) she takes, for her at `mid` heading `heading`.
const FENDER_GIVE := 0.1


func _fendered(mid: Vector3, heading: float, cx: float) -> float:
	if absf(cx) < 0.0005 or sea == null:
		return 1.0
	var real: Node = sea.get("sea") if sea.get("sea") != null else sea
	var h: Node = real.get("harbour") if real else null
	var q: Node = h.get("quay") if h else null
	if q == null or not q.has_method("float_near"):
		return 1.0
	var turn := Basis(Vector3.UP, heading)
	var lim := cx
	for z: float in [-0.35, 0.0, 0.38]:
		for side: float in [-1.0, 1.0]:
			var w := mid + turn * Vector3(side * beam * 0.5, 0.0, z * length)
			var fl: Array = q.call("float_near", Vector2(w.x, w.z), 3.0)
			if fl.is_empty():
				continue
			var way := float(fl[2])
			var toward := -way * lim
			if toward <= 0.0:
				continue
			# (how far her side may come in from where it is before it's FENDER_GIVE past lying on its fenders)
			var room := maxf((w.x - float(fl[1])) * way - Lines.OFF + FENDER_GIVE, 0.0)
			lim = -way * (room * tanh(toward / room) if room > 0.0005 else 0.0)
	return lim / cx


## How the spot `local` of her (boat-local) is going through the world (m/s): her way, her turn, her heave, her
## pitch and roll there, all of it (what you take with you leaping off her rail, and what a deck you come down on is
## doing under you). Over her last frame; before she's had one, just the helm's word.
func point_velocity(local: Vector3) -> Vector3:
	if _was_dt <= 0.0:
		var v := Helm.ahead_of(helm.heading) * helm.speed + helm.drift if helm else Vector2.ZERO
		return Vector3(v.x + carried_rate.x, 0.0, v.y + carried_rate.z)
	return (global_transform * local - _was * local) / _was_dt


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
