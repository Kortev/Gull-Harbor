extends Node
## The radar on every boat, made honest, and the chart plotter beside it. The skiff carries a radar (a screen on her
## console, a bar on her T-top) and a plotter. A flock with its birds up paints a tight return in the same spot sweep
## after sweep; the sea clutter close in boils (different every sweep) and grows with the sea; rain lays clutter out
## across the screen that a sunny day doesn't. The plotter draws her track as she goes and marks a flock where it was
## picked out.
## Run: godot --headless --path . res://tests/radar_test.tscn

const Sea := preload("res://sea/sea.gd")
const Radar := preload("res://tuna/radar.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	sea.set_condition("sunny")
	sea.boat.use_kind("skiff")
	await get_tree().process_frame
	_check(_screen(sea.boat, "radar_scope"), "the skiff has a radar screen on her dash")
	_check(_screen(sea.boat, "plotter"), "and a chart plotter beside it")
	_check(sea.boat.get("_radar") != null, "and a radar bar going round on her T-top")
	sea.fish_hold.head_out()
	await get_tree().process_frame
	var helm: Node = sea.boat.helm
	helm.set("at", Vector2.ZERO)
	helm.set("heading", 0.0)
	helm.set("speed", 0.0)
	var radar: Radar = sea.get_node("Radar")
	# a flock 900 m off her starboard bow, birds up and working, staying put
	sea.schools.call("_host_start")
	var s: Node = sea.schools.schools[sea.schools.schools.size() - 1]
	var t: float = sea.schools.now()
	s.set("start", Vector2(500.0, -750.0))
	s.set("t0", t)
	s.set("speed", 0.3)
	s.set("life", 1e6)
	var k := 0
	while sea.schools.call("hash1", float(int(s.get("seed")) % 1000), float(k)) <= 0.38:
		k += 1
	s.set("born", t - k * 40.0 - 1.0)
	_check(bool(s.call("feeding", t)), "the flock's birds are up")
	# a sweep to settle, then three more: the flock paints every time, and the clutter close in doesn't hold
	await _sweeps(radar, 1)
	# (in a fair sea: a rough one covers so much of the screen that cells stay lit three sweeps running by chance)
	sea.set_condition("sunny")
	var steady := 0
	var near_px: Array = []
	for i in 3:
		await _sweeps(radar, 1)
		var c: Vector2 = s.call("center", sea.schools.now())
		if radar.painted(c, 1) > 0.5:
			steady += 1
		near_px.append(_lit_near(radar))
	_check(steady == 3, "the flock paints a strong return, sweep after sweep (%d of 3)" % steady)
	var same := 0
	var all := 0
	for i in near_px[0].size():
		all += 1
		if near_px[1][i] == near_px[0][i] and near_px[2][i] == near_px[0][i] and near_px[0][i]:
			same += 1
	var lit0 := (near_px[0] as Array).count(true)
	# (steady returns in the same band, a buoy or a raft of gulls, stay lit by right: only most of it has to boil)
	_check(lit0 > 0 and same < lit0 * 0.7, "the sea clutter close in boils: %d lit, %d the same three sweeps running"
			% [lit0, same])
	var calm_close := radar.cover(80.0, 400.0)
	var sunny_far := radar.cover(500.0, 1900.0)
	# a storm: more clutter close in, and rain clutter out across the screen
	sea.set_condition("storm")
	await _sweeps(radar, 2)
	var storm_close := radar.cover(80.0, 400.0)
	_check(storm_close > calm_close * 1.5 and storm_close > 0.1,
			"sea clutter grows with the sea (%.2f sunny, %.2f storm, 80-400 m)" % [calm_close, storm_close])
	sea.set_condition("rain")
	await _sweeps(radar, 2)
	var rain_far := radar.cover(500.0, 1900.0)
	_check(rain_far > sunny_far + 0.02, "rain clutter out across the screen (%.3f sunny, %.3f rain, 0.5-1.9 km)"
			% [sunny_far, rain_far])
	var c2: Vector2 = s.call("center", sea.schools.now())
	_check(radar.painted(c2, 1) > 0.3, "and the flock still shows through it")
	# the plotter: her track as she goes, and the flock picked out
	var plotter: Node = sea.get_node("Plotter")
	var before := (plotter.get("track") as PackedVector2Array).size()
	for i in 12:
		helm.set("at", Vector2(0.0, -30.0 * (i + 1)))
		await get_tree().process_frame
		await get_tree().process_frame
	var after := (plotter.get("track") as PackedVector2Array).size()
	_check(after >= before + 10, "the plotter lays down her track (%d -> %d points)" % [before, after])
	plotter.call("saw", s)
	var marks: Dictionary = plotter.get("marks")
	_check(marks.has(int(s.get("id"))) and (marks[int(s.get("id"))][0] as Vector2).distance_to(c2) < 50.0,
			"a flock picked out is marked where it was")
	_check(int(plotter.get("drawn")) > 0, "the plotter's drawing its chart")
	_done()


## Whether a screen called `what` on her dash has its picture on it.
func _screen(boat: Node, what: String) -> bool:
	for mi: Node in boat.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(i)
			if sm and sm.resource_name == what and m.get_surface_override_material(i) != null:
				return true
	return false


## Which pixels are lit in the ring 60-300 m out.
func _lit_near(radar: Radar) -> Array:
	var out := []
	var r: PackedFloat32Array = radar.get("_px_r")
	var v: PackedFloat32Array = radar.get("_val")
	for i in r.size():
		if r[i] > 60.0 and r[i] < 300.0:
			out.append(v[i] >= 0.08)
	return out


func _sweeps(radar: Radar, n: int) -> void:
	await get_tree().create_timer(TAU / Radar.SWEEP * n + 0.1).timeout


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("RADAR TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
