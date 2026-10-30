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


func _ready() -> void:
	var st := _st()
	_quay(st)
	_pier(st, PIER_X, PIER_OUT, PIER_W, DECK_Y, true)
	_pier(st, FINGER_X, FINGER_OUT, FINGER_W, DECK_Y - 0.6, false)
	_shed(st)
	_clutter(st)
	_finish(st)
	_sign()
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
		_quad(st, Vector3(x, QUAY_Y, z0), Vector3(x1, QUAY_Y, z1), Vector3(x1, QUAY_Y, z1 + back),
				Vector3(x, QUAY_Y, z0 + back), Color(0.56, 0.55, 0.52).lerp(Color(0.5, 0.49, 0.47), _hash(int(x))))
		# the face: dry concrete, the wet band, the weed under it
		_quad(st, Vector3(x, QUAY_Y, z0), Vector3(x, 0.6, z0), Vector3(x1, 0.6, z1), Vector3(x1, QUAY_Y, z1),
				Color(0.48, 0.47, 0.44))
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


## A timber pier out from the quay at `px`: planks on stringers, pilings down both sides with their tops proud of the
## deck, cleats, tyres for fenders; `lamps`: lamp posts along it.
func _pier(st: SurfaceTool, px: float, out: float, w: float, y: float, lamps: bool) -> void:
	var face := _shore(px) - 2.0
	var far := face - out
	var wood := Color(0.42, 0.33, 0.24)
	# the planks, each a little different, with a gap between
	var z := face
	var i := 0
	while z > far:
		var c := wood.lerp(Color(0.5, 0.42, 0.32), _hash(i * 7)).darkened(0.1 * _hash(i * 3))
		_box(st, Vector3(px, y, z - 0.14), Vector3(w, 0.07, 0.26), c, (_hash(i) - 0.5) * 0.01)
		z -= 0.3
		i += 1
	# the stringers under them, and the cross-bracing
	for side: float in [-1.0, 1.0]:
		_box(st, Vector3(px + side * (w * 0.5 - 0.15), y - 0.2, (face + far) * 0.5), Vector3(0.2, 0.3, out),
				wood.darkened(0.3), 0.0)
	# the pilings, a pair every 4 m
	var n := int(out / 4.0)
	for k in n + 1:
		var pz := face - k * 4.0 - 0.3
		for side: float in [-1.0, 1.0]:
			var at := Vector3(px + side * (w * 0.5 + 0.1), -5.0, pz)
			_cyl(st, at, y + 5.0 + 0.55, 0.2, 0.18, 7, Color(0.3, 0.25, 0.2).lerp(Color(0.36, 0.3, 0.24), _hash(k)))
			# the green slime band at the waterline, barnacles
			_cyl(st, at + Vector3(0, 4.6, 0), 0.6, 0.215, 0.215, 7, Color(0.16, 0.24, 0.14))
			if k % 2 == 1:
				_cleat(st, Vector3(px + side * (w * 0.5 - 0.35), y + 0.04, pz + 2.0))
			if k % 3 == 1:
				# a tyre hung on it for a fender
				_box(st, at + Vector3(side * 0.28, 5.4, 0.0), Vector3(0.22, 0.7, 0.7), Color(0.08, 0.08, 0.09), 0.0)
		if k > 0 and k % 2 == 0:
			_box(st, Vector3(px, y - 0.55, pz), Vector3(w + 0.2, 0.18, 0.18), wood.darkened(0.35), 0.0)
	if lamps:
		var lz := face - 6.0
		while lz > far + 2.0:
			_lamp(st, Vector3(px + w * 0.5 - 0.2, y, lz))
			lz -= 20.0
		# a ladder down at the end
		for r in 8:
			_box(st, Vector3(px - w * 0.5 - 0.05, y - 0.35 - r * 0.35, far + 1.0), Vector3(0.08, 0.04, 0.5),
					Color(0.6, 0.62, 0.6), 0.0)


func _bollard(st: SurfaceTool, at: Vector3) -> void:
	_cyl(st, at, 0.55, 0.22, 0.18, 8, Color(0.15, 0.16, 0.17))
	_cyl(st, at + Vector3(0, 0.55, 0), 0.08, 0.3, 0.3, 8, Color(0.15, 0.16, 0.17))


func _cleat(st: SurfaceTool, at: Vector3) -> void:
	_box(st, at + Vector3(0, 0.06, 0), Vector3(0.1, 0.12, 0.1), Color(0.2, 0.2, 0.22), 0.0)
	_box(st, at + Vector3(0, 0.13, 0), Vector3(0.1, 0.05, 0.45), Color(0.2, 0.2, 0.22), 0.0)


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

var _mat: StandardMaterial3D


func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _finish(st: SurfaceTool) -> void:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.92
	mi.material_override = _mat
	add_child(mi)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)


func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, yaw: float) -> void:
	var h := s * 0.5
	var p := []
	for i in 8:
		var v := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		p.append(c + v.rotated(Vector3.UP, yaw))
	_quad(st, p[2], p[6], p[7], p[3], col)                   # top
	_quad(st, p[0], p[2], p[3], p[1], col * 0.9)             # -z
	_quad(st, p[4], p[5], p[7], p[6], col * 0.9)             # +z
	_quad(st, p[0], p[4], p[6], p[2], col * 0.82)            # -x
	_quad(st, p[1], p[3], p[7], p[5], col * 0.82)            # +x
	_quad(st, p[0], p[1], p[5], p[4], col * 0.6)             # bottom


static func _box_st(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var p := []
	for i in 8:
		p.append(c + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for f: Array in [[2, 6, 7, 3], [0, 2, 3, 1], [4, 5, 7, 6], [0, 4, 6, 2], [1, 3, 7, 5], [0, 1, 5, 4]]:
		st.set_color(col)
		for k: int in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.add_vertex(p[k])


func _roof(st: SurfaceTool, c: Vector3, w: float, l: float, rise: float, col: Color) -> void:
	var a := c + Vector3(-w * 0.5, 0, -l * 0.5)
	var b := c + Vector3(w * 0.5, 0, -l * 0.5)
	var e := c + Vector3(w * 0.5, 0, l * 0.5)
	var f := c + Vector3(-w * 0.5, 0, l * 0.5)
	var r0 := c + Vector3(-w * 0.5, rise, 0)
	var r1 := c + Vector3(w * 0.5, rise, 0)
	_quad(st, a, r0, r1, b, col)
	_quad(st, f, e, r1, r0, col * 0.85)
	_tri(st, a, f, r0, col * 0.7)
	_tri(st, b, r1, e, col * 0.7)


func _cyl(st: SurfaceTool, base: Vector3, h: float, r0: float, r1: float, n: int, col: Color) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p1 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var q0 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var q1 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		_quad(st, p0, q0, q1, p1, col * (0.8 + 0.2 * cos(a0 - 0.6)))
		_tri(st, base + Vector3(0, h, 0), q1, q0, col)


static func _hash(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898 + 4.1) * 43758.5453, 1.0)
