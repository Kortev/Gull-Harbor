extends Node
## The chart plotter beside the radar on her dash (the screen called plotter, boat/kinds.gd): north up, her in the
## middle, RANGE m to the top edge. The chart: the sea, the coast (sea/landmarks.gd's shore), Gull Harbor's
## breakwaters and pier, the lighthouse, the buoys and the rig, a faint grid every kilometre; her track this trip, a
## line behind her; and a mark wherever someone aboard picked a flock out (crew/spotter.gd: saw()), where it was then.
## Flocks move on: a mark is where the birds were, not where they are, and it fades as it gets old.
##
## Everyone aboard sees the same: her track comes from the helm's synced position, the marks go through the host to
## everyone, and a late joiner is sent both.

const Landmarks := preload("res://sea/landmarks.gd")
const Harbour := preload("res://sea/harbour.gd")

const W := 160
const H := 124
## Metres from her (the middle) to the top edge.
const RANGE := 3000.0
## A point on her track every this many m; at most this many kept.
const STEP := 25.0
const KEEP := 6000
## A mark this old (s) is drawn faded.
const OLD := 300.0

const SEA := Color(0.04, 0.11, 0.24)
const GRID := Color(0.07, 0.16, 0.31)
const LAND := Color(0.62, 0.53, 0.33)
const SHORE := Color(0.85, 0.78, 0.55)
const TRACK := Color(1.0, 0.32, 0.28)
const MARK := Color(1.0, 0.92, 0.18)

var sea: Node                # sea/sea.gd
var boat: Node3D             # boat/boat.gd
## Where she's been this trip (world x, z).
var track := PackedVector2Array()
## The flocks picked out: school id -> [where (world x, z), when (sea clock)].
var marks := {}
var _img: Image
var _tex: ImageTexture
var _in := 0.0
var _was_docked := true


func _ready() -> void:
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_sync.rpc_id(id, track, marks))


func attach(to: Node3D) -> void:
	boat = to
	_img = Image.create(W, H, false, Image.FORMAT_RGB8)
	_img.fill(SEA)
	_tex = ImageTexture.create_from_image(_img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _tex
	mat.emission_enabled = true
	mat.emission_texture = _tex
	mat.emission_energy_multiplier = 1.3
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi: Node in to.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(i)
			if sm and sm.resource_name == "plotter":
				m.set_surface_override_material(i, mat)


## Someone aboard picked out this flock (crew/spotter.gd): mark where it is now, for everyone.
func saw(school: Node) -> void:
	var schools: Node = sea.get("schools")
	var t := float(schools.call("now"))
	var at: Vector2 = school.call("center", t)
	var id := int(school.get("id"))
	if marks.has(id) and (marks[id][0] as Vector2).distance_to(at) < 40.0 and t - float(marks[id][1]) < 30.0:
		return
	if Net.in_session():
		if Net.is_host():
			_mark.rpc(id, at, t)
		else:
			_ask_mark.rpc_id(1, id, at, t)
	else:
		_mark(id, at, t)


@rpc("any_peer", "call_remote", "reliable")
func _ask_mark(id: int, at: Vector2, t: float) -> void:
	_mark.rpc(id, at, t)


@rpc("authority", "call_local", "reliable")
func _mark(id: int, at: Vector2, t: float) -> void:
	marks[id] = [at, t]


@rpc("authority", "call_remote", "reliable")
func _sync(tr: PackedVector2Array, mk: Dictionary) -> void:
	track = tr
	marks = mk


func _process(delta: float) -> void:
	if _img == null or boat == null:
		return
	# a new trip: a clean chart
	var hold: Node = sea.get("fish_hold")
	var docked := hold != null and bool(hold.get("docked"))
	if docked != _was_docked and not docked:
		track.clear()
		marks.clear()
	_was_docked = docked
	var at: Vector2 = boat.get("helm").get("at")
	if not docked and (track.is_empty() or track[track.size() - 1].distance_to(at) > STEP):
		track.append(at)
		if track.size() > KEEP:
			track = track.slice(track.size() - KEEP)
	_in -= delta
	if _in > 0.0:
		return
	_in = 0.25
	_draw(at)
	_tex.update(_img)


func _px(p: Vector2, at: Vector2) -> Vector2:
	var k := (H * 0.5) / RANGE
	return Vector2(W * 0.5, H * 0.5) + (p - at) * k


func _draw(at: Vector2) -> void:
	var k := RANGE / (H * 0.5)
	_img.fill(SEA)
	# a grid every km, fixed to the sea (it slides by as she goes)
	var x0 := at.x - W * 0.5 * k
	var z0 := at.y - H * 0.5 * k
	var gx := ceilf(x0 / 1000.0) * 1000.0
	while gx < x0 + W * k:
		var x := int((gx - x0) / k)
		for y in H:
			_put(x, y, GRID)
		gx += 1000.0
	var gz := ceilf(z0 / 1000.0) * 1000.0
	while gz < z0 + H * k:
		var y := int((gz - z0) / k)
		for x in W:
			_put(x, y, GRID)
		gz += 1000.0
	# the land: below the shore in each column (north up: the land's to the south, +z)
	var marks_n: Node = sea.get("landmarks")
	if marks_n != null:
		for x in W:
			var wx := x0 + (x + 0.5) * k
			var edge := int(floorf((float(marks_n.call("shore_z", wx)) - z0) / k))
			for y in range(maxi(edge, 0), H):
				_put(x, y, SHORE if y == edge else LAND)
		for arm: Array in marks_n.call("breakwater_arms"):
			_line(_px(arm[0], at), _px(arm[1], at), Color(0.95, 0.95, 0.92))
		# the fish pier, and the harbour's mark: a small anchor at its mouth
		var pier := Vector2(Harbour.PIER_X, float(marks_n.call("shore_z", Harbour.PIER_X)))
		_line(_px(pier, at), _px(pier - Vector2(0, Harbour.PIER_OUT), at), Color(0.95, 0.95, 0.92))
		var mouth := Vector2(Landmarks.HARBOUR_X, float(marks_n.call("shore_z", Landmarks.HARBOUR_X)) - 110.0)
		_anchor(_px(mouth, at))
		var lh := Vector2(Landmarks.LIGHTHOUSE_X, float(marks_n.call("shore_z", Landmarks.LIGHTHOUSE_X)) + 15.0)
		_blob(_px(lh, at), 1, Color(1.0, 1.0, 0.75))
		for bu: Dictionary in marks_n.get("_buoys"):
			_blob(_px(bu["at"], at), 0, Color(1.0, 0.55, 0.45))
		var rig := _px(Landmarks.RIG, at)
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if absi(dx) == 2 or absi(dy) == 2:
					_put(int(rig.x) + dx, int(rig.y) + dy, Color(0.85, 0.85, 0.85))
	# her track
	# (a jump, put somewhere by the game rather than run there, isn't joined up)
	var last := Vector2.INF
	for p: Vector2 in track + PackedVector2Array([at]):
		if last != Vector2.INF and last.distance_to(p) < STEP * 6.0:
			_line(_px(last, at), _px(p, at), TRACK)
		last = p
	# the flocks picked out: a ringed dot, pinned to the edge (an arrowhead) if it's off the chart
	var t := float((sea.get("schools") as Node).call("now"))
	for id: int in marks:
		var q := _px(marks[id][0], at)
		var faded := t - float(marks[id][1]) > OLD
		var c := MARK.lerp(SEA, 0.45) if faded else MARK
		if q.x < 2 or q.y < 2 or q.x > W - 3 or q.y > H - 3:
			var mid := Vector2(W * 0.5, H * 0.5)
			var d := (q - mid).normalized()
			var e := mid + d * minf((W * 0.5 - 3.0) / maxf(absf(d.x), 0.001), (H * 0.5 - 3.0) / maxf(absf(d.y), 0.001))
			_blob(e, 1, c)
			continue
		for dx in range(-4, 5):
			for dy in range(-4, 5):
				var r2 := dx * dx + dy * dy
				if r2 <= 5:
					_put(int(q.x) + dx, int(q.y) + dy, c)
				elif r2 <= 13:
					_put(int(q.x) + dx, int(q.y) + dy, Color(0.05, 0.05, 0.05))
	# her: an arrowhead along her heading, outlined
	var h := float(boat.get("helm").get("heading"))
	var fwd := Vector2(-sin(h), -cos(h))
	var side := Vector2(-fwd.y, fwd.x)
	var c0 := Vector2(W * 0.5, H * 0.5)
	var nose := c0 + fwd * 6.0
	var l := c0 - fwd * 4.0 + side * 3.5
	var r := c0 - fwd * 4.0 - side * 3.5
	for s in 9:
		_line(nose, l.lerp(r, s / 8.0), Color(1, 1, 1))
	_line(nose, l, Color(0.0, 0.0, 0.0))
	_line(nose, r, Color(0.0, 0.0, 0.0))
	_line(l, r, Color(0.0, 0.0, 0.0))
	# north: an N in the top corner
	_glyph_n(W - 9, 2)


func _anchor(p: Vector2) -> void:
	var x := int(p.x)
	var y := int(p.y)
	var c := Color(1, 1, 1)
	for d in range(-3, 4):
		_put(x, y + d, c)
	for d in range(-2, 3):
		_put(x + d, y - 2, c)
	_put(x - 2, y + 2, c)
	_put(x + 2, y + 2, c)
	_put(x - 1, y + 3, c)
	_put(x + 1, y + 3, c)


func _glyph_n(x: int, y: int) -> void:
	var c := Color(1, 1, 1)
	for d in 7:
		_put(x, y + d, c)
		_put(x + 5, y + d, c)
		_put(x + 1 + d * 4 / 6, y + d, c)


func _blob(p: Vector2, r: int, c: Color) -> void:
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			_put(int(p.x) + dx, int(p.y) + dy, c)


func _line(a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	if n > 4 * W:
		return
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		_put(int(p.x), int(p.y), c)


func _put(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		_img.set_pixel(x, y, c)
