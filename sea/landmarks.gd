extends Node3D
## Things out there at fixed spots, so the sea's a place and not an endless test level (the user's call, 2026-10-29):
## the coast astern of where you start (hills, the town round its harbour, the breakwaters), the lighthouse on its
## headland, an oil rig out to the north-west, and buoys: the fairway buoy and the channel in, a weather buoy offshore.
## Every peer builds the same (nothing's random but a fixed seed), so nothing goes over the network.
##
## How they sit on this sea: the ocean curves away (ocean.gd's CURVE_START/RADIUS, a small planet), so far things are
## sunk to sit on the horizon line rather than float above it, and anything further than DRAW m is drawn shrunk in
## toward the camera along the same line of sight (the same look, never cut off by the far plane). The haze goes by
## where they really are (landmark.gdshader): a coast pale on the horizon on a clear day, gone in fog.
## The buoys are near enough to ride the swell. The shore and the rig stop the boat (blocked(): boat/helm.gd), and
## no school turns up on land (tuna/schools.gd asks at_sea()).

const LAND_SHADER := preload("res://sea/landmark.gdshader")
const LIGHT_SHADER := preload("res://sea/landmark_light.gdshader")

## Where things are (world x, z; the boat starts at 0, 0 facing -z, so the coast's astern).
const SHORE_Z := 1900.0
const HARBOUR_X := 0.0
const LIGHTHOUSE_X := 1150.0
const RIG := Vector2(-1700.0, -2000.0)
const RIG_SCALE := 1.5                 # (the model's in metres of a modest platform: this one's a big one)
const RIG_KEEP_OFF := 60.0             # m from its middle the boat can't come (its legs, its anchor chains)
const SHORE_KEEP_OFF := 30.0           # m off the water's edge the boat touches bottom
const COAST_X := Vector2(-9000.0, 9000.0)
## The harbour front (world x from .. to, and how far up from the water): sea/harbour.gd builds its houses up close.
const FRONT_X := Vector2(-190.0, 200.0)
const FRONT_D := 110.0
const CHUNK := 2000.0                 # m of coast per piece (each sinks and shrinks on its own)
const DRAW := 3500.0                  # m: anything further is drawn in at this distance, shrunk to match
const CURVE_START := 350.0            # (ocean.gd's)
const CURVE_RADIUS := 12000.0

var ocean: Node3D                     # sea/ocean.gd
var night := 0.0                      # 0 day .. 1 night (sea.gd)
var lights_on := false
var harbour: Node3D           # sea/harbour.gd: its piers are in the way too

var _land_mat: ShaderMaterial
var _light_mat: ShaderMaterial
var _near_mat: StandardMaterial3D     # (the buoys: close enough for the scene's own fog and light)
## Far pieces: {node, anchor (world, sea level), geo: [GeometryInstance3D], scale}
var _far: Array[Dictionary] = []
## Buoys: {node, at (x, z), lamp, blink: [period s, on s, offset s], colour}
var _buoys: Array[Dictionary] = []
var _lamp: MeshInstance3D              # the lighthouse's
var _beam: Node3D
var _beam_mats: Array[ShaderMaterial] = []
var _flare: MeshInstance3D
var _night_lights: Array[MeshInstance3D] = []    # windows and deck lights: on after dark
var _t := 0.0


func _ready() -> void:
	_land_mat = ShaderMaterial.new()
	_land_mat.shader = LAND_SHADER
	_light_mat = ShaderMaterial.new()
	_light_mat.shader = LIGHT_SHADER
	_near_mat = StandardMaterial3D.new()
	_near_mat.vertex_color_use_as_albedo = true
	_near_mat.roughness = 0.7
	_near_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_coast()
	_build_rig()
	_build_buoys()


## The weather and the light (sea.gd's _apply_look): the colour far things fade into and how far you can see (m).
func set_look(haze: Color, visibility: float, dark: float, lamps: bool) -> void:
	# (a Color, not a Vector3: so it's turned from sRGB to linear like the sky's own colours)
	_land_mat.set_shader_parameter("haze_color", haze)
	_land_mat.set_shader_parameter("visibility", visibility)
	_light_mat.set_shader_parameter("visibility", visibility)
	night = dark
	lights_on = lamps


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	var centre := Vector2(eye.x, eye.z)
	if ocean != null:
		centre = Vector2(ocean.global_position.x, ocean.global_position.z)
	# how far below level the horizon is from this eye (where a line from it just grazes the curved sea)
	var h := maxf(eye.y, 0.5)
	var r := sqrt(CURVE_START * CURVE_START + 2.0 * CURVE_RADIUS * h)
	var dip := (h + pow(r - CURVE_START, 2.0) / (2.0 * CURVE_RADIUS)) / r
	for f in _far:
		var a: Vector3 = f["anchor"]
		var d := Vector2(a.x, a.z).distance_to(centre)
		var drop := pow(maxf(d - CURVE_START, 0.0), 2.0) / (2.0 * CURVE_RADIUS)
		var sink := clampf(dip * d - h + 0.0015 * d, 0.0, drop)
		var real := a - Vector3(0.0, sink, 0.0)
		var span := real.distance_to(eye)
		var k := minf(1.0, DRAW / maxf(span, 1.0))
		var node: Node3D = f["node"]
		node.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * k * float(f.get("scale", 1.0))),
				eye + (real - eye) * k)
		for g: GeometryInstance3D in f["geo"]:
			g.set_instance_shader_parameter("far_mul", 1.0 / k)
	_ride_buoys()
	_turn_light()
	var flick := 0.85 + 0.15 * sin(_t * 9.0) * sin(_t * 5.3 + 1.0)
	if _flare:
		_flare.set_instance_shader_parameter("glow", flick * 1.6)
	for l in _night_lights:
		l.visible = lights_on
	if harbour != null:
		harbour.set("lights_on", lights_on)


# ---- where you can go ------------------------------------------------------------------------------------------

## Land (or near enough to it to touch bottom), or the rig: somewhere the boat can't be (world x, z).
func blocked(p: Vector2) -> bool:
	if harbour != null and harbour.call("blocked", p):
		return true
	if p.y > shore_z(p.x) - _keep_off(p.x) or p.distance_to(RIG) < RIG_KEEP_OFF:
		return true
	for arm: Array in breakwater_arms():
		if Geometry2D.get_closest_point_to_segment(p, arm[0], arm[1]).distance_to(p) < 8.0:
			return true
	return false


## The harbour's two breakwaters, each from where it leaves the shore to its light (world x, z).
func breakwater_arms() -> Array:
	var mouth := shore_z(HARBOUR_X) - 210.0
	var arms := []
	for side: float in [-1.0, 1.0]:
		arms.append([Vector2(HARBOUR_X + side * 330.0, shore_z(HARBOUR_X + side * 330.0) + 10.0),
				Vector2(HARBOUR_X + side * 45.0, mouth)])
	return arms


## How far off the water's edge she touches bottom at x: in the harbour, dredged right up to the quay.
func _keep_off(x: float) -> float:
	return lerpf(SHORE_KEEP_OFF, 3.0, _bell(x - HARBOUR_X, 160.0) if absf(x - HARBOUR_X) < 280.0 else 0.0)


## Open water, `room` m clear of the shore and the rig (world x, z): where a school can be.
func at_sea(p: Vector2, room := 0.0) -> bool:
	return p.y < shore_z(p.x) - room and p.distance_to(RIG) > RIG_KEEP_OFF + room


# ---- the coast -------------------------------------------------------------------------------------------------

## Where the water's edge is at x (world z): a wandering shore, a bay for the harbour, the lighthouse's headland.
## (sea/ocean.gd and ocean.gdshader have the same sum, for the waves dying away in the shallows: keep them in step.)
func shore_z(x: float) -> float:
	var z := SHORE_Z + 140.0 * sin(x / 1100.0 + 0.5) + 50.0 * sin(x / 370.0 + 2.0)
	z += 220.0 * _bell(x - HARBOUR_X, 260.0)            # (the bay)
	z -= 330.0 * _bell(x - LIGHTHOUSE_X, 240.0)         # (the headland)
	return z


## The land's height (m) at x, `d` m in from the shore (below 0: under the water).
func land_h(x: float, d: float) -> float:
	if d <= 0.0:
		return -18.0
	var hills := 60.0 + 230.0 * pow(_noise(x / 2600.0, 3), 2.0) + 60.0 * _noise(x / 700.0, 7)
	var back := maxf(260.0 + 320.0 * _noise(x / 3800.0, 11), 80.0)   # the mountains behind
	var rise := smoothstep(0.0, 900.0, d) * hills + smoothstep(1200.0, 3200.0, d) * back
	# a low cliff along most of it, a beach where it's low, the town's slope gentle
	var cliff := 14.0 * smoothstep(0.0, 25.0, d) * (0.4 + 0.6 * _noise(x / 500.0, 5))
	var town := _bell(x - HARBOUR_X, 500.0)
	var head := _bell(x - LIGHTHOUSE_X, 200.0)
	# (the harbour's head: low and flat behind the quay, sea/harbour.gd's apron at 2.2 m, rising from there)
	var flat := _bell(x - HARBOUR_X, 190.0) * (1.0 - smoothstep(30.0, 140.0, d))
	cliff *= 1.0 - flat
	var h := cliff + rise * (1.0 - 0.3 * town) * (1.0 - flat)
	h += head * 34.0 * smoothstep(0.0, 30.0, d)
	h += 6.0 * _noise(x / 90.0 + d / 70.0, 13)
	return maxf(lerpf(h * smoothstep(-2.0, 12.0, d), 2.0, flat * 0.9), 1.0)


func _build_coast() -> void:
	var x := COAST_X.x
	while x < COAST_X.y - 1.0:
		var x1 := x + CHUNK
		var ax := (x + x1) * 0.5
		var anchor := Vector3(ax, 0.0, shore_z(ax))
		var st := _st()
		_terrain(st, x, x1, anchor)
		var geo: Array = []
		var node := Node3D.new()
		node.name = "Coast%d" % int(ax)
		add_child(node)
		if HARBOUR_X >= x and HARBOUR_X < x1:
			_town(st, anchor)
			_breakwaters(st, anchor, node)
		if LIGHTHOUSE_X >= x and LIGHTHOUSE_X < x1:
			_lighthouse(st, anchor, node)
		for w: Array in _pending_windows:
			_night_lights.append(_light(node, w[0], w[1], w[2]))
		_pending_windows.clear()
		geo.append(_finish(st, node, false))
		for c in node.get_children():
			if c is GeometryInstance3D and not geo.has(c):
				geo.append(c)
		_far.append({"node": node, "anchor": anchor, "geo": geo})
		x = x1


## The land from x0 to x1: a grid along the shore (a column every 100 m), rows going inland, faceted.
func _terrain(st: SurfaceTool, x0: float, x1: float, anchor: Vector3) -> void:
	var rows := [-80.0, 0.0, 14.0, 40.0, 110.0, 240.0, 450.0, 750.0, 1150.0, 1700.0, 2400.0, 3300.0]
	var step := 100.0
	var cols := int(round((x1 - x0) / step))
	var grid := []
	for i in cols + 1:
		var gx := x0 + i * step
		var col := []
		for d: float in rows:
			# (the columns wobble a little so the facets don't line up)
			var wob := 0.0 if d <= 0.0 else 18.0 * _noise(gx / 60.0 + d / 50.0, 17)
			var px := gx + wob
			col.append(Vector3(px, land_h(px, d), shore_z(px) + d) - anchor)
		grid.append(col)
	for i in cols:
		for j in rows.size() - 1:
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i + 1][j]
			var c: Vector3 = grid[i + 1][j + 1]
			var e: Vector3 = grid[i][j + 1]
			_tri(st, a, b, c, _land_colour(a, b, c, i * 31 + j))
			_tri(st, a, c, e, _land_colour(a, c, e, i * 17 + j * 3 + 1))


func _land_colour(a: Vector3, b: Vector3, c: Vector3, n: int) -> Color:
	var y := (a.y + b.y + c.y) / 3.0
	var nrm := (b - a).cross(c - a).normalized()
	var steep := 1.0 - absf(nrm.y)
	var j := _hash(n) * 0.08 - 0.04
	var col: Color
	if y < 3.0 and steep < 0.3:
		col = Color(0.74, 0.68, 0.52)                    # sand and shingle
	elif steep > 0.55 or y < 12.0:
		col = Color(0.46, 0.44, 0.41)                    # rock
	elif y > 380.0:
		col = Color(0.5, 0.5, 0.46)                      # bare tops
	elif y > 200.0:
		col = Color(0.22, 0.34, 0.18).lerp(Color(0.4, 0.38, 0.3), (y - 200.0) / 180.0)
	else:
		col = Color(0.27, 0.46, 0.18).lerp(Color(0.2, 0.36, 0.17), _hash(n + 5))   # grass and scrub
	# (darker than it'd be up close: far land reads as a dark band under the pale sky, the haze lightens it)
	return Color(col.r + j, col.g + j, col.b + j * 0.6) * 0.45


## The town round the harbour: houses up the slope, sheds and a warehouse on the quay, a church.
func _town(st: SurfaceTool, anchor: Vector3) -> void:
	var walls := [Color(0.92, 0.9, 0.84), Color(0.88, 0.84, 0.72), Color(0.7, 0.78, 0.84), Color(0.9, 0.8, 0.55),
			Color(0.75, 0.42, 0.34), Color(0.94, 0.94, 0.92)]
	var roofs := [Color(0.55, 0.22, 0.17), Color(0.3, 0.32, 0.36), Color(0.42, 0.3, 0.24), Color(0.25, 0.27, 0.3)]
	var n := 0
	var tries := 0
	while n < 170 and tries < 1500:
		tries += 1
		var u := _hash(tries * 7 + 1)
		var v := _hash(tries * 13 + 2)
		var x := HARBOUR_X + (u - 0.5) * 1100.0
		var d := 25.0 + pow(v, 1.3) * 520.0 * (1.0 - 0.6 * absf(u - 0.5))
		var y := land_h(x, d)
		if y > 120.0:
			continue
		# (the harbour front's are sea/harbour.gd's, built for seeing up close)
		if x > FRONT_X.x - 10.0 and x < FRONT_X.y + 10.0 and d < FRONT_D + 12.0:
			continue
		var at := Vector3(x, y, shore_z(x) + d) - anchor
		var w := 8.0 + 5.0 * _hash(tries * 3)
		var l := 9.0 + 7.0 * _hash(tries * 5)
		var tall := 6.0 + 6.0 * _hash(tries * 11)
		var yaw := (_hash(tries * 19) - 0.5) * 0.5
		_box(st, at + Vector3(0, tall * 0.5 - 2.0, 0), Vector3(w, tall + 4.0, l), walls[tries % walls.size()], yaw)
		_roof(st, at + Vector3(0, tall, 0), w + 0.8, l + 0.8, 2.5 + 1.5 * _hash(tries), roofs[tries % roofs.size()], yaw)
		if _hash(tries * 23) < 0.35:
			_window_light(at + Vector3(0, tall * 0.6, 0) + Vector3(w * 0.5 + 0.2, 0, 0).rotated(Vector3.UP, yaw),
					1.2, Color(1.0, 0.78, 0.45))
		n += 1
	# the church, up the hill behind the harbour
	var cx := HARBOUR_X - 120.0
	var cd := 260.0
	var cy := land_h(cx, cd)
	var c := Vector3(cx, cy, shore_z(cx) + cd) - anchor
	_box(st, c + Vector3(0, 4.0, 0), Vector3(12, 14, 24), Color(0.9, 0.88, 0.82), 0.1)
	_roof(st, c + Vector3(0, 11.0, 0), 13, 25, 6.0, Color(0.3, 0.32, 0.36), 0.1)
	var tower := c + Vector3(0, 0, -14).rotated(Vector3.UP, 0.1)
	_box(st, tower + Vector3(0, 9.0, 0), Vector3(6, 22, 6), Color(0.9, 0.88, 0.82), 0.1)
	_cone(st, tower + Vector3(0, 20.0, 0), 13.0, 4.2, 4, Color(0.25, 0.27, 0.3), 0.1 + PI / 4.0)
	# the fish quay: a warehouse and sheds along the water, and the ice plant
	for i in 5:
		var qx := HARBOUR_X - 160.0 + i * 70.0
		if qx > FRONT_X.x and qx < FRONT_X.y:
			continue           # (sea/harbour.gd's, up close)
		var q := Vector3(qx, land_h(qx, 18.0), shore_z(qx) + 18.0) - anchor
		var big := i == 2
		var sz := Vector3(40, 10, 22) if big else Vector3(22, 7, 14)
		_box(st, q + Vector3(0, sz.y * 0.5 - 2.0, 0), sz + Vector3(0, 4, 0),
				Color(0.62, 0.66, 0.68) if big else Color(0.82, 0.78, 0.7), 0.0)
		_roof(st, q + Vector3(0, sz.y, 0), sz.x + 1.0, sz.z + 1.0, 3.0, Color(0.38, 0.42, 0.46), PI * 0.5)
		_window_light(q + Vector3(0, 4.0, -sz.z * 0.5 - 0.3), 2.0, Color(1.0, 0.9, 0.7))


## The harbour's two arms of piled rock, a light at each end (green to starboard coming in, red to port).
func _breakwaters(st: SurfaceTool, anchor: Vector3, node: Node3D) -> void:
	for arm: Array in breakwater_arms():
		var side := signf((arm[1] as Vector2).x - HARBOUR_X)
		var root := Vector3((arm[0] as Vector2).x, 0.0, (arm[0] as Vector2).y)
		var tip := Vector3((arm[1] as Vector2).x, 0.0, (arm[1] as Vector2).y)
		var dir := tip - root
		var len := dir.length()
		var across := dir.normalized().cross(Vector3.UP)
		var steps := int(len / 4.5)
		var salt := int(side * 3.0 + 3.0) * 1000
		for i in steps + 1:
			var p := root + dir * (float(i) / steps)
			# the mound: big blocks tumbled down both faces into the water, smaller ones heaped along the crest, the
			# odd one standing proud; dark and weedy low down, paler and dry up top
			for k in 6:
				var h := _hash(salt + i * 31 + k * 7)
				var off := (float(k) - 2.5) / 2.5          # -1 .. 1 across the mound
				var s := lerpf(2.4, 4.6, _hash(salt + i * 17 + k * 3))
				var top := lerpf(4.6, 0.3, absf(off)) + 1.4 * h
				var c := p - anchor + across * off * 7.0 + dir.normalized() * (h - 0.5) * 3.0
				var rock := Color(0.55, 0.53, 0.5).lerp(Color(0.4, 0.39, 0.37), _hash(salt + i * 5 + k))
				if top < 1.2:
					rock = rock.lerp(Color(0.18, 0.22, 0.17), 0.6)
				_box(st, c + Vector3(0, top - s * 0.5, 0), Vector3(s, s * 0.8, s * 1.1), rock, h * 3.0)
		# the light at its end: a little white tower, its lamp
		var t := tip - anchor
		_cyl(st, t + Vector3(0, 3.0, 0), 7.0, 1.4, 1.1, 8, Color(0.92, 0.92, 0.9))
		_cyl(st, t + Vector3(0, 10.0, 0), 1.2, 1.5, 1.5, 8, Color(0.12, 0.45, 0.2) if side > 0.0 else Color(0.7, 0.14, 0.12))
		var lamp := _light(node, t + Vector3(0, 11.8, 0), 1.0,
				Color(0.3, 1.0, 0.45) if side > 0.0 else Color(1.0, 0.25, 0.2))
		_night_lights.append(lamp)


## The lighthouse on the headland: a tapering tower, banded red and white, its gallery and lantern, the keeper's
## cottage. At night its beam goes round.
func _lighthouse(st: SurfaceTool, anchor: Vector3, node: Node3D) -> void:
	var x := LIGHTHOUSE_X
	var d := 45.0
	var base := Vector3(x, land_h(x, d), shore_z(x) + d) - anchor
	var tall := 42.0
	var bands := 7
	for i in bands:
		var y0 := tall * i / bands
		var y1 := tall * (i + 1) / bands
		var r0 := lerpf(4.2, 2.8, y0 / tall)
		var r1 := lerpf(4.2, 2.8, y1 / tall)
		_cyl(st, base + Vector3(0, y0 - (3.0 if i == 0 else 0.0), 0), y1 - y0 + (3.0 if i == 0 else 0.0), r0, r1, 12,
				Color(0.95, 0.95, 0.93) if i % 2 == 0 else Color(0.75, 0.13, 0.11))
	_cyl(st, base + Vector3(0, tall, 0), 0.6, 4.0, 4.0, 12, Color(0.15, 0.15, 0.16))           # the gallery
	_cyl(st, base + Vector3(0, tall + 0.6, 0), 3.6, 2.2, 2.2, 10, Color(0.75, 0.72, 0.55))     # the glass
	_cone(st, base + Vector3(0, tall + 4.2, 0), 3.0, 2.6, 10, Color(0.15, 0.15, 0.16), 0.0)    # the cap
	# the keeper's cottage and its wall
	var k := base + Vector3(-12.0, 0.0, 6.0)
	_box(st, k + Vector3(0, 1.5, 0), Vector3(9, 7, 14), Color(0.94, 0.94, 0.92), 0.3)
	_roof(st, k + Vector3(0, 5.0, 0), 10, 15, 3.0, Color(0.25, 0.27, 0.3), 0.3)
	_lamp = _light(node, base + Vector3(0, tall + 2.4, 0), 3.0, Color(1.0, 0.92, 0.7))
	# the beam: two long soft cones turning round the lamp
	_beam = Node3D.new()
	_beam.position = base + Vector3(0, tall + 2.4, 0)
	node.add_child(_beam)
	for side: float in [0.0, PI]:
		var m := ShaderMaterial.new()
		m.shader = _beam_shader()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.6
		cone.bottom_radius = 16.0
		cone.height = 500.0
		cone.radial_segments = 12
		cone.cap_top = false
		cone.cap_bottom = false
		cone.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# (the cylinder's along y: lay it along x, its narrow end at the lamp)
		mi.transform = Transform3D(Basis(Vector3(0, 0, 1), -PI / 2.0).rotated(Vector3.UP, side), Vector3.ZERO)
		mi.translate_object_local(Vector3(0, -250.0, 0))
		_beam.add_child(mi)
		_beam_mats.append(m)


func _beam_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float glow = 0.0;
varying float along;
void vertex() { along = UV.y; }
void fragment() {
	// bright at the lamp, fading out along the beam, softer at its edges
	float edge = pow(abs(dot(NORMAL, VIEW)), 1.5);
	ALBEDO = vec3(1.0, 0.93, 0.75) * glow * edge * pow(1.0 - along, 3.0) * 0.12;
}
"""
	return s


# ---- the rig ---------------------------------------------------------------------------------------------------

## A production platform: four legs, a two-deck topside crammed with modules, the drilling derrick, the helideck
## out on a corner, a crane, the flare boom with its flame burning day and night, lights all over after dark.
func _build_rig() -> void:
	var node := Node3D.new()
	node.name = "Rig"
	add_child(node)
	var st := _st()
	var leg := Color(0.82, 0.62, 0.18)
	var steel := Color(0.45, 0.47, 0.5)
	for lx: float in [-18.0, 18.0]:
		for lz: float in [-14.0, 14.0]:
			_cyl(st, Vector3(lx, -20.0, lz), 46.0, 3.2, 2.6, 10, leg)
			_box(st, Vector3(lx, 1.5, lz), Vector3(7.5, 3.0, 7.5), Color(0.25, 0.25, 0.27), 0.0)   # (the splash zone)
	# the bracing between the legs
	for lz: float in [-14.0, 14.0]:
		_strut(st, Vector3(-18, 6, lz), Vector3(18, 20, lz), 0.9, leg)
		_strut(st, Vector3(-18, 20, lz), Vector3(18, 6, lz), 0.9, leg)
	for lx: float in [-18.0, 18.0]:
		_strut(st, Vector3(lx, 6, -14), Vector3(lx, 20, 14), 0.9, leg)
	# the decks
	_box(st, Vector3(0, 24.0, 0), Vector3(56, 3.0, 44), steel, 0.0)
	_box(st, Vector3(0, 32.0, 0), Vector3(54, 2.0, 42), steel, 0.0)
	# the modules
	var mods := [[Vector3(-14, 28.5, -10), Vector3(22, 6, 16), Color(0.9, 0.9, 0.88)],
			[Vector3(12, 28.5, -8), Vector3(24, 6, 22), Color(0.28, 0.42, 0.62)],
			[Vector3(-10, 28.5, 12), Vector3(30, 6, 14), Color(0.82, 0.8, 0.74)],
			[Vector3(16, 37.0, 12), Vector3(16, 8, 14), Color(0.92, 0.92, 0.9)],
			[Vector3(-18, 36.0, -6), Vector3(14, 6, 24), Color(0.85, 0.38, 0.18)]]
	for m: Array in mods:
		_box(st, m[0], m[1], m[2], 0.0)
	# the derrick: a tapering lattice tower
	var dbase := Vector3(4.0, 33.0, -4.0)
	var dh := 52.0
	var corners := [Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)]
	for i in 4:
		var c0: Vector2 = corners[i]
		var c1: Vector2 = corners[(i + 1) % 4]
		var bot0 := dbase + Vector3(c0.x, 0, c0.y)
		var top0 := dbase + Vector3(c0.x * 0.25, dh, c0.y * 0.25)
		var bot1 := dbase + Vector3(c1.x, 0, c1.y)
		var top1 := dbase + Vector3(c1.x * 0.25, dh, c1.y * 0.25)
		_strut(st, bot0, top0, 0.45, Color(0.85, 0.2, 0.15))
		for k in 5:
			var f0 := float(k) / 5.0
			var f1 := float(k + 1) / 5.0
			_strut(st, bot0.lerp(top0, f0), bot1.lerp(top1, f1), 0.22, Color(0.9, 0.9, 0.88))
			_strut(st, bot0.lerp(top0, f1), bot1.lerp(top1, f1), 0.22, Color(0.85, 0.2, 0.15))
	_box(st, dbase + Vector3(0, dh + 1.0, 0), Vector3(4, 2, 4), Color(0.85, 0.2, 0.15), 0.0)
	# the helideck, out over the corner on its legs
	var heli := Vector3(-26.0, 41.0, 20.0)
	_cyl(st, heli, 1.0, 13.0, 13.0, 8, Color(0.22, 0.42, 0.3))
	_cyl(st, heli + Vector3(0, 1.0, 0), 0.05, 4.0, 4.0, 8, Color(0.9, 0.85, 0.3))
	_strut(st, heli + Vector3(6, 0, -6), Vector3(-14, 33, 10), 0.6, steel)
	_strut(st, heli + Vector3(-6, 0, -8), Vector3(-22, 33, 6), 0.6, steel)
	# the crane
	_cyl(st, Vector3(20, 33, -16), 10.0, 1.6, 1.4, 8, Color(0.92, 0.75, 0.15))
	_strut(st, Vector3(20, 42, -16), Vector3(46, 56, -30), 0.7, Color(0.92, 0.75, 0.15))
	# the flare boom, out the other side, angled up, the flame on its end
	var boom0 := Vector3(26, 34, 8)
	var boom1 := Vector3(78, 70, 26)
	_strut(st, boom0, boom1, 1.1, Color(0.6, 0.6, 0.62))
	_strut(st, boom0 + Vector3(0, -6, 4), boom1, 0.6, Color(0.6, 0.6, 0.62))
	var geo: Array = [_finish(st, node, false)]
	_flare = _light(node, boom1 + Vector3(2, 6, 1), 16.0, Color(1.0, 0.55, 0.15))
	_flare.set_instance_shader_parameter("glow", 1.6)
	geo.append(_flare)
	# lights round the decks after dark, a red one on top of the derrick
	for i in 10:
		var a := TAU * i / 10.0
		var l := _light(node, Vector3(cos(a) * 28.0, 26.0 + 8.0 * (i % 2), sin(a) * 22.0), 1.6, Color(1.0, 0.9, 0.7))
		_night_lights.append(l)
		geo.append(l)
	var top := _light(node, dbase + Vector3(0, dh + 2.5, 0), 1.6, Color(1.0, 0.2, 0.15))
	geo.append(top)
	for c in node.get_children():
		if c is GeometryInstance3D and not geo.has(c):
			geo.append(c)
	_far.append({"node": node, "anchor": Vector3(RIG.x, 0.0, RIG.y), "geo": geo, "scale": RIG_SCALE})


# ---- the buoys -------------------------------------------------------------------------------------------------

## The fairway buoy off the harbour, the channel in (red to port, green to starboard coming in), a cardinal on the
## shoal off the headland, the weather buoy offshore. Each rides the swell where it's moored, and blinks after dark.
func _build_buoys() -> void:
	var red := Color(0.78, 0.14, 0.12)
	var green := Color(0.12, 0.5, 0.25)
	var mouth := shore_z(HARBOUR_X) - 210.0
	_buoy("fairway", Vector2(HARBOUR_X, mouth - 1500.0), [Color(0.82, 0.12, 0.1), Color(0.96, 0.96, 0.94)],
			Color(1, 1, 1), [10.0, 1.0, 0.0])
	for i in 3:
		var z := mouth - 300.0 - i * 400.0
		# (coming in heading +z: port is +x, starboard -x)
		_buoy("can", Vector2(HARBOUR_X + 70.0, z), [red], Color(1.0, 0.2, 0.15), [4.0, 0.6, i * 1.3])
		_buoy("cone", Vector2(HARBOUR_X - 70.0, z), [green], Color(0.25, 1.0, 0.4), [4.0, 0.6, i * 1.3 + 2.0])
	_buoy("cardinal", Vector2(LIGHTHOUSE_X + 120.0, shore_z(LIGHTHOUSE_X) - 600.0),
			[Color(0.1, 0.1, 0.1), Color(0.95, 0.8, 0.15)], Color(1, 1, 1), [5.0, 0.3, 0.0])
	_buoy("weather", Vector2(1500.0, -1700.0), [Color(0.95, 0.8, 0.15)], Color(1.0, 0.85, 0.2), [20.0, 1.0, 0.0])


func _buoy(kind: String, at: Vector2, cols: Array, lamp_col: Color, blink: Array) -> void:
	var node := Node3D.new()
	node.name = "Buoy_" + kind
	add_child(node)
	var st := _st()
	var top := 4.0
	match kind:
		"fairway":
			# a pillar buoy, red and white stripes, a red ball on top
			_cyl(st, Vector3(0, -1.0, 0), 2.0, 1.6, 1.7, 10, Color(0.2, 0.2, 0.22))
			for i in 4:
				_cyl(st, Vector3(0, 1.0 + i * 0.9, 0), 0.9, 1.0 - i * 0.12, 0.88 - i * 0.12, 8, cols[i % 2])
			_cyl(st, Vector3(0, 4.6, 0), 0.6, 0.45, 0.45, 8, cols[0])
			top = 5.4
		"can":
			_cyl(st, Vector3(0, -0.8, 0), 3.2, 1.0, 1.0, 10, cols[0])
			_cyl(st, Vector3(0, 2.4, 0), 1.2, 0.25, 0.25, 6, Color(0.3, 0.3, 0.3))
			top = 3.8
		"cone":
			_cyl(st, Vector3(0, -0.8, 0), 1.6, 1.0, 1.0, 10, cols[0])
			_cone(st, Vector3(0, 0.8, 0), 2.0, 1.0, 10, cols[0], 0.0)
			top = 3.2
		"cardinal":
			_cyl(st, Vector3(0, -1.0, 0), 2.2, 1.3, 1.2, 8, cols[0])
			_cyl(st, Vector3(0, 1.2, 0), 2.0, 0.9, 0.7, 8, cols[1])
			_cone(st, Vector3(0, 3.4, 0), 0.8, 0.6, 8, cols[0], 0.0)
			_cone(st, Vector3(0, 4.4, 0), 0.8, 0.6, 8, cols[0], 0.0)
			top = 5.4
		"weather":
			# a big yellow disc with a mast, its instruments and a solar panel
			_cyl(st, Vector3(0, -0.6, 0), 1.4, 2.6, 2.6, 12, cols[0])
			_cyl(st, Vector3(0, 0.8, 0), 0.5, 1.4, 1.0, 10, cols[0])
			_strut(st, Vector3(0, 1.3, 0), Vector3(0, 6.0, 0), 0.12, Color(0.8, 0.8, 0.8))
			_box(st, Vector3(0.4, 3.5, 0), Vector3(0.05, 1.0, 1.4), Color(0.15, 0.2, 0.35), 0.0)
			_box(st, Vector3(0, 5.6, 0), Vector3(1.2, 0.08, 0.08), Color(0.8, 0.8, 0.8), 0.0)
			top = 6.3
	_finish(st, node, true, _near_mat)
	var lamp := _light(node, Vector3(0, top, 0), 0.6, lamp_col)
	_buoys.append({"node": node, "at": at, "lamp": lamp, "blink": blink})


func _ride_buoys() -> void:
	var cam := get_viewport().get_camera_3d()
	for b in _buoys:
		var node: Node3D = b["node"]
		var at: Vector2 = b["at"]
		var far := cam.global_position.distance_to(Vector3(at.x, 0.0, at.y)) if cam else 0.0
		node.visible = far < 2600.0
		if not node.visible:
			continue
		var p := Vector3(at.x, 0.0, at.y)
		var y := 0.0
		var tilt := Basis.IDENTITY
		if ocean != null and ocean.has_method("height_at"):
			y = float(ocean.call("height_at", p))
			var dx := float(ocean.call("height_at", p + Vector3(1.5, 0, 0))) - float(ocean.call("height_at", p - Vector3(1.5, 0, 0)))
			var dz := float(ocean.call("height_at", p + Vector3(0, 0, 1.5))) - float(ocean.call("height_at", p - Vector3(0, 0, 1.5)))
			var up := Vector3(-dx / 3.0, 1.0, -dz / 3.0).normalized().lerp(Vector3.UP, 0.4).normalized()
			tilt = Basis(Quaternion(Vector3.UP, up))
		node.global_transform = Transform3D(tilt, Vector3(p.x, y, p.z))
		var bl: Array = b["blink"]
		var on := fmod(_t + float(bl[2]), float(bl[0])) < float(bl[1])
		(b["lamp"] as MeshInstance3D).visible = lights_on and on


## The lighthouse's beam goes round every 12 s; the lamp flares as the beam sweeps past you.
func _turn_light() -> void:
	if _beam == null:
		return
	var a := fmod(_t, 12.0) / 12.0 * TAU
	_beam.rotation = Vector3(0.0, a, 0.0)
	# (the beam shows in the dark and in thick weather, not at dawn's first lamps-on)
	var glow := smoothstep(0.55, 0.9, night) if lights_on else 0.0
	for m in _beam_mats:
		m.set_shader_parameter("glow", glow)
	if _lamp:
		var cam := get_viewport().get_camera_3d()
		var flash := 0.0
		if cam:
			var to := cam.global_position - _lamp.global_position
			var face := absf(Vector2(cos(a), -sin(a)).dot(Vector2(to.x, to.z).normalized()))
			flash = pow(face, 30.0)
		_lamp.visible = lights_on
		_lamp.set_instance_shader_parameter("glow", 0.4 + 3.0 * flash)


# ---- building ---------------------------------------------------------------------------------------------------

func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)    # (no smoothing: flat facets)
	return st


func _finish(st: SurfaceTool, parent: Node3D, shadows: bool, mat: Material = null) -> MeshInstance3D:
	if mat != null:
		st.generate_normals()      # (flat: every triangle has its own corners)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat if mat != null else _land_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A glowing dot (landmark_light.gdshader).
func _light(parent: Node3D, at: Vector3, size: float, col: Color) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _light_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 200.0
	mi.position = at
	parent.add_child(mi)
	mi.set_instance_shader_parameter("tint", col)
	mi.set_instance_shader_parameter("size", size)
	mi.set_instance_shader_parameter("glow", 1.0)
	return mi


func _window_light(at: Vector3, size: float, col: Color) -> void:
	# (the town's lights: added to the coast piece the town's in, after it's made)
	_pending_windows.append([at, size, col])


var _pending_windows: Array = []


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
	var shade := [1.0, 0.92, 0.85, 0.95]
	_quad(st, p[2], p[3], p[7], p[6], col)                          # top
	_quad(st, p[0], p[1], p[3], p[2], col * shade[1])               # -z
	_quad(st, p[4], p[6], p[7], p[5], col * shade[1])               # +z
	_quad(st, p[0], p[2], p[6], p[4], col * shade[2])               # -x
	_quad(st, p[1], p[5], p[7], p[3], col * shade[2])               # +x
	_quad(st, p[0], p[4], p[5], p[1], col * 0.6)                    # bottom


## A pitched roof on a w x l footprint (its ridge along l), `rise` m up.
func _roof(st: SurfaceTool, c: Vector3, w: float, l: float, rise: float, col: Color, yaw: float) -> void:
	var hw := w * 0.5
	var hl := l * 0.5
	var a := [Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl), Vector3(hw, 0, hl), Vector3(-hw, 0, hl),
			Vector3(0, rise, -hl), Vector3(0, rise, hl)]
	var p := []
	for v: Vector3 in a:
		p.append(c + v.rotated(Vector3.UP, yaw))
	_quad(st, p[0], p[4], p[5], p[3], col)
	_quad(st, p[1], p[2], p[5], p[4], col * 0.85)
	_tri(st, p[0], p[1], p[4], col * 0.75)
	_tri(st, p[3], p[5], p[2], col * 0.75)


## An upright cylinder (or a tapering one), `n` sided, from `base` up `h` m.
func _cyl(st: SurfaceTool, base: Vector3, h: float, r0: float, r1: float, n: int, col: Color) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var b0 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var b1 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var t0 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var t1 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		var shade := 0.82 + 0.18 * cos(a0 - 0.8)
		_quad(st, b0, b1, t1, t0, col * shade)
		_tri(st, base + Vector3(0, h, 0), t0, t1, col)


func _cone(st: SurfaceTool, base: Vector3, h: float, r: float, n: int, col: Color, turn: float) -> void:
	for i in n:
		var a0 := TAU * i / n + turn
		var a1 := TAU * (i + 1) / n + turn
		_tri(st, base + Vector3(cos(a0) * r, 0, sin(a0) * r), base + Vector3(cos(a1) * r, 0, sin(a1) * r),
				base + Vector3(0, h, 0), col * (0.8 + 0.2 * cos(a0 - 0.8)))


## A square beam from a to b, `t` m thick.
func _strut(st: SurfaceTool, a: Vector3, b: Vector3, t: float, col: Color) -> void:
	var d := (b - a).normalized()
	var side := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized() * t * 0.5
	var up := side.cross(d).normalized() * t * 0.5
	var c := [side + up, -side + up, -side - up, side - up]
	for i in 4:
		var c0: Vector3 = c[i]
		var c1: Vector3 = c[(i + 1) % 4]
		_quad(st, a + c0, a + c1, b + c1, b + c0, col * (0.8 + 0.2 * (i % 2)))


func _bell(x: float, w: float) -> float:
	return exp(-(x * x) / (2.0 * w * w))


## Smooth noise along a line, -1..1 (a fixed seed: every peer's the same).
func _noise(x: float, seed_value: int) -> float:
	var i := floorf(x)
	var f := x - i
	var u := f * f * (3.0 - 2.0 * f)
	return lerpf(_hash(int(i) * 7919 + seed_value * 104729), _hash(int(i + 1.0) * 7919 + seed_value * 104729), u) * 2.0 - 1.0


func _hash(n: int) -> float:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x & 0xffff) / 65535.0
