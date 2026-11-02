extends Node
## The fight, headless, many times over, played by test anglers that read only what a player gets (tests/fight_bot.gd:
## the bend, the reel screaming or grinding, the spool, the drag lever, the line going slack, him jumping), with the
## boat round them (a captain a second late keeping her stern to him, backing down on him and swapping on the rod, or
## alone with the rod in its holder while you get on the wheel). Fought well, a bluefin of any size comes boatside, a
## schoolie in a minute or two, a giant in several; alone takes longer. And each pressure on its own:
## - the spool: a giant with nobody chasing him and the drag too light takes the lot; the drag climbs as it empties;
## - the drag too heavy: the hook tears out, or a jolt on a short line parts it;
## - winding against a run twists the line and it parts; pumping wins line a crank alone can't, and a lift into his
##   run gains nothing;
## - the line under the boat or along her hull chafes through; the props cut it;
## - your arms: they go, spent they wind slow, the holder rests them;
## - the hook: slack while he shakes and it falls out, tight while he jumps and he throws it;
## - his phases: the first run, his nature, the leader and his last run at it, the spiral only close in.
## Run: godot --headless --path . res://tests/fight_test.tscn

const Fight := preload("res://tuna/fight.gd")
const Bot := preload("res://tests/fight_bot.gd")
const DT := 1.0 / 30.0
const TURN := 0.45       # rad/s: how fast the captain swings her (boat/helm.gd)

var fails: Array[String] = []


func _ready() -> void:
	# fought well: a crew lands them all, alone most; it takes longer alone, far longer on a giant
	var medians := {}
	for kg: float in [35.0, 150.0, 300.0]:
		var crew := _many(kg, "good", 2, 20)
		var solo := _many(kg, "good", 1, 20)
		medians[kg] = crew["median"]
		print("FIGHT %3d kg fought well with a captain: %s, median %.0f s; alone: %s, median %.0f s"
				% [kg, crew["ends"], crew["median"], solo["ends"], solo["median"]])
		_check(int(crew["landed"]) >= (16 if kg < 60.0 else 19), "%d kg: fought well with a captain, it comes boatside (%d of 20)"
				% [kg, crew["landed"]])
		_check(int(solo["landed"]) >= 15, "%d kg: alone, fought well, the holder and the wheel, you land most (%d of 20)"
				% [kg, solo["landed"]])
		var lo := {35.0: 25.0, 150.0: 70.0, 300.0: 150.0}[kg] as float
		var hi := {35.0: 180.0, 150.0: 360.0, 300.0: 600.0}[kg] as float
		_check(float(crew["median"]) > lo and float(crew["median"]) < hi,
				"%d kg: with a crew it takes a while, %.0f..%.0f s (median %.0f s)" % [kg, lo, hi, crew["median"]])
		if kg > 100.0:
			_check(float(solo["median"]) > float(crew["median"]) * 1.15,
					"%d kg: alone it takes longer (%.0f vs %.0f s)" % [kg, solo["median"], crew["median"]])
	_check(float(medians[300.0]) > 3.0 * float(medians[35.0]),
			"a giant takes far longer than a schoolie (%.0f vs %.0f s)" % [medians[300.0], medians[35.0]])
	var huge := _many(400.0, "good", 2, 20)
	print("FIGHT 400 kg fought well with a captain: %s" % huge["ends"])
	_check(int(huge["landed"]) >= 16, "400 kg: a crew that knows what it's doing lands the biggest (%d of 20)"
			% huge["landed"])
	_check(not _many(35.0, "statue", 0, 10)["ends"].has("boatside")
			and not _many(300.0, "statue", 0, 10)["ends"].has("boatside"), "doing nothing never lands one")

	# THE SPOOL: a giant, nobody chasing him, the drag barely on: he takes it all. Chased (backing down), he doesn't.
	var light := _many(400.0, "light", 2, 20, true)
	print("FIGHT 400 kg, the drag barely on, the captain keeping her stern to him but never backing down: %s"
			% light["ends"])
	_check(int(light["ends"].get("spooled", 0)) >= 14, "a giant on a light drag with nobody chasing spools you (%d of 20)"
			% light["ends"].get("spooled", 0))
	_check(int(huge["ends"].get("spooled", 0)) <= 2, "the same giant chased down by a captain backing on him: (%d of 20 spooled)"
			% huge["ends"].get("spooled", 0))
	var sp := Fight.new(300.0, 50.0, 1.0, 5)
	var full_spool := sp.drag_at(Fight.STRIKE_DRAG) * sp.spool_gain()
	sp.line_out = 420.0
	var near_empty := sp.drag_at(Fight.STRIKE_DRAG) * sp.spool_gain()
	_check(near_empty > full_spool * 1.7, "the same lever holds harder as the spool empties (%.2f -> %.2f)"
			% [full_spool, near_empty])
	# the reel's note: a run's clicks come faster and higher as it empties (rods/rod.gd; checked in rods_test)

	# THE DRAG TOO HEAVY: shoved to full and left there, a giant tears the hook out
	var heavy := _many(300.0, "heavy", 2, 20)
	print("FIGHT 300 kg, the drag shoved to full and left there: %s" % heavy["ends"])
	_check(int(heavy["ends"].get("pulled", 0)) + int(heavy["ends"].get("broke", 0)) >= 15,
			"the drag too heavy on a giant: the hook tears out, or the line goes (%s)" % heavy["ends"])
	# ... and a jolt on a short line with it heavy parts the line; eased off, the same surge is let run
	var jolted := {}
	for lever: float in [1.0, 0.4]:
		var ends := {}
		for sd in 10:
			var j := Fight.new(300.0, 14.0, 0.6, 30 + sd)
			j.leader = true
			j.carry_on("dog", 0.25 * j.give(), 1.0, 1.0)
			j.grace = 0.0
			var how := ["on"]
			j.lost.connect(func(why: String) -> void: how[0] = why)
			for k in 20:
				j.step(DT, 0.0, 0.7, 0.0, lever)
			j.carry_on("surge", j.stretch, 1.0, 1.0)
			j.grace = 0.0
			for k in 120:
				j.step(DT, 0.0, 0.7, 0.0, lever)
				if j.done:
					break
			ends[how[0]] = int(ends.get(how[0], 0)) + 1
		jolted[lever] = ends
	print("FIGHT a surge at the leader, full drag %s, eased %s" % [jolted[1.0], jolted[0.4]])
	_check(int(jolted[1.0].get("broke", 0)) >= 6, "a surge at the leader on a full drag parts the line (%s)" % jolted[1.0])
	_check(int(jolted[0.4].get("on", 0)) >= 9, "eased off, the same surge runs and he's still on (%s)" % jolted[0.4])

	# WINDING AGAINST A RUN: it twists the line, and twisted it parts
	var crank := _many(400.0, "cranker", 2, 20)
	print("FIGHT 400 kg cranked through everything: %s" % crank["ends"])
	_check(int(crank["ends"].get("twisted", 0)) + int(crank["ends"].get("broke", 0)) >= 14,
			"cranking through his runs twists the line and it parts (%s)" % crank["ends"])
	var tw := Fight.new(150.0, 80.0, 0.9, 4)
	tw.carry_on("run")
	tw.grace = 999.0
	for k in 150:
		tw.step(DT, 1.0, 0.8, 0.0, Fight.STRIKE_DRAG)
	var tw2 := Fight.new(150.0, 80.0, 0.9, 4)
	tw2.carry_on("run")
	tw2.grace = 999.0
	for k in 150:
		tw2.step(DT, 0.0, 0.8, 0.0, Fight.STRIKE_DRAG)
	_check(tw.twist > 0.1 and tw2.twist == 0.0 and tw.line_out > 80.0,
			"five seconds cranking while he runs: the line twisted (%.2f) and still going out (%.0f m); hands off, none"
			% [tw.twist, tw.line_out])

	# PUMP AND WIND: on a pulling fish, lifting and winding on the drop wins line a crank alone can't; a lift into his
	# run wins nothing
	var pumped := 0.0
	var cranked := 0.0
	for m: String in ["dog", "circle", "sound"]:
		for sd in 3:
			pumped += _gain(300.0, 100.0, m, "good", sd)
			cranked += _gain(300.0, 100.0, m, "no_pump", sd)
	_check(pumped > 1.5 * cranked and pumped > 30.0,
			"on a giant that's pulling, pumping wins line (%.0f m) a crank alone can't (%.0f m)" % [pumped, cranked])
	var into := Fight.new(300.0, 100.0, 0.8, 9)
	into.carry_on("run")
	into.grace = 999.0
	var into_out := into.line_out
	var p := 0.4
	for k in 60:
		p += 0.75 * DT
		into.step(DT, 0.0, p, 0.0, Fight.STRIKE_DRAG)
	_check(into.line_out > into_out and into.slipping, "a lift into his run: the drag just slips, line still going (%.0f -> %.0f m)"
			% [into_out, into.line_out])

	# THE LINE ON THE BOAT: under her, it chafes through; dead astern, it doesn't wear at all
	var ch := Fight.new(200.0, 30.0, 0.5, 13)
	ch.carry_on("dog")
	ch.grace = 999.0
	var ch_how := [""]
	ch.lost.connect(func(why: String) -> void: ch_how[0] = why)
	var cht := 0.0
	while not ch.done and cht < 60.0:
		ch.bearing = 2.2
		ch.depth = 4.0
		ch.step(DT, 0.0, 0.7, 0.0, Fight.STRIKE_DRAG)
		cht += DT
	var clear := Fight.new(200.0, 30.0, 0.5, 13)
	clear.carry_on("dog")
	clear.grace = 999.0
	for k in 600:
		clear.bearing = 0.0
		clear.depth = 4.0
		clear.step(DT, 0.0, 0.7, 0.0, Fight.STRIKE_DRAG)
	_check(ch_how[0] in ["chafed", "broke_rail"] and cht < 45.0 and clear.wear < 0.01,
			"the line along her hull chafes through (%s after %.0f s); dead astern it doesn't wear (%.3f)"
			% [ch_how[0], cht, clear.wear])
	var cut := 0
	var blind_ends := {}
	for s in 40:
		var how_b := str(_fight(300.0, s, "good", 2, true)[0])
		blind_ends[how_b] = int(blind_ends.get(how_b, 0)) + 1
		if how_b == "cut":
			cut += 1
	print("FIGHT backing down blind: %s" % blind_ends)
	_check(int(blind_ends.get("cut", 0)) + int(blind_ends.get("chafed", 0)) + int(blind_ends.get("broke_rail", 0)) >= 25,
			"backing down hard and steering anywhere loses him, on her hull or in the props (%s)" % blind_ends)
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
		pr.step(DT, 0.0, 0.8, 0.0, Fight.STRIKE_DRAG)
		pt += DT
	_check(pr_how[0] == "cut" and pt < Fight.PROP_GRACE + 0.5,
			"under her with the props turning, the line's cut (%s after %.1f s)" % [pr_how[0], pt])

	# YOUR ARMS: a giant takes them, spent they wind slow, the holder gives them back
	var ar := Fight.new(300.0, 80.0, 0.8, 4)
	ar.carry_on("dog")
	ar.grace = 999.0
	var am := {}
	for k in 900:
		ar.bearing = 0.0
		var act := Bot.act(ar.cues(), DT, "good", am)
		ar.step(DT, float(act["crank"]), float(act["pitch"]), 0.0, float(act["drag"]))
	var sm := Fight.new(35.0, 80.0, 0.8, 4)
	sm.carry_on("dog")
	sm.grace = 999.0
	var smm := {}
	for k in 900:
		sm.bearing = 0.0
		var act := Bot.act(sm.cues(), DT, "good", smm)
		sm.step(DT, float(act["crank"]), float(act["pitch"]), 0.0, float(act["drag"]))
	_check(ar.arms < 0.8 and sm.arms > ar.arms + 0.05,
			"thirty seconds pumping: a giant takes your arms down to %.2f, a schoolie only to %.2f" % [ar.arms, sm.arms])
	var won := []
	for fresh_arms: float in [1.0, 0.0]:
		var sw := Fight.new(150.0, 80.0, 0.3, 8)
		sw.carry_on("circle")
		sw.grace = 999.0
		var swm := {}
		var o := sw.line_out
		for k in 300:
			sw.arms = fresh_arms
			sw.bearing = 0.0
			var act := Bot.act(sw.cues(), DT, "good", swm)
			sw.step(DT, float(act["crank"]), float(act["pitch"]), 0.0, float(act["drag"]))
		won.append(o - sw.line_out)
	_check(float(won[1]) < float(won[0]) * 0.6, "spent arms wind and lift slow (%.1f m vs %.1f m fresh)" % [won[1], won[0]])
	var rest := Fight.new(150.0, 80.0, 0.6, 8)
	rest.carry_on("dog")
	rest.arms = 0.1
	rest.in_holder = true
	for k in 900:
		rest.step(DT, 0.0, 0.8, 0.0, Fight.STRIKE_DRAG)
	_check(rest.arms > 0.9, "thirty seconds with the rod in its holder and your arms are back (%.2f)" % rest.arms)
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
			gf.step(DT, float(act["crank"]), float(act["pitch"]), 0.0, float(act["drag"]))
			low_arms = minf(low_arms, gf.arms)
			gt += DT
		if low_arms < Fight.TIRED:
			swaps += 1
	_check(swaps >= 7, "a giant tires out the angler before he's beaten: swap on the rod (%d fights of 10)" % swaps)

	# THE HOOK: slack while he shakes his head and it falls out; tight while he jumps and he throws it
	var sh := Fight.new(150.0, 40.0, 0.7, 2)
	sh.carry_on("shake", -3.0)
	sh.grace = 0.0
	var sh_how := [""]
	sh.lost.connect(func(why: String) -> void: sh_how[0] = why)
	var sht := 0.0
	while not sh.done and sht < 30.0:
		if sh.move != "shake":
			sh.carry_on("shake", minf(sh.stretch, -3.0), 1.0, sh.hold)
			sh.grace = 0.0
		sh.stretch = minf(sh.stretch, -3.0)
		sh.step(DT, 0.0, 0.7, 0.0, Fight.STRIKE_DRAG)
		sht += DT
	_check(sh_how[0] == "shaken" and sht < 20.0, "a slack line while he shakes his head: it falls out (%s after %.0f s)"
			% [sh_how[0], sht])
	var thrown := {}
	for tip_down: bool in [false, true]:
		var n := 0
		for sd in 10:
			var jf := Fight.new(35.0, 40.0, 0.7, 300 + sd)
			jf.carry_on("dog", 0.2 * jf.give(), 1.0, 1.0)
			jf.grace = 0.0
			var jh := [""]
			jf.lost.connect(func(why: String) -> void: jh[0] = why)
			var pitch := 0.8
			for k in 3:
				jf.carry_on("jump", jf.stretch, 1.0, jf.hold)
				jf.grace = 0.0
				for f in 60:
					pitch = move_toward(pitch, 0.25 if tip_down else 1.3, (2.5 if tip_down else 1.0) * DT)
					jf.step(DT, 0.0 if tip_down else 1.0, pitch, 0.0, Fight.STRIKE_DRAG)
					if jf.done:
						break
				if jf.done:
					break
				pitch = 0.8
			if jh[0] == "thrown":
				n += 1
		thrown[tip_down] = n
	_check(int(thrown[false]) >= 3 and int(thrown[true]) <= 1,
			"three jumps kept tight throw the hook (%d of 10); the tip dropped each time, he stays on (%d thrown)"
			% [thrown[false], thrown[true]])

	# HIS PHASES: the first run off the strike; his nature; the leader and his last run at it; the spiral close in
	var first := Fight.new(300.0, 45.0, 1.0, 3)
	_check(first.move == "run" and first.slipping, "hooked: he's off on his first run, the drag screaming")
	var deep := {"sounder": 0.0, "runner": 0.0}
	var deep_n := {"sounder": 0, "runner": 0}
	var natures := {}
	for sd in 40:
		var nf := Fight.new(300.0, 45.0, 1.0, 200 + sd)
		natures[nf.nature] = true
		if not deep.has(nf.nature):
			continue
		var nm := {}
		var nb := {}
		var most := 0.0
		for k in 3600:
			var act := Bot.act(nf.cues(), DT, "good", nm)
			Bot.crew(nf, DT, 2, nb)
			nf.step(DT, float(act["crank"]), float(act["pitch"]), 0.0, float(act["drag"]))
			most = maxf(most, nf.depth)
			if nf.done:
				break
		deep[nf.nature] = float(deep[nf.nature]) + most
		deep_n[nf.nature] = int(deep_n[nf.nature]) + 1
	var sounder := float(deep["sounder"]) / maxf(float(deep_n["sounder"]), 1.0)
	var runner := float(deep["runner"]) / maxf(float(deep_n["runner"]), 1.0)
	_check(natures.size() >= 3 and not natures.has("jumper") and sounder > runner * 1.15,
			"giants have natures (%s): a sounder goes deeper than a runner (%.0f m vs %.0f m)"
			% [", ".join(natures.keys()), sounder, runner])
	var ld := Fight.new(200.0, 20.0, 0.3, 17)
	ld.carry_on("spiral")
	ld.grace = 999.0
	var up := [false]
	ld.leader_up.connect(func() -> void: up[0] = true)
	var lm := {}
	var lt := 0.0
	while not up[0] and lt < 60.0:
		ld.bearing = 0.0
		var act := Bot.act(ld.cues(), DT, "good", lm)
		ld.step(DT, float(act["crank"]), float(act["pitch"]), 0.0, float(act["drag"]))
		lt += DT
	_check(up[0] and ld.move == "surge", "the leader up at the rod tip: the moment, and he's off on his last run (%s)"
			% ld.move)
	var spiral_out := 0.0
	for s in 20:
		spiral_out = maxf(spiral_out, float(_fight(300.0, s, "good", 2)[2]))
	_check(spiral_out <= Fight.SPIRAL_IN + 4.0,
			"a beaten fish only goes into its death spiral close in (furthest %.0f m)" % spiral_out)
	var quiet := 0.0
	for k in 10:
		var q := Fight.new(200.0, 60.0, 1.0, 40 + k)
		var since := 0.0
		var qm := {}
		var qt := 0.0
		while not q.done and q.energy > 0.35 and qt < 600.0:
			var act := Bot.act(q.cues(), DT, "good", qm)
			q.step(DT, float(act["crank"]), float(act["pitch"]), 0.0, float(act["drag"]))
			since = 0.0 if q.move in ["run", "surge"] else since + DT
			quiet = maxf(quiet, since)
			qt += DT
	_check(quiet <= Fight.QUIET + 15.0, "with fight in him, he's never quiet long: a run or a surge within %.0f s" % quiet)

	# the rest of the boat: nobody at the wheel he wanders off her stern; off it you win less; other lines tangle
	var wide_t := 0.0
	var all_t := 0.0
	for sd in 10:
		var nw := Fight.new(150.0, 45.0, 1.0, 60 + sd)
		var nm := {}
		var tt2 := 0.0
		while not nw.done and tt2 < 240.0:
			var act := Bot.act(nw.cues(), DT, "good", nm)
			nw.step(DT, float(act["crank"]), float(act["pitch"]), 0.0, float(act["drag"]))
			if nw.angle_k() < 0.5:
				wide_t += DT
			all_t += DT
			tt2 += DT
	print("FIGHT nobody at the wheel: off her stern %.0f%% of the time" % (100.0 * wide_t / all_t))
	_check(wide_t / all_t > 0.1, "nobody at the wheel, he's off her stern a good part of the fight (%.0f%%)"
			% (100.0 * wide_t / all_t))
	var gains := []
	for b: float in [0.0, PI * 0.5]:
		gains.append(_gain(150.0, 80.0, "circle", "good", 3, b))
	_check(float(gains[0]) > 5.0 and float(gains[1]) < float(gains[0]) * 0.5,
			"astern you win line (%.1f m in 30 s), abeam far less (%.1f m)" % [gains[0], gains[1]])
	var tangle := Fight.new(150.0, 60.0, 0.6, 11)
	tangle.tangled = true
	var how := [""]
	tangle.lost.connect(func(why: String) -> void: how[0] = why)
	var tt := 0.0
	var mem := {}
	while not tangle.done and tt < 120.0:
		var act := Bot.act(tangle.cues(), DT, "good", mem)
		tangle.step(DT, float(act["crank"]), float(act["pitch"]), float(act["side"]), float(act["drag"]))
		tt += DT
	_check(how[0] in ["tangle", "broke", "broke_rail"] and tt < Fight.TANGLE_LIFE + 10.0,
			"a tangle left alone saws through (%s after %.0f s)" % [how[0], tt])
	var sr := Fight.new(150.0, 60.0, 0.6, 3)
	sr.depth = 5.0
	sr.bearing = 0.3
	var astern_rub := sr.side_rub()
	sr.bearing = 2.3
	_check(astern_rub == 0.0 and sr.side_rub() > 0.5,
			"astern the line's clear of her side (%.2f); forward of her beam it's on it (%.2f)" % [astern_rub, sr.side_rub()])
	# A rod in its holder with nobody on it: the drag plays him, he takes line on his runs, wins none back.
	var on := 0
	var between := 0.0
	for s in 20:
		var f := Fight.new(200.0, 45.0, 1.0, s)
		f.in_holder = true
		var t := 0.0
		var least := f.line_out
		while not f.done and t < 30.0:
			f.step(DT, 0.0, 0.6, 0.0, Fight.STRIKE_DRAG)
			least = minf(least, f.line_out)
			t += DT
		if not f.done:
			on += 1
		between = maxf(between, 45.0 - least)
	_check(on >= 18 and between <= 0.01, "in its holder he's still on after 30 s (%d of 20), and nobody wins line back"
			% on)
	# The same fish played the same way comes out the same; picked up mid-move, it carries on with it.
	var a1 := _fight(150.0, 3, "good", 2)
	var a2 := _fight(150.0, 3, "good", 2)
	_check(str(a1) == str(a2), "the same fish fought the same way ends the same (%s)" % str(a1))
	var mid := Fight.new(200.0, 80.0, 0.5, 7)
	var was_m := "circle" if mid.move != "circle" else "sound"
	mid.carry_on(was_m, 0.4, -1.0, 0.6)
	_check(mid.move == was_m and is_equal_approx(mid.stretch, 0.4) and is_equal_approx(mid.hold, 0.6)
			and mid.turn_sign() < 0.0 and mid.grace > 0.0,
			"a fight picked up mid-move carries on with it: %s, the same stretch, hook and way round" % mid.move)
	_check(Fight.nature_of(77, 300.0) == Fight.nature_of(77, 300.0), "his nature's his own, whoever's got the rod")
	# The line rubs where it runs over her house and bow, not over the open cockpit, not off your own stand.
	var hb := 2.4
	var aft := 7.3
	var house := 0.4
	var bow := -6.7
	var stand := Vector2(hb - 0.3, aft - 0.8)
	var ahead_out := Vector2(stand.x + 40.0 * sin(2.4), aft + 40.0 * cos(2.4))
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
	for f in fails:
		print("FAIL ", f)
	print("FIGHT TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


## Line won (m) in 30 s off a `kg` fish `out` m off doing `m` (held at it, at bearing `b`), by an angler of `style`.
func _gain(kg: float, out: float, m: String, style: String, sd: int, b := 0.0) -> float:
	var f := Fight.new(kg, out, 0.6, sd)
	f.carry_on(m)
	f.grace = 999.0
	var mem := {}
	var l0 := f.line_out
	for k in 900:
		if f.move != m:
			f.carry_on(m, f.stretch, f.turn_sign(), f.hold)
			f.grace = 999.0
		f.bearing = b
		var act := Bot.act(f.cues(), DT, style, mem)
		f.step(DT, float(act["crank"]), float(act["pitch"]), 0.0, float(act["drag"]))
	return l0 - f.line_out


## n fights of a kg fish by one style, `crew` aboard (0: nobody does anything about the boat, 1: alone with the
## holder and the wheel, 2: an angler and a captain): {ends: {how: count}, landed, median (s, of the landed ones)}.
func _many(kg: float, style: String, crew: int, n: int, no_back := false) -> Dictionary:
	var ends := {}
	var times: Array[float] = []
	for s in n:
		var r := _fight(kg, s, style, crew, false, no_back)
		ends[r[0]] = int(ends.get(r[0], 0)) + 1
		if r[0] == "boatside":
			times.append(float(r[1]))
	times.sort()
	return {"ends": ends, "landed": times.size(), "median": times[times.size() / 2] if not times.is_empty() else 9999.0}


## Fights one fish; returns [how it ended, seconds, the most line out in a death spiral (m), its fight left at the end].
## crew: as _many (tests/fight_bot.gd's crew); blind: the captain backs down all the time and steers anywhere.
func _fight(kg: float, seed_value: int, style: String, crew := 0, blind := false, no_back := false) -> Array:
	var f := Fight.new(kg, 45.0, 1.0, seed_value)
	var end := ["timeout", 0.0, 0.0, 1.0]
	f.lost.connect(func(why: String) -> void: end[0] = why)
	f.boatside.connect(func() -> void: end[0] = "boatside")
	var t := 0.0
	var mem := {}
	var boat := {"no_back": no_back}
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
