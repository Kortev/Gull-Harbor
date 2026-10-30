extends Node
## The chart plotter beside the radar on her dash (the screen called plotter in her model): north up, her in the
## middle, RANGE m to the top edge, drawn like a chart, in pixels. The water shaded by depth with its contours and
## soundings, the coast (sea/landmarks.gd's shore), Gull Harbor's breakwaters, pier and anchor, the lighthouse, the
## buoys and the rig, a faint grid every kilometre; a bar along the top with her speed, heading and the depth under
## her; her heading line out ahead of her and her track this trip, a
## line behind her; and a mark wherever someone aboard picked a flock out (crew/spotter.gd: saw()), where it was then.
## Flocks move on: a mark is where the birds were, not where they are, and it fades as it gets old.
##
## Everyone aboard sees the same: her track comes from the helm's synced position, the marks go through the host to
## everyone, and a late joiner is sent both.

const Landmarks := preload("res://sea/landmarks.gd")
const Harbour := preload("res://sea/harbour.gd")
const PixFont := preload("res://ui/pixfont.gd")

## The screen's picture, px: drawn in whole pixels, hard edged, with the little pixel font (ui/pixfont.gd), into a
## small viewport shown on the dash, to sit with the game's pixel look.
const W := 176
const H := 124
## The bar along the top, px.
const BAR_H := 9
## Metres from her (the middle) to the top edge.
const RANGE := 3000.0
## A point on her track every this many m; at most this many kept.
const STEP := 25.0
const KEEP := 6000
## A mark this old (s) is drawn faded.
const OLD := 300.0
## The depth contours: [depth m, how far off the water's edge the bottom drops past it m], shoal to deep.
const CONTOURS := [[5.0, 70.0], [10.0, 180.0], [20.0, 450.0], [30.0, 900.0], [50.0, 1800.0], [100.0, 3600.0]]

## A paper chart's colours: the shoal water a deeper blue, the deep water near white, the land buff.
const DEEP := Color(0.9, 0.95, 0.98)
const SHOAL := Color(0.47, 0.71, 0.9)
const CONTOUR := Color(0.36, 0.52, 0.68)
const LAND := Color(0.95, 0.87, 0.6)
const COAST := Color(0.3, 0.26, 0.18)
const GRID := Color(0.55, 0.65, 0.75, 0.35)
const INK := Color(0.08, 0.1, 0.14)
const SOUNDING := Color(0.35, 0.42, 0.5)
const MAGENTA := Color(0.82, 0.12, 0.62)
const TRACK := Color(0.9, 0.15, 0.12)
const MARK := Color(1.0, 0.78, 0.1)
const BAR := Color(0.06, 0.08, 0.11, 0.9)

## The chart's symbols, a row per string ("#" lit).
const ANCHOR := [".#.", "###", ".#.", "#.#", ".#."]
const FLARE := [".#.", "###", "###", ".#."]
const RIG_MARK := ["#####", "##.##", "#.#.#", "##.##", "#####"]
const WAYPOINT := [".###.", "#...#", "#...#", "#...#", ".###."]
const NORTH := [".#.", "###", "#.#"]

var sea: Node                # sea/sea.gd
var boat: Node3D             # boat/boat.gd
## Where she's been this trip (world x, z).
var track := PackedVector2Array()
## The flocks picked out: school id -> [where (world x, z), when (sea clock)].
var marks := {}
## The chart's canvas, drawn into _view; how many times it's been drawn.
var _view: SubViewport
var _chart: Node2D
var drawn := 0
var _at := Vector2.ZERO
var _in := 0.0
var _was_docked := true


func _ready() -> void:
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_sync.rpc_id(id, track, marks))


func attach(to: Node3D) -> void:
	boat = to
	if _view == null:
		_view = SubViewport.new()
		_view.size = Vector2i(W, H)
		_view.disable_3d = true
		_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(_view)
		_chart = Node2D.new()
		_chart.draw.connect(_draw_chart)
		_view.add_child(_chart)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _view.get_texture()
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
	if _view == null or boat == null:
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
	_at = at
	_chart.queue_redraw()
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _px(p: Vector2, at: Vector2) -> Vector2:
	var k := (H * 0.5) / RANGE
	return Vector2(W * 0.5, H * 0.5) + (p - at) * k


## Where depth contour i runs at x (world z): its distance off the water's edge, wandering a little along the coast.
func _contour_z(i: int, x: float, shore: float) -> float:
	var off: float = CONTOURS[i][1]
	off *= 1.0 + 0.16 * sin(x * 0.0017 + i * 1.3) + 0.09 * sin(x * 0.0049 + i * 2.7)
	return shore - off


## How deep it is (m) at p (world x, z), as the chart has it (tuna/sonar.gd reads it too).
func depth_at(p: Vector2) -> float:
	var lm: Node = sea.get("landmarks")
	return _depth_off(float(lm.call("shore_z", p.x)) - p.y) if lm else 60.0


## How deep it is (m) this far off the water's edge: between the contours.
func _depth_off(off: float) -> float:
	var last := [0.0, 0.0]
	for c: Array in CONTOURS:
		if off < float(c[1]):
			return lerpf(float(last[0]), float(c[0]), (off - float(last[1])) / (float(c[1]) - float(last[1])))
		last = c
	return float(last[0]) + (off - float(last[1])) * 0.02


func _draw_chart() -> void:
	drawn += 1
	var at := _at
	var c := _chart
	var k := RANGE / (H * 0.5)
	var x0 := at.x - W * 0.5 * k
	var z0 := at.y - H * 0.5 * k
	c.draw_rect(Rect2(0, 0, W, H), DEEP)
	var lm: Node = sea.get("landmarks")
	if lm != null:
		# the depth bands, deep to shoal, each filled from its contour in to the shore (north up: the land's south)
		var xs: Array[float] = []
		for sx in range(-4, W + 6, 3):
			xs.append(x0 + sx * k)
		var shores: Array[float] = []
		for wx: float in xs:
			shores.append(float(lm.call("shore_z", wx)))
		for i in range(CONTOURS.size() - 1, -1, -1):
			var pts := PackedVector2Array()
			for j in xs.size():
				pts.append(_px(Vector2(xs[j], _contour_z(i, xs[j], shores[j])), at).round())
			var line := pts.duplicate()
			pts.append(Vector2(W + 6.0, H + 1000.0))
			pts.append(Vector2(-4.0, H + 1000.0))
			c.draw_colored_polygon(_clip(pts), SHOAL.lerp(DEEP, float(i) / (CONTOURS.size() - 0.5)))
			c.draw_polyline(line, CONTOUR, -1.0)
		# soundings: a depth in some of the 1200 m squares, fixed to the sea
		var cell := 1200.0
		var gx := floorf(x0 / cell) * cell
		while gx < x0 + W * k:
			var gz := floorf(z0 / cell) * cell
			while gz < z0 + H * k:
				var h := absf(sin(gx * 12.9898 + gz * 78.233) * 43758.5453)
				var p := Vector2(gx + cell * (0.2 + 0.6 * fmod(h, 1.0)), gz + cell * (0.2 + 0.6 * fmod(h * 7.1, 1.0)))
				var off := float(lm.call("shore_z", p.x)) - p.y
				if off > 60.0 and fmod(h * 5.7, 1.0) < 0.6:
					var d := _depth_off(off) * (0.9 + 0.2 * fmod(h * 3.3, 1.0))
					PixFont.draw(c, _px(p, at), "%d" % roundi(d), SOUNDING)
				gz += cell
			gx += cell
		# the land, and its coastline
		var land := PackedVector2Array()
		for j in xs.size():
			land.append(_px(Vector2(xs[j], shores[j]), at).round())
		var coast := land.duplicate()
		land.append(Vector2(W + 6.0, H + 1000.0))
		land.append(Vector2(-4.0, H + 1000.0))
		c.draw_colored_polygon(_clip(land), LAND)
		c.draw_polyline(coast, COAST, -1.0)
		# the breakwaters and the pier, the harbour's anchor, the lighthouse, the buoys, the rig
		for arm: Array in lm.call("breakwater_arms"):
			c.draw_line(_px(arm[0], at).round(), _px(arm[1], at).round(), COAST, 2.0)
		var pier := Vector2(Harbour.PIER_X, float(lm.call("shore_z", Harbour.PIER_X)))
		c.draw_line(_px(pier, at).round(), _px(pier - Vector2(0, Harbour.PIER_OUT), at).round(), COAST, -1.0)
		var mouth := Vector2(Landmarks.HARBOUR_X, float(lm.call("shore_z", Landmarks.HARBOUR_X)) - 110.0)
		_sprite(_px(mouth, at) + Vector2(0, -5), ANCHOR, MAGENTA)
		var lh := Vector2(Landmarks.LIGHTHOUSE_X, float(lm.call("shore_z", Landmarks.LIGHTHOUSE_X)) + 15.0)
		_sprite(_px(lh, at), FLARE, MAGENTA)
		var n := 0
		for bu: Dictionary in lm.get("_buoys"):
			var q := _px(bu["at"], at).floor()
			c.draw_rect(Rect2(q - Vector2(1, 1), Vector2(3, 3)), INK)
			c.draw_rect(Rect2(q, Vector2(1, 1)), Color(0.1, 0.7, 0.2) if n % 2 == 0 else Color(0.9, 0.15, 0.12))
			n += 1
		var rig := _px(Landmarks.RIG, at).floor()
		_sprite(rig, RIG_MARK, INK)
		PixFont.draw(c, rig + Vector2(5, -2), "RIG", INK)
	# a faint grid every km, fixed to the sea
	var g := ceilf(x0 / 1000.0) * 1000.0
	while g < x0 + W * k:
		var x := floorf((g - x0) / k) + 0.5
		c.draw_line(Vector2(x, 0), Vector2(x, H), GRID, -1.0)
		g += 1000.0
	g = ceilf(z0 / 1000.0) * 1000.0
	while g < z0 + H * k:
		var y := floorf((g - z0) / k) + 0.5
		c.draw_line(Vector2(0, y), Vector2(W, y), GRID, -1.0)
		g += 1000.0
	# her track
	# (a jump, put somewhere by the game rather than run there, isn't joined up)
	var run := PackedVector2Array()
	var last := Vector2.INF
	for p: Vector2 in track + PackedVector2Array([at]):
		if last != Vector2.INF and last.distance_to(p) >= STEP * 6.0:
			if run.size() > 1:
				c.draw_polyline(run, TRACK, -1.0)
			run = PackedVector2Array()
		run.append(_px(p, at).floor() + Vector2(0.5, 0.5))
		last = p
	if run.size() > 1:
		c.draw_polyline(run, TRACK, -1.0)
	# the flocks picked out: a ringed dot, pinned to the edge (an arrowhead) if it's off the chart
	var t := float((sea.get("schools") as Node).call("now"))
	var mid := Vector2(W * 0.5, H * 0.5)
	for id: int in marks:
		var q := _px(marks[id][0], at).floor()
		var col := MARK.lerp(DEEP, 0.5) if t - float(marks[id][1]) > OLD else MARK
		if q.x < 4 or q.y < BAR_H + 4 or q.x > W - 5 or q.y > H - 5:
			var d := (q - mid).normalized()
			var e := mid + d * minf((W * 0.5 - 4.0) / maxf(absf(d.x), 0.001), (H * 0.5 - 6.0) / maxf(absf(d.y), 0.001))
			c.draw_rect(Rect2(e.floor() - Vector2(1, 1), Vector2(3, 3)), col)
			continue
		_sprite(q, WAYPOINT, INK)
		c.draw_rect(Rect2(q - Vector2(1, 1), Vector2(3, 3)), col)
	# her: a little hull along her heading, outlined, and her heading line out ahead of her
	var helm: Node = boat.get("helm")
	var hd := float(helm.get("heading"))
	var fwd := Vector2(-sin(hd), -cos(hd))
	var side := Vector2(-fwd.y, fwd.x)
	var c0 := mid
	for s in range(6, 34, 4):
		c.draw_line((c0 + fwd * s).round(), (c0 + fwd * (s + 2)).round(), INK, -1.0)
	var hull := PackedVector2Array([c0 + fwd * 5.0, c0 + side * 2.5, c0 - fwd * 4.0 + side * 2.5,
			c0 - fwd * 4.0 - side * 2.5, c0 - side * 2.5])
	for i in hull.size():
		hull[i] = hull[i].round()
	c.draw_colored_polygon(hull, INK)
	hull.append(hull[0])
	c.draw_polyline(hull, Color(1, 1, 1), -1.0)
	# the bar along the top: speed over ground, heading, the depth under her
	c.draw_rect(Rect2(0, 0, W, BAR_H), BAR)
	var knots := absf(float(helm.get("speed"))) * 1.944
	var deg := fposmod(rad_to_deg(-hd), 360.0)
	PixFont.draw(c, Vector2(3, 2), "%.1fKN" % knots, Color(1, 1, 1))
	PixFont.draw(c, Vector2(66, 2), "%03d°" % roundi(deg), Color(1, 1, 1))
	var dep := "%dM" % roundi(depth_at(at))
	PixFont.draw(c, Vector2(W - 3 - PixFont.width(dep), 2), dep, Color(1, 1, 1))
	# the scale, and north
	var km := floorf(1000.0 / k)
	c.draw_rect(Rect2(2, H - 9, km + 18, 8), Color(DEEP, 0.85))
	c.draw_line(Vector2(4, H - 3.5), Vector2(4 + km, H - 3.5), INK, -1.0)
	c.draw_line(Vector2(4.5, H - 6), Vector2(4.5, H - 3), INK, -1.0)
	c.draw_line(Vector2(4.5 + km, H - 6), Vector2(4.5 + km, H - 3), INK, -1.0)
	PixFont.draw(c, Vector2(7 + km, H - 7), "1KM", INK)
	_sprite(Vector2(W - 6, BAR_H + 5), NORTH, INK)


## A little picture, centred on p: one string per row, "#" lit.
func _sprite(p: Vector2, rows: Array, col: Color) -> void:
	var o := p.floor() - Vector2(floorf((rows[0] as String).length() / 2.0), floorf(rows.size() / 2.0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				_chart.draw_rect(Rect2(o.x + x, o.y + y, 1, 1), col)


## A polygon's points pulled in to a little past the screen (so a coast far off doesn't make a huge one).
func _clip(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(Vector2(clampf(p.x, -6.0, W + 6.0), clampf(p.y, -6.0, H + 6.0)))
	return out
