extends Node3D
## Gull Harbor underfoot: the quay, the fish pier, the floats along both its sides, the gangways down to them, the
## town float off the quay and the brow down to it, the boarding steps on their edges. Walked on the way a boat's deck is (crew/player.gd): a still physics world of its
## own (the DECK SPACE, as boat/boat.gd has) holding its collider, and this node's pose carries it, which for the
## quay is just where it stands. It's in group "boats" so the crew's movement takes it as one more frame: step off her
## gunwale and you're in the air (AIR), come down over the float and you're on it (_drop_in); walk off the float's edge
## toward her and you're in the air over her, down on her deck. Group "quay" tells it from a boat.
##
## Its own frame is the world's turned not at all, set at the middle of what's walkable (so `length` and `beam`, which
## the crew's movement reads off a boat for "over her at all", are the quay's extent along z and x).
##
## The harbour (sea/harbour.gd) draws it all; this is only what's solid. Places on it (sea/places.gd: the counters,
## the hoist, the pump) add their own walls with add_box().

const FLOAT_Y := 0.6          # m: the floats' decks over the water
const FLOAT_W := 2.4          # m across
const FLOAT_GAP := 0.4        # m between the pier's edge and a float's inner edge
const STEP_Y := 0.95          # m: the boarding steps' tops (from them you can jump onto her gunwale)
const STEP_EVERY := 5.0
const CLEAT_EVERY := 3.0
## The town float: off the quay in the middle of the harbour, the harbour mouth dead ahead of it, a boat down each of
## its sides (sea/harbour.gd's berths 2 and 3). Its middle line's x, how far it runs out from the quay face, how long
## the brow down to it from the quay is. It's two floats' width across (TOWN_W): each boat's hoist, scale and buyer
## stand down its middle (sea/places.gd), a float's width of deck left clear along each edge to walk her length on.
const TOWN_X := 0.0
const TOWN_W := 4.8
const TOWN_OUT := 26.0
const TOWN_BROW := 6.0
const X0 := -150.0            # the quay's ends (world x)
const X1 := 170.0

const PierLadder := preload("res://sea/pier_ladder.gd")

var harbour: Node3D           # sea/harbour.gd
var sea: Node                 # sea/sea.gd (the crew's movement asks a frame for it)
## What the crew's movement reads off a frame: how long and wide (m), her deck (here the water: y 0 in its frame).
var length := 100.0
var beam := 100.0
var deck := 0.0
var spec := {}
var helm: Node = null
var ladder: Node3D = null
var tower: Node3D = null
var deck_space: SubViewport
var deck_root: Node3D
var _body: StaticBody3D
var _tris := PackedVector3Array()
## The floats: [Rect2 (world x, z), outer edge's x, which way out (-1 west, +1 east)].
var floats: Array = []
## Every cleat along the floats' outer edges (world): where a boat's lines go.
var cleats: Array[Vector3] = []
## The boarding steps (world: the middle of each one's top), and which way each one's float edge faces (-1 west).
var steps: Array[Vector3] = []
var step_ways: Array[float] = []
## The gangways: [foot (float), top (pier), world].
var gangways: Array = []
## The brows, straight down off the quay's edge onto a float's middle: [foot (float), top (quay), world].
var brows: Array = []


func _ready() -> void:
	add_to_group("boats")
	add_to_group("quay")
	deck_space = SubViewport.new()
	deck_space.name = "DeckSpace"
	deck_space.own_world_3d = true
	deck_space.size = Vector2i(2, 2)
	deck_space.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(deck_space)
	deck_root = Node3D.new()
	deck_root.name = "Deck"
	deck_space.add_child(deck_root)
	_body = StaticBody3D.new()
	_body.name = "Quay"
	_body.collision_layer = 1
	_body.collision_mask = 0
	deck_root.add_child(_body)
	_build()


## Never going anywhere: what the crew's movement asks a boat for a spot's way through the world.
func point_velocity(_local: Vector3) -> Vector3:
	return Vector3.ZERO


func shore(x: float) -> float:
	return float(harbour.call("_shore", x))


## The fish pier's quay face (world z) and its far end.
func face() -> float:
	return shore(float(harbour.get("PIER_X"))) - 2.0


func pier_end() -> float:
	return face() - float(harbour.get("PIER_OUT"))


## The quay face where the town float lies off it (world z).
func town_face() -> float:
	return shore(TOWN_X) - 2.0


func _build() -> void:
	var px := float(harbour.get("PIER_X"))
	var pw := float(harbour.get("PIER_W"))
	var dy := float(harbour.get("DECK_Y"))
	var qy := float(harbour.get("QUAY_Y"))
	var f := face()
	var far := pier_end()
	# where it all is, and so where this frame stands
	var zmin := far - 2.0
	var zmax := -INF
	var x := X0
	while x <= X1:
		zmax = maxf(zmax, shore(x) + 40.0)
		zmin = minf(zmin, shore(x) - 6.0)
		x += 8.0
	position = Vector3((X0 + X1) * 0.5, 0.0, (zmin + zmax) * 0.5)
	length = zmax - zmin
	beam = X1 - X0
	# the quay and the street behind it, the kerb (a ramp, not a step), the sidewalk, the house fronts' line behind it
	x = X0
	while x < X1:
		var x1 := minf(x + 8.0, X1)
		var z0 := shore(x) - 2.0
		var z1 := shore(x1) - 2.0
		_quad(Vector3(x, qy, z0), Vector3(x1, qy, z1), Vector3(x1, qy, z1 + 37.0), Vector3(x, qy, z0 + 37.0))
		_quad(Vector3(x, qy, z0 + 37.0), Vector3(x1, qy, z1 + 37.0), Vector3(x1, qy + 0.16, z1 + 37.4),
				Vector3(x, qy + 0.16, z0 + 37.4))
		_quad(Vector3(x, qy + 0.16, z0 + 37.4), Vector3(x1, qy + 0.16, z1 + 37.4), Vector3(x1, qy + 0.16, z1 + 41.0),
				Vector3(x, qy + 0.16, z0 + 41.0))
		_quad(Vector3(x, qy + 0.16, z0 + 41.0), Vector3(x1, qy + 0.16, z1 + 41.0), Vector3(x1, qy + 4.0, z1 + 41.0),
				Vector3(x, qy + 4.0, z0 + 41.0))
		# the quay's face, down into the water: what you'd bounce off swimming or falling against it (not where the
		# fish pier and the finger pier leave it)
		_quad(Vector3(x, qy, z0), Vector3(x, -4.0, z0), Vector3(x1, -4.0, z1), Vector3(x1, qy, z1))
		x = x1
	for ex: float in [X0, X1]:
		var z := shore(ex) - 2.0
		_quad(Vector3(ex, -4.0, z), Vector3(ex, qy + 4.0, z), Vector3(ex, qy + 4.0, z + 41.0), Vector3(ex, -4.0, z + 41.0))
	# the finger pier's not for walking (its boats aren't yours): a rail across its root
	var fx := float(harbour.get("FINGER_X"))
	var fw := float(harbour.get("FINGER_W"))
	add_box(Vector3(fx, qy + 0.6, shore(fx) - 2.2), Vector3(fw + 0.4, 1.2, 0.2))
	# the fish pier: its deck, a ramp up the last metres onto the quay (it's a hand's width lower), its sides and end
	_box_top(Vector3(px - pw * 0.5, dy, far), Vector3(px + pw * 0.5, dy, f - 3.0))
	_quad(Vector3(px - pw * 0.5, dy, f - 3.0), Vector3(px + pw * 0.5, dy, f - 3.0), Vector3(px + pw * 0.5, qy, f),
			Vector3(px - pw * 0.5, qy, f))
	for s: float in [-1.0, 1.0]:
		var ex := px + s * pw * 0.5
		_quad(Vector3(ex, dy, far), Vector3(ex, -4.0, far), Vector3(ex, -4.0, f), Vector3(ex, dy, f))
	_quad(Vector3(px - pw * 0.5, dy, far), Vector3(px + pw * 0.5, dy, far), Vector3(px + pw * 0.5, -4.0, far),
			Vector3(px - pw * 0.5, -4.0, far))
	# the floats either side of it, a gangway down to each, boarding steps along their outer edges, cleats
	for s: float in [-1.0, 1.0]:
		var inner := px + s * (pw * 0.5 + FLOAT_GAP)
		var outer := inner + s * FLOAT_W
		var x_lo := minf(inner, outer)
		var x_hi := maxf(inner, outer)
		var z_lo := far + 2.0
		var z_hi := f - 6.0
		floats.append([Rect2(x_lo, z_lo, FLOAT_W, z_hi - z_lo), outer, s])
		_box_top(Vector3(x_lo, FLOAT_Y, z_lo), Vector3(x_hi, FLOAT_Y, z_hi))
		for ex: float in [x_lo, x_hi]:
			_quad(Vector3(ex, FLOAT_Y, z_lo), Vector3(ex, -0.6, z_lo), Vector3(ex, -0.6, z_hi), Vector3(ex, FLOAT_Y, z_hi))
		for ez: float in [z_lo, z_hi]:
			_quad(Vector3(x_lo, FLOAT_Y, ez), Vector3(x_hi, FLOAT_Y, ez), Vector3(x_hi, -0.6, ez), Vector3(x_lo, -0.6, ez))
		# the gangway: on the float's inner half, up toward the quay, a landing across to the pier's deck at its top
		var g_in := inner
		var g_out := inner + s * FLOAT_W * 0.5
		var gx0 := minf(g_in, g_out)
		var gx1 := maxf(g_in, g_out)
		var foot := f - 13.0
		var top := f - 7.0
		_quad(Vector3(gx0, FLOAT_Y + 0.02, foot), Vector3(gx1, FLOAT_Y + 0.02, foot), Vector3(gx1, dy, top),
				Vector3(gx0, dy, top))
		_box_top(Vector3(gx0 if s < 0.0 else px + pw * 0.5, dy, top),
				Vector3(px - pw * 0.5 if s < 0.0 else gx1, dy, top + 1.0))
		# (its handrail on the open side, and the ends of the landing)
		var rail_x := g_out
		_quad(Vector3(rail_x, FLOAT_Y, foot), Vector3(rail_x, FLOAT_Y + 1.0, foot), Vector3(rail_x, dy + 1.0, top + 1.0),
				Vector3(rail_x, dy, top + 1.0))
		gangways.append([Vector3((gx0 + gx1) * 0.5, FLOAT_Y, foot), Vector3((gx0 + gx1) * 0.5, dy, top + 0.5)])
		# boarding steps: up a ramp from the float to STEP_Y at its outer edge (from there a jump gets you aboard)
		var z := z_hi - 4.0
		while z > z_lo + 1.0:
			var sx_out := outer
			var sx_in := outer - s * 0.8
			_quad(Vector3(sx_in, FLOAT_Y, z - 0.5), Vector3(sx_in, FLOAT_Y, z + 0.5), Vector3(sx_out, STEP_Y, z + 0.5),
					Vector3(sx_out, STEP_Y, z - 0.5))
			_quad(Vector3(sx_out, FLOAT_Y, z - 0.5), Vector3(sx_out, STEP_Y, z - 0.5), Vector3(sx_out, STEP_Y, z + 0.5),
					Vector3(sx_out, FLOAT_Y, z + 0.5))
			for ez: float in [z - 0.5, z + 0.5]:
				_tri(Vector3(sx_in, FLOAT_Y, ez), Vector3(sx_out, FLOAT_Y, ez), Vector3(sx_out, STEP_Y, ez))
			steps.append(Vector3((sx_in + sx_out) * 0.5, (FLOAT_Y + STEP_Y) * 0.5, z))
			step_ways.append(s)
			z -= STEP_EVERY
		var cz := z_hi - 1.0
		while cz > z_lo + 0.5:
			cleats.append(Vector3(outer - s * 0.22, FLOAT_Y, cz))
			cz -= CLEAT_EVERY
	_town_float(qy)
	# the sheds on the quay, the fish buyer's, the clutter big enough to walk into
	for w: Array in [[-150.0, Vector3(20, 7, 13)], [-95.0, Vector3(22, 8, 14)], [-25.0, Vector3(38, 10, 20)],
			[130.0, Vector3(20, 7, 13)]]:
		var wx := float(w[0])
		var size: Vector3 = w[1]
		add_box(Vector3(wx, qy + size.y * 0.5, shore(wx) + 17.0), size)
	add_box(Vector3(px + 13.0, qy + 3.0, f + 9.0), Vector3(16.0, 6.0, 11.0))
	var base := Vector3(px, qy, f)
	add_box(base + Vector3(5.25, 1.0, 5.0), Vector3(3.8, 2.0, 1.0))         # the totes
	add_box(base + Vector3(-16.0, 0.8, 3.1), Vector3(5.2, 1.6, 0.9))        # the pots
	add_box(base + Vector3(21.0, 1.7, 3.0), Vector3(3.0, 3.4, 2.5))         # the ice machine
	add_box(base + Vector3(-3.35, 0.45, 8.35), Vector3(1.4, 0.9, 1.4))      # the drums
	add_box(base + Vector3(-6.0, 0.25, 6.0), Vector3(1.2, 0.5, 1.0))        # the pallets
	add_box(Vector3(-30.0, qy + 0.8, shore(-30.0) + 31.5), Vector3(5.2, 1.6, 1.9))   # the pickups
	add_box(Vector3(95.0, qy + 0.8, shore(95.0) + 33.0), Vector3(5.2, 1.6, 1.9))
	_commit()
	# the ladder down the pier's west side at its end (sea/harbour.gd draws it): out of the harbour onto the pier
	ladder = PierLadder.new()
	ladder.name = "PierLadder"
	ladder.set("boat", self)
	ladder.set("spot", Vector3(0.0, dy, 0.0))
	ladder.set("face", -PI * 0.5)
	ladder.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(px - pw * 0.5 - 0.12, 0.0, far + 1.0) - position)
	add_child(ladder)


## The town float: one float out from the quay, both its edges for lying alongside (so it's in `floats` twice, once an
## edge), the brow down its middle from the quay's edge with a handrail either side, boarding steps down both edges
## (staggered, so there's a way between them), cleats.
func _town_float(qy: float) -> void:
	var tf := town_face()
	var x_lo := TOWN_X - TOWN_W * 0.5
	var x_hi := TOWN_X + TOWN_W * 0.5
	var z_lo := tf - TOWN_OUT
	var z_hi := tf - FLOAT_GAP
	_box_top(Vector3(x_lo, FLOAT_Y, z_lo), Vector3(x_hi, FLOAT_Y, z_hi))
	for ex: float in [x_lo, x_hi]:
		_quad(Vector3(ex, FLOAT_Y, z_lo), Vector3(ex, -0.6, z_lo), Vector3(ex, -0.6, z_hi), Vector3(ex, FLOAT_Y, z_hi))
	for ez: float in [z_lo, z_hi]:
		_quad(Vector3(x_lo, FLOAT_Y, ez), Vector3(x_hi, FLOAT_Y, ez), Vector3(x_hi, -0.6, ez), Vector3(x_lo, -0.6, ez))
	# the brow: from the float's middle up onto the quay (its top lapped over the edge), closed in under its rails
	var foot := tf - TOWN_BROW
	var bx0 := TOWN_X - FLOAT_W * 0.25
	var bx1 := TOWN_X + FLOAT_W * 0.25
	_quad(Vector3(bx0, FLOAT_Y + 0.02, foot), Vector3(bx1, FLOAT_Y + 0.02, foot), Vector3(bx1, qy, tf),
			Vector3(bx0, qy, tf))
	_box_top(Vector3(bx0, qy, tf), Vector3(bx1, qy, tf + 0.4))
	for rx: float in [bx0, bx1]:
		_quad(Vector3(rx, FLOAT_Y, foot), Vector3(rx, FLOAT_Y + 1.0, foot), Vector3(rx, qy + 1.0, tf),
				Vector3(rx, FLOAT_Y, tf))
	brows.append([Vector3(TOWN_X, FLOAT_Y, foot), Vector3(TOWN_X, qy, tf)])
	for s: float in [-1.0, 1.0]:
		var outer := TOWN_X + s * TOWN_W * 0.5
		floats.append([Rect2(x_lo, z_lo, TOWN_W, z_hi - z_lo), outer, s])
		var z := foot - 4.0 - (STEP_EVERY * 0.5 if s > 0.0 else 0.0)
		while z > z_lo + 1.0:
			var sx_in := outer - s * 0.8
			_quad(Vector3(sx_in, FLOAT_Y, z - 0.5), Vector3(sx_in, FLOAT_Y, z + 0.5), Vector3(outer, STEP_Y, z + 0.5),
					Vector3(outer, STEP_Y, z - 0.5))
			_quad(Vector3(outer, FLOAT_Y, z - 0.5), Vector3(outer, STEP_Y, z - 0.5), Vector3(outer, STEP_Y, z + 0.5),
					Vector3(outer, FLOAT_Y, z + 0.5))
			for ez: float in [z - 0.5, z + 0.5]:
				_tri(Vector3(sx_in, FLOAT_Y, ez), Vector3(outer, FLOAT_Y, ez), Vector3(outer, STEP_Y, ez))
			steps.append(Vector3((sx_in + outer) * 0.5, (FLOAT_Y + STEP_Y) * 0.5, z))
			step_ways.append(s)
			z -= STEP_EVERY
		var cz := z_hi - 1.0
		while cz > z_lo + 0.5:
			cleats.append(Vector3(outer - s * 0.22, FLOAT_Y, cz))
			cz -= CLEAT_EVERY


## A solid box (world: its middle and size), turned `yaw`: a wall, a counter, a stack of something.
func add_box(at: Vector3, size: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), at - position)
	_body.add_child(cs)


## World to this frame (the quay's turned not at all: just where it stands).
func local(world: Vector3) -> Vector3:
	return world - position


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(a, b, c)
	_tri(a, c, d)


func _tri(a: Vector3, b: Vector3, c: Vector3) -> void:
	for v: Vector3 in [a, b, c]:
		_tris.append(v - position)


## A flat top from one corner to the other (world).
func _box_top(lo: Vector3, hi: Vector3) -> void:
	_quad(Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z))


func _commit() -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_tris)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	_body.add_child(cs)


## The float a point's alongside (world x, z), within `room` m of its outer edge on the water side: [float] or [].
func float_near(p: Vector2, room: float) -> Array:
	for fl: Array in floats:
		var r: Rect2 = fl[0]
		if p.y < r.position.y - 1.0 or p.y > r.end.y + 1.0:
			continue
		var out := float(fl[1])
		var s := float(fl[2])
		var off := (p.x - out) * s      # (how far out on the water side of its edge)
		if off > -0.5 and off < room:
			return fl
	return []


## The nearest cleat to `p` (world), and how far: [index, m]; [-1, INF] with none.
func nearest_cleat(p: Vector3) -> Array:
	var best := -1
	var d := INF
	for i in cleats.size():
		var e := Vector2(cleats[i].x - p.x, cleats[i].z - p.z).length()
		if e < d:
			d = e
			best = i
	return [best, d]
