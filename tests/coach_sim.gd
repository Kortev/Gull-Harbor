extends Node
## Following the coach (ui/fight_coach.gd) and nothing else: whole fights headless (tuna/fight.gd), an angler who does
## just what the line by the reel says (wait, lift, wind as you drop, hands off on a run, wind when it's slack, drop
## the tip, the drag when it says), a mate at the wheel keeping her stern to him (tests/fight_bot.gd's crew). Prints how many land and how long they take; checks
## that a 110 kg fish comes in, done the coach's way, in about 1.5-2.5 min, and that lifting whenever (never waiting
## for him) is slower. Run: godot --headless --path . res://tests/coach_sim.tscn

const Fight := preload("res://tuna/fight.gd")
const Coach := preload("res://ui/fight_coach.gd")
const Bot := preload("res://tests/fight_bot.gd")
const DT := 1.0 / 30.0
const N := 12

var fails: Array[String] = []


func _ready() -> void:
	for kg: float in [110.0, 150.0, 300.0]:
		var rhythm := _many(kg, true)
		var blind := _many(kg, false)
		print("COACH %3d kg: following it landed %2d/%d, median %3.0f s; lifting blind %2d/%d, median %3.0f s  %s"
				% [kg, rhythm[0], N, rhythm[1], blind[0], N, blind[1], rhythm[2]])
		if kg == 110.0:
			_check(rhythm[0] >= N - 1, "110 kg the coach's way: landed (%d/%d)" % [rhythm[0], N])
			_check(rhythm[1] >= 80.0 and rhythm[1] <= 160.0, "110 kg the coach's way: 1.5-2.5 min or so (%.0f s)"
					% rhythm[1])
			_check(rhythm[1] < blind[1], "waiting for his tired moments is quicker than lifting blind (%.0f < %.0f s)"
					% [rhythm[1], blind[1]])
	if fails.is_empty():
		print("COACH SIM PASSED")
	else:
		for f in fails:
			print("FAIL ", f)
		print("COACH SIM FAILED")
	get_tree().quit()


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)


## [landed, median s, why the rest got away].
func _many(kg: float, wait: bool) -> Array:
	var times: Array[float] = []
	var ends := {}
	for s in N:
		var r := _fight(kg, 900 + s, wait)
		ends[r[0]] = int(ends.get(r[0], 0)) + 1
		if r[0] == "boatside":
			times.append(float(r[1]))
	times.sort()
	return [times.size(), times[times.size() / 2] if not times.is_empty() else 0.0, ends]


## One fight followed the coach's way (`wait` false: the same, but lifting again the moment the rod's down).
func _fight(kg: float, seed_value: int, wait: bool) -> Array:
	var f := Fight.new(kg, 60.0, 1.0, seed_value)
	f.carry_on("run", 0.0, 0.0, 1.0, Fight.BURST)
	var coach := Coach.new()
	coach.begin()
	var end := ["timeout"]
	var pitch := 0.6
	f.lost.connect(func(why: String) -> void: end[0] = why)
	f.boatside.connect(func() -> void: end[0] = "boatside")
	var drag := Fight.STRIKE_DRAG
	var notch := 0.0
	var t := 0.0
	var crank := false
	var boat := {}
	while not f.done and t < 900.0:
		Bot.crew(f, DT, 2, boat)        # (a mate at the wheel keeping her stern to him, a second late)
		coach.tick(DT, f, pitch, crank)
		var keys := coach.keys
		if not wait and keys == "wait":
			keys = "lift"
		crank = false
		match keys:
			"none":
				pitch = move_toward(pitch, 0.9, 0.8 * DT)
			"wait":
				pitch = move_toward(pitch, 0.9, 0.5 * DT)      # (rod up a little, winding, waiting for him)
				crank = true
			"lift":
				pitch += 0.7 * DT * (1.0 - 0.55 * f.strain) * lerpf(0.45, 1.0, f.power())
			"wind":
				pitch -= 1.0 * DT
				crank = true
			"drop":
				pitch = move_toward(pitch, 0.3, 2.5 * DT)
			"drag_down", "drag_up":
				notch -= DT
				if notch <= 0.0:
					notch = 1.0
					drag = clampf(drag + (Fight.STEP if keys == "drag_up" else -Fight.STEP), 0.0, 1.0)
					coach.dragged(drag, keys == "drag_up")
		if f.strain > 0.3:
			pitch -= 0.35 * f.strain * DT        # (a fish on drags the rod down, as rods.gd's _aim)
		pitch = clampf(pitch, 0.15, 1.35)
		f.step(DT, 1.0 if crank else 0.0, pitch, 0.0, drag)
		t += DT
	return [end[0], t]
