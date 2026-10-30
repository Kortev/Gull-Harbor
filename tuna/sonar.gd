extends Node
## The fish finder at the helm (the screen called sonar in her model): a scrolling echogram, the newest ping on the
## right, a column every tenth of a second, drawn with real type into a little viewport and shown on the dash.
## Deep blue water; the surface clutter on top; a faint speckled thermocline; the bottom a hard red line with the
## brown of the mud under it, as deep as the chart says (boat/plotter.gd's depth_at); bait as a loose green cloud;
## and tuna as arches, a fish crossing the beam reading deep at its edges and shallowest under her: red cored, at
## their depth, fainter and fewer the further off the school is. Down the right, the depth scale and the A-scope
## (the newest ping, as bars); along the top, the depth under her, the water's temperature and the range.
## Everyone paints their own from the shared schools, so everyone aboard sees the same fish, if not the same specks.

## The echogram's own picture, px (columns of history, rows of depth).
const EW := 210
const EH := 150
## The screen's picture, px.
const W := 480
const H := 288
## Where the echogram sits in it: under the top bar, left of the A-scope and the scale.
const TOP := 28
const ECHO_W := 404
const ASCOPE := 30
## The depths the range steps through (m to the bottom of the screen), picked to keep the bottom in the lower part.
const RANGES := [20.0, 30.0, 50.0, 80.0, 120.0, 200.0, 300.0]
## How far to the side a school still shows (m from the boat).
const REACH := 70.0
const BAR := Color(0.04, 0.06, 0.1)

## The fish finder's colour scale, weak to strong: water, light blue, green, yellow, orange, red, deep red.
const PALETTE := [Color(0.02, 0.07, 0.24), Color(0.12, 0.35, 0.75), Color(0.15, 0.75, 0.55), Color(0.95, 0.9, 0.2),
		Color(1.0, 0.55, 0.1), Color(0.95, 0.12, 0.08), Color(0.55, 0.05, 0.08)]

var sea: Node                # sea/sea.gd
var schools: Node            # tuna/schools.gd
## The range now (m), and the depth under her (m).
var range_m := 80.0
var bottom := 60.0
var _echo: Image
var _echo_tex: ImageTexture
var _view: SubViewport
var _screen: Node2D
var _ping := PackedFloat32Array()
## The fish going through the beam: [depth m, columns to cross it, columns in, how strong].
var _fish: Array = []
var _in := 0.0
var _col := 0


func attach(boat: Node3D) -> void:
	if _view == null:
		_echo = Image.create(EW, EH, false, Image.FORMAT_RGB8)
		_echo.fill(PALETTE[0])
		_echo_tex = ImageTexture.create_from_image(_echo)
		_ping.resize(EH)
		_view = SubViewport.new()
		_view.size = Vector2i(W, H)
		_view.disable_3d = true
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(_view)
		_screen = Node2D.new()
		_screen.draw.connect(_draw_screen)
		_view.add_child(_screen)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _view.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi: Node in boat.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(i)
			if sm and sm.resource_name == "sonar":
				m.set_surface_override_material(i, mat)


func _process(delta: float) -> void:
	if _view == null:
		return
	_in -= delta
	if _in > 0.0:
		return
	_in = 0.1
	_col += 1
	_sound()
	_echo.blit_rect(_echo, Rect2i(1, 0, EW - 1, EH), Vector2i(0, 0))
	for y in EH:
		_echo.set_pixel(EW - 1, y, _colour(_ping[y]))
	_echo_tex.update(_echo)
	_screen.queue_redraw()
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE


## One ping: how strong the echo is at each row, into _ping.
func _sound() -> void:
	var at := Vector2.ZERO
	if schools:
		at = schools.call("boat_at")
	var plotter: Node = sea.get("plotter") if sea else null
	if plotter:
		bottom = lerpf(bottom, float(plotter.call("depth_at", at)), 0.1)
	# the range: the next step down that keeps the bottom about three quarters of the way down
	for r: float in RANGES:
		if bottom < r * 0.8:
			if absf(r - range_m) > 0.1 and (bottom < range_m * 0.55 or bottom > range_m * 0.85):
				range_m = r
			break
	var row_m := range_m / EH
	# fish coming into the beam: the nearer the school, the more of them and the stronger
	if schools:
		for s: Node in schools.call("near", Vector3(at.x, 0.0, at.y), REACH):
			var c: Vector2 = s.call("center", float(schools.call("now")))
			var near := 1.0 - c.distance_to(at) / REACH
			if near <= 0.0:
				continue
			var seed_ := float(int(s.get("seed")) % 977)
			var depth := 12.0 + 30.0 * float(schools.call("hash1", seed_, 3.0)) + (1.0 - near) * 10.0
			depth = minf(depth, bottom - 4.0)
			if bool(s.get("bait_only")):
				# bait: a loose cloud, no arches
				_fish.append([depth + randf_range(-5.0, 5.0), 3, 0, -near])
			elif randf() < 0.45 * near * near + 0.05:
				_fish.append([depth + randf_range(-6.0, 6.0), randi_range(10, 18), 0, 0.45 + 0.55 * near])
	for y in EH:
		var d := (y + 0.5) * row_m
		var v := 0.0
		# the surface: wave and wake clutter, dying off in the first few metres
		v += maxf(0.0, 1.0 - d / 3.5) * randf_range(0.4, 0.9)
		# the thermocline: a faint speckled band
		if absf(d - 28.0) < 1.5 and randf() < 0.35:
			v = maxf(v, 0.22)
		# plankton and the odd speck
		if randf() < 0.01:
			v = maxf(v, randf_range(0.15, 0.35))
		# the bottom: a hard return, the mud under it fading
		var below := d - bottom
		if below >= 0.0:
			v = maxf(v, 0.95 if below < row_m * 2.5 else lerpf(0.82, 0.12, clampf(below / 16.0, 0.0, 1.0))
					* randf_range(0.85, 1.0))
		_ping[y] = v
	for f: Array in _fish:
		var u := float(f[2]) / maxf(float(f[1]) - 1.0, 1.0) * 2.0 - 1.0
		if float(f[3]) < 0.0:
			# bait: a scatter of specks round its depth
			for i in 6:
				var y := int((float(f[0]) + randf_range(-3.0, 3.0)) / row_m)
				if y >= 0 and y < EH:
					_ping[y] = maxf(_ping[y], -float(f[3]) * randf_range(0.3, 0.5))
		else:
			# a fish: deeper at the beam's edges, shallowest and strongest under her
			var fy := (float(f[0]) + u * u * 2.5) / row_m
			var strong := float(f[3]) * (1.0 - 0.55 * u * u)
			for y in range(int(fy) - 3, int(fy) + 4):
				if y >= 0 and y < EH:
					var e := strong * exp(-pow((y - fy) / 1.3, 2.0))
					_ping[y] = maxf(_ping[y], e)
		f[2] = int(f[2]) + 1
	_fish = _fish.filter(func(f: Array) -> bool: return int(f[2]) < int(f[1]))


func _colour(v: float) -> Color:
	var x := clampf(v, 0.0, 1.0) * (PALETTE.size() - 1)
	var i := mini(int(x), PALETTE.size() - 2)
	return (PALETTE[i] as Color).lerp(PALETTE[i + 1], x - i)


func _draw_screen() -> void:
	var c := _screen
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(0, 0, W, H), BAR)
	var eh := H - TOP
	c.draw_texture_rect(_echo_tex, Rect2(0, TOP, ECHO_W, eh), false)
	# the depth lines and scale, every step of the range
	var step := range_m / 4.0
	for i in range(1, 5):
		var y := TOP + eh * i / 4.0
		var dash := 0.0
		while dash < ECHO_W:
			c.draw_line(Vector2(dash, y), Vector2(dash + 3.0, y), Color(1, 1, 1, 0.22), 1.0)
			dash += 8.0
		c.draw_line(Vector2(ECHO_W + ASCOPE, y), Vector2(ECHO_W + ASCOPE + 6, y), Color(0.75, 0.8, 0.86), 1.0)
		var label := "%d" % roundi(step * i)
		c.draw_string(font, Vector2(ECHO_W + ASCOPE + 8, minf(y + 4.0, H - 3.0)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(0.85, 0.88, 0.92))
	# the A-scope: the newest ping, row by row, as bars out from the left
	c.draw_rect(Rect2(ECHO_W, TOP, ASCOPE, eh), Color(0.02, 0.04, 0.09))
	var rh := float(eh) / EH
	for y in EH:
		var v := _ping[y]
		if v > 0.08:
			c.draw_rect(Rect2(ECHO_W + 1, TOP + y * rh, (ASCOPE - 3) * clampf(v, 0.0, 1.0), rh + 0.5), _colour(v))
	c.draw_line(Vector2(ECHO_W, TOP), Vector2(ECHO_W, H), Color(0.3, 0.35, 0.42), 1.0)
	# the bar along the top: the depth under her, the water, the range
	c.draw_rect(Rect2(0, 0, W, TOP), BAR)
	c.draw_line(Vector2(0, TOP), Vector2(W, TOP), Color(0.3, 0.35, 0.42), 1.0)
	c.draw_string(font, Vector2(10, 23), "%.1f" % bottom, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1))
	var w := font.get_string_size("%.1f" % bottom, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	c.draw_string(font, Vector2(14 + w, 23), "m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.8, 0.86))
	var at: Vector2 = schools.call("boat_at") if schools else Vector2.ZERO
	var temp := 18.0 + 0.8 * sin(at.x * 0.0011) + 0.5 * sin(at.y * 0.0017)
	c.draw_string(font, Vector2(150, 19), "WATER  %.1f °C" % temp, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.8, 0.86))
	c.draw_string(font, Vector2(300, 19), "50 kHz", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.8, 0.86))
	c.draw_string(font, Vector2(W - 64, 19), "%d m" % int(range_m), HORIZONTAL_ALIGNMENT_RIGHT, 56, 12,
			Color(0.75, 0.8, 0.86))
