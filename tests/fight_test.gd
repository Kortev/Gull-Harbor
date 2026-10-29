extends Node
## The fight, headless, many times over: fought right with a captain keeping the stern on it, a bluefin of any size
## comes boatside in a few minutes; alone it takes longer (nobody backs down on it); the line rubs only where it
## runs over her house and bow, never off your own corner going away from her;
## just cranking breaks the big ones off; doing nothing never lands one; backing down hard whatever the fish does
## puts it in the props.
## Run: godot --headless --path . res://tests/fight_test.tscn

const Fight := preload("res://tuna/fight.gd")
const DT := 1.0 / 30.0
const TURN := 0.45       # rad/s: how fast the captain swings her (boat/helm.gd)
const OFF_REST := 0.03   # arms back per s off the rod (rods.gd)

var fails: Array[String] = []


func _ready() -> void:
	for kg: float in [35.0, 150.0, 300.0, 450.0]:
		var landed := 0
		var alone := 0
		var times: Array[float] = []
		var times_alone: Array[float] = []
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
				times_alone.append(a[1])
		times.sort()
		times_alone.sort()
		var med_alone := times_alone[times_alone.size() / 2] if not times_alone.is_empty() else 9999.0
		var med := times[times.size() / 2] if not times.is_empty() else 0.0
		print("FIGHT %3d kg fought right with a captain: %s, median %.0f s; alone: %s" % [kg, ends, med, ends_alone])
		_check(landed >= 18, "%d kg: fought right with a captain, it comes boatside (%d of 20)" % [kg, landed])
		_check(med > 20.0 and med < 330.0, "%d kg: a fight of a minute or a few (median %.0f s)" % [kg, med])
		if kg <= 150.0:
			_check(alone >= 14, "%d kg: alone, you land most of them (%d of 20)" % [kg, alone])
		elif kg >= 400.0:
			# (nobody backing down on it, nobody swinging her: alone a giant's a long fight)
			_check(med_alone > med, "%d kg: alone, a giant takes longer than with a captain (median %.0f vs %.0f s)"
					% [kg, med_alone, med])
	for kg: float in [150.0, 450.0]:
		var one: Array[float] = []
		var two: Array[float] = []
		var lost := [0, 0]
		for s in 20:
			var a := _fight(kg, s, "right", true, false, 1)
			var b := _fight(kg, s, "right", true, false, 2)
			if a[0] == "boatside":
				one.append(a[1])
			else:
				lost[0] += 1
			if b[0] == "boatside":
				two.append(b[1])
			else:
				lost[1] += 1
		one.sort()
		two.sort()
		var m1 := one[one.size() / 2] if not one.is_empty() else 900.0
		var m2 := two[two.size() / 2] if not two.is_empty() else 900.0
		print("FIGHT %d kg with a captain: one angler median %.0f s (lost %d), two taking turns %.0f s (lost %d)"
				% [kg, m1, lost[0], m2, lost[1]])
		if kg >= 400.0:
			# (tired arms only reel slower, and fought right they barely tire: turns help a little, never hurt)
			_check(m2 <= m1 * 1.02, "%d kg: two anglers taking turns are no slower than one (%.0f vs %.0f s)" % [kg, m2, m1])
		else:
			_check(m2 > m1 * 0.9, "%d kg: one angler's arms last the fight (%.0f vs %.0f s)" % [kg, m1, m2])
	var cut := 0
	for s in 40:
		if _fight(300.0, s, "right", true, true)[0] == "cut":
			cut += 1
	print("FIGHT backing down blind: %d of 40 cut by the props" % cut)
	_check(cut >= 4, "backing down hard whatever the fish does puts it in the props (%d of 40)" % cut)
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
	# A rod in its holder with nobody on it: the drag works the fish. It takes line on its runs and none between
	# them, and it's still on half a minute later (it used to pour line off nonstop and spool the reel).
	var on := 0
	var between := 0.0
	for s in 20:
		var f := Fight.new(200.0, 45.0, 1.0, s)
		f.in_holder = true
		var t := 0.0
		while not f.done and t < 30.0:
			var before := f.line_out
			f.step(DT, false, 0.0)
			if f.move in ["rest", "shake", "circle", "spiral"]:
				between = maxf(between, f.line_out - before)
			t += DT
		if not f.done:
			on += 1
	print("FIGHT in its holder: still on after 30 s %d of 20; most line taken between runs in a step %.3f m"
			% [on, between])
	_check(on >= 18, "in its holder, the fish is still on after 30 s (%d of 20)" % on)
	_check(between <= 0.001, "in its holder, it takes no line between its runs (%.3f m)" % between)
	# Alone, following the fish to its corner and holding the rod out keeps the line off the hull longer.
	var plain := 0
	var corner := 0
	# (arms don't tire any more: alone, a giant fought right is landed; the hard part alone is the wheel and the rod)
	var spiral_out := 0.0
	var solo_t: Array[float] = []
	for s in 40:
		var a := _fight(400.0, s, "patient")
		if a[0] == "boatside":
			plain += 1
		var c := _fight(400.0, s, "patient", false, false, 1, 1.0)
		if c[0] == "boatside":
			corner += 1
			solo_t.append(float(c[1]))
		spiral_out = maxf(spiral_out, maxf(float(a[2]), float(c[2])))
	solo_t.sort()
	print("FIGHT 400 kg alone, taking breathers: landed %d of 40 from the middle, %d of 40 from its corner (median %.0f s)"
			% [plain, corner, solo_t[int(solo_t.size() / 2.0)] if not solo_t.is_empty() else 0.0])
	_check(corner >= 20, "alone, with breathers, from the corner, you land most giants (%d of 40)" % corner)
	_check(spiral_out <= Fight.SPIRAL_IN + 0.5,
			"a beaten fish only goes into its death spiral close in (furthest %.0f m)" % spiral_out)
	# The line rubs where it runs over her house and bow, not over the open cockpit, not off your own stand.
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
	# Picking a fight up where it was: the fish carries on with what it was doing.
	var mid := Fight.new(200.0, 80.0, 0.5, 7)
	var was := "spiral" if mid.move != "spiral" else "sound"
	mid.carry_on(was, 0.7, -1.0)
	_check(mid.move == was and is_equal_approx(mid.strain, 0.7) and mid.turn_sign() < 0.0,
			"a fight picked up mid-move carries on with it: %s, the same strain and the same way round" % mid.move)
	# a tangled line saws through if nobody clears it
	var tangle := Fight.new(150.0, 60.0, 0.6, 11)
	tangle.tangled = true
	var how := [""]
	tangle.lost.connect(func(why: String) -> void: how[0] = why)
	var tt := 0.0
	while not tangle.done and tt < 120.0:
		tangle.step(DT, tangle.answer() == "tight", 0.0)      # (keeping it tight through its headshakes)
		tt += DT
	_check(how[0] == "tangle" and tt < Fight.TANGLE_LIFE + 5.0,
			"a tangle left alone saws through (%s after %.0f s)" % [how[0], tt])
	for f in fails:
		print("FAIL ", f)
	print("FIGHT TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


## Fights one fish with a style of angler; returns [how it ended, seconds, the most line out in a death spiral (m)].
## style: right (each move's answer, flat out), patient (the same, but with spent arms takes a breather till they're
## back, keeping it tight through headshakes), crank (cranks whatever it does), idle (nothing).
## captain: someone at the wheel keeps the stern on it and backs down on it when it's astern (blind: backs down
## all the time and steers anywhere).
## reach: the angler at the fish's corner with the rod held out (0 .. 1, rods.gd's _reach).
## anglers: how many take turns on the rod (a fresh one takes over when the holder's arms are going; off the rod
## you rest up at OFF_REST).
func _fight(kg: float, seed_value: int, style: String, captain := false, blind := false, anglers := 1,
		reach := 0.0) -> Array:
	var rested: Array[float] = []
	for i in anglers - 1:
		rested.append(1.0)
	var f := Fight.new(kg, 45.0, 1.0, seed_value)
	f.reach = reach
	var end := ["timeout", 0.0, 0.0]
	f.lost.connect(func(why: String) -> void: end[0] = why)
	f.boatside.connect(func() -> void: end[0] = "boatside")
	var t := 0.0
	var lifting := 0.0
	var resting := false
	while not f.done and t < 1800.0:
		var crank := false
		var lift := 0.0
		if style == "patient":
			if f.arms < 0.15:
				resting = true
			elif f.arms > 0.6:
				resting = false
		if style == "crank":
			crank = true
		elif style == "patient" and resting:
			crank = f.answer() == "tight"
		elif style == "right" or style == "patient":
			match f.answer():
				"hold", "ease":
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
		for i in rested.size():
			rested[i] = minf(rested[i] + OFF_REST * DT, 1.0)
		if not rested.is_empty() and f.arms < 0.25 and rested[0] > 0.6:
			var fresh: float = rested.pop_front()
			rested.append(f.arms)
			f.arms = fresh
		if f.move == "spiral":
			end[2] = maxf(float(end[2]), f.line_out)
	end[1] = t
	return end


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
