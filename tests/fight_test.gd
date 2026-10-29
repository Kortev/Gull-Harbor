extends Node
## The fight, headless, many times over: fought right with a captain keeping the stern on it, a bluefin of any size
## comes boatside in a few minutes; alone you land the small ones but a giant swings round and chafes you off;
## just cranking breaks the big ones off; doing nothing never lands one; backing down hard whatever the fish does
## puts it in the props.
## Run: godot --headless --path . res://tests/fight_test.tscn

const Fight := preload("res://tuna/fight.gd")
const DT := 1.0 / 30.0
const TURN := 0.3        # rad/s: how fast the captain swings her (rods.gd's helm)

var fails: Array[String] = []


func _ready() -> void:
	for kg: float in [35.0, 150.0, 300.0, 450.0]:
		var landed := 0
		var alone := 0
		var times: Array[float] = []
		var ends := {}
		var ends_alone := {}
		for s in 20:
			var r := _fight(kg, s, "right", true)
			ends[r[0]] = int(ends.get(r[0], 0)) + 1
			if r[0] == "boatside":
				landed += 1
				times.append(r[1])
			var a := _fight(kg, s, "right", false)
			ends_alone[a[0]] = int(ends_alone.get(a[0], 0)) + 1
			if a[0] == "boatside":
				alone += 1
		times.sort()
		var med := times[times.size() / 2] if not times.is_empty() else 0.0
		print("FIGHT %3d kg fought right with a captain: %s, median %.0f s; alone: %s" % [kg, ends, med, ends_alone])
		_check(landed >= 18, "%d kg: fought right with a captain, it comes boatside (%d of 20)" % [kg, landed])
		_check(med > 20.0 and med < 330.0, "%d kg: a fight of a minute or a few (median %.0f s)" % [kg, med])
		if kg <= 150.0:
			_check(alone >= 14, "%d kg: alone, you land most of them (%d of 20)" % [kg, alone])
		else:
			_check(alone < landed - 3, "%d kg: alone, a giant often gets away (%d of 20 vs %d)" % [kg, alone, landed])
	var cut := 0
	for s in 20:
		if _fight(300.0, s, "right", true, true)[0] == "cut":
			cut += 1
	print("FIGHT backing down blind: %d of 20 cut by the props" % cut)
	_check(cut >= 5, "backing down hard whatever the fish does puts it in the props (%d of 20)" % cut)
	for kg: float in [150.0, 400.0]:
		var broke := 0
		var idle := {}
		for s in 20:
			if _fight(kg, s, "crank")[0] == "broke":
				broke += 1
			var r := _fight(kg, s, "idle")
			idle[r[0]] = int(idle.get(r[0], 0)) + 1
		print("FIGHT %3d kg just cranking: broke %d of 20; doing nothing: %s" % [kg, broke, idle])
		_check(broke >= 15, "%d kg: cranking against its runs breaks it off (%d of 20)" % [kg, broke])
		_check(not idle.has("boatside"), "%d kg: doing nothing never lands it" % kg)
	for f in fails:
		print("FAIL ", f)
	print("FIGHT TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


## Fights one fish with a style of angler; returns [how it ended, seconds].
## captain: someone at the wheel keeps the stern on it and backs down on it when it's astern (blind: backs down
## all the time and steers anywhere).
func _fight(kg: float, seed_value: int, style: String, captain := false, blind := false) -> Array:
	var f := Fight.new(kg, 45.0, 1.0, seed_value)
	var end := ["timeout", 0.0]
	f.lost.connect(func(why: String) -> void: end[0] = why)
	f.boatside.connect(func() -> void: end[0] = "boatside")
	var t := 0.0
	var lifting := 0.0
	while not f.done and t < 900.0:
		var crank := false
		var lift := 0.0
		match style:
			"crank":
				crank = true
			"right":
				match f.answer():
					"hold":
						crank = false
					"pump":
						# heave for a second, then crank down for a second and a half
						lifting = fmod(t, 2.5)
						lift = 1.0 if lifting < 1.0 else 0.0
						crank = lifting >= 1.0
					_:
						crank = true
		if captain:
			var b := wrapf(f.bearing, -PI, PI)
			if blind:
				f.bearing -= TURN * DT * (1.0 if fmod(t, 40.0) < 20.0 else -1.0)
				f.throttle = -1.0
			else:
				f.bearing -= clampf(b * 1.5, -1.0, 1.0) * TURN * DT
				f.throttle = -1.0 if absf(b) < 0.6 and f.line_out > 25.0 else 0.0
		f.step(DT, crank, lift)
		t += DT
	end[1] = t
	return end


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
