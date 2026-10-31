extends RefCounted
## A test angler for tuna/fight.gd: reads only what's on the screen (Fight.cues(): the needle, whether he's running or
## jumping) and plays it, the way a person watching the bar would. Used by fight_test, strike_test and trip_test.
##
## Styles: "good" (keeps the needle in the green: reels while it's low, lets go as it rises past the middle of the
## green, and whenever he runs or jumps), "reeler" (reels all the time except on runs: ignores the needle),
## "cranker" (reels through everything), "statue" (does nothing), "jump_reeler" (good, but reels through his jumps).
## "sloppy" (a first-timer: sees the bar a third of a second late, overshoots both ways, lets go of a run or a jump
## only once it's well under way). "distracted" (sloppy, and every fifteen seconds or so looks away for a second or
## two, hand doing whatever it was doing). ("no_side" and "high_tip", the old styles, are "good" and "jump_reeler".)
##
## And the rest of the boat (`crew`, for a headless Fight): with a crew, someone at the wheel keeps her stern to him a
## second or so late, and when the angler's arms go, the captain comes off the wheel and takes the rod (nobody steers
## for the walk), the tired one going to the wheel; alone, the rod goes in its holder when he's gone wide or your arms
## are spent, you walk to the wheel and swing her, rest, and walk back.

## -> {crank 0..1, pitch, side, drag}. `mem` keeps the angler's state between calls (start with {}).
static func act(c: Dictionary, _dt: float, style: String, mem: Dictionary) -> Dictionary:
	var t := float(c["tension"])
	var on := bool(mem.get("on", true))
	var crank := 0.0
	if style == "distracted":
		# a first-timer who now and then looks away (the plotter, a crewmate, the other lines) and keeps doing
		# whatever their hand was doing for a second or so
		var rng: RandomNumberGenerator = mem.get("rng", null)
		if rng == null:
			rng = RandomNumberGenerator.new()
			rng.seed = 77
			mem["rng"] = rng
		var away := float(mem.get("away", 0.0))
		if away > 0.0:
			mem["away"] = away - _dt
			mem["seen"] = []
			return {"crank": float(mem.get("last", 0.0)), "pitch": 0.8, "side": 0.0, "drag": 0.72}
		if rng.randf() < _dt / 15.0:
			mem["away"] = rng.randf_range(0.8, 2.0)
		var out := act(c, _dt, "sloppy", mem)
		mem["last"] = out["crank"]
		return out
	if style == "sloppy":
		# what it showed a moment ago
		var seen: Array = mem.get("seen", [])
		seen.append([t, bool(c["slipping"]), bool(c["jumping"])])
		var late := int(0.35 / maxf(_dt, 0.001))
		while seen.size() > late:
			seen.pop_front()
		mem["seen"] = seen
		var then: Array = seen[0]
		var tl := float(then[0])
		if on and tl > 0.74:
			on = false
		elif not on and tl < 0.3:
			on = true
		crank = 1.0 if on and not bool(then[1]) and not bool(then[2]) else 0.0
		mem["on"] = on
		return {"crank": crank, "pitch": 0.8, "side": 0.0, "drag": 0.72}
	match style:
		"statue":
			crank = 0.0
		"cranker":
			crank = 1.0
		"reeler":
			crank = 0.0 if bool(c["slipping"]) else 1.0
		_:
			# reel up into the green, let it settle back, reel again: a hand on the button watching the bar
			if on and t > 0.6:
				on = false
			elif not on and t < 0.45:
				on = true
			crank = 1.0 if on else 0.0
			if bool(c["slipping"]):
				crank = 0.0
			if bool(c["jumping"]):
				crank = 1.0 if style in ["jump_reeler", "high_tip"] else 0.0
	mem["on"] = on
	return {"crank": crank, "pitch": 0.8, "side": 0.0, "drag": 0.72}


## The boat round a headless fight, a tick on: the captain, swapping on the rod, the holder. `n` is how many aboard
## (1: alone); `mem` keeps its state (start with {}). TURN: how fast she swings (rad/s, boat/helm.gd).
const TURN := 0.45
const WALK := 2.5          # s from the rod to the wheel and back
const LATE := 1.0          # s a captain's slow to see he's gone wide


## `careless`: the captain's two seconds late, and now and then looks away for a few. mem["busy"] true: the captain's
## off the wheel (winding the other lines in).
static func crew(f: Object, dt: float, n: int, mem: Dictionary, careless := false) -> void:
	var b := wrapf(float(f.get("bearing")), -PI, PI)
	var t := float(mem.get("t", 0.0)) + dt
	mem["t"] = t
	var arms := float(f.get("arms"))
	var steering := false
	if n >= 2:
		# the others' arms come back while they're off the rod
		var rest := float(mem.get("rest", 1.0))
		rest = minf(rest + dt / 24.0, 1.0)
		var walk := float(mem.get("walk", 0.0))
		if walk > 0.0:
			walk -= dt
			if walk <= 0.0:
				f.set("arms", rest)
				rest = arms
				f.set("grace", 1.0)
		elif arms < 0.15 and rest > 0.6 and not bool(f.get("slipping")):
			walk = WALK
		mem["walk"] = walk
		mem["rest"] = rest
		steering = walk <= 0.0 and not bool(mem.get("busy", false))
	else:
		var resting := bool(mem.get("resting", false))
		var walk := float(mem.get("walk", 0.0))
		if walk > 0.0:
			walk -= dt
			if walk <= 0.0 and not resting:
				f.set("in_holder", false)
				f.call("carry_on", str(f.get("move")), float(f.get("stretch")), float(f.call("turn_sign")),
						float(f.get("hold")))
		elif not resting and (float(f.call("angle_k")) < 0.4 or arms < 0.12) and not bool(f.get("slipping")):
			resting = true
			walk = WALK
			f.set("in_holder", true)
		elif resting and absf(b) < 0.3 and float(f.get("arms")) > 0.7:
			resting = false
			walk = WALK
		mem["walk"] = walk
		mem["resting"] = resting
		steering = resting and walk <= 0.0
	# the captain: a moment late seeing he's gone wide, then hard over till the stern's on him
	if careless:
		var rng: RandomNumberGenerator = mem.get("rng", null)
		if rng == null:
			rng = RandomNumberGenerator.new()
			rng.seed = 91
			mem["rng"] = rng
		var away := float(mem.get("away", 0.0)) - dt
		if away <= 0.0 and rng.randf() < dt / 20.0:
			away = rng.randf_range(2.0, 5.0)
		mem["away"] = away
		steering = steering and away <= 0.0
	var wide := absf(b) > 0.35
	var seen := float(mem.get("seen", 0.0))
	seen = seen + dt if wide else 0.0
	mem["seen"] = seen
	if steering and seen > (2.0 if careless else LATE) or (steering and absf(b) > 0.15 and bool(mem.get("swinging", false))):
		mem["swinging"] = true
		f.set("bearing", float(f.get("bearing")) - signf(b) * minf(TURN * dt, absf(b)))
	else:
		mem["swinging"] = false
	f.set("throttle", 0.0)
