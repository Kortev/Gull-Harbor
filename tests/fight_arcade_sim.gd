extends Node
## A quick look at how arcade fights go (tests/fight_arcade_test.gd is the test): godot --headless --path . tests/fight_arcade_sim.tscn

const Arcade := preload("res://tuna/fight_arcade.gd")
const Bot := preload("res://tests/fight_arcade_bot.gd")
const DT := 1.0 / 30.0


func _ready() -> void:
	for style: String in ["good", "sloppy", "nothing"]:
		for kg: float in [35.0, 60.0, 150.0, 300.0]:
			var ends := {}
			var times := []
			var extra := ""
			for s in 8:
				var r := run(kg, 100 + s, style)
				ends[r["end"]] = int(ends.get(r["end"], 0)) + 1
				times.append(int(r["t"]))
				if s == 0:
					extra = "hold %.2f wear %.2f best x%d pulls %d bosses %s most out %.0f grades %s games %s" % [r["hold"], r["wear"],
							r["best"], r["pulls"], r["bosses"], r["far"], r["grades"], r["games"]]
			print("SIM %-7s %3d kg: %s  s=%s  %s" % [style, kg, ends, times, extra])
	get_tree().quit()


## One fight, `style` on the buttons (tests/fight_arcade_bot.gd), someone at the wheel keeping her stern to him.
static func run(kg: float, seed_value: int, style: String, limit := 1800.0) -> Dictionary:
	var f := Arcade.new(kg, 45.0, 1.0, seed_value)
	var end := ["timeout"]
	f.lost.connect(func(why: String) -> void: end[0] = why)
	f.boatside.connect(func() -> void: end[0] = "boatside")
	var mem := {"seed": seed_value}
	var t := 0.0
	var grades := {}
	var games := {}
	var moves := {}
	var far := 0.0
	var idle := 0.0
	var idle_most := 0.0
	var last := ""
	var twice := 0
	var pulls := 0
	var pull_m := 0.0
	var bosses := [0, 0]
	var longest := 0.0
	while not f.done and t < limit:
		var act := Bot.act(f, DT, style, mem)
		f.pull_btn = float(act["b"])
		f.step(DT, float(act["a"]), 0.6, 0.0, 0.6)
		f.bearing = move_toward(wrapf(f.bearing, -PI, PI), 0.0, 0.2 * DT)
		t += DT
		far = maxf(far, f.line_out)
		moves[f.move] = true
		idle = idle + DT if f.game == null else 0.0
		idle_most = maxf(idle_most, idle)
		if f.game != null:
			longest = maxf(longest, f.game.t)
		for e: Array in f.take_events():
			match str(e[0]):
				"grade":
					grades[e[1]] = int(grades.get(e[1], 0)) + 1
				"game":
					if e[1] != "pull":
						games[e[1]] = int(games.get(e[1], 0)) + 1
						if e[1] == last:
							twice += 1
						last = e[1]
				"pull":
					pulls += 1
					pull_m += float(e[1])
				"boss":
					bosses[0 if bool(e[1]) else 1] += 1
	return {"end": end[0], "t": t, "hold": f.hold, "wear": f.wear, "best": f.best, "far": far, "grades": grades,
			"games": games, "moves": moves, "idle": idle_most, "energy": f.energy, "fight": f, "twice": twice,
			"pulls": pulls, "pull_m": pull_m, "bosses": bosses, "longest": longest}
