extends Node3D
## Gull Harbor up close: what sea/landmarks.gd's town and breakwaters are from a mile off, the bit you're tied up in.
## The quay along the water, the fish pier out into the harbour (her berth on its west side), the fish buyer's shed
## and its scale, a finger pier with a couple of other boats on it, lamps along the pier, gulls on the pilings. All
## in world space, real size; only built for near (when the boat's more than FAR off it's hidden: the town in
## landmarks.gd is what's seen). The water in here is still: sea/ocean.gd's shelter.
##
## blocked() is where the boat can't go (the piers, the boats on them): landmarks.gd asks it.

const Landmarks := preload("res://sea/landmarks.gd")
const Kinds := preload("res://boat/kinds.gd")

## The fish pier: its middle line's x, how far it runs out from the quay face (m), its width, its deck's height.
const PIER_X := 60.0
const PIER_OUT := 80.0
const PIER_W := 4.0
const DECK_Y := 1.9
## The finger pier the other boats lie on.
const FINGER_X := -45.0
const FINGER_OUT := 46.0
const FINGER_W := 2.4
const QUAY_Y := 2.2
const FAR := 2600.0

var marks: Landmarks
var _moored: Array[Node3D] = []       # the other boats, bobbing
var _gulls: Array[Node3D] = []        # sitting on the pilings, a head turning now and then
var _lamps: Array[Node3D] = []
var _t := 0.0
var lights_on := false
var _lit := true          # (what the lamps were last set to: so they're only touched when it changes)


func _ready() -> void:
	var st := _st()
	_quay(st)
	_pier(st, PIER_X, PIER_OUT, PIER_W, DECK_Y, true)
	_pier(st, FINGER_X, FINGER_OUT, FINGER_W, DECK_Y - 0.6, false)
	_shed(st)
	_clutter(st)
	_warehouses(st)
	_front(st)
	_finish(st)
	_finish_glows()
	_sign()
	_front_signs()
	_boats()
	_birds()


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	visible = cam == null or cam.global_position.distance_to(Vector3(PIER_X, 0, _shore(PIER_X))) < FAR
	if not visible:
		return
	for i in _moored.size():
		var b := _moored[i]
		var base: Transform3D = b.get_meta("base")
		var k := _t * 0.7 + i * 1.7
		b.transform = base.rotated_local(Vector3.FORWARD, sin(k) * 0.02).rotated_local(Vector3.RIGHT, sin(k * 0.6) * 0.012) \
				.translated(Vector3(0.0, sin(k * 0.8) * 0.05, 0.0))
	for i in _gulls.size():
		var g := _gulls[i]
		# a head turn every few seconds, a shuffle
		var turn := floorf((_t + i * 3.1) / (2.5 + fmod(i * 0.7, 2.0)))
		g.rotation.y = lerp_angle(g.rotation.y, float(g.get_meta("yaw")) + sin(turn * 12.9898 + i) * 1.4,
				minf(1.0, delta * 6.0))
	if lights_on != _lit:
		_lit = lights_on
		for l in _lamps:
			l.visible = lights_on


## Where the boat can't be (world x, z): the piers, and the boats lying on the finger pier.
func blocked(p: Vector2, room := 0.0) -> bool:
	for r: Rect2 in _keep_out():
		if r.grow(room).has_point(p):
			return true
	return false


## Her berth: alongside the fish pier's west side, bow out to sea, `half_beam` m from her middle to her side, `length`
## m long. (world x, z of her middle)
func berth(half_beam: float, length: float) -> Vector2:
	var face := _shore(PIER_X) - 2.0
	return Vector2(PIER_X - PIER_W * 0.5 - 0.7 - half_beam, face - 12.0 - length * 0.5)


func _keep_out() -> Array:
	var a := _shore(PIER_X) - 2.0
	var b := _shore(FINGER_X) - 2.0
	return [Rect2(PIER_X - PIER_W * 0.5 - 0.3, a - PIER_OUT - 0.5, PIER_W + 0.6, PIER_OUT + 3.0),
			Rect2(FINGER_X - FINGER_W * 0.5 - 6.0, b - FINGER_OUT - 3.0, FINGER_W + 12.0, FINGER_OUT + 5.0)]


func _shore(x: float) -> float:
	return marks.shore_z(x) if marks != null else 2232.0


# ---- building --------------------------------------------------------------------------------------------------

## The quay: a concrete apron along the harbour's head, its face down into the water with the weed line on it, the
## edge picked out in yellow, bollards along it.
func _quay(st: SurfaceTool) -> void:
	var step := 8.0
	var x := -150.0
	while x < 170.0:
		var x1 := x + step
		var z0 := _shore(x) - 2.0
		var z1 := _shore(x1) - 2.0
		var back := 30.0
		# the top
		_kind = CONCRETE
		_quad(st, Vector3(x, QUAY_Y, z0), Vector3(x1, QUAY_Y, z1), Vector3(x1, QUAY_Y, z1 + back),
				Vector3(x, QUAY_Y, z0 + back), Color(0.5, 0.49, 0.46).lerp(Color(0.45, 0.44, 0.42), _hash(int(x))))
		# the face: dry concrete, the wet band, the weed under it
		_quad(st, Vector3(x, QUAY_Y, z0), Vector3(x, 0.6, z0), Vector3(x1, 0.6, z1), Vector3(x1, QUAY_Y, z1),
				Color(0.48, 0.47, 0.44))
		_kind = PLAIN
		_quad(st, Vector3(x, 0.6, z0), Vector3(x, -0.1, z0), Vector3(x1, -0.1, z1), Vector3(x1, 0.6, z1),
				Color(0.26, 0.27, 0.25))
		_quad(st, Vector3(x, -0.1, z0), Vector3(x, -4.0, z0), Vector3(x1, -4.0, z1), Vector3(x1, -0.1, z1),
				Color(0.12, 0.2, 0.12))
		# the yellow edge line
		_quad(st, Vector3(x, QUAY_Y + 0.01, z0 + 0.25), Vector3(x1, QUAY_Y + 0.01, z1 + 0.25),
				Vector3(x1, QUAY_Y + 0.01, z1 + 0.45), Vector3(x, QUAY_Y + 0.01, z0 + 0.45), Color(0.85, 0.7, 0.15))
		if int(x) % 24 == 2:
			_bollard(st, Vector3(x + 4.0, QUAY_Y, (z0 + z1) * 0.5 + 0.9))
		x = x1


## A timber pier out from the quay at `px`: the decking laid across on joists (one solid run, harbour.gdshader drawing
## each plank and the seams between: no gaps to see the water through), rim boards and a curb down both edges, a bent
## every 4 m (a pair of pilings, their cap beam under the joists, an X of bracing on every other one), cleats, tyres
## hung for fenders; `lamps`: lamp posts along it and a ladder down at the end.
func _pier(st: SurfaceTool, px: float, out: float, w: float, y: float, lamps: bool) -> void:
	var face := _shore(px) - 2.0
	var far := face - out
	var mid := (face + far) * 0.5
	var wood := Color(0.33, 0.29, 0.24)
	var dark := Color(0.24, 0.21, 0.18)
	_kind = PLANKS
	_box(st, Vector3(px, y - 0.06, mid), Vector3(w, 0.12, out), wood, 0.0)
	_kind = TIMBER
	for side: float in [-1.0, 1.0]:
		# the rim board, its face the pier's edge from the water; the curb on blocks along the top
		_box(st, Vector3(px + side * (w * 0.5 + 0.04), y - 0.2, mid), Vector3(0.08, 0.36, out + 0.08), wood.darkened(0.2), 0.0)
		_box(st, Vector3(px + side * (w * 0.5 - 0.12), y + 0.11, mid - 0.2), Vector3(0.2, 0.14, out - 0.4),
				wood.darkened(0.08), 0.0)
	_box(st, Vector3(px, y - 0.2, far - 0.04), Vector3(w + 0.16, 0.36, 0.08), wood.darkened(0.2), 0.0)
	for j in 4:
		_box(st, Vector3(px - w * 0.5 + 0.3 + j * (w - 0.6) / 3.0, y - 0.3, mid), Vector3(0.12, 0.36, out), dark, 0.0)
	var n := int(out / 4.0)
	for k in n + 1:
		var pz := face - k * 4.0 - 0.3
		# the cap beam the joists sit on, through both pilings and out past them
		_box(st, Vector3(px, y - 0.62, pz), Vector3(w + 0.9, 0.28, 0.3), dark, 0.0)
		for side: float in [-1.0, 1.0]:
			var at := Vector3(px + side * (w * 0.5 + 0.12), -6.0, pz)
			_cyl(st, at, y + 6.0 + 0.55, 0.21, 0.19, 8, Color(0.36, 0.3, 0.24).lerp(Color(0.42, 0.36, 0.28), _hash(k)))
			# the tarred top, the green slime band at the waterline with the barnacles over it
			_kind = PLAIN
			_cyl(st, at + Vector3(0, y + 6.5, 0), 0.08, 0.205, 0.17, 8, Color(0.14, 0.13, 0.12))
			_cyl(st, at + Vector3(0, 5.4, 0), 0.8, 0.225, 0.225, 8, Color(0.16, 0.24, 0.14))
			_cyl(st, at + Vector3(0, 6.2, 0), 0.25, 0.222, 0.222, 8, Color(0.4, 0.41, 0.36))
			if k % 2 == 1:
				_cleat(st, Vector3(px + side * (w * 0.5 - 0.42), y, pz + 2.0))
			if k % 3 == 1:
				_tyre(st, at + Vector3(side * 0.42, 6.6, 0.0), side)
			_kind = TIMBER
		if k % 2 == 0 and k < n:
			# the X of bracing across the bent, on its seaward face
			var bz := pz - 0.24
			var l := Vector3(px - w * 0.5 - 0.12, 0.0, bz)
			var r := Vector3(px + w * 0.5 + 0.12, 0.0, bz)
			_beam(st, l + Vector3(0, y - 0.7, 0), r + Vector3(0, -0.3, 0), Vector3.BACK, 0.07, 0.24, dark)
			_beam(st, r + Vector3(0, y - 0.7, 0), l + Vector3(0, -0.3, 0), Vector3.BACK, 0.07, 0.24, dark)
	_kind = PLAIN
	if lamps:
		var lz := face - 6.0
		while lz > far + 2.0:
			_lamp(st, Vector3(px + w * 0.5 - 0.45, y, lz))
			lz -= 20.0
		# a ladder down at the end: two rails, the rungs between
		var lx := px - w * 0.5 - 0.12
		for s: float in [-0.25, 0.25]:
			_box(st, Vector3(lx, y - 1.4, far + 1.0 + s), Vector3(0.06, 3.4, 0.06), Color(0.6, 0.62, 0.6), 0.0)
		for r in 8:
			_box(st, Vector3(lx, y - 0.25 - r * 0.35, far + 1.0), Vector3(0.05, 0.04, 0.5), Color(0.6, 0.62, 0.6), 0.0)


func _bollard(st: SurfaceTool, at: Vector3) -> void:
	_cyl(st, at, 0.55, 0.22, 0.18, 8, Color(0.15, 0.16, 0.17))
	_cyl(st, at + Vector3(0, 0.55, 0), 0.08, 0.3, 0.3, 8, Color(0.15, 0.16, 0.17))


## A horn cleat, galvanised: its foot bolted to the deck, the horns out fore and aft.
func _cleat(st: SurfaceTool, at: Vector3) -> void:
	var steel := Color(0.52, 0.54, 0.56)
	_box(st, at + Vector3(0, 0.04, 0), Vector3(0.12, 0.08, 0.2), steel.darkened(0.2), 0.0)
	_box(st, at + Vector3(0, 0.13, 0), Vector3(0.08, 0.1, 0.12), steel, 0.0)
	_box(st, at + Vector3(0, 0.19, 0), Vector3(0.09, 0.05, 0.46), steel, 0.0)


## A tyre hung on a piling for a fender: a ring of eight segments in the plane facing the water (`side`: which way that
## is), its rope up to the deck.
func _tyre(st: SurfaceTool, c: Vector3, side: float) -> void:
	var rub := Color(0.09, 0.09, 0.1)
	var r := 0.33
	for i in 8:
		var a0 := TAU * i / 8.0
		var a1 := TAU * (i + 1) / 8.0
		var p0 := c + Vector3(0, sin(a0) * r, cos(a0) * r)
		var p1 := c + Vector3(0, sin(a1) * r, cos(a1) * r)
		_beam(st, p0, p1, Vector3(side, 0, 0), 0.24, 0.17, rub)
	_box(st, c + Vector3(0, 0.75, 0), Vector3(0.04, 0.9, 0.04), Color(0.75, 0.68, 0.45), 0.0)


## A lamp post: a pole, an arm out over the water, a warm lamp (lit after dark).
func _lamp(st: SurfaceTool, at: Vector3) -> void:
	var col := Color(0.2, 0.24, 0.22)
	_cyl(st, at, 4.6, 0.08, 0.06, 6, col)
	_box(st, at + Vector3(-0.35, 4.55, 0), Vector3(0.8, 0.06, 0.06), col, 0.0)
	_box(st, at + Vector3(-0.7, 4.42, 0), Vector3(0.3, 0.18, 0.3), col, 0.0)
	var glass := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.08, 0.22)
	glass.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.45)
	mat.emission_energy_multiplier = 3.0
	glass.material_override = mat
	glass.position = at + Vector3(-0.7, 4.3, 0)
	add_child(glass)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.5)
	light.omni_range = 11.0
	light.light_energy = 1.4
	light.position = at + Vector3(-0.7, 4.1, 0)
	light.shadow_enabled = false
	add_child(light)
	_lamps.append(light)
	_lamps.append(glass)


## The quay's other sheds: the ice plant (the big one), net stores and a boat shed, each corrugated tin with its
## ribs, a roller door or two, a row of high windows, a pitched roof.
func _warehouses(st: SurfaceTool) -> void:
	for w: Array in [[-150.0, Vector3(20, 7, 13), Color(0.82, 0.78, 0.7), "NETS"],
			[-95.0, Vector3(22, 8, 14), Color(0.55, 0.62, 0.66), ""],
			[-25.0, Vector3(38, 10, 20), Color(0.62, 0.66, 0.68), "GULL HARBOR ICE"],
			[130.0, Vector3(20, 7, 13), Color(0.7, 0.5, 0.38), "BOATYARD"]]:
		var x := float(w[0])
		var size: Vector3 = w[1]
		var tin: Color = w[2]
		var c := Vector3(x, QUAY_Y, _shore(x) + 17.0)
		var front := c.z - size.z * 0.5
		_box(st, c + Vector3(0, size.y * 0.5, 0), size, tin, 0.0)
		for k in int(size.x / 0.5):
			_box(st, Vector3(c.x - size.x * 0.5 + 0.25 + k * 0.5, c.y + size.y * 0.5, front - 0.02),
					Vector3(0.08, size.y, 0.05), tin.darkened(0.14), 0.0)
		_roof(st, c + Vector3(0, size.y, 0), size.x + 1.0, size.z + 1.0, 2.2, Color(0.36, 0.4, 0.43))
		# roller doors (one half up, showing the dark), a row of high windows along the front
		for k: int in [-1, 1] if size.x > 30.0 else [0]:
			var dx: float = c.x + k * size.x * 0.25
			_box(st, Vector3(dx, c.y + 2.0, front - 0.05), Vector3(5.0, 4.0, 0.06), Color(0.07, 0.08, 0.09), 0.0)
			_box(st, Vector3(dx, c.y + (3.4 if k != 1 else 2.2), front - 0.08),
					Vector3(5.2, 1.4 if k != 1 else 3.8, 0.06), tin.darkened(0.25), 0.0)
		for k in int(size.x / 3.0):
			var wx := c.x - size.x * 0.5 + 1.5 + k * 3.0
			_box(st, Vector3(wx, c.y + size.y - 1.4, front - 0.05), Vector3(1.6, 0.8, 0.05), Color(0.12, 0.14, 0.17), 0.0)
		if not str(w[3]).is_empty():
			_shops.append([Vector3(c.x, c.y + size.y - 2.8, front - 0.1), str(w[3]), 0.022])


## The fish buyer's: a corrugated shed on the quay at the pier's root, its roller door open on the pier, a gantry
## out over the edge with the hanging scale under it.
func _shed(st: SurfaceTool) -> void:
	var face := _shore(PIER_X) - 2.0
	var c := Vector3(PIER_X + 13.0, QUAY_Y, face + 9.0)
	var tin := Color(0.62, 0.66, 0.68)
	_box(st, c + Vector3(0, 3.0, 0), Vector3(16.0, 6.0, 11.0), tin, 0.0)
	# the corrugations: a rib every half metre down the front
	for k in 31:
		_box(st, c + Vector3(-7.5 + k * 0.5, 3.0, -5.52), Vector3(0.08, 6.0, 0.06), tin.darkened(0.12), 0.0)
	# the roof, pitched, overhanging
	_roof(st, c + Vector3(0, 6.0, 0), 17.0, 12.0, 1.6, Color(0.36, 0.4, 0.43))
	# the roller door, half up: the dark inside, the door's slats over it
	_box(st, c + Vector3(-4.0, 1.6, -5.56), Vector3(5.0, 3.2, 0.04), Color(0.06, 0.07, 0.08), 0.0)
	_box(st, c + Vector3(-4.0, 3.9, -5.6), Vector3(5.2, 1.4, 0.06), Color(0.7, 0.3, 0.2), 0.0)
	# a window with its light
	_box(st, c + Vector3(3.5, 3.0, -5.56), Vector3(2.4, 1.2, 0.04), Color(0.95, 0.85, 0.6), 0.0)
	# the gantry: two legs on the quay, a beam out over the edge, the scale's chain and hook
	var g := Vector3(PIER_X + 5.0, QUAY_Y, face + 1.2)
	var steel := Color(0.25, 0.35, 0.5)
	_box(st, g + Vector3(0, 2.6, 2.5), Vector3(0.25, 5.2, 0.25), steel, 0.0)
	_box(st, g + Vector3(0, 2.6, -0.2), Vector3(0.25, 5.2, 0.25), steel, 0.0)
	_box(st, g + Vector3(0, 5.25, 0.2), Vector3(0.3, 0.3, 4.4), steel, 0.0)
	_box(st, g + Vector3(0, 4.6, -1.8), Vector3(0.05, 1.0, 0.05), Color(0.6, 0.6, 0.6), 0.0)
	_box(st, g + Vector3(0, 3.95, -1.8), Vector3(0.45, 0.45, 0.18), Color(0.85, 0.85, 0.82), 0.0)
	_box(st, g + Vector3(0, 3.55, -1.8), Vector3(0.05, 0.4, 0.05), Color(0.6, 0.6, 0.6), 0.0)


## The sign over the buyer's door.
func _sign() -> void:
	var face := _shore(PIER_X) - 2.0
	var at := Vector3(PIER_X + 13.0, QUAY_Y + 5.2, face + 3.42)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(9.0, 1.1, 0.1)
	board.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.2, 0.32)
	board.material_override = mat
	board.position = at
	add_child(board)
	var text := Label3D.new()
	text.text = "GULL HARBOR FISH CO."
	text.font_size = 96
	text.pixel_size = 0.006
	text.modulate = Color(0.95, 0.92, 0.82)
	text.outline_size = 0
	text.position = at + Vector3(0, 0, -0.07)
	text.rotation.y = PI
	add_child(text)
	var buy := Label3D.new()
	buy.text = "BLUEFIN BOUGHT HERE  ·  ICE"
	buy.font_size = 48
	buy.pixel_size = 0.006
	buy.modulate = Color(0.85, 0.75, 0.4)
	buy.position = at + Vector3(0, -0.85, -0.02)
	buy.rotation.y = PI
	add_child(buy)


## What lies about on a working quay: fish totes stacked, pallets, lobster pots, an ice machine, a coil of rope, drums.
func _clutter(st: SurfaceTool) -> void:
	var face := _shore(PIER_X) - 2.0
	var base := Vector3(PIER_X, QUAY_Y, face)
	# totes, blue and grey, stacked by the shed
	for k in 9:
		var at := base + Vector3(4.0 + (k % 3) * 1.25, 0.35 + (k / 3) * 0.62, 5.0 + (k % 2) * 0.1)
		_box(st, at, Vector3(1.15, 0.6, 0.8), Color(0.2, 0.42, 0.62) if k % 4 != 3 else Color(0.6, 0.62, 0.6), 0.0)
	# pallets
	for k in 3:
		_box(st, base + Vector3(-6.0, 0.08 + k * 0.16, 6.0), Vector3(1.2, 0.14, 1.0), Color(0.55, 0.45, 0.32), 0.0)
	# lobster pots, a stack on the quay west of the pier
	for k in 14:
		var at := base + Vector3(-14.0 - (k % 5) * 1.0, 0.3 + (k / 5) * 0.55, 3.0 + (k % 2) * 0.2)
		_box(st, at, Vector3(0.9, 0.5, 0.6), Color(0.15, 0.32, 0.22).lerp(Color(0.6, 0.45, 0.2), float(k % 3 == 0)),
				(_hash(k) - 0.5) * 0.3)
	# the ice machine, a white box with a chute
	_box(st, base + Vector3(21.0, 1.7, 3.0), Vector3(3.0, 3.4, 2.5), Color(0.9, 0.9, 0.88), 0.0)
	_box(st, base + Vector3(21.0, 1.2, 1.5), Vector3(0.8, 0.3, 1.0), Color(0.6, 0.62, 0.64), 0.4)
	# drums
	for k in 4:
		_cyl(st, base + Vector3(-3.0 - (k % 2) * 0.7, 0.0, 8.0 + (k / 2) * 0.7), 0.9, 0.3, 0.3, 8,
				Color(0.7, 0.18, 0.12) if k != 2 else Color(0.2, 0.35, 0.6))
	# a coil of line by the pier's root
	_cyl(st, base + Vector3(-1.4, 0.0, 1.8), 0.25, 0.5, 0.45, 9, Color(0.75, 0.68, 0.45))


## The harbour front: a street along the back of the quay (lamps, benches, a couple of pickups), a sidewalk, and the
## houses facing the water in three rows up the slope behind it, a New England fishing town's: painted clapboard or
## grey cedar shingle, gable end or long side to the street, each with its trim (corner boards, cornice, rakes, a white
## fascia under its eaves), windows in their casings with sills (shutters on some), a panelled door up its granite
## steps under a hood or a porch, a brick chimney. The shops are on the street, each a false front with its shop
## windows, its sign and most an awning: the harbor master's, the bait and tackle, the diner, the chandlery, the general
## store. The front row's built for looking at from the pier; the rows behind are the same houses with less on them.
## Some windows lit after dark.
const WALLS := [Color(0.94, 0.93, 0.89), Color(0.86, 0.8, 0.64), Color(0.6, 0.71, 0.79), Color(0.9, 0.78, 0.5),
		Color(0.68, 0.32, 0.26), Color(0.97, 0.97, 0.95), Color(0.52, 0.6, 0.52), Color(0.38, 0.47, 0.58)]
const CEDAR := [Color(0.56, 0.51, 0.45), Color(0.63, 0.57, 0.48), Color(0.5, 0.48, 0.45)]
const ROOFS := [Color(0.2, 0.21, 0.24), Color(0.36, 0.19, 0.16), Color(0.15, 0.16, 0.19), Color(0.3, 0.28, 0.26),
		Color(0.24, 0.3, 0.27)]
const TRIM := Color(0.95, 0.94, 0.9)
const DOORS := [Color(0.15, 0.3, 0.5), Color(0.58, 0.14, 0.12), Color(0.18, 0.34, 0.22), Color(0.12, 0.12, 0.13),
		Color(0.85, 0.68, 0.28)]
const SHUTTERS := [Color(0.13, 0.22, 0.16), Color(0.11, 0.12, 0.14), Color(0.2, 0.3, 0.46), Color(0.46, 0.15, 0.12)]
## The shops: about where on the street (world x: the front-row house nearest it), the sign, the walls, the trim (and
## the sign board), the sign's lettering, the awning (alpha 0: none), how many storeys.
const SHOPS := [
	[50.0, "BAIT & TACKLE", Color(0.56, 0.51, 0.45), Color(0.95, 0.94, 0.9), Color(0.55, 0.12, 0.1),
			Color(0.16, 0.38, 0.26), 2],
	[28.0, "GULL DINER", Color(0.93, 0.9, 0.78), Color(0.72, 0.13, 0.11), Color(0.97, 0.95, 0.88),
			Color(0.72, 0.13, 0.11), 1],
	[4.0, "CHANDLERY", Color(0.36, 0.45, 0.56), Color(0.95, 0.94, 0.9), Color(0.12, 0.2, 0.34),
			Color(0.14, 0.24, 0.44), 2],
	[110.0, "HARBOR MASTER", Color(0.97, 0.97, 0.95), Color(0.12, 0.2, 0.34), Color(0.95, 0.94, 0.9),
			Color(0, 0, 0, 0), 2],
	[-62.0, "GENERAL STORE", Color(0.9, 0.78, 0.5), Color(0.32, 0.2, 0.14), Color(0.95, 0.9, 0.75),
			Color(0.6, 0.16, 0.12), 2],
]
const FLOOR := 0.6            # m: a house's ground floor over the ground, on its granite foundation
var _shops := []          # [where the sign goes, what it says, (pixel size), (lettering)]


func _front(st: SurfaceTool) -> void:
	# the street: tarmac behind the quay apron, a kerb, the sidewalk, lamps and benches
	var x := Landmarks.FRONT_X.x
	while x < Landmarks.FRONT_X.y:
		var x1 := x + 10.0
		var z0 := _shore(x) + 28.0
		var z1 := _shore(x1) + 28.0
		_kind = TARMAC
		_quad(st, Vector3(x, QUAY_Y + 0.02, z0), Vector3(x1, QUAY_Y + 0.02, z1), Vector3(x1, QUAY_Y + 0.02, z1 + 7.0),
				Vector3(x, QUAY_Y + 0.02, z0 + 7.0), Color(0.24, 0.25, 0.26))
		_kind = CONCRETE
		_box(st, Vector3((x + x1) * 0.5, QUAY_Y + 0.08, (z0 + z1) * 0.5 + 7.2), Vector3(10.0, 0.16, 0.4),
				Color(0.6, 0.6, 0.58), -atan2(z1 - z0, 10.0))
		var y := QUAY_Y + 0.16
		_quad(st, Vector3(x, y, z0 + 7.4), Vector3(x1, y, z1 + 7.4), Vector3(x1, y, z1 + 11.0), Vector3(x, y, z0 + 11.0),
				Color(0.62, 0.61, 0.58))
		_quad_out(st, Vector3(x, y, z0 + 11.0), Vector3(x1, y, z1 + 11.0), Vector3(x1, y - 1.5, z1 + 11.0),
				Vector3(x, y - 1.5, z0 + 11.0), Color(0.5, 0.49, 0.47), Vector3.BACK)
		_kind = PLAIN
		if posmod(int(x), 30) == 0:
			_lamp(st, Vector3(x + 0.5, QUAY_Y, (z0 + z1) * 0.5 - 0.6))
		if posmod(int(x), 40) == 10:
			_bench(st, Vector3(x + 3.0, QUAY_Y, (z0 + z1) * 0.5 - 1.2))
		x = x1
	_pickup(st, Vector3(-30.0, QUAY_Y, _shore(-30.0) + 31.5), Color(0.55, 0.12, 0.1))
	_pickup(st, Vector3(95.0, QUAY_Y, _shore(95.0) + 33.0), Color(0.82, 0.82, 0.8))
	# the houses: three rows up the slope, shoulder to shoulder, each its own width and colour. Laid out first, so the
	# shops can go to the front-row houses nearest their spots.
	var lots := []
	var n := 0
	for row in 3:
		var hx := Landmarks.FRONT_X.x + 4.0 + row * 5.0
		while hx < Landmarks.FRONT_X.y - 8.0:
			var w := 7.0 + 4.0 * _hash(n * 13 + 1)
			var set_back := 0.3 + 2.2 * _hash(n * 7) if row == 0 else 1.0 + 2.5 * _hash(n * 7)
			lots.append([n, row, hx + w * 0.5, w, 39.0 + row * 24.0 + set_back])
			hx += w + 0.6 + 2.5 * _hash(n * 17)
			n += 1
	var shop_at := {}
	for s: Array in SHOPS:
		var best := -1
		for lot: Array in lots:
			if lot[1] != 0 or shop_at.has(lot[0]):
				continue
			if best < 0 or absf(float(lot[2]) - float(s[0])) < absf(float(lots[best][2]) - float(s[0])):
				best = lot[0]
		shop_at[best] = s
	for lot: Array in lots:
		var cx: float = lot[2]
		var w: float = lot[3]
		var d: float = lot[4]
		var front: bool = lot[1] == 0
		var ground := marks.land_h(cx, d) if marks != null else QUAY_Y
		if front:
			ground = maxf(ground, QUAY_Y + 0.16)
			# the front yard between the sidewalk and the house, at the house's own level
			_box(st, Vector3(cx, ground - 0.6, _shore(cx) + (39.0 + d) * 0.5), Vector3(w + 0.6, 1.2, d - 38.9),
					Color(0.36, 0.46, 0.24), 0.0)
		var c := Vector3(cx, ground, _shore(cx) + d)
		if shop_at.has(lot[0]):
			_store(st, c, w, shop_at[lot[0]])
		else:
			_house(st, c, w, lot[0], front)
			if front and d > 40.0:
				_fence(st, Vector3(cx, QUAY_Y + 0.16, _shore(cx) + 39.1), w, c.x + _door_x(w, lot[0]) * -1.0)


## A house facing the sea (-z) at `c` (the middle of its front, at the ground), `w` m wide. `near`: the front row, with
## everything on it; the rows behind get the same house with less (plain sashes, no shutters, porches or hoods).
func _house(st: SurfaceTool, c: Vector3, w: float, n: int, near: bool) -> void:
	var l := 8.0 + 3.0 * _hash(n * 3)
	var gable_end := _gable_end(n)
	var cedar := _hash(n * 43) < 0.3
	var wall: Color = CEDAR[n % CEDAR.size()] if cedar else WALLS[(n * 5) % WALLS.size()]
	var roof: Color = ROOFS[(n * 3) % ROOFS.size()]
	var siding := SHINGLE if cedar else CLAPBOARD
	var two := _hash(n * 11) > 0.25
	var tall := FLOOR + (5.4 if two else 3.1)    # the eaves, over the ground
	var f := _facade(c, Vector3.FORWARD)
	_walls(st, c, w, l, tall, wall, siding)
	var rise := _gable_roof(st, c, w, l, tall, roof, wall, siding, gable_end, n)
	_kind = PLAIN
	# the trim: corner boards, and the cornice (a pediment's returns on a gable end, a frieze board under the eaves)
	for s: float in [-1.0, 1.0]:
		_fbox(st, f, Vector3(s * (w * 0.5 - 0.08), (FLOOR + tall) * 0.5, 0.03), Vector3(0.2, tall - FLOOR, 0.1), TRIM)
	_fbox(st, f, Vector3(0, tall - 0.12, 0.05), Vector3(w, 0.24, 0.1), TRIM)
	if gable_end:
		for s: float in [-1.0, 1.0]:
			_fbox(st, f, Vector3(s * (w * 0.5 - 0.25), tall + 0.03, 0.12), Vector3(0.9, 0.12, 0.3), TRIM)
	# the chimney: an end chimney up the gable wall outside, or through the roof behind the ridge
	var side := -1.0 if _hash(n * 31) < 0.5 else 1.0
	var brick := Color(0.6, 0.3, 0.24) if n % 3 else Color(0.55, 0.52, 0.5)
	var cz := c.z + l * (0.7 if gable_end else 0.5)
	var chx := c.x + side * (w * 0.22 if gable_end else w * 0.5 + 0.35)
	var top := c.y + tall + rise + 0.9
	var bottom := c.y + (tall - 0.5 if gable_end else -0.5)
	_kind = BRICK
	_box(st, Vector3(chx, (top + bottom) * 0.5, cz), Vector3(0.8 if gable_end else 1.0, top - bottom, 0.7), brick, 0.0)
	_kind = PLAIN
	_box(st, Vector3(chx, top + 0.06, cz), Vector3(1.0 if gable_end else 1.2, 0.12, 0.9), Color(0.32, 0.3, 0.29), 0.0)
	# the windows and the door, across the front
	var cols := _cols(w, n)
	var door := _door_col(w, n)
	var span := w / cols
	var shut: Color = SHUTTERS[n % SHUTTERS.size()] if near and not cedar and _hash(n * 53) < 0.55 and span > 2.2 \
			else Color(0, 0, 0, 0)
	for k in cols:
		var wx := -w * 0.5 + (k + 0.5) * span
		if k == door:
			_door(st, f, wx, DOORS[n % DOORS.size()], near)
		else:
			_window(st, f, wx, FLOOR + 1.45, near, n * 10 + k, shut)
		if two:
			_window(st, f, wx, FLOOR + 4.0, near, n * 10 + 5 + k, shut)
	if gable_end and rise > 2.0:
		_window(st, f, 0.0, tall + rise * 0.38, near, n * 10 + 9, Color(0, 0, 0, 0), Vector2(0.7, 0.95))
	var dx := _door_x(w, n)
	if near and gable_end and _hash(n * 59) < 0.6:
		_porch(st, f, w, dx, roof)
	else:
		_steps(st, f, dx, 0.0)
		if near:
			_hood(st, f, dx, roof)


## Whether house `n` has its gable end to the street (its door to one side), or its long side (the door in the middle).
func _gable_end(n: int) -> bool:
	return _hash(n * 41) < 0.5


## How many bays across house `n`'s front, `w` wide; which one the door's in, and where that is (the wall's own x).
func _cols(w: float, n: int) -> int:
	return (2 if w < 8.5 else 3) if _gable_end(n) else (3 if w < 10.2 else 5)


func _door_col(w: float, n: int) -> int:
	if not _gable_end(n):
		return _cols(w, n) / 2
	return 0 if _hash(n * 47) < 0.5 else _cols(w, n) - 1


func _door_x(w: float, n: int) -> float:
	return -w * 0.5 + (_door_col(w, n) + 0.5) * w / _cols(w, n)


## A house's walls: a box from under the ground up to its eaves, sided; its granite foundation round the bottom.
func _walls(st: SurfaceTool, c: Vector3, w: float, l: float, tall: float, wall: Color, siding: int,
		base := FLOOR) -> void:
	_kind = siding
	_box(st, c + Vector3(0.0, (tall - 3.0) * 0.5, l * 0.5), Vector3(w, tall + 3.0, l), wall, 0.0)
	_kind = CONCRETE
	_box(st, c + Vector3(0.0, (base - 1.2) * 0.5 - 0.05, l * 0.5), Vector3(w + 0.1, base + 1.1, l + 0.1),
			Color(0.52, 0.51, 0.49), 0.0)


## A gabled roof on a house `w` x `l` with its eaves `tall` up: two slopes, each a slab with its slates on top and white
## underneath (so the overhangs read from below, the fascia and rakes from the side), the ridge capped, the gable ends
## closed in the house's own siding. `gable_end`: its ridge runs back from the street (else along it). Returns its rise.
func _gable_roof(st: SurfaceTool, c: Vector3, w: float, l: float, tall: float, roof: Color, wall: Color, siding: int,
		gable_end: bool, n: int) -> float:
	var span := w if gable_end else l                 # across the slopes
	var run := l if gable_end else w                  # along the ridge
	var half := span * 0.5
	var rise := half * (0.75 + 0.45 * _hash(n * 29)) if gable_end else 2.2 + 1.4 * _hash(n * 29)
	var e := 0.4                                      # the eaves out past the walls
	var t := 0.16
	var across := Vector3.RIGHT if gable_end else Vector3.BACK
	var along := Vector3.BACK if gable_end else Vector3.RIGHT
	var mid := c + Vector3(0, tall, l * 0.5)          # (the middle of the house at its eaves)
	var ridge := mid + Vector3(0, rise, 0)
	_kind = PLAIN
	for s: float in [-1.0, 1.0]:
		var eave := mid + across * s * (half + e) + Vector3(0, -e * rise / half, 0)
		var nrm := (across * s * rise + Vector3.UP * half).normalized()
		var up := (ridge - eave).normalized()
		_beam(st, eave + nrm * t * 0.5, ridge + nrm * t * 0.5 + up * 0.08, nrm, t, run + 0.6, TRIM, roof, ROOFING)
	_box(st, ridge + Vector3(0, t * 1.2, 0), along * (run + 0.64) + across * 0.26 + Vector3(0, 0.12, 0),
			roof.darkened(0.3), 0.0)
	_kind = siding
	for s: float in [-1.0, 1.0]:
		var end := mid + along * s * run * 0.5
		_tri_out(st, end - across * half, end + across * half, end + Vector3(0, rise, 0), wall * 0.95, along * s)
	return rise


## A window on a wall (_facade) at x, `y` its middle: a double-hung sash (the top pane catching the sky, the bottom
## darker), its casing, its head and sill, shutters if `shut` has any alpha. `near`: the sash bars too. About one in
## four lit after dark (`n` says which).
func _window(st: SurfaceTool, f: Transform3D, x: float, y: float, near: bool, n: int, shut: Color,
		size := Vector2(0.95, 1.45)) -> void:
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var gw := size.x - 0.1
	if near:
		_fbox(st, f, Vector3(x, y + hh * 0.5 - 0.02, 0.012), Vector3(gw, hh, 0.024), Color(0.32, 0.4, 0.47))
		_fbox(st, f, Vector3(x, y - hh * 0.5 + 0.02, 0.012), Vector3(gw, hh, 0.024), Color(0.11, 0.14, 0.18))
		_fbox(st, f, Vector3(x, y, 0.035), Vector3(gw, 0.07, 0.05), TRIM)
		_fbox(st, f, Vector3(x, y, 0.03), Vector3(0.035, size.y - 0.1, 0.04), TRIM)
		for s: float in [-1.0, 1.0]:
			_fbox(st, f, Vector3(x, y + s * hh * 0.5, 0.03), Vector3(gw, 0.035, 0.04), TRIM)
	else:
		_fbox(st, f, Vector3(x, y, 0.012), Vector3(gw, size.y - 0.1, 0.024), Color(0.16, 0.2, 0.25))
		_fbox(st, f, Vector3(x, y, 0.035), Vector3(gw, 0.07, 0.05), TRIM)
	for s: float in [-1.0, 1.0]:
		_fbox(st, f, Vector3(x + s * (hw + 0.02), y, 0.04), Vector3(0.14, size.y + 0.1, 0.08), TRIM)
	_fbox(st, f, Vector3(x, y + hh + 0.1, 0.05), Vector3(size.x + 0.34, 0.2, 0.1), TRIM)
	_fbox(st, f, Vector3(x, y - hh - 0.05, 0.07), Vector3(size.x + 0.3, 0.07, 0.16), TRIM)
	if near:
		_fbox(st, f, Vector3(x, y + hh + 0.23, 0.08), Vector3(size.x + 0.46, 0.06, 0.16), TRIM)
	if shut.a > 0.0:
		_kind = LOUVRE
		for s: float in [-1.0, 1.0]:
			_fbox(st, f, Vector3(x + s * (hw + 0.33), y, 0.03), Vector3(0.42, size.y + 0.05, 0.05), shut)
		_kind = PLAIN
	if _hash(n * 37 + 5) < 0.28:
		_window_glow(f * Vector3(x, y, 0.026), Vector2(gw - 0.05, size.y - 0.15), f.basis)


## A front door at x on a wall (_facade), up at the ground floor: its casing (pilasters, a head with its cap), the
## door with its panels (`near`) and knob.
func _door(st: SurfaceTool, f: Transform3D, x: float, col: Color, near: bool) -> void:
	for s: float in [-1.0, 1.0]:
		_fbox(st, f, Vector3(x + s * 0.6, FLOOR + 1.15, 0.05), Vector3(0.18, 2.3, 0.1), TRIM)
	_fbox(st, f, Vector3(x, FLOOR + 2.4, 0.07), Vector3(1.42, 0.22, 0.14), TRIM)
	_fbox(st, f, Vector3(x, FLOOR + 2.55, 0.1), Vector3(1.58, 0.08, 0.2), TRIM)
	_fbox(st, f, Vector3(x, FLOOR + 1.07, 0.025), Vector3(1.02, 2.14, 0.05), col)
	if near:
		for s: float in [-1.0, 1.0]:
			_fbox(st, f, Vector3(x + s * 0.22, FLOOR + 0.6, 0.055), Vector3(0.32, 0.7, 0.02), col.darkened(0.22))
			_fbox(st, f, Vector3(x + s * 0.22, FLOOR + 1.55, 0.055), Vector3(0.32, 0.8, 0.02), col.darkened(0.22))
		_fbox(st, f, Vector3(x + 0.36, FLOOR + 1.0, 0.08), Vector3(0.07, 0.07, 0.07), Color(0.85, 0.7, 0.3))


## Granite steps up to the door at x, from `z0` m out from the wall (the porch's edge, or the wall itself).
func _steps(st: SurfaceTool, f: Transform3D, x: float, z0: float) -> void:
	_kind = CONCRETE
	var n := 3
	for k in n:
		var top := FLOOR * (n - k) / n
		_fbox(st, f, Vector3(x, (top - 0.6) * 0.5, z0 + 0.32 * k + 0.16), Vector3(1.5, top + 0.6, 0.32),
				Color(0.64, 0.63, 0.6).darkened(0.04 * k))
	_kind = PLAIN


## A little roof over the door on two brackets.
func _hood(st: SurfaceTool, f: Transform3D, x: float, roof: Color) -> void:
	_beam(st, f * Vector3(x, FLOOR + 2.95, 0.0), f * Vector3(x, FLOOR + 2.72, 0.85), f.basis * Vector3(0, 1, 0.27),
			0.1, 1.9, TRIM, roof, ROOFING)
	for s: float in [-1.0, 1.0]:
		_fbox(st, f, Vector3(x + s * 0.8, FLOOR + 2.55, 0.25), Vector3(0.09, 0.4, 0.45), TRIM)


## A porch across the front: its deck on a lattice skirt, posts, a railing (left open at the steps, at x), a shed roof.
func _porch(st: SurfaceTool, f: Transform3D, w: float, x: float, roof: Color) -> void:
	var deep := 2.0
	var pw := w - 0.3
	_kind = PLANKS
	_fbox(st, f, Vector3(0, FLOOR - 0.08, deep * 0.5), Vector3(pw, 0.16, deep), Color(0.5, 0.51, 0.49))
	_kind = LOUVRE
	_fbox(st, f, Vector3(0, (FLOOR - 0.16) * 0.5 - 0.3, deep - 0.04), Vector3(pw - 0.1, FLOOR + 0.44, 0.04), TRIM * 0.8)
	_kind = PLAIN
	var posts := maxi(3, int(pw / 2.6) + 1)
	for k in posts:
		var px := -pw * 0.5 + 0.1 + k * (pw - 0.2) / (posts - 1)
		_fbox(st, f, Vector3(px, FLOOR + 1.3, deep - 0.12), Vector3(0.15, 2.6, 0.15), TRIM)
		if k == posts - 1:
			continue
		var nx := -pw * 0.5 + 0.1 + (k + 1) * (pw - 0.2) / (posts - 1)
		if x > px and x < nx:
			continue             # (the way up)
		_fbox(st, f, Vector3((px + nx) * 0.5, FLOOR + 0.9, deep - 0.12), Vector3(nx - px, 0.08, 0.1), TRIM)
		_fbox(st, f, Vector3((px + nx) * 0.5, FLOOR + 0.12, deep - 0.12), Vector3(nx - px, 0.06, 0.08), TRIM)
		var b := px + 0.2
		while b < nx - 0.1:
			_fbox(st, f, Vector3(b, FLOOR + 0.5, deep - 0.12), Vector3(0.045, 0.76, 0.045), TRIM)
			b += 0.2
	_fbox(st, f, Vector3(0, FLOOR + 2.68, deep - 0.12), Vector3(pw, 0.2, 0.16), TRIM)
	_beam(st, f * Vector3(0, FLOOR + 3.1, 0.0), f * Vector3(0, FLOOR + 2.8, deep + 0.25), f.basis * Vector3(0, 1, 0.15),
			0.14, pw + 0.3, TRIM, roof, ROOFING)
	_steps(st, f, x, deep)


## A white picket fence along the sidewalk at `at` (the middle of the house's frontage), `w` wide, its gate (open) at
## world x `gate`.
func _fence(st: SurfaceTool, at: Vector3, w: float, gate: float) -> void:
	var x := at.x - w * 0.5 - 0.2
	while x < at.x + w * 0.5 + 0.2:
		if absf(x - gate) > 0.8:
			_box(st, Vector3(x, at.y + 0.42, at.z), Vector3(0.07, 0.84, 0.03), TRIM, 0.0)
		x += 0.17
	for y: float in [0.25, 0.65]:
		for s: float in [-1.0, 1.0]:
			var a := gate + s * 0.8
			var b := at.x + s * (w * 0.5 + 0.2)
			if (b - a) * s > 0.0:
				_box(st, Vector3((a + b) * 0.5, at.y + y, at.z + 0.03), Vector3(absf(b - a), 0.07, 0.03), TRIM, 0.0)


## A shop on the street at `c`, `w` wide (`shop`: a row of SHOPS): a false front, its parapet and cornice on brackets
## over a flat roof, the shop front below (pilasters, shop windows over panelled bulkheads, the door set between them
## with its transom), the sign board over it, a striped awning, the windows of the flat upstairs.
func _store(st: SurfaceTool, c: Vector3, w: float, shop: Array) -> void:
	var name: String = shop[1]
	var wall: Color = shop[2]
	var trim: Color = shop[3]
	var awning: Color = shop[5]
	var two: bool = shop[6] == 2
	var l := 12.0
	var tall := 4.2 + (3.0 if two else 0.0)
	var f := _facade(c, Vector3.FORWARD)
	var siding := SHINGLE if name.begins_with("BAIT") else CLAPBOARD
	_walls(st, c, w, l, tall, wall, siding, 0.0)
	# the flat roof, tarred; the false front up past it, its cornice on brackets
	_kind = PLAIN
	_box(st, c + Vector3(0, tall + 0.05, l * 0.5 + 0.2), Vector3(w - 0.1, 0.12, l - 0.5), Color(0.22, 0.22, 0.24), 0.0)
	_kind = siding
	_fbox(st, f, Vector3(0, tall + 0.6, -0.15), Vector3(w, 1.2, 0.3), wall)
	_kind = PLAIN
	_fbox(st, f, Vector3(0, tall + 0.3, 0.06), Vector3(w, 0.4, 0.12), trim)
	_fbox(st, f, Vector3(0, tall + 1.27, 0.12), Vector3(w + 0.36, 0.16, 0.6), trim)
	for k in 5:
		_fbox(st, f, Vector3(-w * 0.5 + 0.2 + k * (w - 0.4) / 4.0, tall + 1.02, 0.18), Vector3(0.16, 0.36, 0.36), trim)
	for s: float in [-1.0, 1.0]:
		_fbox(st, f, Vector3(s * (w * 0.5 - 0.08), (tall + 0.6) * 0.5, 0.03), Vector3(0.2, tall + 0.6, 0.1), trim)
	# the shop front: pilasters, the sign board over it (the shop floor's at the sidewalk)
	for px: float in [-(w * 0.5 - 0.2), w * 0.5 - 0.2, -0.85, 0.85]:
		_fbox(st, f, Vector3(px, 1.6, 0.09), Vector3(0.3 if absf(px) > 1.0 else 0.2, 3.2, 0.18), trim)
	_fbox(st, f, Vector3(0, 3.5, 0.12), Vector3(w - 0.1, 0.72, 0.24), trim)
	_fbox(st, f, Vector3(0, 3.12, 0.2), Vector3(w, 0.08, 0.36), trim.darkened(0.15))
	_fbox(st, f, Vector3(0, 3.9, 0.2), Vector3(w, 0.08, 0.36), trim.darkened(0.15))
	_shops.append([f * Vector3(0, 3.5, 0.25), name, 0.008, shop[4]])
	var glass := Color(0.22, 0.29, 0.35)
	for s: float in [-1.0, 1.0]:
		var x0 := s * 1.0
		var x1 := s * (w * 0.5 - 0.35)
		var mx := (x0 + x1) * 0.5
		var ww := absf(x1 - x0)
		# the bulkhead and its two panels; the glass over it, a bar up the middle, the transom bar, the frame
		_fbox(st, f, Vector3(mx, 0.4, 0.06), Vector3(ww, 0.8, 0.12), trim)
		for p: float in [-0.25, 0.25]:
			_fbox(st, f, Vector3(mx + p * ww, 0.4, 0.13), Vector3(ww * 0.4, 0.45, 0.02), trim.darkened(0.15))
		_fbox(st, f, Vector3(mx, 1.85, 0.02), Vector3(ww, 2.1, 0.04), glass)
		_fbox(st, f, Vector3(mx, 0.84, 0.1), Vector3(ww + 0.1, 0.07, 0.2), trim)
		_fbox(st, f, Vector3(mx, 2.45, 0.06), Vector3(ww, 0.07, 0.08), trim)
		_fbox(st, f, Vector3(mx, 1.65, 0.06), Vector3(0.06, 1.6, 0.08), trim)
		_fbox(st, f, Vector3(mx, 2.92, 0.06), Vector3(ww, 0.1, 0.08), trim)
		_window_glow(f * Vector3(mx, 1.85, 0.045), Vector2(ww - 0.1, 2.0), f.basis)
	# the door between them: glass in its top half, a transom over it
	_fbox(st, f, Vector3(0, 1.5, 0.01), Vector3(1.5, 3.0, 0.02), Color(0.1, 0.1, 0.11))
	_fbox(st, f, Vector3(0, 1.12, 0.03), Vector3(0.98, 2.2, 0.04), trim)
	_fbox(st, f, Vector3(0, 1.5, 0.055), Vector3(0.66, 1.0, 0.02), glass)
	_fbox(st, f, Vector3(0, 2.62, 0.03), Vector3(0.98, 0.42, 0.04), glass)
	_fbox(st, f, Vector3(0.34, 1.05, 0.07), Vector3(0.07, 0.07, 0.07), Color(0.85, 0.7, 0.3))
	# the awning: striped, sloping out over the windows, its valance hanging off the front
	if awning.a > 0.0:
		var stripes := int((w - 0.2) / 0.45)
		var sw := (w - 0.2) / stripes
		for k in stripes:
			var sx := -(w - 0.2) * 0.5 + (k + 0.5) * sw
			var col := awning if k % 2 == 0 else Color(0.96, 0.95, 0.9)
			_beam(st, f * Vector3(sx, 3.08, 0.25), f * Vector3(sx, 2.55, 1.6), f.basis * Vector3(0, 1, 0.38), 0.04, sw, col)
			_fbox(st, f, Vector3(sx, 2.4, 1.6), Vector3(sw, 0.3, 0.03), col)
	if two:
		var cols := maxi(2, int(w / 2.6))
		for k in cols:
			_window(st, f, -w * 0.5 + (k + 0.5) * w / cols, 5.6, true, int(c.x) + k, Color(0, 0, 0, 0))


## A lit pane on a wall facing `facing`'s z, showing after dark only. (Every one goes into the one mesh, _glows: one
## thing to switch on at dusk, not a hundred and fifty.)
func _window_glow(at: Vector3, size: Vector2, facing: Basis) -> void:
	if _glows == null:
		_glows = SurfaceTool.new()
		_glows.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := facing.x * size.x * 0.5
	var y := facing.y * size.y * 0.5
	for v: Vector3 in [at - x - y, at + x - y, at + x + y, at - x - y, at + x + y, at - x + y]:
		_glows.add_vertex(v)


## The window glows, made one mesh: unshaded, warm, both sides (they're flat on their walls).
func _finish_glows() -> void:
	if _glows == null:
		return
	var q := MeshInstance3D.new()
	q.mesh = _glows.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.5)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material_override = mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)
	_lamps.append(q)


var _glows: SurfaceTool


func _bench(st: SurfaceTool, at: Vector3) -> void:
	var wood := Color(0.45, 0.32, 0.2)
	_box(st, at + Vector3(0, 0.45, 0), Vector3(1.8, 0.06, 0.45), wood, 0.0)
	_box(st, at + Vector3(0, 0.8, 0.22), Vector3(1.8, 0.35, 0.05), wood, 0.0)
	for s: float in [-0.8, 0.8]:
		_box(st, at + Vector3(s, 0.22, 0), Vector3(0.06, 0.45, 0.45), Color(0.15, 0.15, 0.16), 0.0)


## A pickup parked along the street.
func _pickup(st: SurfaceTool, at: Vector3, paint: Color) -> void:
	_box(st, at + Vector3(0, 0.75, 0), Vector3(5.2, 0.7, 1.9), paint, 0.0)
	_box(st, at + Vector3(-0.6, 1.45, 0), Vector3(1.9, 0.8, 1.8), paint, 0.0)
	_box(st, at + Vector3(-0.6, 1.5, 0), Vector3(1.95, 0.55, 1.7), Color(0.12, 0.15, 0.18), 0.0)
	_box(st, at + Vector3(1.4, 1.15, 0), Vector3(2.2, 0.1, 1.9), paint.darkened(0.3), 0.0)
	for wx: float in [-1.7, 1.7]:
		for wz: float in [-0.9, 0.9]:
			_box(st, at + Vector3(wx, 0.38, wz), Vector3(0.75, 0.75, 0.3), Color(0.08, 0.08, 0.08), 0.0)


## The signs: the shops' on their boards over the shop fronts, the sheds' up on their walls.
func _front_signs() -> void:
	for s: Array in _shops:
		var t := Label3D.new()
		t.text = str(s[1])
		t.font_size = 64
		t.pixel_size = float(s[2]) if s.size() > 2 else 0.008
		t.modulate = Color(0.15, 0.17, 0.2)
		t.outline_modulate = Color(0.95, 0.93, 0.85)
		t.outline_size = 18
		if s.size() > 3:
			# (on its own board: the lettering only)
			t.modulate = s[3]
			t.outline_size = 0
		t.position = s[0]
		t.rotation.y = PI
		add_child(t)


## The other boats: one on each side of the finger pier, tied up, bobbing a little.
func _boats() -> void:
	var b := _shore(FINGER_X) - 2.0
	var lay := [["sportfisher", FINGER_X - FINGER_W * 0.5 - 3.0, b - 20.0],
			["skiff", FINGER_X + FINGER_W * 0.5 + 1.8, b - 14.0],
			["skiff", FINGER_X + FINGER_W * 0.5 + 1.8, b - 32.0]]
	for l: Array in lay:
		var spec: Dictionary = Kinds.spec(str(l[0]))
		var scene := load(str(spec["model"])) as PackedScene
		if scene == null:
			continue
		var boat := scene.instantiate() as Node3D
		# (only what boat.gd shows of her: her collider and markers stay hidden)
		for mi: Node in boat.find_children("*", "MeshInstance3D", true, false):
			var keep := false
			for n: String in ["boat", "chair", "wheel", "radar"]:
				var up: Node = mi
				while up != null and up != boat:
					keep = keep or up.name == n
					up = up.get_parent()
			(mi as MeshInstance3D).visible = keep
		var t := Transform3D(Basis.IDENTITY, Vector3(float(l[1]), -float(spec["sink"]), float(l[2])))
		boat.set_meta("base", t)
		boat.transform = t
		add_child(boat)
		_moored.append(boat)


## Gulls sitting on the pier's piling tops and along the quay's edge.
func _birds() -> void:
	var mesh := _gull_mesh()
	var face := _shore(PIER_X) - 2.0
	var spots := []
	for k in [3, 6, 7, 11, 14, 17, 19]:
		var side := -1.0 if k % 2 == 0 else 1.0
		spots.append(Vector3(PIER_X + side * (PIER_W * 0.5 + 0.1), DECK_Y + 0.6, face - k * 4.0 - 0.3))
	for k in 5:
		spots.append(Vector3(-60.0 + k * 23.0, QUAY_Y, _shore(-60.0 + k * 23.0) - 1.6))
	for k in spots.size():
		var g := MeshInstance3D.new()
		g.mesh = mesh
		g.position = spots[k]
		var yaw := _hash(k * 11) * TAU
		g.set_meta("yaw", yaw)
		g.rotation.y = yaw
		add_child(g)
		_gulls.append(g)


## A herring gull sitting: a white body, a grey back, a yellow bill, about life size.
static func _gull_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color(0.93, 0.93, 0.9)
	var grey := Color(0.55, 0.58, 0.62)
	_box_st(st, Vector3(0, 0.16, 0), Vector3(0.2, 0.2, 0.42), white)
	_box_st(st, Vector3(0, 0.27, 0.04), Vector3(0.22, 0.05, 0.4), grey)          # the folded wings
	_box_st(st, Vector3(0, 0.25, 0.27), Vector3(0.08, 0.04, 0.16), Color(0.12, 0.12, 0.13))  # the wingtips
	_box_st(st, Vector3(0, 0.34, -0.17), Vector3(0.12, 0.12, 0.13), white)        # the head
	_box_st(st, Vector3(0, 0.33, -0.27), Vector3(0.04, 0.035, 0.09), Color(0.95, 0.8, 0.2))  # the bill
	_box_st(st, Vector3(0.04, 0.04, 0), Vector3(0.025, 0.08, 0.025), Color(0.85, 0.6, 0.55))
	_box_st(st, Vector3(-0.04, 0.04, 0), Vector3(0.025, 0.08, 0.025), Color(0.85, 0.6, 0.55))
	st.generate_normals()
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	m.surface_set_material(0, mat)
	return m


# ---- mesh bits -------------------------------------------------------------------------------------------------
# (every face wound so it faces out: clockwise seen from outside, Godot's front. A face wound the other way is culled
# from outside, and you see the inside of the back wall through where the front should be)

## What a face is made of, for harbour.gdshader's grain (it rides in UV.x): set _kind before building a part.
enum { PLAIN, CLAPBOARD, SHINGLE, ROOFING, PLANKS, CONCRETE, TIMBER, BRICK, TARMAC, LOUVRE, ROCK }
const SHADER := preload("res://sea/harbour.gdshader")
var _kind := PLAIN


func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)    # (no smoothing: a flat facet per face, never a box's corners averaged)
	return st


func _finish(st: SurfaceTool) -> void:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mi.material_override = mat
	add_child(mi)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	for v: Vector3 in [a, b, c]:
		st.set_uv(Vector2(_kind, 0.0))
		st.add_vertex(v)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)


## A triangle (or a flat quad, its corners in order round it) facing `out`, whichever way its corners came.
func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, out: Vector3) -> void:
	if (a - c).cross(a - b).dot(out) < 0.0:
		_tri(st, a, c, b, col)
	else:
		_tri(st, a, b, c, col)


func _quad_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out: Vector3) -> void:
	_tri_out(st, a, b, c, col, out)
	_tri_out(st, a, c, d, col, out)


## A box round `c`, its half sides x, y, z (y its top; x, y, z a right-handed set). `top`: another colour for the top
## (and `top_kind` another grain), as a roof's slates over its white soffit and fascia.
func _obox(st: SurfaceTool, c: Vector3, x: Vector3, y: Vector3, z: Vector3, col: Color, top := Color(0, 0, 0, 0),
		top_kind := -1) -> void:
	var p := []
	for i in 8:
		p.append(c + (x if i & 1 else -x) + (y if i & 2 else -y) + (z if i & 4 else -z))
	var k := _kind
	if top_kind >= 0:
		_kind = top_kind
	_quad(st, p[2], p[3], p[7], p[6], col if top.a == 0.0 else top)    # top
	_kind = k
	_quad(st, p[0], p[1], p[3], p[2], col * 0.95)                       # -z
	_quad(st, p[4], p[6], p[7], p[5], col * 0.95)                       # +z
	_quad(st, p[0], p[2], p[6], p[4], col * 0.9)                        # -x
	_quad(st, p[1], p[5], p[7], p[3], col * 0.9)                        # +x
	_quad(st, p[0], p[4], p[5], p[1], col * 0.7)                        # bottom


## A box at `c`, `s` its size, turned `yaw` about the vertical.
func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, yaw: float) -> void:
	_obox(st, c, Vector3(s.x * 0.5, 0, 0).rotated(Vector3.UP, yaw), Vector3(0, s.y * 0.5, 0),
			Vector3(0, 0, s.z * 0.5).rotated(Vector3.UP, yaw), col)


## A beam from a to b, `thick` m through along `up` and `wide` m across: a brace, a rafter, a roof's slope.
func _beam(st: SurfaceTool, a: Vector3, b: Vector3, up: Vector3, thick: float, wide: float, col: Color,
		top := Color(0, 0, 0, 0), top_kind := -1) -> void:
	var x := (b - a) * 0.5
	var xd := x.normalized()
	var yd := (up - xd * up.dot(xd)).normalized()
	_obox(st, (a + b) * 0.5, x, yd * thick * 0.5, xd.cross(yd) * wide * 0.5, col, top, top_kind)


## A wall's own frame: x along it (to your right, facing it), y up, z out of it; at `at`, facing `out`.
static func _facade(at: Vector3, out: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), at)


## A box on a wall (_facade): `at` its middle and `s` its size in the wall's own x, y, z.
func _fbox(st: SurfaceTool, f: Transform3D, at: Vector3, s: Vector3, col: Color) -> void:
	_obox(st, f * at, f.basis.x * s.x * 0.5, f.basis.y * s.y * 0.5, f.basis.z * s.z * 0.5, col)


static func _box_st(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var p := []
	for i in 8:
		p.append(c + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for f: Array in [[2, 3, 7, 6], [0, 1, 3, 2], [4, 6, 7, 5], [0, 2, 6, 4], [1, 5, 7, 3], [0, 4, 5, 1]]:
		st.set_color(col)
		for k: int in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.add_vertex(p[k])


## A shed's pitched roof on a w x l footprint, its ridge along x, `rise` m up; its gable ends closed.
func _roof(st: SurfaceTool, c: Vector3, w: float, l: float, rise: float, col: Color) -> void:
	var a := c + Vector3(-w * 0.5, 0, -l * 0.5)
	var b := c + Vector3(w * 0.5, 0, -l * 0.5)
	var e := c + Vector3(w * 0.5, 0, l * 0.5)
	var f := c + Vector3(-w * 0.5, 0, l * 0.5)
	var r0 := c + Vector3(-w * 0.5, rise, 0)
	var r1 := c + Vector3(w * 0.5, rise, 0)
	_quad_out(st, a, r0, r1, b, col, Vector3(0, 1, -1))
	_quad_out(st, f, e, r1, r0, col * 0.85, Vector3(0, 1, 1))
	_tri_out(st, a, f, r0, col * 0.7, Vector3.LEFT)
	_tri_out(st, b, r1, e, col * 0.7, Vector3.RIGHT)
	# (and its underside, seen from under the eaves)
	_quad_out(st, a, b, e, f, col * 0.5, Vector3.DOWN)


## An upright cylinder (or a tapering one), `n` sided, from `base` up `h` m, its top closed.
func _cyl(st: SurfaceTool, base: Vector3, h: float, r0: float, r1: float, n: int, col: Color) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p1 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var q0 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var q1 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		_quad(st, p0, p1, q1, q0, col * (0.85 + 0.15 * cos(a0 - 0.6)))
		_tri(st, base + Vector3(0, h, 0), q0, q1, col)


static func _hash(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898 + 4.1) * 43758.5453, 1.0)
