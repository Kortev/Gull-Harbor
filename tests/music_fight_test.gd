extends Node
## The music over real fights (tuna/fight.gd, played headless by tests/fight_bot.gd's anglers with a crew, as
## tests/fight_sim does), in flat calm: every fight drives it hard more than once and keeps it up a good share of the
## time (stressful every time, whatever the weather), the line-about-to-part stripping comes only when the line's near
## going, and it doesn't flap. Prints each size's numbers.
## Run: godot --headless --path . res://tests/music_fight_test.tscn

const Fight := preload("res://tuna/fight.gd")
const Bot := preload("res://tests/fight_bot.gd")
const State := preload("res://audio/music_state.gd")
const DT := 1.0 / 30.0
const N := 6
const KGS := [35.0, 150.0, 300.0]

var fails: Array[String] = []


func _ready() -> void:
	for style: String in ["good", "sloppy"]:
		for kg: float in KGS:
			var peaks := 1000
			var share := 1.0
			var share_sum := 0.0
			var parting_ok := true
			var flaps := 0
			var landed := 0
			var leader := 0
			var warned := 0
			var parted := 0
			var bare := 0.0
			var tired := 0.0
			var tension := 0.0
			var tense := 1.0
			for s in N:
				var r := _fight(kg, 700 + s, style)
				peaks = mini(peaks, int(r["peaks"]))
				share = minf(share, float(r["drive"]))
				share_sum += float(r["drive"])
				parting_ok = parting_ok and bool(r["parting_ok"])
				flaps = maxi(flaps, int(r["flaps"]))
				bare += float(r["bare"]) / N
				tired += float(r["tired"]) / N
				tension = maxf(tension, float(r["tension"]))
				tense = minf(tense, float(r["tense"]))
				landed += 1 if r["end"] == "boatside" else 0
				leader += 1 if bool(r["leader"]) else 0
				if r["end"] in ["broke", "broke_rail", "twisted"]:
					parted += 1
					warned += 1 if bool(r["warned"]) else 0
			print("%-6s %3d kg: drive peaks >= %d a fight, drive up %.0f%% of it (least %.0f%%), %d/%d landed, %d saw the "
					% [style, kg, peaks, 100.0 * share_sum / N, 100.0 * share, landed, N, leader]
					+ "leader, line parted %d (stripped bare before it: %d), most section changes in 4.3 s: %d; "
					% [parted, warned, flaps]
					+ "stripped bare %.1f%% of the time, tired %.0f%%, the most bend against the line %.2f"
					% [100.0 * bare, 100.0 * tired, tension])
			_check(peaks >= 2, "%s %d kg: every fight drives it hard at least twice (%d)" % [style, kg, peaks])
			_check(share >= 0.3, "%s %d kg: the drive's up a third of every fight at least (%.0f%%)" % [style, kg,
					100.0 * share])
			_check(tense >= 0.08, "%s %d kg: the tension stem's in for a good part of every fight (least %.0f%%)"
					% [style, kg, 100.0 * tense])
			_check(parting_ok, "%s %d kg: stripped bare only with the line near going" % [style, kg])
			_check(flaps <= 2, "%s %d kg: it doesn't flap (%d changes in 4.3 s)" % [style, kg, flaps])
			_check(leader >= landed, "%s %d kg: every fish landed came up on the leader's music" % [style, kg])
	_done()


func _fight(kg: float, seed_value: int, style: String) -> Dictionary:
	var f := Fight.new(kg, 45.0, 1.0, seed_value)
	var st := State.new(seed_value)
	var end := ["timeout"]
	f.lost.connect(func(why: String) -> void: end[0] = why)
	f.boatside.connect(func() -> void: end[0] = "boatside")
	var mem := {}
	var boat := {}
	var t := 0.0
	var up := 0.0
	var peaks := 0
	var was_up := false
	var parting_ok := true
	var changes: Array[float] = []
	var sec := ""
	var leader := false
	var bare_t := -INF
	var bare := 0.0
	var tired := 0.0
	var tension := 0.0
	var tense := 0.0
	while not f.done and t < 1200.0:
		var act := Bot.act(f.cues(), DT, style, mem)
		Bot.crew(f, DT, 2, boat, style != "good")
		f.step(DT, float(act["crank"]), float(act["pitch"]), float(act["side"]), float(act["drag"]))
		t += DT
		if f.done:
			break
		var fish := {"id": "0:0", "line_out": f.line_out, "depth": f.depth, "move": f.move, "tangled": f.tangled}
		fish.merge(State.feel(f.cues(), f.strength()), true)
		st.step({"docked": false, "condition": "calm", "fights": [fish]}, DT)
		var d := st.level("drive")
		if d >= 0.6:
			up += DT
		if d >= 0.8 and not was_up:
			peaks += 1
		was_up = d >= 0.8 if was_up else d >= 0.8
		if was_up and d < 0.5:
			was_up = false
		tension = maxf(tension, float(fish["tension"]))
		tense += DT if st.level("tension") >= 0.5 else 0.0
		tired += DT if st.section == "tired" else 0.0
		if st.parting:
			bare += DT
			bare_t = t
			parting_ok = parting_ok and st.danger >= State.PARTED
		if st.section != sec:
			changes.append(t)
			sec = st.section
		leader = leader or st.section == "leader"
	var flaps := 0
	for i in changes.size():
		var k := 0
		for j in range(i, changes.size()):
			if changes[j] - changes[i] < 4.3:
				k += 1
		flaps = maxi(flaps, k - 1)
	return {"end": end[0], "peaks": peaks, "drive": up / maxf(t, 1.0), "parting_ok": parting_ok, "flaps": flaps,
			"leader": leader, "warned": t - bare_t < 3.0, "bare": bare / maxf(t, 1.0), "tired": tired / maxf(t, 1.0),
			"tension": tension, "tense": tense / maxf(t, 1.0)}


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("MUSIC FIGHT TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
