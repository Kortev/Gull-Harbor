extends Node
## The fight's music over real fights (tuna/fight.gd, played headless by tests/fight_bot.gd's anglers with a crew, as
## tests/fight_sim does), in flat calm: every fight brings the drums in for a good share of it and the whole band at
## least once (stressful every time, whatever the weather), every fish landed comes up on the whole band (the
## leader), and the layers don't flap in and out. Prints each size's numbers.
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
			var drums := 1.0
			var drums_sum := 0.0
			var full_least := 1000
			var flaps := 0
			var landed := 0
			var leader := 0
			for s in N:
				var r := _fight(kg, 700 + s, style)
				drums = minf(drums, float(r["drums"]))
				drums_sum += float(r["drums"])
				full_least = mini(full_least, int(r["full"]))
				flaps = maxi(flaps, int(r["flaps"]))
				landed += 1 if r["end"] == "boatside" else 0
				leader += 1 if bool(r["leader"]) and r["end"] == "boatside" else 0
			print("%-6s %3d kg: the drums up %.0f%% of a fight (least %.0f%%), the whole band in %d times a fight at "
					% [style, kg, 100.0 * drums_sum / N, 100.0 * drums, full_least]
					+ "least, %d/%d landed (%d on the whole band), the most one layer came in in 10 s: %d"
					% [landed, N, leader, flaps])
			_check(drums >= 0.3, "%s %d kg: the drums up a third of every fight at least (%.0f%%)" % [style, kg,
					100.0 * drums])
			_check(full_least >= 1, "%s %d kg: the whole band in at least once every fight" % [style, kg])
			_check(leader == landed, "%s %d kg: every fish landed came up on the whole band" % [style, kg])
			_check(flaps <= 2, "%s %d kg: no layer flapping (in %d times in 10 s at most)" % [style, kg, flaps])
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
	var fulls := 0
	var full_on := false
	var leader := false
	var ins := {"drums": [], "full": []}  # (when each layer came in: crossing up through a half)
	var was := {"drums": false, "full": false}
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
		up += DT if st.level("drums") >= 0.6 else 0.0
		var full := st.level("full") >= 0.8
		if full and not full_on:
			fulls += 1
		full_on = full if full else full_on and st.level("full") >= 0.4
		leader = leader or (f.line_out < State.LEADER and st.level("full") >= 0.8)
		for k: String in was:
			var on := st.level(k) >= 0.5
			if on and not was[k]:
				ins[k].append(t)
			was[k] = on
	var flaps := 0
	for layer: String in ins:
		var at: Array = ins[layer]
		for i in at.size():
			var k := 0
			for j in range(i, at.size()):
				if float(at[j]) - float(at[i]) < 10.0:
					k += 1
			flaps = maxi(flaps, k)
	return {"end": end[0], "drums": up / maxf(t, 1.0), "full": fulls, "leader": leader, "flaps": flaps}


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("MUSIC FIGHT TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
