extends Node
## How often a fish gets away, and why: many whole fights, headless, played by test anglers (tests/fight_bot.gd)
## with the boat round them (a captain a second late on the wheel and swapping on the rod, or alone with the holder),
## and the other lines out at the hookup, wound in one by one (a crew gets to them sooner than one alone). Prints a
## table; checks nothing. Run: godot --headless --path . res://tests/fight_sim.tscn

const Fight := preload("res://tuna/fight.gd")
const Bot := preload("res://tests/fight_bot.gd")
const Rods := preload("res://rods/rods.gd")
const DT := 1.0 / 30.0
const N := 20
## The other baits in the spread (bearings off her stern, m out), as the sportfisher trolls them (boat/kinds.gd).
const SPREAD := [[-0.27, 56.0], [-0.14, 39.0], [0.27, 56.0]]


func _ready() -> void:
	for style: String in ["good", "sloppy", "distracted"]:
		for n: int in [1, 2]:
			for kg: float in [35.0, 150.0, 300.0]:
				var ends := {}
				var times: Array[float] = []
				var wide := 0.0
				var total := 0.0
				for s in N:
					var r := _fight(kg, 500 + s, style, n)
					ends[r[0]] = int(ends.get(r[0], 0)) + 1
					if r[0] == "boatside":
						times.append(float(r[1]))
					wide += float(r[2])
					total += float(r[1])
				times.sort()
				var med := times[times.size() / 2] if not times.is_empty() else 0.0
				print("SIM %-6s %s %3d kg: landed %2d/%d, median %3.0f s, off the stern %2.0f%% of the time  %s"
						% [style, "alone" if n == 1 else "crew ", kg, times.size(), N, med, 100.0 * wide / total, ends])
	# and a crew that never reels the other lines in: his runs across them
	for kg: float in [35.0, 150.0, 300.0]:
		var ends := {}
		for s in N:
			var r := _fight(kg, 500 + s, "sloppy", 2, true)
			ends[r[0]] = int(ends.get(r[0], 0)) + 1
		print("SIM sloppy crew  %3d kg, the other lines left out: %s" % [kg, ends])
	get_tree().quit()


## One fight: [how it ended, s, s spent with him off to the side (angle under a half)].
func _fight(kg: float, seed_value: int, style: String, n: int, left_out := false) -> Array:
	var f := Fight.new(kg, 45.0, 1.0, seed_value)
	var end := ["timeout", 0.0, 0.0]
	f.lost.connect(func(why: String) -> void: end[0] = why)
	f.boatside.connect(func() -> void: end[0] = "boatside")
	var t := 0.0
	var mem := {}
	var boat := {}
	var lines: Array = SPREAD.duplicate(true)
	var foul := 0.0
	var tangled_t := -1.0
	var tangled_k := 0
	var wound := 0
	var first := 4.0 if n >= 2 else 8.0
	var every := 4.0 if n >= 2 else 6.0
	while not f.done and t < 1500.0:
		var act := Bot.act(f.cues(), DT, style, mem)
		boat["busy"] = not lines.is_empty() and not left_out
		Bot.crew(f, DT, n, boat, style != "good")
		# the other lines: wound in one by one; his run across one still out tangles it, and then that one's wound in
		# first, as soon as someone gets to it
		if not lines.is_empty() and t > first + every * float(wound) and not left_out:
			lines.pop_front()
			wound += 1
		var b := wrapf(f.bearing, -PI, PI)
		var crossing := -1
		for k in lines.size():
			var l: Array = lines[k]
			if absf(b - float(l[0])) < Rods.CROSS and f.line_out > float(l[1]) * 0.6:
				crossing = k
		foul = foul + DT if crossing >= 0 else 0.0
		if foul > Rods.FOUL_IN and tangled_t < 0.0:
			tangled_t = t
			tangled_k = crossing
			f.tangled = true
		if tangled_t >= 0.0 and t > tangled_t + (5.0 if n >= 2 else 7.0) and not left_out:
			if not lines.is_empty():
				lines.remove_at(mini(tangled_k, lines.size() - 1))
			tangled_t = -1.0
			f.tangled = false
		f.step(DT, float(act["crank"]), float(act["pitch"]), float(act["side"]), float(act["drag"]))
		t += DT
		if f.angle_k() < 0.5:
			end[2] = float(end[2]) + DT
	end[1] = t
	return end
