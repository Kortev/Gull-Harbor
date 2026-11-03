extends Node
## She floats (boat/buoyancy.gd): out at sea in the weather given, stopped or under way, for a few minutes of it, how
## high the water ever stands over her rail right beside her (her sheer, all the way round, and a hand outboard of
## it), and how much of her bottom is ever out of the water (hanging over air); her heave, pitch and roll (riding the
## swell, not frozen and not thrown about); and that her motion is the sea clock's alone: worked out again at a
## third of the frame rate, and again from a standing start partway through, it's the same.
## Run: godot --headless --fixed-fps 30 --path . res://tests/float_test.tscn -- --kind=sportfisher --cond=storm
##   --speed=0..1 (the throttle)  --secs=N (default 180)  --full (also the whole GPU sea's height beside her, the
##   swell and chop tiles' every wave, not only height_at's: what was drawn there before she floated on the same sea)
## Passes when the water's never over her rail beside her by more than a splash (GREEN m: a sea coming aboard, and
## then boat/green_water.gd showed it), at most GREEN_SHARE of the time; never more than AIR of her length out of the
## water at once; and the re-worked motions agree.

const Sea := preload("res://sea/sea.gd")
const Buoyancy := preload("res://boat/buoyancy.gd")
const Spectrum := preload("res://sea/ocean_spectrum.gd")
const Ocean := preload("res://sea/ocean.gd")
const GREEN := 0.45
const GREEN_SHARE := 0.03
const AIR := 0.6

var sea: Sea
var kind := "sportfisher"
var cond := "storm"
var speed := 0.0
var secs := 180.0
var full := false
var trace := false
var _rail: Array[Vector3] = []
var _keel: Array[Vector3] = []
var _t0 := 0.0
var _frames := 0
var _over_frames := 0
var _worst := -INF
var _full_worst := -INF
var _full_over := 0
var _full_n := 0
var _air_worst := 0.0
var _air_frames := 0
var _heave := PackedFloat64Array()
var _pitch_max := 0.0
var _roll_max := 0.0
var _slow: Buoyancy
var _late: Buoyancy
var _slow_diff := 0.0
var _late_diff := 0.0
var _residual: Array = []      # [kx, kz, amplitude, omega, phase, swell?] the waves height_at leaves out
var _bursts0 := 0
var _plane_worst := -INF
var _plane_over := 0
var _plane_full_worst := -INF
var _plane_full_over := 0
var _plane_air := 0.0
var _slow_sum := 0.0
var _slow_n := 0
var _plane_tilt := Vector2.ZERO
var _far_worst := -INF


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		full = full or a == "--full"
		trace = trace or a == "--trace"
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"kind": kind = kv[1]
			"cond": cond = kv[1]
			"speed": speed = float(kv[1])
			"secs": secs = float(kv[1])
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_float_test.cfg"
	await get_tree().create_timer(0.5).timeout
	sea.fish_hold.head_out(kind)
	sea.set_condition(cond)
	sea.crew.me.force_input = true
	var helm: Node = sea.boat.get("helm")
	helm.set("at", Vector2(0.0, -900.0))
	helm.set("heading", 0.4)
	await get_tree().create_timer(0.5).timeout
	if speed > 0.0:
		helm.call("request", true)
		await get_tree().create_timer(0.5).timeout
		Input.action_press("move_forward", speed)
	var fl: Buoyancy = sea.boat.get("floating")
	# her rail (her sheer over her topsides, all the way round) and a hand outboard of it; her bottom along her middle
	var hl := fl.length * 0.5
	var z := -hl + 0.3
	while z < hl:
		for s: float in [-1.0, 1.0]:
			_rail.append(Vector3(s * fl.half_beam(z), fl.sheer_at(z), z))
		_keel.append(Vector3(0.0, -0.5 * fl.draft - fl.sink, z))
		z += 0.5
	var hb := fl.half_beam(hl - 0.05)
	for i in 7:
		_rail.append(Vector3(lerpf(-hb, hb, i / 6.0), fl.sheer_at(hl), hl))
	if full:
		_tail_waves()
	await get_tree().create_timer(6.0).timeout
	_slow = Buoyancy.new()
	_slow.ocean = sea.ocean
	_slow.configure(kind, sea.boat.get("spec"))
	_bursts0 = int(sea.boat.get("green").get("bursts"))
	_t0 = float(sea.ocean.wave_time)
	get_tree().process_frame.connect(_tick)


## The swell and chop tiles' waves height_at leaves out (each tile's biggest up to a thousand: all but a sliver of it),
## scaled as ocean.gd scales the ones it keeps.
func _tail_waves() -> void:
	var o: Node = sea.ocean
	var spec := Spectrum.new(Ocean.SEA_SEED, o.get("wind"), PackedInt32Array([1000, 1000, 0]))
	var waves: Array = o.get("_waves")
	var nbig: int = (o.get("_big") as Array).size()
	var keep := [Ocean.SWELL_N, Ocean.CHOP_N]
	var first := [nbig, nbig + Ocean.SWELL_N]
	for c in 2:
		var top: Array = spec.biggest[c]
		var hs := float(waves[first[c]][3]) / float(top[0][0])
		for i in range(keep[c], top.size()):
			var w: Array = top[i]
			var kv := Vector2(float(w[1]), float(w[2]))
			var k := kv.length()
			var wv := Ocean._wave(TAU / k, float(w[0]) * hs, atan2(-kv.y, -kv.x), PI * 0.5 - float(w[3]))
			_residual.append([wv[2] * wv[0], wv[2] * wv[1], wv[3], wv[4], wv[5], 1.0 if c == 0 else 0.0])


func _tail_at(p: Vector3) -> float:
	var o: Node = sea.ocean
	var t := float(o.wave_time)
	var mods: Vector3 = o.call("_mods", Vector2(p.x, p.z), t, o.get("_group_drift"))
	var y := 0.0
	for w: Array in _residual:
		var a := float(w[2]) * (mods.y if float(w[5]) > 0.5 else mods.x)
		y += a * sin(float(w[0]) * p.x + float(w[1]) * p.z - float(w[3]) * t + float(w[4]))
	return y


func _tick() -> void:
	var o: Node = sea.ocean
	var now := float(o.wave_time)
	var b: Node3D = sea.boat
	var xf := b.global_transform
	_frames += 1
	# the water a hand outboard of her rail, against her rail's height
	var over := -INF
	var at := Vector3.ZERO
	for r in _rail:
		var out := Vector3(signf(r.x) * 0.3, 0.0, 0.3 if absf(r.z - _rail[-1].z) < 0.01 else 0.0)
		var p := xf * (r + out)
		var top := xf * r
		var o_h := float(o.call("height_at", p)) - top.y
		if o_h > over:
			over = o_h
			at = p
	if over > 0.0:
		_over_frames += 1
	_worst = maxf(_worst, over)
	# (and a stride further out, 1.5 m off her side)
	for i in range(0, _rail.size(), 3):
		var r := _rail[i]
		var p := xf * (r + Vector3(signf(r.x) * 1.5, 0.0, 0.0))
		_far_worst = maxf(_far_worst, float(o.call("height_at", p)) - (xf * r).y)
	if full and _frames % 3 == 0:
		var fo := -INF
		for i in range(0, _rail.size(), 2):
			var r := _rail[i]
			var p := xf * (r + Vector3(signf(r.x) * 0.3, 0.0, 0.0))
			fo = maxf(fo, float(o.call("height_at", p)) + _tail_at(p) - (xf * r).y)
		_full_n += 1
		if fo > 0.0:
			_full_over += 1
		_full_worst = maxf(_full_worst, fo)
	# and how she'd have sat before she floated: a plane laid on the water under her (boat.gd's pose until 2026-11-02)
	var was := _plane(b)
	var we := was.basis.get_euler()
	_plane_tilt = _plane_tilt.max(Vector2(absf(we.x), absf(we.z)))
	var wo := -INF
	var wfo := -INF
	for i in _rail.size():
		var r := _rail[i]
		var p := was * (r + Vector3(signf(r.x) * 0.3, 0.0, 0.0))
		var h := float(o.call("height_at", p))
		wo = maxf(wo, h - (was * r).y)
		if full and _frames % 3 == 0 and i % 2 == 0:
			wfo = maxf(wfo, h + _tail_at(p) - (was * r).y)
	_plane_worst = maxf(_plane_worst, wo)
	if wo > 0.0:
		_plane_over += 1
	if full and _frames % 3 == 0:
		_plane_full_worst = maxf(_plane_full_worst, wfo)
		if wfo > 0.0:
			_plane_full_over += 1
		var pd := 0
		for k in _keel:
			var p := was * k
			if float(o.call("height_at", p)) + _tail_at(p) < p.y:
				pd += 1
		_plane_air = maxf(_plane_air, float(pd) / _keel.size())
	# her bottom along her middle: how much of her length is out of the water
	var dry := 0
	for k in _keel:
		var p := xf * k
		if float(o.call("height_at", p)) < p.y:
			dry += 1
	var air := float(dry) / _keel.size()
	_air_worst = maxf(_air_worst, air)
	if air > 0.5:
		_air_frames += 1
	var e := xf.basis.get_euler()
	if trace and _frames % 10 == 0:
		print("TRACE t %.2f y %+.2f water %+.2f pitch %+.1f roll %+.1f (plane %+.1f %+.1f) dry %.0f%%" % [now - _t0,
				xf.origin.y, float(o.call("height_at", xf.origin)), rad_to_deg(e.x), rad_to_deg(e.z), rad_to_deg(we.x),
				rad_to_deg(we.z), air * 100.0])
	_heave.append(xf.origin.y)
	_pitch_max = maxf(_pitch_max, absf(e.x))
	_roll_max = maxf(_roll_max, absf(e.z))
	# the same motion worked out at a third of the frame rate, and from a standing start 40 s in
	var helm: Node = b.get("helm")
	var mid := Vector2(xf.origin.x, xf.origin.z)
	var yaw := float(helm.get("heading")) + float(b.get("carried_yaw"))
	var mine: Vector3 = b.get("floating").call("at", now, mid, yaw)
	if _frames % 3 == 0:
		var s := _slow.at(now, mid, yaw)
		if now - _t0 > 20.0:
			var g := _gap(s, mine)
			_slow_diff = maxf(_slow_diff, g)
			_slow_sum += g
			_slow_n += 1
	if now - _t0 > 40.0:
		if _late == null:
			_late = Buoyancy.new()
			_late.ocean = o
			_late.configure(kind, b.get("spec"))
		var l := _late.at(now, mid, yaw)
		if now - _t0 > 55.0:
			_late_diff = maxf(_late_diff, _gap(l, mine))
	if now - _t0 >= secs:
		_report()


## The old pose: a plane fitted to the water under her, five stations along and three across (kinds' pitch_follow and
## roll_follow of its slopes), her waterline on it, her bow lifted under way.
func _plane(b: Node3D) -> Transform3D:
	var o: Node = sea.ocean
	var spec: Dictionary = b.get("spec")
	var helm: Node = b.get("helm")
	var xf := b.global_transform
	var mid := Vector3(xf.origin.x, 0.0, xf.origin.z)
	var turn := Basis(Vector3.UP, float(helm.get("heading")) + float(b.get("carried_yaw")))
	var length := float(spec["length"])
	var beam := float(spec["beam"])
	var sum := 0.0
	var sx := 0.0
	var sz := 0.0
	var xx := 0.0
	var zz := 0.0
	for i in 5:
		var z := (i - 2) * length * 0.2
		for j in 3:
			var x := (j - 1) * beam * 0.4
			var h := float(o.call("height_at", mid + turn * Vector3(x, 0.0, z)))
			sum += h
			sx += x * h
			sz += z * h
			xx += x * x
			zz += z * z
	var y := sum / 15.0 - float(spec["sink"])
	var pitch := atan(-sz / zz) * float(spec["pitch_follow"])
	var roll := atan(sx / xx) * float(spec["roll_follow"])
	var ahead := clampf(float(helm.get("speed")) / float(helm.get("ahead")), 0.0, 1.0)
	pitch += 0.07 * smoothstep(0.0, 0.6, ahead)
	return Transform3D(turn * Basis.from_euler(Vector3(pitch, 0.0, roll)), Vector3(mid.x, y, mid.z))


func _gap(a: Vector3, b: Vector3) -> float:
	return maxf(absf(a.x - b.x), maxf(absf(a.y - b.y), absf(a.z - b.z)) * 5.0)


func _report() -> void:
	get_tree().process_frame.disconnect(_tick)
	Input.action_release("move_forward")
	var m := 0.0
	for h in _heave:
		m += h
	m /= _heave.size()
	var v := 0.0
	for h in _heave:
		v += (h - m) * (h - m)
	var heave_hs := 4.0 * sqrt(v / _heave.size())
	var share := float(_over_frames) / _frames
	var bursts := int(sea.boat.get("green").get("bursts")) - _bursts0
	var helm: Node = sea.boat.get("helm")
	print("FLOAT %s %s %.1f m/s, %d s (%d frames)" % [kind, cond, float(helm.get("speed")), int(secs), _frames])
	print("FLOAT water over her rail beside her: worst %+.2f m, over it %.1f%% of the time (green water came aboard %d times)"
			% [_worst, share * 100.0, bursts])
	if full:
		print("FLOAT  the whole GPU sea there (every wave of the swell and chop tiles): worst %+.2f m, over it %.1f%% of the time"
				% [_full_worst, 100.0 * _full_over / maxf(_full_n, 1)])
	print("FLOAT (before she floated, a plane laid on the water: worst %+.2f m, over %.1f%% of the time)"
			% [_plane_worst, 100.0 * _plane_over / _frames])
	if full:
		print("FLOAT (  and on the whole GPU sea drawn round her then: worst %+.2f m, over %.1f%% of the time; her bottom out of it, at worst %.0f%% of her length)"
				% [_plane_full_worst, 100.0 * _plane_full_over / maxf(_full_n, 1), _plane_air * 100.0])
	print("FLOAT her bottom out of the water: at worst %.0f%% of her length, over half of it %.1f%% of the time"
			% [_air_worst * 100.0, 100.0 * _air_frames / _frames])
	print("FLOAT 1.5 m off her side, the sea against her rail's height: worst %+.2f m (drawn taken down to her sheer)"
			% _far_worst)
	print("FLOAT riding: heave %.2f m (4 sd), pitch to %.1f deg, roll to %.1f deg (the plane: pitch to %.1f, roll to %.1f)"
			% [heave_hs, rad_to_deg(_pitch_max), rad_to_deg(_roll_max), rad_to_deg(_plane_tilt.x),
			rad_to_deg(_plane_tilt.y)])
	var mean := _slow_sum / maxf(_slow_n, 1)
	print("FLOAT the same motion at a third of the frame rate: within %.3f on average, %.3f at worst; from a standing start, 15 s on: within %.3f (m, and rad x5)"
			% [mean, _slow_diff, _late_diff])
	var ok := _worst < GREEN and share < GREEN_SHARE and _air_worst < AIR and mean < 0.01 and _slow_diff < 0.3 \
			and _late_diff < 0.3
	if _worst > 0.1 and bursts == 0:
		ok = false
	print("FLOAT TEST " + ("PASSED" if ok else "FAILED"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit(0 if ok else 1)
