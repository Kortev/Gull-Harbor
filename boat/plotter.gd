extends Node
## The chart plotter beside the radar on her dash (the screen called plotter in her model): north up, her in the
## middle, RANGE m to the top edge, drawn like a paper chart. The water shaded by depth with its contours and
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

## The screen's picture, px (drawn with anti-aliased lines and real type into a little viewport, shown on the dash).
const W := 480
const H := 336
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
const BAR := Color(0.06, 0.08, 0.11, 0.88)

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
		_view.msaa_2d = Viewport.MSAA_4X
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(_view)
		_chart = Node2D.new()
		_chart.draw.connect(_draw_chart)
		_view.add_child(_chart)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _view.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
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
	var font := ThemeDB.fallback_font
	var k := RANGE / (H * 0.5)
	var x0 := at.x - W * 0.5 * k
	var z0 := at.y - H * 0.5 * k
	c.draw_rect(Rect2(0, 0, W, H), DEEP)
	var lm: Node = sea.get("landmarks")
	if lm != null:
		# the depth bands, deep to shoal, each filled from its contour in to the shore (north up: the land's south)
		var xs: Array[float] = []
		var sx := -16.0
		while sx <= W + 16.0:
			xs.append(x0 + sx * k)
			sx += 6.0
		var shores: Array[float] = []
		for wx: float in xs:
			shores.append(float(lm.call("shore_z", wx)))
		for i in range(CONTOURS.size() - 1, -1, -1):
			var pts := PackedVector2Array()
			for j in xs.size():
				pts.append(_px(Vector2(xs[j], _contour_z(i, xs[j], shores[j])), at))
			var line := pts.duplicate()
			pts.append(Vector2(W + 16.0, H + 4000.0))
			pts.append(Vector2(-16.0, H + 4000.0))
			var shade := SHOAL.lerp(DEEP, float(i) / (CONTOURS.size() - 0.5))
			c.draw_colored_polygon(_clip(pts), shade)
			c.draw_polyline(line, CONTOUR, 1.0, true)
			# its depth, written on it once across the screen
			var lx := W * (0.18 + 0.27 * (i % 3))
			var ly := _px(Vector2(x0 + lx * k, _contour_z(i, x0 + lx * k, float(lm.call("shore_z", x0 + lx * k)))), at).y
			if ly > 40.0 and ly < H - 8.0:
				var label := "%d" % int(CONTOURS[i][0])
				c.draw_rect(Rect2(lx - 8, ly - 7, 16, 12), shade)
				c.draw_string(font, Vector2(lx - 7, ly + 4), label, HORIZONTAL_ALIGNMENT_CENTER, 14, 10, CONTOUR)
		# soundings: a depth in most 900 m squares, fixed to the sea
		var cell := 900.0
		var gx := floorf(x0 / cell) * cell
		while gx < x0 + W * k:
			var gz := floorf(z0 / cell) * cell
			while gz < z0 + H * k:
				var h := absf(sin(gx * 12.9898 + gz * 78.233) * 43758.5453)
				var p := Vector2(gx + cell * (0.2 + 0.6 * fmod(h, 1.0)), gz + cell * (0.2 + 0.6 * fmod(h * 7.1, 1.0)))
				var off := float(lm.call("shore_z", p.x)) - p.y
				if off > 40.0 and fmod(h * 5.7, 1.0) < 0.7:
					var q := _px(p, at)
					var d := _depth_off(off) * (0.9 + 0.2 * fmod(h * 3.3, 1.0))
					c.draw_string(font, q, "%d" % roundi(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, SOUNDING)
				gz += cell
			gx += cell
		# the land
		var land := PackedVector2Array()
		var coast := PackedVector2Array()
		for j in xs.size():
			var q := _px(Vector2(xs[j], shores[j]), at)
			land.append(q)
			coast.append(q)
		land.append(Vector2(W + 16.0, H + 4000.0))
		land.append(Vector2(-16.0, H + 4000.0))
		c.draw_colored_polygon(_clip(land), LAND)
		c.draw_polyline(coast, COAST, 1.5, true)
		# the breakwaters and the pier, the harbour's anchor, the lighthouse's flare, the buoys, the rig
		for arm: Array in lm.call("breakwater_arms"):
			c.draw_line(_px(arm[0], at), _px(arm[1], at), COAST, 3.0, true)
		var pier := Vector2(Harbour.PIER_X, float(lm.call("shore_z", Harbour.PIER_X)))
		c.draw_line(_px(pier, at), _px(pier - Vector2(0, Harbour.PIER_OUT), at), COAST, 2.0, true)
		var mouth := Vector2(Landmarks.HARBOUR_X, float(lm.call("shore_z", Landmarks.HARBOUR_X)) - 110.0)
		_anchor(_px(mouth, at) + Vector2(0, -12))
		var lh := _px(Vector2(Landmarks.LIGHTHOUSE_X, float(lm.call("shore_z", Landmarks.LIGHTHOUSE_X)) + 15.0), at)
		c.draw_colored_polygon(PackedVector2Array([lh, lh + Vector2(-4, -9), lh + Vector2(0, -15), lh + Vector2(4, -9)]),
				MAGENTA)
		c.draw_circle(lh, 2.5, INK)
		var n := 0
		for bu: Dictionary in lm.get("_buoys"):
			var q := _px(bu["at"], at)
			c.draw_circle(q, 4.0, Color(0.1, 0.65, 0.2) if n % 2 == 0 else Color(0.85, 0.15, 0.12))
			c.draw_arc(q, 4.0, 0.0, TAU, 12, INK, 1.0, true)
			c.draw_circle(q, 6.5, Color(MAGENTA, 0.35))
			n += 1
		var rig := _px(Landmarks.RIG, at)
		c.draw_rect(Rect2(rig - Vector2(6, 6), Vector2(12, 12)), INK, false, 1.5)
		c.draw_line(rig - Vector2(6, 6), rig + Vector2(6, 6), INK, 1.0, true)
		c.draw_line(rig + Vector2(-6, 6), rig + Vector2(6, -6), INK, 1.0, true)
		c.draw_string(font, rig + Vector2(9, 4), "Rig", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	# a faint graticule every km, fixed to the sea
	var g := ceilf(x0 / 1000.0) * 1000.0
	while g < x0 + W * k:
		c.draw_line(Vector2((g - x0) / k, 0), Vector2((g - x0) / k, H), GRID, 1.0)
		g += 1000.0
	g = ceilf(z0 / 1000.0) * 1000.0
	while g < z0 + H * k:
		c.draw_line(Vector2(0, (g - z0) / k), Vector2(W, (g - z0) / k), GRID, 1.0)
		g += 1000.0
	# her track
	# (a jump, put somewhere by the game rather than run there, isn't joined up)
	var run := PackedVector2Array()
	var last := Vector2.INF
	for p: Vector2 in track + PackedVector2Array([at]):
		if last != Vector2.INF and last.distance_to(p) >= STEP * 6.0:
			if run.size() > 1:
				c.draw_polyline(run, TRACK, 2.0, true)
			run = PackedVector2Array()
		run.append(_px(p, at))
		last = p
	if run.size() > 1:
		c.draw_polyline(run, TRACK, 2.0, true)
	# the flocks picked out: a waypoint (a ringed dot with a bird's V), pinned to the edge if it's off the chart
	var t := float((sea.get("schools") as Node).call("now"))
	for id: int in marks:
		var q := _px(marks[id][0], at)
		var faded := t - float(marks[id][1]) > OLD
		var col := Color(MARK, 0.5) if faded else MARK
		var mid := Vector2(W * 0.5, H * 0.5)
		if q.x < 10 or q.y < 40 or q.x > W - 10 or q.y > H - 10:
			var d := (q - mid).normalized()
			var e := mid + d * minf((W * 0.5 - 12.0) / maxf(absf(d.x), 0.001), (H * 0.5 - 24.0) / maxf(absf(d.y), 0.001))
			var sd := Vector2(-d.y, d.x)
			c.draw_colored_polygon(PackedVector2Array([e + d * 8.0, e - d * 4.0 + sd * 6.0, e - d * 4.0 - sd * 6.0]), col)
			continue
		c.draw_circle(q, 8.0, INK)
		c.draw_circle(q, 6.5, col)
		c.draw_polyline(PackedVector2Array([q + Vector2(-4, -1), q + Vector2(-2, 1), q + Vector2(0, -1),
				q + Vector2(2, 1), q + Vector2(4, -1)]), INK, 1.5, true)
	# her: a hull shape along her heading, and her heading line out ahead of her
	var helm: Node = boat.get("helm")
	var hd := float(helm.get("heading"))
	var fwd := Vector2(-sin(hd), -cos(hd))
	var side := Vector2(-fwd.y, fwd.x)
	var c0 := Vector2(W * 0.5, H * 0.5)
	var dash := 0.0
	while dash < 120.0:
		c.draw_line(c0 + fwd * (14.0 + dash), c0 + fwd * (14.0 + dash + 6.0), INK, 1.5, true)
		dash += 10.0
	var hull := PackedVector2Array([c0 + fwd * 13.0, c0 + fwd * 3.0 + side * 6.0, c0 - fwd * 10.0 + side * 5.0,
			c0 - fwd * 10.0 - side * 5.0, c0 + fwd * 3.0 - side * 6.0])
	c.draw_colored_polygon(hull, INK)
	hull.append(hull[0])
	c.draw_polyline(hull, Color(1, 1, 1), 1.5, true)
	# the data bar: speed over ground, heading, the depth under her
	c.draw_rect(Rect2(0, 0, W, 30), BAR)
	var knots := absf(float(helm.get("speed"))) * 1.944
	var deg := fposmod(rad_to_deg(-hd), 360.0)
	var under := 0.0
	if lm != null:
		under = _depth_off(float(lm.call("shore_z", at.x)) - at.y)
	_readout(font, 10, "SOG", "%.1f" % knots, "kn")
	_readout(font, 170, "HDG", "%03d" % roundi(deg) + "°", "T")
	_readout(font, 330, "DEPTH", "%d" % roundi(under), "m")
	# the scale, and north
	c.draw_rect(Rect2(10, H - 24, 92, 16), Color(1, 1, 1, 0.7))
	var km := 1000.0 / k
	c.draw_line(Vector2(14, H - 12), Vector2(14 + km, H - 12), INK, 2.0)
	c.draw_line(Vector2(14, H - 16), Vector2(14, H - 9), INK, 2.0)
	c.draw_line(Vector2(14 + km, H - 16), Vector2(14 + km, H - 9), INK, 2.0)
	c.draw_string(font, Vector2(20 + km, H - 11), "1 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	var nn := Vector2(W - 20, 52)
	c.draw_circle(nn, 13.0, Color(1, 1, 1, 0.75))
	c.draw_colored_polygon(PackedVector2Array([nn + Vector2(0, -10), nn + Vector2(5, 6), nn + Vector2(0, 2),
			nn + Vector2(-5, 6)]), INK)
	c.draw_string(font, nn + Vector2(-4, 24), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)


## A figure on the data bar: its name small, the number big, its unit after it.
func _readout(font: Font, x: float, name_: String, value: String, unit: String) -> void:
	_chart.draw_string(font, Vector2(x, 12), name_, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.68, 0.76))
	var w := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_chart.draw_string(font, Vector2(x + 38, 24), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1))
	_chart.draw_string(font, Vector2(x + 42 + w, 24), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.8, 0.86))


## A polygon's points pulled in to a little past the screen (so a coast far off doesn't make a huge one).
func _clip(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(Vector2(clampf(p.x, -20.0, W + 20.0), clampf(p.y, -20.0, H + 20.0)))
	return out


## The harbour's mark: an anchor.
func _anchor(p: Vector2) -> void:
	var c := _chart
	c.draw_line(p + Vector2(0, -7), p + Vector2(0, 7), MAGENTA, 2.0, true)
	c.draw_line(p + Vector2(-4, -4), p + Vector2(4, -4), MAGENTA, 2.0, true)
	c.draw_arc(p + Vector2(0, 1), 6.0, 0.3, PI - 0.3, 8, MAGENTA, 2.0, true)
	c.draw_circle(p + Vector2(0, -8), 2.0, MAGENTA)
