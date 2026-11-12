extends RefCounted
## A test angler for tuna/fight_arcade.gd: asks the minigame that's on what the right input is (its hint(): tests
## only) and presses A and B. Styles: "good" (plays the hint as it's given), "sloppy" (a first-timer: a tenth of a
## second or so behind it, drops some presses, now and then lets go for a moment), "nothing" (hands off).

const Arcade := preload("res://tuna/fight_arcade.gd")


## -> {a 0..1, b 0..1}. `mem` keeps the angler's state between calls (start with {}, or {"seed": n}).
static func act(f: Arcade, dt: float, style: String, mem: Dictionary) -> Dictionary:
	var out := {"a": 0.0, "b": 0.0}
	if style == "nothing" or f == null or f.game == null:
		mem["q"] = []
		return out
	var h := f.game.hint()
	if style != "sloppy":
		return {"a": 1.0 if bool(h["a"]) else 0.0, "b": 1.0 if bool(h["b"]) else 0.0}
	var rng: RandomNumberGenerator = mem.get("rng", null)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = int(mem.get("seed", 11))
		mem["rng"] = rng
	if mem.get("game") != f.game:
		mem["game"] = f.game
		mem["lag"] = rng.randf_range(0.05, 0.14)
		mem["q"] = []
		mem["drop"] = [false, false]
		mem["was"] = [false, false]
		mem["lapse"] = 0.0
	# (sees it a moment late)
	var q: Array = mem["q"]
	q.append([bool(h["a"]), bool(h["b"])])
	while q.size() > maxi(int(float(mem["lag"]) / maxf(dt, 0.001)), 1):
		q.pop_front()
	var seen: Array = q[0]
	var drop: Array = mem["drop"]
	var was: Array = mem["was"]
	for i in 2:
		var on := bool(seen[i])
		if on and not bool(was[i]):
			drop[i] = rng.randf() < 0.12          # (misses this press altogether)
		if not on:
			drop[i] = false
		was[i] = on
		if on and not bool(drop[i]):
			out["a" if i == 0 else "b"] = 1.0
	# (and now and then the hands come off for a moment)
	mem["lapse"] = float(mem["lapse"]) - dt
	if float(mem["lapse"]) > 0.0:
		return {"a": 0.0, "b": 0.0}
	if rng.randf() < 0.12 * dt:
		mem["lapse"] = rng.randf_range(0.3, 0.6)
	return out
