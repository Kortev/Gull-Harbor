extends RefCounted
## A test angler for tuna/fight.gd: reads only what a player gets (Fight.cues(): the rod's bend, the reel screaming
## or grinding, the spool, the drag lever under their thumb, the line going slack, him jumping) and plays it, the way a
## person with a rod would. Used by fight_test, fight_sim, strike_test and trip_test.
##
## Styles:
## - "good": pumps (lifts slow, drops winding), hands off the crank and the rod up while he runs, the tip dropped when
##   he jumps, winds like mad on a slack line; works the drag: strike to start, backed off as the spool empties or the
##   bend gets heavy and at the leader, pushed up to lift a fish that's sulking close.
## - "sloppy" (a first-timer: sees it all a third of a second late, pumps out of rhythm, only touches the drag when
##   it's screaming at them), "distracted" (sloppy, and every fifteen seconds or so looks away for a second or two).
## - The wrong ways, one each: "cranker" (winds through everything, never pumps or touches the drag), "statue" (does
##   nothing), "jump_reeler" (good, but keeps it tight through his jumps), "heavy" (good, the drag shoved to full and
##   left there), "light" (good, the drag barely on), "no_pump" (good, but only ever cranks).
##
## And the rest of the boat (`crew`, for a headless Fight): with a crew, someone at the wheel keeps her stern to him a
## second or so late and backs down on him when he's taken a lot of line, and when the angler's arms go the captain
## takes the rod (fresh arms, nobody steering for the walk); alone, the rod goes in its holder when he's gone wide,
## spooling you or your arms are spent, you walk to the wheel, swing her and back down, and walk back.

const Fight := preload("res://tuna/fight.gd")


## -> {crank 0..1, pitch, side, drag}. `mem` keeps the angler's state between calls (start with {}).
static func act(c: Dictionary, dt: float, style: String, mem: Dictionary) -> Dictionary:
	if style == "distracted":
		var rng: RandomNumberGenerator = mem.get("rng", null)
		if rng == null:
			rng = RandomNumberGenerator.new()
			rng.seed = 77
			mem["rng"] = rng
		var away := float(mem.get("away", 0.0))
		if away > 0.0:
			# (looking away: the hand keeps doing what it was, the rod sags under him)
			mem["away"] = away - dt
			mem["seen"] = []
			mem["pitch"] = maxf(float(mem.get("pitch", 0.7)) - 0.25 * float(c["tension"]) * dt, 0.3)
			return {"crank": float(mem.get("last", 0.0)), "pitch": mem["pitch"], "side": 0.0,
					"drag": float(mem.get("drag", Fight.STRIKE_DRAG))}
		if rng.randf() < dt / 15.0:
			mem["away"] = rng.randf_range(0.8, 2.0)
		var out := act(c, dt, "sloppy", mem)
		mem["last"] = out["crank"]
		return out
	var see := c
	if style == "sloppy":
		# what it showed a moment ago
		var seen: Array = mem.get("seen", [])
		seen.append(c)
		while seen.size() > maxi(int(0.35 / maxf(dt, 0.001)), 1):
			seen.pop_front()
		mem["seen"] = seen
		see = seen[0]
	var t := float(see["tension"])
	var pitch := float(mem.get("pitch", 0.7))
	var lever := float(mem.get("drag", Fight.STRIKE_DRAG))
	var crank := 0.0
	var phase := str(mem.get("phase", "lift"))
	var slipping := bool(see["slipping"])
	var out := float(see["line_out"])
	var spool := float(see["spool"])
	mem["calm"] = float(mem.get("calm", 0.0)) + dt if not slipping else 0.0
	# the drag
	var want := lever
	match style:
		"heavy":
			want = 1.0
		"light":
			want = 0.3
		"cranker", "statue":
			want = Fight.STRIKE_DRAG
		"sloppy":
			# a first-timer only backs it off when it's screaming at them or it's nearly all gone; and when he won't
			# come, shoves it up, and forgets it's there
			if t > 0.6 or spool > 0.7:
				want = lever - 0.1
			elif float(mem["calm"]) > 8.0 and out < 200.0:
				want = 0.7
		_:
			# keep the bend off the edge (back it off as the spool empties and its drag climbs), more on him when
			# he's taking it too easily with the spool going, more to lift him when he's sulking close, less at the
			# leader (no give in a short line)
			want = (Fight.STRIKE_DRAG if spool < 0.4 else 0.5) if not slipping else lever
			if slipping and t < 0.3 and spool > 0.45:
				want = minf(lever + 0.1, 0.8)
			elif float(mem["calm"]) > 3.0 and out < 120.0:
				want = 0.7
			if out < Fight.LEADER + 10.0:
				want = minf(want, 0.5)
			# (the line he's dragging through the water on a long fast run pulls at his end too: keep it lighter)
			if t > (0.36 if slipping and spool > 0.4 else 0.45):
				want = minf(want, lever - 0.1)
	var notch := float(mem.get("notch", 0.0)) - dt
	if notch <= 0.0 and absf(want - lever) > 0.05:
		lever = clampf(lever + signf(want - lever) * Fight.STEP, 0.0, 1.0)
		notch = 1.0 if style == "sloppy" else 0.3
	mem["notch"] = notch
	mem["drag"] = lever
	# the rod and the reel
	match style:
		"statue":
			return {"crank": 0.0, "pitch": 0.7, "side": 0.0, "drag": lever}
		"cranker":
			return {"crank": 1.0, "pitch": 0.8, "side": 0.0, "drag": lever}
	var jumping := bool(see["jumping"]) or bool(see["airborne"])
	if jumping and style == "jump_reeler":
		pitch = move_toward(pitch, 1.3, 1.0 * dt)         # (the rod held up and wound: tight on him in the air)
		crank = 1.0
	elif jumping:
		pitch = move_toward(pitch, 0.25, 2.5 * dt)        # (bow to him: the tip down)
		crank = 0.0
		phase = "drop"
	elif bool(see["slack"]) or bool(see["charging"]):
		crank = 1.0                    # (wind like mad)
		pitch = move_toward(pitch, 0.9, 1.0 * dt)
		phase = "lift"
	elif bool(see["thrash"]) and style == "good" and t > 0.15:
		crank = 0.0                    # (his head going: ease off him, don't horse him, but don't give slack)
		pitch = move_toward(pitch, 0.7, 0.6 * dt)
	elif slipping:
		crank = 0.0                    # (hands off the crank: he's taking it)
		pitch = move_toward(pitch, 0.9, 1.0 * dt)
		phase = "lift"
	elif style == "no_pump":
		crank = 1.0
		pitch = move_toward(pitch, 0.8, 1.0 * dt)
	else:
		# pump: lift slow, drop winding
		var top := 1.25 if style != "sloppy" else 1.1
		var lift_rate := 0.75 if style != "sloppy" else 0.55
		var was_t := float(mem.get("was_t", t))
		mem["t_rate"] = lerpf(float(mem.get("t_rate", 0.0)), (t - was_t) / maxf(dt, 1e-4), minf(1.0, 4.0 * dt))
		mem["was_t"] = t
		if phase == "lift":
			pitch += lift_rate * dt
			crank = 0.0
			if pitch >= top or t > float(see["drag_now"]) * 0.97:
				phase = "drop"
		elif phase == "drop":
			pitch -= (1.2 if style != "sloppy" else 1.9) * dt      # (a first-timer drops it faster than he can wind: slack)
			crank = 1.0
			if pitch <= 0.45:
				phase = "wait"
				mem["wait"] = 0.0
		else:
			# at the bottom, winding to keep it tight, waiting for his tired moment: the bend easing off (a
			# first-timer just goes again)
			crank = 1.0
			mem["wait"] = float(mem.get("wait", 0.0)) + dt
			var easing := float(mem["t_rate"]) < -0.02 or t < 0.12
			if style == "sloppy" or easing or float(mem["wait"]) > 2.5:
				phase = "lift"
		if style == "jump_reeler":
			crank = maxf(crank, 1.0 if jumping else 0.0)
	pitch = clampf(pitch, 0.15, 1.35)
	mem["pitch"] = pitch
	mem["phase"] = phase
	return {"crank": crank, "pitch": pitch, "side": 0.0, "drag": lever}


## The boat round a headless fight, a tick on: the captain, swapping on the rod, the holder. `n` is how many aboard
## (1: alone); `mem` keeps its state (start with {}). TURN: how fast she swings (rad/s, boat/helm.gd).
const TURN := 0.45
const WALK := 2.5          # s from the rod to the wheel and back
const LATE := 1.0          # s a captain's slow to see he's gone wide
const ROD_MIN := 4.0       # s alone back on the rod, winding, before the next go at the wheel
const CHASE := 0.7         # alone, the spool this empty with him still running: to the wheel to chase him


## `careless`: the captain's two seconds late, and now and then looks away for a few. mem["busy"] true: the captain's
## off the wheel (winding the other lines in).
static func crew(f: Object, dt: float, n: int, mem: Dictionary, careless := false) -> void:
	var b := wrapf(float(f.get("bearing")), -PI, PI)
	var t := float(mem.get("t", 0.0)) + dt
	mem["t"] = t
	var arms := float(f.get("arms"))
	var spool := float(f.get("line_out")) / Fight.CAPACITY
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
		# (the rod in its holder only between his runs, mostly: on a run a rod nobody's on gives him line twice as
		# fast. To the wheel to swing her stern to him or back down and make slack; back to the rod to wind it up, and
		# a while on it winding before the next go at the wheel. Only with the spool nearly gone, mid-run.)
		var slipping := bool(f.get("slipping"))
		var on_rod := float(mem.get("rod_t", 99.0))
		if walk > 0.0:
			walk -= dt
			if walk <= 0.0 and not resting:
				f.set("in_holder", false)
				f.call("carry_on", str(f.get("move")), float(f.get("stretch")), float(f.call("turn_sign")),
						float(f.get("hold")))
				mem["rod_t"] = 0.0
		elif not resting and ((on_rod > ROD_MIN and not slipping and float(f.call("angle_k")) < 0.4
				and float(f.get("line_out")) > 12.0) or arms < 0.12 or (spool > CHASE and slipping)):
			resting = true
			walk = WALK
			f.set("in_holder", true)
		elif resting and absf(b) < 0.4 and float(f.get("arms")) > 0.5 and (spool < CHASE or not slipping) \
				and (float(f.get("stretch")) < -2.0 or float(mem.get("helm_t", 0.0)) > 6.0):
			resting = false         # (she's backed down on him, or long enough: back to the rod, wind up the slack)
			walk = WALK
		mem["helm_t"] = float(mem.get("helm_t", 0.0)) + dt if resting else 0.0
		if not resting and walk <= 0.0:
			mem["rod_t"] = on_rod + dt
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
	# backing down on him when he's taken a lot (never with him under her or close in)
	var backing := bool(mem.get("backing", false))
	var late_s := float(mem.get("spool_seen", 0.0))
	late_s = late_s + dt if spool > 0.3 else 0.0
	mem["spool_seen"] = late_s
	var tight := bool(f.get("slipping")) or float(f.get("strain")) > 0.12
	if steering and late_s > (3.0 if careless else 1.0) and absf(b) < 0.6 and tight and not bool(mem.get("no_back", false)):
		backing = true
	if n == 1 and steering and late_s > (3.0 if careless else 1.0) and absf(b) < 0.6 and not bool(mem.get("no_back", false)):
		backing = float(f.get("stretch")) > -4.0      # (alone: back down on him for a belly of slack to go and wind)
	elif not tight and float(f.get("stretch")) < (-2.0 if careless else -0.2):
		backing = false          # (she's run up the slack: hold her while the angler winds it)
	if not steering or spool < 0.12 or absf(b) > 0.9 or float(f.get("line_out")) < 40.0:
		backing = false
	mem["backing"] = backing
	f.set("throttle", -1.0 if backing else 0.0)
