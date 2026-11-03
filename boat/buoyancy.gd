extends RefCounted
## How she floats (boat/boat.gd's pose): a body with mass, heaving, pitching and rolling on the water under her, not a
## plane laid on the swell. Her waterplane is cut into cells (STATIONS along her, ACROSS her beam, each as wide as her
## hull is there, sea/ocean.gdshader's half_of); each cell is pushed up by the water over it (Archimedes: rho g times
## its area times how deep it's in), nothing once it's out of the water, no more once the sea's at her rail (then
## it's coming aboard: boat/green_water.gd). The pushes and her weight heave her, and their moments about her middle
## pitch and roll her, against her mass and inertia and the water's she drags with her (added mass), damped by the
## water she pushes about (each cell resisting the water rising or falling past it). So she rides up the face of a
## swell, hangs on its crest and drops off the back with a little lag and overshoot, as a hull does; her bow lifts
## clear and slams down in a steep sea; and since nothing holds her up but water, she's never left hanging over air.
## Her course, her speed and where she is (the helm, the water's orbits carrying her) are boat.gd's: this is only her
## heave, pitch and roll.
##
## Every peer works this out for itself, the same: it steps on a fixed grid of the shared wave clock (every DT s of
## ocean.gd's wave_time, whatever the frame rate), from the same sea (a pure function of that clock) under the same
## hull (the helm's word, synced), and what's drawn is between the last two steps. A body this damped forgets how it
## started within a few seconds, so a peer that joins late, or whose clock was nudged, or whose helm is a hair
## different, settles onto the same motion as everyone else; nothing needs sending.

const DT := 1.0 / 30.0
const RHO := 1025.0
const G := 9.81
## Her waterplane's cells: stations along her and across her.
const STATIONS := 7
const ACROSS := 3
## Each kind's hull: `draft` (m, of a flat-bottomed hull with her waterplane and her weight: how deep her weight
## puts her, so how fast she heaves, about 2.8 s the sportfisher, 1.7 the skiff), how long a roll takes her (s, her
## stability: a beamy sportfisher rolls slow and easy, a skiff quick and snappy), how damped she is (a share of
## critical: heave, pitch, roll; roll least), and her sheer (her rail's cap over her origin aft, and how much more it
## rises to her stem: art/*.py).
const HULLS := {
	"skiff": {"draft": 0.42, "roll": 3.0, "zeta": Vector3(0.35, 0.38, 0.28), "sheer": Vector2(1.15, 0.55)},
	"sportfisher": {"draft": 1.1, "roll": 4.6, "zeta": Vector3(0.35, 0.38, 0.2), "sheer": Vector2(1.45, 0.95)},
}
## The water she drags with her, a share of her own mass (heave), and of her inertia (pitch, roll).
const ADDED := Vector3(0.9, 0.9, 0.25)
## Her radii of gyration: pitch, a share of her length; roll, of her beam.
const GYRATION := Vector2(0.26, 0.38)
## The wave clock jumping more than this (s), or her moving further than this (m) in one go (moored, put somewhere by
## a test): she starts afresh, sitting on the water where she is.
const JUMP_T := 2.0
const JUMP_AT := 15.0
## How far she may pitch and roll (rad): a steep sea never throws her past it.
const MAX_TILT := 0.6
## How fast the water can rise or fall past a cell, for its damping (m/s).
const RATE_MAX := 5.0

var ocean: Node                # sea/ocean.gd
var length := 14.0
var beam := 4.8
var sink := 0.12
var draft := 1.1
var sheer := Vector2(1.45, 0.95)
## The cells: x, z (boat-local, at her origin's height), area (m^2), how deep it's in when the sea's at her rail (m).
var cells := PackedVector4Array()
var mass := 1.0
var _dry := Vector3.ONE       # heave, pitch, roll: her own mass and inertia
var _inertia := Vector3.ONE   # (and with the water she drags with her, afloat)
var _area := 1.0              # her waterplane (m^2)
var _damp := Vector3.ZERO     # per m^2 of cell (and per m^2 m^2 for the moments), from the damping ratios
var _bg := 0.0                # (her weight high over her buoyancy: what's left of the waterplane's roll stiffness)
var _zc := 0.0                # (her middle along her, where her weight is: the waterplane's, fuller aft than forward)

## Her state at wave time _t (y of her origin, its rate; pitch, its rate; roll, its rate), and a step before (_s0):
## drawn between the two.
var _t := NAN
var _s0 := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
var _s1 := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
## Each cell's depth in at _t (before it's clamped to her bottom and her rail): how fast the water's rising past it.
var _imm := PackedFloat64Array()
## Where she was (x, z; heading) at the last two times she was asked: each step's cells are placed along it.
var _track := [NAN, Vector2.ZERO, 0.0, NAN, Vector2.ZERO, 0.0]
## How far the sea's over her rail at the last step (m, the worst cell; below it, negative): green water's measure.
var over_rail := -1.0


## Her hull, from her kind (boat/kinds.gd's spec and HULLS): the cells, her mass and inertia, her damping.
func configure(kind: String, spec: Dictionary) -> void:
	var hull: Dictionary = HULLS.get(kind, HULLS["sportfisher"])
	length = float(spec["length"])
	beam = float(spec["beam"])
	sink = float(spec["sink"])
	draft = float(hull["draft"])
	sheer = hull["sheer"]
	cells.clear()
	var area := 0.0
	var az := 0.0
	var xx := 0.0
	var dz := length / STATIONS
	for j in STATIONS:
		var z := -length * 0.5 + (j + 0.5) * dz
		var half := half_beam(z)
		var w := 2.0 * half / ACROSS
		for a in ACROSS:
			var x := -half + (a + 0.5) * w
			var ar := w * dz
			cells.append(Vector4(x, z, ar, draft - sink + sheer_at(z)))
			area += ar
			az += ar * z
			xx += ar * x * x
	# (her weight's over the middle of her waterplane, so she floats level: her moments are about it)
	_zc = az / area
	var zz := 0.0
	for c in cells:
		zz += c.z * (c.y - _zc) * (c.y - _zc)
	mass = RHO * area * draft
	_area = area
	var zeta: Vector3 = hull["zeta"]
	_dry = Vector3(mass, mass * pow(GYRATION.x * length, 2.0), mass * pow(GYRATION.y * beam, 2.0))
	_inertia = _dry * (Vector3.ONE + ADDED)
	# (roll: the waterplane's stiffness less what her weight up high takes off it, leaving her roll period)
	var roll_k := _inertia.z * pow(TAU / float(hull["roll"]), 2.0)
	_bg = maxf(RHO * G * xx - roll_k, 0.0) / (mass * G)
	var heave_k := RHO * G * area
	var pitch_k := RHO * G * zz
	_damp = Vector3(2.0 * zeta.x * sqrt(heave_k * _inertia.x) / area,
			2.0 * zeta.y * sqrt(pitch_k * _inertia.y) / zz,
			2.0 * zeta.z * sqrt(roll_k * _inertia.z) / xx)
	_imm.resize(cells.size())
	_t = NAN


## Her half beam at her rail at z along her (bow toward -z): sea/ocean.gdshader's half_of, the same hull.
func half_beam(z: float) -> float:
	var b := beam / 4.3
	var u := (length * 0.5 - z) / length
	if u < 0.0 or u > 1.0:
		return 0.02
	if u < 0.3:
		return b * (1.98 + 0.17 * smoothstep(0.0, 0.3, u))
	if u < 0.55:
		return b * 2.15
	var t := (u - 0.55) / 0.45
	return maxf(b * (0.07 + 2.08 * pow(maxf(0.0, 1.0 - pow(t, 2.2)), 0.55)), 0.02)


## Her rail's cap over her origin at z along her (m): ocean.gdshader's sheer_of, the same line.
func sheer_at(z: float) -> float:
	var u := clampf((length * 0.5 - z) / length, 0.0, 1.0)
	return sheer.x + sheer.y * pow(smoothstep(0.5, 1.0, u), 1.4)


## Start afresh: next time she's asked, she's set down on the water where she is, still.
func reset() -> void:
	_t = NAN


## Her heave, pitch and roll at wave time `now` (her origin's world y, rad, rad), with her at `mid` (world x, z)
## heading `yaw` (round +Y, her bow toward -Z turned by it): stepped on from where she was to now.
func at(now: float, mid: Vector2, yaw: float) -> Vector3:
	if ocean == null or cells.is_empty():
		return Vector3(-sink, 0.0, 0.0)
	var jumped := is_nan(_t) or absf(now - _t) > JUMP_T or is_nan(float(_track[3])) \
			or (_track[4] as Vector2).distance_to(mid) > JUMP_AT
	if not jumped and now != float(_track[3]):
		_track = [_track[3], _track[4], _track[5], now, mid, yaw]
	elif jumped:
		_track = [now - DT, mid, yaw, now, mid, yaw]
		_settle(now)
	while _t < now:
		_step()
	# (and if the sea under her was somewhere else entirely when she started, metres off where it is now: the sea's
	# mesh hadn't come along with her yet, a test put her there, she's set down on it afresh)
	if not jumped:
		var m := 0.0
		for d in _imm:
			m += d
		m /= maxf(_imm.size(), 1)
		if m > draft + 4.0 or m < -3.0:
			_settle(now)
			while _t < now:
				_step()
	var a := clampf((now - (_t - DT)) / DT, 0.0, 1.0)
	# (on the sea as it's drawn, curving away from the middle of its mesh: her motion's worked out on it flat)
	var curve := float(ocean.call("curve_at", Vector3(mid.x, 0.0, mid.y)))
	return Vector3(lerpf(_s0[0], _s1[0], a) - curve, lerpf(_s0[2], _s1[2], a), lerpf(_s0[4], _s1[4], a))


## Where she is (x, z) and her heading at wave time `t`, along her track (a step past it, carried on).
func _where(t: float) -> Array:
	var t0 := float(_track[0])
	var t1 := float(_track[3])
	var f := clampf((t - t0) / (t1 - t0), 0.0, 2.0) if t1 > t0 else 1.0
	return [(_track[1] as Vector2).lerp(_track[4], f), lerp_angle(float(_track[2]), float(_track[5]), f)]


## Each cell's world point (x, y, z) for her at `mid` heading `yaw`, origin at height y, pitched and rolled.
func _cell_basis(yaw: float, pitch: float, roll: float) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis.from_euler(Vector3(pitch, 0.0, roll))


## How deep each cell's in (m, unclamped) for her in state s at wave time t.
func _depths(s: PackedFloat64Array, t: float) -> PackedFloat64Array:
	var w := _where(t)
	var mid: Vector2 = w[0]
	var b := _cell_basis(float(w[1]), s[2], s[4])
	var origin := Vector3(mid.x, s[0], mid.y)
	var ahead := t - float(ocean.get("wave_time"))
	var out := PackedFloat64Array()
	out.resize(cells.size())
	for i in cells.size():
		var c := cells[i]
		var p := origin + b * Vector3(c.x, 0.0, c.y)
		out[i] = _flat(Vector3(p.x, 0.0, p.z), ahead) - p.y + draft - sink
	return out


## The sea's height at world point p, `ahead` s from now, flat (the curve away to the horizon left out: it moves with
## the sea's mesh, not with the water).
func _flat(p: Vector3, ahead: float) -> float:
	return float(ocean.call("height_at", p, ahead)) + float(ocean.call("curve_at", p))


## Set down on the water at `now`, still: a plane through the water under her cells, her waterline on it.
func _settle(now: float) -> void:
	_t = floorf(now / DT) * DT
	var w := _where(_t)
	var mid: Vector2 = w[0]
	var turn := Basis(Vector3.UP, float(w[1]))
	var ahead := _t - float(ocean.get("wave_time"))
	var hs := PackedFloat64Array()
	var a := 0.0
	var hm := 0.0
	for c in cells:
		var p := turn * Vector3(c.x, 0.0, c.y)
		var h := _flat(Vector3(mid.x + p.x, 0.0, mid.y + p.z), ahead)
		hs.append(h)
		a += c.z
		hm += c.z * h
	hm /= a
	# (the plane's slopes along her, about her middle, and across her: least squares)
	var sz := 0.0
	var sx := 0.0
	var zz := 0.0
	var xx := 0.0
	for i in cells.size():
		var c := cells[i]
		sz += c.z * (c.y - _zc) * (hs[i] - hm)
		sx += c.z * c.x * (hs[i] - hm)
		zz += c.z * (c.y - _zc) * (c.y - _zc)
		xx += c.z * c.x * c.x
	var slope := sz / zz
	_s1 = PackedFloat64Array([hm - slope * _zc - sink, 0.0, atan(-slope), 0.0, atan(sx / xx), 0.0])
	_s0 = _s1.duplicate()
	_imm = _depths(_s1, _t)


## One step on: the water's pushes on her at _t, her state carried DT on by them (semi-implicit Euler).
func _step() -> void:
	var s := _s1
	var depth := _depths(s, _t)
	var lift := 0.0
	var pitch_m := 0.0
	var roll_m := 0.0
	var dh := 0.0
	var dp := 0.0
	var dr := 0.0
	var worst := -INF
	var wet := 0.0
	for i in cells.size():
		var c := cells[i]
		var d := depth[i]
		worst = maxf(worst, d - c.w)
		if d <= 0.0:
			continue
		# (pushed up by the water over it, no more once the sea's at her rail; and the water rising past it drags it)
		var f := RHO * G * c.z * minf(d, c.w)
		# (from where it was, or from the surface if it was out: a cell coming back in from a metre up isn't hitting
		# the water at 30 m/s)
		var rate := clampf((d - maxf(_imm[i], 0.0)) / DT, -RATE_MAX, RATE_MAX)
		wet += c.z * minf(d / draft, 1.0)
		lift += f
		pitch_m -= (c.y - _zc) * f
		roll_m += c.x * f
		dh += c.z * rate
		dp -= c.z * (c.y - _zc) * rate
		dr += c.z * c.x * rate
	over_rail = worst
	_imm = depth
	# (the water she drags with her only as much as she's in it: off the top of a crest she falls as freely as she
	# would, not slowed by water that isn't there)
	var k := Vector3.ONE + ADDED * clampf(wet / _area, 0.0, 1.0)
	var ay := (lift + _damp.x * dh - mass * G) / (_dry.x * k.x)
	var ap := (pitch_m + _damp.y * dp) / (_dry.y * k.y)
	var ar := (roll_m + _damp.z * dr + mass * G * _bg * sin(s[4])) / (_dry.z * k.z)
	var n := s.duplicate()
	n[1] += ay * DT
	n[0] += n[1] * DT
	for j: int in [2, 4]:
		n[j + 1] += (ap if j == 2 else ar) * DT
		n[j] += n[j + 1] * DT
		# (never thrown past MAX_TILT: stopped there, not bounced off it)
		if absf(n[j]) > MAX_TILT:
			n[j] = signf(n[j]) * MAX_TILT
			n[j + 1] = 0.0
	_s0 = s
	_s1 = n
	_t += DT
