extends Node
## The radar at the helm (every boat's: the screen called radar_scope on her dash, boat/kinds.gd), made honest: it
## paints what a small boat's radar would, and reading it is a skill. Heading up, RANGE m to the edge, rings every
## RING m, the sweep going round with the bar on her roof; each patch of screen keeps what the sweep painted there
## till it comes round again.
##
## What paints:
##   - birds in the air over a flock: a tight return, the same every sweep, drifting slowly as the flock travels
##     (gulls over little bait paint exactly like tuna birds: you still have to go and look, crew/spotter.gd);
##   - birds rafted on the water: a weak return that comes and goes;
##   - the odd gull raft with no school under it at all, and the buoys (steady, and they don't drift);
##   - the land, the breakwaters and the rig: solid;
##   - sea clutter: a ring of speckle close round her, wider and thicker the rougher the sea, different every sweep;
##   - rain clutter: smears of speckle in rain, heavy and storm, drifting down the wind, and the rain dims what's
##     behind it.
## So a flock is the return that holds from sweep to sweep while the speckle round it boils. Far off (past NEAR_FLOCK)
## it's small and dim, the same green as the clutter, and it doesn't paint every sweep: the tell is that it's still
## there, in the same place, sweep after sweep, where the clutter never is. Closer in it firms up, yellow, then orange.
## It leaves a faint trail back along where it's been (TRAIL, the way a radar's target trails show), so you can see
## which way it's going and get out ahead of it. Reading it is a skill, not luck. Everything comes
## from the sea's shared state (the sea clock, its weather, the synced schools, fixed landmarks) and a hash, never
## randf: every peer's screen paints the same.

const Landmarks := preload("res://sea/landmarks.gd")

const S := 128
## Metres to the screen's edge, and the range rings' spacing.
const RANGE := 2000.0
const RING := 500.0
## The sweep (rad/s): boat.gd spins the bar at the same rate.
const SWEEP := 2.6
## Angular slices of the screen the sweep repaints as it passes.
const BINS := 256
## Birds in the air (m across the return), birds on the water, a buoy.
const FLOCK_R := 55.0
const RAFT_R := 30.0
const BUOY_R := 12.0
## False gull rafts: one in this share of the CELL m squares round her, drifting.
const CELL := 700.0
const FALSE_RAFTS := 0.14
## A flock's trail: where it was every TRAIL_STEP s back, this many of them, fading.
const TRAIL := 6
const TRAIL_STEP := 25.0
## A flock paints full strength inside NEAR_FLOCK m; out at the screen's edge it's FAR_FLOCK as strong, and paints
## that share of sweeps (FAR_SEEN), and smaller.
const NEAR_FLOCK := 600.0
const FAR_FLOCK := 0.28
const FAR_SEEN := 0.65
## The clutter, sea and rain, never paints brighter than this (a dim green): only a real return goes yellow and red.
const CLUTTER_MAX := 0.3

const BG := Color(0.01, 0.025, 0.04)
const WEAK := Color(0.1, 0.42, 0.22)
const MID := Color(0.98, 0.86, 0.22)
const STRONG := Color(1.0, 0.36, 0.12)

var schools: Node            # tuna/schools.gd
var boat: Node3D             # boat/boat.gd
var _img: Image
var _echo: Image
var _tex: ImageTexture
var _in := 0.0
## Each pixel inside the scope: its slice, its range (m) and bearing from the bow (rad, clockwise).
var _bins: Array[PackedInt32Array] = []
var _px_r := PackedFloat32Array()
var _px_a := PackedFloat32Array()
var _rings := PackedInt32Array()
## Where the sweep had got to when last painted (rad, unwound).
var _swept := -1.0
var _targets: Array = []
## How strong each pixel last painted (0 nothing .. 1 land).
var _val := PackedFloat32Array()


func _init() -> void:
	for b in BINS:
		_bins.append(PackedInt32Array())
	_px_r.resize(S * S)
	_px_a.resize(S * S)
	_val.resize(S * S)
	var mid := Vector2(S, S) * 0.5
	var px_m := RANGE / (S * 0.5 - 1.0)
	for y in S:
		for x in S:
			var d := Vector2(x + 0.5, y + 0.5) - mid
			var r := d.length() * px_m
			var a := fposmod(atan2(d.x, -d.y), TAU)
			_px_r[y * S + x] = r
			_px_a[y * S + x] = a
			if r <= RANGE:
				_bins[mini(int(a / TAU * BINS), BINS - 1)].append(y * S + x)
			var ring := fposmod(r + px_m * 0.5, RING) < px_m and r > RING * 0.5 and r <= RANGE + px_m
			if ring:
				_rings.append(y * S + x)


func attach(to: Node3D) -> void:
	boat = to
	_img = Image.create(S, S, false, Image.FORMAT_RGB8)
	_img.fill(BG)
	_echo = Image.create(S, S, false, Image.FORMAT_RGB8)
	_echo.fill(BG)
	_swept = -1.0
	_val.fill(0.0)
	_tex = ImageTexture.create_from_image(_img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _tex
	mat.emission_enabled = true
	mat.emission_texture = _tex
	mat.emission_energy_multiplier = 1.4
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi: Node in to.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(i)
			if sm and sm.resource_name == "radar_scope":
				m.set_surface_override_material(i, mat)


func _process(delta: float) -> void:
	if _img == null or schools == null or boat == null:
		return
	var t := float(schools.call("now"))
	var total := t * SWEEP
	if _swept < 0.0 or total < _swept or total - _swept > TAU:
		_swept = total        # (a blank screen, painted in as the sweep goes round)
	if total - _swept >= TAU / BINS:
		_gather(t)
		var b0 := int(floorf(_swept / TAU * BINS))
		var b1 := int(floorf(total / TAU * BINS))
		for b in range(b0, b1):
			_paint(posmod(b, BINS), b / BINS, t)
		_swept = float(b1) * TAU / BINS
	_in -= delta
	if _in > 0.0:
		return
	_in = 0.05
	_compose(fposmod(total, TAU))


## What's out there this sweep: [where (world x, z), how wide (m), how strong, how often it paints (0..1)].
func _gather(t: float) -> void:
	_targets.clear()
	var at := _at()
	var sea: Node = schools.get("sea")
	for s: Node in schools.get("schools"):
		var c: Vector2 = s.call("center", t)
		if c.distance_to(at) > RANGE + 100.0:
			continue
		var going := float(s.call("scattering", t))
		var down = s.get("spooked_until")
		var flying := bool(s.call("feeding", t)) or going > 0.0 or (down != null and t < float(down))
		var id := int(s.get("id"))
		if flying:
			# far off: dim, small, there most sweeps; firming up as she closes
			var far := smoothstep(NEAR_FLOCK, RANGE, c.distance_to(at))
			var strong := lerpf(0.9, FAR_FLOCK, far) * (1.0 - going * 0.8)
			_targets.append([c, FLOCK_R * lerpf(1.0, 0.6, far) * (1.0 + going * 2.0), strong, lerpf(1.0, FAR_SEEN, far), id])
			# its trail, back along where it's been, fainter still
			for k in range(1, TRAIL + 1):
				var was: Vector2 = s.call("center", t - k * TRAIL_STEP)
				_targets.append([was, FLOCK_R * 0.4, (0.2 * (1.0 - float(k) / (TRAIL + 1)) + 0.1) * lerpf(1.0, 0.6, far),
						lerpf(1.0, FAR_SEEN, far), id])
		else:
			_targets.append([c, RAFT_R, 0.36, 0.4, id])
	# gull rafts with nothing under them, drifting a little
	var c0 := Vector2(floorf(at.x / CELL), floorf(at.y / CELL))
	for i in range(-3, 4):
		for j in range(-3, 4):
			var cell := c0 + Vector2(i, j)
			if _hash(cell.x, cell.y, 1.0) > FALSE_RAFTS:
				continue
			var p := (cell + Vector2(_hash(cell.x, cell.y, 2.0), _hash(cell.x, cell.y, 3.0))) * CELL
			p += Vector2(sin(t * 0.004 + cell.x), cos(t * 0.003 + cell.y)) * 60.0
			if p.distance_to(at) < RANGE + 50.0:
				_targets.append([p, RAFT_R, 0.36, 0.4, int(cell.x * 7919.0 + cell.y)])
	var marks: Node = sea.get("landmarks") if sea else null
	if marks != null:
		for bu: Dictionary in marks.get("_buoys"):
			_targets.append([bu["at"], BUOY_R, 0.62, 0.9, -1])
		_targets.append([Landmarks.RIG, 70.0, 1.0, 1.0, -2])
	# in VS, the other boat
	var vs: Node = sea.get("vs") if sea else null
	if vs != null and bool(vs.get("on")):
		for side: Object in vs.get("sides"):
			var other: Node = side.get("boat")
			if other != null and other != boat:
				_targets.append([other.get("helm").get("at"), 14.0, 0.95, 1.0, -3])


## Repaint one slice of the screen, as the sweep crosses it.
func _paint(b: int, rev: int, t: float) -> void:
	var helm: Node = boat.get("helm")
	var h := float(helm.get("heading"))
	var at := _at()
	var fwd := Vector2(-sin(h), -cos(h))
	var right := Vector2(cos(h), -sin(h))
	var ocean: Node = schools.call("ocean")
	var sea_state := float(ocean.get("weather"))
	var rain := float(ocean.get("rain"))
	var wind: Vector2 = ocean.get("wind")
	var marks: Node = (schools.get("sea") as Node).get("landmarks")
	var arms: Array = marks.call("breakwater_arms") if marks != null else []
	# sea clutter: out this far, this thick
	var reach := 90.0 + 650.0 * sea_state
	var thick := 0.08 + 0.6 * sea_state
	var drift := wind.normalized() * t * (4.0 + 10.0 * sea_state)
	var px_m := RANGE / (S * 0.5 - 1.0)
	for i in _bins[b]:
		var r := _px_r[i]
		var a := _px_a[i]
		var p := at + (right * sin(a) + fwd * cos(a)) * r
		var gx := floorf(p.x / px_m)
		var gz := floorf(p.y / px_m)
		var v := 0.0
		# the sea's own speckle, close in: new every sweep
		if r > px_m * 1.5:
			var sc := thick * exp(-r / reach)
			var n := _hash(gx, gz, rev * 1.37)
			if n < sc:
				v = minf(0.12 + 0.4 * sc * _hash(gz, gx, rev * 0.71), CLUTTER_MAX)
		# rain: patches drifting down the wind, speckled inside, and dimming what's beyond
		var dim := 1.0
		if rain > 0.02:
			var q := (p - drift) / (260.0 + 300.0 * rain)
			var cloud := _noise(q.x, q.y) * 0.7 + _noise(q.x * 2.3 + 5.0, q.y * 2.3) * 0.3
			var patch := smoothstep(1.0 - 0.45 * rain, 1.08 - 0.35 * rain, cloud)
			if patch > 0.0 and _hash(gx, gz, rev * 2.11 + 9.0) < 0.2 + 0.45 * patch:
				v = maxf(v, minf((0.12 + 0.33 * rain) * patch * (0.6 + 0.4 * _hash(gx, gz, 4.0 + rev)), CLUTTER_MAX))
			dim = 1.0 - 0.45 * rain * r / RANGE
		# the land and the breakwaters, solid (the first few hundred metres in: the hills behind are in its shadow)
		if marks != null:
			var in_from := p.y - float(marks.call("shore_z", p.x))
			if in_from > 0.0:
				v = maxf(v, 0.95 if in_from < 450.0 else 0.4 * _hash(gx, gz, 7.0))
			for arm: Array in arms:
				if Geometry2D.get_closest_point_to_segment(p, arm[0], arm[1]).distance_to(p) < 14.0 + px_m * 0.5:
					v = maxf(v, 0.95)
		# the targets
		for tg: Array in _targets:
			var wide := maxf(float(tg[1]), px_m * 0.75)
			if p.distance_to(tg[0]) < wide and _hash(float(tg[4]), rev, 5.0) < float(tg[3]):
				v = maxf(v, float(tg[2]) * (0.92 + 0.08 * _hash(gx, gz, rev)) * dim)
		_val[i] = v
		_echo.set_pixel(i % S, i / S, _shade(v))


## The screen: what the sweep left, the rings, her heading line, the sweep itself, her in the middle.
func _compose(sweep: float) -> void:
	_img.copy_from(_echo)
	for i in _rings:
		if _val[i] < 0.08:
			_img.set_pixel(i % S, i / S, Color(0.2, 0.46, 0.38))
	var mid := Vector2(S, S) * 0.5
	for j in range(3, int(S * 0.5) - 1, 3):
		_dot(mid + Vector2(0, -j), Color(0.55, 0.62, 0.6))
	for k in 6:
		var a := sweep - k * 0.035
		var c := Color(0.55, 1.0, 0.65).lerp(Color(0.05, 0.2, 0.12), k / 6.0)
		for j in range(2, int(S * 0.5) - 1):
			var p := mid + Vector2(sin(a), -cos(a)) * j
			if k == 0 or _val[clampi(int(p.y), 0, S - 1) * S + clampi(int(p.x), 0, S - 1)] < 0.08:
				_dot(p, c)
	for d: Vector2 in [Vector2.ZERO, Vector2(-1, 0), Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 1), Vector2(0, 1)]:
		_dot(mid + d, Color(1, 1, 1))
	_tex.update(_img)


static func _shade(v: float) -> Color:
	if v < 0.08:
		return BG
	if v < 0.45:
		return WEAK.lerp(MID, (v - 0.08) / 0.37)
	return MID.lerp(STRONG, clampf((v - 0.45) / 0.45, 0.0, 1.0))


func _at() -> Vector2:
	return boat.get("helm").get("at")


## How strong the screen paints a world point now (0 nothing .. 1 land): the brightest pixel within `px` of it (tests).
func painted(p: Vector2, px := 1) -> float:
	var helm: Node = boat.get("helm")
	var h := float(helm.get("heading"))
	var rel := p - _at()
	var fwd := Vector2(-sin(h), -cos(h))
	var right := Vector2(cos(h), -sin(h))
	var scale := (S * 0.5 - 1.0) / RANGE
	var c := Vector2(S, S) * 0.5 + Vector2(rel.dot(right), -rel.dot(fwd)) * scale
	var best := 0.0
	for dx in range(-px, px + 1):
		for dy in range(-px, px + 1):
			var x := int(c.x) + dx
			var y := int(c.y) + dy
			if x >= 0 and y >= 0 and x < S and y < S:
				best = maxf(best, _val[y * S + x])
	return best


## Share of the scope's pixels painted at all between `r0` and `r1` m out (tests: the clutter).
func cover(r0: float, r1: float) -> float:
	var n := 0
	var lit := 0
	for i in S * S:
		if _px_r[i] >= r0 and _px_r[i] < r1:
			n += 1
			if _val[i] >= 0.08:
				lit += 1
	return float(lit) / maxf(n, 1.0)


func _dot(p: Vector2, c: Color) -> void:
	var x := int(p.x)
	var y := int(p.y)
	if x >= 0 and y >= 0 and x < S and y < S:
		_img.set_pixel(x, y, c)


static func _hash(a: float, b: float, c: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453, 1.0)


## Smooth value noise (0..1).
static func _noise(x: float, y: float) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(ix, iy, 0.5)
	var b := _hash(ix + 1.0, iy, 0.5)
	var c := _hash(ix, iy + 1.0, 0.5)
	var d := _hash(ix + 1.0, iy + 1.0, 0.5)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)
