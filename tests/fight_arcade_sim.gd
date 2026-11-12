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
					extra = "hold %.2f wear %.2f best x%d most out %.0f grades %s pieces %s" % [r["hold"], r["wear"], r["best"],
							r["far"], r["grades"], r["pieces"]]
			print("SIM %-7s %3d kg: %s  s=%s  %s" % [style, kg, ends, times, extra])
	get_tree().quit()


static func run(kg: float, seed_value: int, style: String, limit := 1800.0) -> Dictionary:
	var f := Arcade.new(kg, 45.0, 1.0, seed_value)
	var end := ["timeout"]
	f.lost.connect(func(why: String) -> void: end[0] = why)
	f.boatside.connect(func() -> void: end[0] = "boatside")
	var mem := {"seed": seed_value}
	var t := 0.0
	var grades := {}
	var pieces := {}
	var far := 0.0
	var idle := 0.0
	var idle_most := 0.0
	while not f.done and t < limit:
		var v := f.view()
		var act := Bot.act(v, DT, style, mem)
		f.pull_btn = float(act["b"])
		f.step(DT, float(act["a"]), 0.6, 0.0, 0.6)
		# (someone at the wheel keeping her stern to him)
		f.bearing = move_toward(wrapf(f.bearing, -PI, PI), 0.0, 0.2 * DT)
		t += DT
		far = maxf(far, f.line_out)
		pieces[f.move] = int(pieces.get(f.move, 0)) + 1
		idle = idle + DT if float(v["intro"]) > 0.0 else 0.0
		idle_most = maxf(idle_most, idle)
		for e: Array in f.take_events():
			if e[0] == "grade":
				grades[e[1]] = int(grades.get(e[1], 0)) + 1
	for k: String in pieces:
		pieces[k] = int(int(pieces[k]) * DT)
	return {"end": end[0], "t": t, "hold": f.hold, "wear": f.wear, "best": f.best, "far": far, "grades": grades,
			"pieces": pieces, "idle": idle_most, "energy": f.energy, "fight": f}
