extends RefCounted
## A test angler for tuna/fight.gd: reads only what's on the screen (Fight.cues(): the needle, whether he's running or
## jumping) and plays it, the way a person watching the bar would. Used by fight_test, strike_test and trip_test.
##
## Styles: "good" (keeps the needle in the green: reels while it's low, lets go as it rises past the middle of the
## green, and whenever he runs or jumps), "reeler" (reels all the time except on runs: ignores the needle),
## "cranker" (reels through everything), "statue" (does nothing), "jump_reeler" (good, but reels through his jumps).
## "sloppy" (a first-timer: sees the bar a third of a second late, overshoots both ways, lets go of a run or a jump
## only once it's well under way). ("no_side" and "high_tip", the old styles, are "good" and "jump_reeler".)

## -> {crank 0..1, pitch, side, drag}. `mem` keeps the angler's state between calls (start with {}).
static func act(c: Dictionary, _dt: float, style: String, mem: Dictionary) -> Dictionary:
	var t := float(c["tension"])
	var on := bool(mem.get("on", true))
	var crank := 0.0
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
