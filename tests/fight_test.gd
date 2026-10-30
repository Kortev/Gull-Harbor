extends Node
## The fight, headless, many times over, played by test anglers that read only the rod, the reel and the line
## (tests/fight_bot.gd). Fought well, with a captain keeping the stern on it, a bluefin of any size comes boatside in
## a minute or a few; alone it takes longer; pumping beats plain reeling; laying the rod over against its swing beats
## not; cranking through everything breaks the big ones off; doing nothing never lands one; a rod held high and
## cranking when a schoolie jumps loses it; the line rubs only where it runs over her house and bow; backing down
## blind puts it in the props.
## Run: godot --headless --path . res://tests/fight_test.tscn

const Fight := preload("res://tuna/fight.gd")
const Bot := preload("res://tests/fight_bot.gd")
const DT := 1.0 / 30.0
const TURN := 0.45       # rad/s: how fast the captain swings her (boat/helm.gd)

var fails: Array[String] = []


func _ready() -> void:
	var good_alone := {}
	for kg: float in [35.0, 150.0, 300.0]:
		var crew := _many(kg, "good", true, 20)
		var solo := _many(kg, "good", false, 20)
		good_alone[kg] = solo
		print("FIGHT %3d kg, fought well with a captain: %s, median %.0f s; alone: %s, median %.0f s"
				% [kg, crew["ends"], crew["median"], solo["ends"], solo["median"]])
		_check(int(crew["landed"]) >= 18, "%d kg: fought well with a captain, it comes boatside (%d of 20)"
				% [kg, crew["landed"]])
		_check(int(solo["landed"]) >= 15, "%d kg: alone, you land most of them (%d of 20)" % [kg, solo["landed"]])
		var lo := 25.0 if kg < 100.0 else 60.0
		var hi := 130.0 if kg < 100.0 else 360.0
		_check(float(crew["median"]) > lo and float(crew["median"]) < hi,
				"%d kg: a fight of a minute or a few (median %.0f s)" % [kg, crew["median"]])
		if kg >= 300.0:
			_check(float(solo["median"]) > float(crew["median"]),
					"%d kg: alone takes longer than with a captain (%.0f vs %.0f s)" % [kg, solo["median"], crew["median"]])
	for kg: float in [150.0, 300.0]:
		var reel := _many(kg, "reeler", false, 20)
		print("FIGHT %3d kg just reeling (no pumping): %s, median %.0f s" % [kg, reel["ends"], reel["median"]])
		_check(float(reel["median"]) >= 1.1 * float(good_alone[kg]["median"]),
				"%d kg: pumping beats just reeling (%.0f vs %.0f s)" % [kg, good_alone[kg]["median"], reel["median"]])
	var no_side := _many(300.0, "no_side", false, 20)
	print("FIGHT 300 kg never laying the rod over: %s, median %.0f s" % [no_side["ends"], no_side["median"]])
	_check(float(no_side["median"]) > float(good_alone[300.0]["median"]),
			"laying the rod over against its swing lands it sooner (%.0f vs %.0f s)"
			% [good_alone[300.0]["median"], no_side["median"]])
	for kg: float in [150.0, 300.0]:
		var c := _many(kg, "cranker", false, 20)
		print("FIGHT %3d kg cranking through everything: %s" % [kg, c["ends"]])
		_check(int(c["ends"].get("broke", 0)) >= 15, "%d kg: cranking through its runs breaks it off (%d of 20)"
				% [kg, c["ends"].get("broke", 0)])
	for kg: float in [35.0, 300.0]:
		var s := _many(kg, "statue", false, 10)
		print("FIGHT %3d kg doing nothing: %s" % [kg, s["ends"]])
		_check(not s["ends"].has("boatside"), "%d kg: doing nothing never lands it" % kg)
	var high := _many(35.0, "high_tip", false, 20)
	var lost_high := 20 - int(high["landed"])
	print("FIGHT 35 kg, rod high and cranking when it jumps: %s" % high["ends"])
	_check(lost_high >= 6, "rod high and cranking when a schoolie jumps loses it (%d of 20)" % lost_high)
	var cut := 0
	for s in 40:
		if str(_fight(300.0, s, "good", true, true)[0]) == "cut":
			cut += 1
	print("FIGHT backing down blind: %d of 40 cut by the props" % cut)
	_check(cut >= 4, "backing down hard whatever the fish does puts it in the props (%d of 40)" % cut)
	# A rod in its holder with nobody on it: the drag works the fish, it takes line on its runs, and it's still on
	# half a minute later.
	var on := 0
	var between := 0.0
	for s in 20:
		var f := Fight.new(200.0, 45.0, 1.0, s)
		f.in_holder = true
		var t := 0.0
		while not f.done and t < 30.0:
			var before := f.line_out
			f.step(DT, 0.0, 0.6, 0.0, Fight.STRIKE_DRAG)
			if f.move in ["dog", "circle", "spiral"] and f.move_t > 2.0:
				between = maxf(between, f.line_out - before)
			t += DT
		if not f.done:
			on += 1
	print("FIGHT in its holder: still on after 30 s %d of 20; most line taken off a run in a step %.3f m" % [on, between])
	_check(on >= 18, "in its holder, the fish is still on after 30 s (%d of 20)" % on)
	_check(between <= 0.05, "in its holder, it takes little line off a run (%.3f m a step)" % between)
	# A beaten fish only spirals close in.
	var spiral_out := 0.0
	for s in 20:
		spiral_out = maxf(spiral_out, float(_fight(300.0, s, "good", true)[2]))
	_check(spiral_out <= Fight.SPIRAL_IN + 0.5,
			"a beaten fish only goes into its death spiral close in (furthest %.0f m)" % spiral_out)
	# The same fish played the same way comes out the same.
	var a1 := _fight(150.0, 3, "good", true)
	var a2 := _fight(150.0, 3, "good", true)
	_check(str(a1) == str(a2), "the same fish fought the same way ends the same (%s)" % str(a1))
	# The line rubs where it runs over her house and bow, not over the open cockpit, not off your own stand
	# (the outline estimate: the headless stand-in for rods.gd's ray-cast against her hull, and the plotter).
	var hb := 2.4
	var aft := 7.3
	var house := 0.4
	var bow := -6.7
	var stand := Vector2(hb - 0.3, aft - 0.8)
	var ahead_out := Vector2(stand.x + 40.0 * sin(2.4), aft + 40.0 * cos(2.4))      # off her bow quarter, your side
	var dead_ahead := Vector2(stand.x, aft - 60.0)
	var far_side := Vector2(-40.0, 3.0)
	var astern := Vector2(0.0, aft + 60.0)
	_check(Fight.rub(stand + (ahead_out - stand).normalized(), ahead_out, hb, house, bow) == 0.0,
			"from her corner, a fish forward of the beam on your side, going away from her: no rub")
	_check(Fight.rub(stand + (dead_ahead - stand).normalized(), dead_ahead, hb, house, bow) > 0.9,
			"from her corner, a fish dead ahead: the line lies along her house and bow, it rubs")
	_check(Fight.rub(Vector2(0.0, 3.3), astern, hb, house, bow) == 0.0,
			"forward in the cockpit with the fish astern: the line's over the cockpit, no rub")
	_check(Fight.rub(stand + (far_side - stand).normalized(), far_side, hb, house, bow) == 0.0,
			"across the cockpit to the far side, aft of her house: no rub")
	var cut_across := Vector2(-20.0, -40.0)
	_check(Fight.rub(stand + (cut_across - stand).normalized(), cut_across, hb, house, bow) > 0.5,
			"across her house to the far bow: it rubs")
	# Picking a fight up where it was: the fish carries on with what it was doing, and a moment's grace.
	var mid := Fight.new(200.0, 80.0, 0.5, 7)
	var was := "circle" if mid.move != "circle" else "sound"
	mid.carry_on(was, 0.4, -1.0, 0.6)
	_check(mid.move == was and is_equal_approx(mid.stretch, 0.4) and is_equal_approx(mid.hold, 0.6)
			and mid.turn_sign() < 0.0 and mid.grace > 0.0,
			"a fight picked up mid-move carries on with it: %s, the same stretch, hook and way round" % mid.move)
	# a tangled line saws through if nobody clears it
	var tangle := Fight.new(150.0, 60.0, 0.6, 11)
	tangle.tangled = true
	var how := [""]
	tangle.lost.connect(func(why: String) -> void: how[0] = why)
	var tt := 0.0
	var mem := {}
	while not tangle.done and tt < 120.0:
		var act := Bot.act(tangle.cues(), DT, "statue", mem)
		tangle.step(DT, float(act["crank"]), float(act["pitch"]), float(act["side"]), float(act["drag"]))
		tt += DT
	_check(how[0] in ["tangle", "broke"] and tt < Fight.TANGLE_LIFE + 5.0,
			"a tangle left alone saws through (%s after %.0f s)" % [how[0], tt])
	for f in fails:
		print("FAIL ", f)
	print("FIGHT TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


## n fights of a kg fish by one style: {ends: {how: count}, landed, median (s, of the landed ones)}.
func _many(kg: float, style: String, captain: bool, n: int) -> Dictionary:
	var ends := {}
	var times: Array[float] = []
	for s in n:
		var r := _fight(kg, s, style, captain)
		ends[r[0]] = int(ends.get(r[0], 0)) + 1
		if r[0] == "boatside":
			times.append(float(r[1]))
	times.sort()
	return {"ends": ends, "landed": times.size(), "median": times[times.size() / 2] if not times.is_empty() else 9999.0}


## Fights one fish; returns [how it ended, seconds, the most line out in a death spiral (m)].
## captain: someone at the wheel keeps the stern on it and backs down on it while it's astern and running (blind:
## backs down all the time and steers anywhere).
func _fight(kg: float, seed_value: int, style: String, captain := false, blind := false) -> Array:
	var f := Fight.new(kg, 45.0, 1.0, seed_value)
	var end := ["timeout", 0.0, 0.0]
	f.lost.connect(func(why: String) -> void: end[0] = why)
	f.boatside.connect(func() -> void: end[0] = "boatside")
	var t := 0.0
	var mem := {}
	while not f.done and t < 1500.0:
		var act := Bot.act(f.cues(), DT, style, mem)
		if captain:
			var b := wrapf(f.bearing, -PI, PI)
			if blind:
				f.bearing -= TURN * DT * (1.0 if fmod(t, 40.0) < 20.0 else -1.0)
				f.throttle = -1.0
			else:
				f.bearing -= clampf(b * 1.5, -1.0, 1.0) * TURN * DT
				f.throttle = -1.0 if f.slipping and f.line_out > 25.0 and absf(b) < 0.6 else 0.0
		f.step(DT, float(act["crank"]), float(act["pitch"]), float(act["side"]), float(act["drag"]))
		t += DT
		if f.move == "spiral":
			end[2] = maxf(float(end[2]), f.line_out)
	end[1] = snappedf(t, 0.01)
	return end


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
