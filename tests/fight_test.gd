extends Node
## The fight, headless, many times over, played by test anglers that read only the bar (tests/fight_bot.gd), with
## the boat round them (a captain a second late keeping her stern to him and swapping on the rod when the angler's
## arms go, or alone with the rod in its holder while you steer). Kept in the green, a bluefin of any size comes
## boatside, a schoolie in a couple of minutes, a giant in several; alone takes longer; reeling through his runs puts
## it in the red and parts the line; doing nothing lets it go slack and the hook falls out; reeling through a jump
## throws it; only the green tires him; held still for the first fish's lesson, nothing moves but the needle. And the
## new rules: off to the side you win less line, abeam next to none; with nobody at the wheel he wanders off her
## stern; forward of her beam the line's on her side; your arms go reeling and come back resting, and spent they wind
## slow; a giant spends a fresh pair before he's beaten; he charges the boat and goes under her. The line rubs where
## it runs over her house and bow; backing down blind puts it in the props; a tangle saws through.
## Run: godot --headless --path . res://tests/fight_test.tscn

const Fight := preload("res://tuna/fight.gd")
const Bot := preload("res://tests/fight_bot.gd")
const DT := 1.0 / 30.0
const TURN := 0.45       # rad/s: how fast the captain swings her (boat/helm.gd)

var fails: Array[String] = []


func _ready() -> void:
	for kg: float in [35.0, 150.0, 300.0]:
		var crew := _many(kg, "good", 2, 20)
		var solo := _many(kg, "good", 1, 20)
		print("FIGHT %3d kg, kept in the green with a captain: %s, median %.0f s; alone: %s, median %.0f s"
				% [kg, crew["ends"], crew["median"], solo["ends"], solo["median"]])
		_check(int(crew["landed"]) >= 18, "%d kg: kept in the green with a captain, it comes boatside (%d of 20)"
				% [kg, crew["landed"]])
		_check(int(solo["landed"]) >= 14, "%d kg: alone, kept in the green, the holder and the wheel, you land most (%d of 20)"
				% [kg, solo["landed"]])
		var lo := {35.0: 40.0, 150.0: 100.0, 300.0: 180.0}[kg] as float
		var hi := {35.0: 200.0, 150.0: 360.0, 300.0: 600.0}[kg] as float
		_check(float(crew["median"]) > lo and float(crew["median"]) < hi,
				"%d kg: with a crew it takes a while, %.0f..%.0f s (median %.0f s)" % [kg, lo, hi, crew["median"]])
		_check(float(solo["median"]) > float(crew["median"]) * 1.2,
				"%d kg: alone it takes longer (%.0f vs %.0f s)" % [kg, solo["median"], crew["median"]])
	var small := _many(35.0, "good", 2, 20)
	var giant := _many(300.0, "good", 2, 20)
	_check(float(giant["median"]) > 2.0 * float(small["median"]),
			"a giant takes far longer than a schoolie (%.0f vs %.0f s)" % [giant["median"], small["median"]])
	for kg: float in [150.0, 300.0]:
		var c := _many(kg, "cranker", 0, 20)
		print("FIGHT %3d kg reeling through everything: %s" % [kg, c["ends"]])
		_check(int(c["ends"].get("broke", 0)) >= 15, "%d kg: reeling through his runs, the red parts the line (%d of 20)"
				% [kg, c["ends"].get("broke", 0)])
	for kg: float in [35.0, 300.0]:
		var s := _many(kg, "statue", 0, 10)
		print("FIGHT %3d kg doing nothing: %s" % [kg, s["ends"]])
		_check(not s["ends"].has("boatside"), "%d kg: doing nothing never lands it" % kg)
		if kg < 100.0:
			_check(int(s["ends"].get("pulled", 0)) >= 8,
					"%d kg: doing nothing, the line goes slack, the hook falls out (%d of 10)" % [kg, s["ends"].get("pulled", 0)])
		else:
			_check(not s["ends"].has("timeout"), "%d kg: doing nothing, he's gone one way or another" % kg)
	var jumps := _many(35.0, "jump_reeler", 2, 20)
	print("FIGHT 35 kg reeling through his jumps: %s" % jumps["ends"])
	_check(int(jumps["ends"].get("thrown", 0)) >= 6, "reeling while a schoolie jumps throws the hook (%d of 20)"
			% jumps["ends"].get("thrown", 0))
	# only the green tires him: out of it (too slack, the hook's grace stretched out) he doesn't
	var g := Fight.new(150.0, 60.0, 0.7, 5)
	g.grace = 999.0
	g.carry_on("circle")
	g.grace = 999.0
	for k in 300:
		g.step(DT, 0.0, 0.8, 0.0, 0.72)
	var left_alone := 0.7 - g.energy
	var h := Fight.new(150.0, 60.0, 0.7, 5)
	h.carry_on("circle")
	var mem := {}
	for k in 300:
		var act := Bot.act(h.cues(), DT, "good", mem)
		h.step(DT, float(act["crank"]), 0.8, 0.0, 0.72)
	_check(left_alone < 0.01 and 0.7 - h.energy > 0.03,
			"ten seconds circling: left slack he doesn't tire (%.3f), kept in the green he does (%.3f)"
			% [left_alone, 0.7 - h.energy])
	# held still for the lesson: nothing moves but the needle, nothing's lost
	var p := Fight.new(150.0, 60.0, 1.0, 9)
	p.paused = true
	var was := [p.line_out, p.energy, p.bearing, p.move_t]
	for k in 600:
		p.step(DT, 0.0, 0.8, 0.0, 0.72)
	var low := p.strain
	for k in 60:
		p.step(DT, 1.0, 0.8, 0.0, 0.72)
	_check(not p.done and [p.line_out, p.energy, p.bearing, p.move_t] == was and p.strain > low + 0.2,
			"paused twenty seconds: he hasn't moved, nothing's lost, the needle still answers the reel (%.2f -> %.2f)"
			% [low, p.strain])
	# A first-timer, end to end: slow, overshooting, never told the fish's weight. Most come in, and the end game
	# (beaten, circling) almost never loses one.
	var late_losses := 0
	var all_losses := 0
	for kg: float in [35.0, 100.0, 200.0, 300.0]:
		var ends := {}
		var landed := 0
		for k in 20:
			var r := _fight(kg, 100 + k, "sloppy", 1)
			ends[r[0]] = int(ends.get(r[0], 0)) + 1
			if r[0] == "boatside":
				landed += 1
			else:
				all_losses += 1
				if float(r[3]) < Fight.BEATEN:
					late_losses += 1
					print("FIGHT   lost beaten: %d kg, %s after %.0f s" % [kg, r[0], r[1]])
		print("FIGHT %3d kg, a first-timer alone: %s" % [kg, ends])
		_check(landed >= 14, "%d kg: a first-timer lands most of them (%d of 20)" % [kg, landed])
	_check(late_losses <= 2, "a beaten fish, circling, is almost never lost (%d of %d losses)" % [late_losses, all_losses])
	# it keeps fighting: a fresh fish never goes long without a run or a surge
	var quiet := 0.0
	for k in 10:
		var q := Fight.new(200.0, 60.0, 1.0, 40 + k)
		var since := 0.0
		var qm := {}
		var qt := 0.0
		while not q.done and q.energy > 0.35 and qt < 600.0:
			var act := Bot.act(q.cues(), DT, "good", qm)
			q.step(DT, float(act["crank"]), 0.8, 0.0, 0.72)
			since = 0.0 if q.move in ["run", "surge"] else since + DT
			quiet = maxf(quiet, since)
			qt += DT
	_check(quiet <= Fight.QUIET + 12.0, "with fight in him, he's never quiet long: a run or a surge within %.0f s" % quiet)
	var cut := 0
	var blind_ends := {}
	for s in 40:
		var how_b := str(_fight(300.0, s, "good", 2, true)[0])
		blind_ends[how_b] = int(blind_ends.get(how_b, 0)) + 1
		if how_b == "cut":
			cut += 1
	print("FIGHT backing down blind: %d of 40 cut by the props %s" % [cut, blind_ends])
	_check(int(blind_ends.get("cut", 0)) + int(blind_ends.get("chafed", 0)) >= 30,
			"backing down hard and steering anywhere loses him, on her hull or in the props (%s)" % blind_ends)
	# Under her with the props turning: cut.
	var pr := Fight.new(150.0, 30.0, 0.5, 13)
	pr.carry_on("dog")
	pr.grace = 999.0
	var pr_how := [""]
	pr.lost.connect(func(why: String) -> void: pr_how[0] = why)
	var pt := 0.0
	while not pr.done and pt < 10.0:
		pr.bearing = PI
		pr.depth = 8.0
		pr.throttle = 0.5
		pr.step(DT, 0.0, 0.8, 0.0, 0.72)
		pt += DT
	_check(pr_how[0] == "cut" and pt < Fight.PROP_GRACE + 0.5,
			"under her with the props turning, the line's cut (%s after %.1f s)" % [pr_how[0], pt])
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
		spiral_out = maxf(spiral_out, float(_fight(300.0, s, "good", 2)[2]))
	_check(spiral_out <= Fight.SPIRAL_IN + 0.5,
			"a beaten fish only goes into its death spiral close in (furthest %.0f m)" % spiral_out)
	# The same fish played the same way comes out the same.
	var a1 := _fight(150.0, 3, "good", 2)
	var a2 := _fight(150.0, 3, "good", 2)
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
	var was_m := "circle" if mid.move != "circle" else "sound"
	mid.carry_on(was_m, 0.4, -1.0, 0.6)
	_check(mid.move == was_m and is_equal_approx(mid.stretch, 0.4) and is_equal_approx(mid.hold, 0.6)
			and mid.turn_sign() < 0.0 and mid.grace > 0.0,
			"a fight picked up mid-move carries on with it: %s, the same needle, hook and way round" % mid.move)
	# a tangled line saws through if nobody clears it
	var tangle := Fight.new(150.0, 60.0, 0.6, 11)
	tangle.tangled = true
	var how := [""]
	tangle.lost.connect(func(why: String) -> void: how[0] = why)
	var tt := 0.0
	mem = {}
	while not tangle.done and tt < 120.0:
		var act := Bot.act(tangle.cues(), DT, "good", mem)
		tangle.step(DT, float(act["crank"]), float(act["pitch"]), float(act["side"]), float(act["drag"]))
		tt += DT
	_check(how[0] in ["tangle", "broke"] and tt < Fight.TANGLE_LIFE + 5.0,
			"a tangle left alone saws through (%s after %.0f s)" % [how[0], tt])
	# The angle: kept in the green on a fish dead astern you win line; the same fish abeam, next to none.
	var won := []
	for b: float in [0.0, PI * 0.5]:
		var w := Fight.new(150.0, 80.0, 0.3, 21)
		w.carry_on("dog")
		w.grace = 999.0
		w.bearing = b
		w.depth = 10.0
		var start_out := w.line_out
		var wm := {}
		for k in 240:
			w.bearing = b
			var act := Bot.act(w.cues(), DT, "good", wm)
			w.step(DT, float(act["crank"]), 0.8, 0.0, 0.72)
		won.append(start_out - w.line_out)
	_check(float(won[0]) > 3.0 and float(won[1]) < float(won[0]) * 0.35,
			"astern you win line (%.1f m in 8 s), abeam next to none (%.1f m)" % [won[0], won[1]])
	# Nobody at the wheel: he wanders off her stern a good part of the fight.
	var wide_t := 0.0
	var all_t := 0.0
	for sd in 10:
		var nw := Fight.new(150.0, 45.0, 1.0, 60 + sd)
		var nm := {}
		var tt2 := 0.0
		while not nw.done and tt2 < 240.0:
			var act := Bot.act(nw.cues(), DT, "good", nm)
			nw.step(DT, float(act["crank"]), 0.8, 0.0, 0.72)
			if nw.angle_k() < 0.5:
				wide_t += DT
			all_t += DT
			tt2 += DT
	print("FIGHT nobody at the wheel: off her stern %.0f%% of the time" % (100.0 * wide_t / all_t))
	_check(wide_t / all_t > 0.2, "nobody at the wheel, he's off her stern a good part of the fight (%.0f%%)"
			% (100.0 * wide_t / all_t))
	# Forward of her beam the line lies along her side.
	var sr := Fight.new(150.0, 60.0, 0.6, 3)
	sr.depth = 5.0
	sr.bearing = 0.3
	var astern_rub := sr.side_rub()
	sr.bearing = 2.3
	_check(astern_rub == 0.0 and sr.side_rub() > 0.5,
			"astern the line's clear of her side (%.2f); forward of her beam it's on it (%.2f)" % [astern_rub, sr.side_rub()])
	# Your arms: reeling drains them, faster on a giant; spent, the reel winds slow; hands off they come back.
	var ar := Fight.new(300.0, 80.0, 0.8, 4)
	ar.carry_on("dog")
	ar.grace = 999.0
	for k in 900:
		ar.bearing = 0.0
		ar.step(DT, 1.0 if ar.strain < 0.6 else 0.0, 0.8, 0.0, 0.72)
	var after_30 := ar.arms
	var sm := Fight.new(35.0, 80.0, 0.8, 4)
	sm.carry_on("dog")
	sm.grace = 999.0
	for k in 900:
		sm.bearing = 0.0
		sm.step(DT, 1.0 if sm.strain < 0.6 else 0.0, 0.8, 0.0, 0.72)
	_check(after_30 < 0.8 and sm.arms > after_30,
			"thirty seconds reeling: a giant takes your arms down to %.2f, a schoolie only to %.2f" % [after_30, sm.arms])
	var spent := Fight.new(150.0, 80.0, 0.22, 8)
	spent.carry_on("dog")
	spent.grace = 999.0
	var fresh_won := 0.0
	var spent_won := 0.0
	for pass_i in 2:
		var o := spent.line_out
		for k in 150:
			spent.arms = 1.0 if pass_i == 0 else 0.0
			spent.bearing = 0.0
			spent.step(DT, 1.0 if spent.strain < 0.6 else 0.0, 0.8, 0.0, 0.72)
		if pass_i == 0:
			fresh_won = o - spent.line_out
		else:
			spent_won = o - spent.line_out
	_check(spent_won < fresh_won * 0.5, "spent arms wind slow (%.1f m vs %.1f m fresh)" % [spent_won, fresh_won])
	var rest := Fight.new(150.0, 80.0, 0.6, 8)
	rest.carry_on("dog")
	rest.arms = 0.1
	rest.in_holder = true
	for k in 300:
		rest.step(DT, 0.0, 0.8, 0.0, 0.72)
	_check(rest.arms > 0.8, "ten seconds with the rod in its holder and your arms are back (%.2f)" % rest.arms)
	# A giant spends a fresh pair of arms before he's beaten: the crew swaps on the rod.
	var swaps := 0
	for sd in 10:
		var gf := Fight.new(300.0, 45.0, 1.0, 80 + sd)
		var gm := {}
		var gb := {}
		var low_arms := 1.0
		var gt := 0.0
		while not gf.done and gt < 900.0:
			var act := Bot.act(gf.cues(), DT, "good", gm)
			Bot.crew(gf, DT, 2, gb)
			gf.step(DT, float(act["crank"]), 0.8, 0.0, 0.72)
			low_arms = minf(low_arms, gf.arms)
			gt += DT
		if low_arms < Fight.TIRED:
			swaps += 1
	_check(swaps >= 7, "a giant tires out the angler before he's beaten, %d fights of 10" % swaps)
	# He charges the boat: round toward her bow, under her.
	var ch := Fight.new(150.0, 60.0, 0.8, 12)
	ch.grace = 999.0
	ch.bearing = 0.4
	ch.carry_on("charge")
	ch.grace = 999.0
	var cm := {}
	var most := 0.0
	for k in 150:
		var act := Bot.act(ch.cues(), DT, "good", cm)
		ch.step(DT, float(act["crank"]), 0.8, 0.0, 0.72)
		most = maxf(most, ch.b_now())
	_check(most > 2.0, "charging the boat, he goes round toward her bow, under her (%.2f rad)" % most)
	for f in fails:
		print("FAIL ", f)
	print("FIGHT TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


## n fights of a kg fish by one style, `crew` aboard (0: nobody does anything about the boat, 1: alone with the
## holder and the wheel, 2: an angler and a captain): {ends: {how: count}, landed, median (s, of the landed ones)}.
func _many(kg: float, style: String, crew: int, n: int) -> Dictionary:
	var ends := {}
	var times: Array[float] = []
	for s in n:
		var r := _fight(kg, s, style, crew)
		ends[r[0]] = int(ends.get(r[0], 0)) + 1
		if r[0] == "boatside":
			times.append(float(r[1]))
	times.sort()
	return {"ends": ends, "landed": times.size(), "median": times[times.size() / 2] if not times.is_empty() else 9999.0}


## Fights one fish; returns [how it ended, seconds, the most line out in a death spiral (m), its fight left at the end].
## crew: as _many (tests/fight_bot.gd's crew); blind: the captain backs down all the time and steers anywhere.
func _fight(kg: float, seed_value: int, style: String, crew := 0, blind := false) -> Array:
	var f := Fight.new(kg, 45.0, 1.0, seed_value)
	var end := ["timeout", 0.0, 0.0, 1.0]
	f.lost.connect(func(why: String) -> void: end[0] = why)
	f.boatside.connect(func() -> void: end[0] = "boatside")
	var t := 0.0
	var mem := {}
	var boat := {}
	while not f.done and t < 1500.0:
		var act := Bot.act(f.cues(), DT, style, mem)
		if blind:
			f.bearing -= TURN * DT * (1.0 if fmod(t, 40.0) < 20.0 else -1.0)
			f.throttle = -1.0
		elif crew > 0:
			Bot.crew(f, DT, crew, boat)
		f.step(DT, float(act["crank"]), float(act["pitch"]), float(act["side"]), float(act["drag"]))
		t += DT
		if f.move == "spiral":
			end[2] = maxf(float(end[2]), f.line_out)
	end[1] = snappedf(t, 0.01)
	end[3] = f.energy
	return end


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
