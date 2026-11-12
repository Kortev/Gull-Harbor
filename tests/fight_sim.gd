extends Node
## How often a fish gets away, and why: many whole fights, headless, played by test anglers (tests/fight_bot.gd)
## with the boat round them (a captain a second late on the wheel and swapping on the rod, or alone with the holder),
## and the other lines out at the hookup, wound in one by one (a crew gets to them sooner than one alone). Prints a
## table; checks nothing. Run: godot --headless --path . res://tests/fight_sim.tscn (after --: --solo, --style=good,
## --kg=300,400, --quick to leave out the lines-left-out table).

const Fight := preload("res://tuna/fight.gd")
const Bot := preload("res://tests/fight_bot.gd")
const Rods := preload("res://rods/rods.gd")
const DT := 1.0 / 30.0
const N := 20
## (--heave=A) the sea throwing her about: her stern heaving A m/s up and down every HEAVE_T s (a small boat in a
## storm: about 1.1; rods.gd's heave)
var heave_a := 0.0
const HEAVE_T := 7.0
const KGS := [35.0, 150.0, 300.0, 400.0]
## The other baits in the spread (bearings off her stern, m out), as the sportfisher trolls them (boat/kinds.gd).
## And where each line leaves her (from her stern: x across, y up, z astern): the outriggers' clips high and wide, the
## shotgun's up the tower, the corner's rod tip; his own line's from the starboard corner's tip (FISH_TIP).
const SPREAD := [[-0.27, 56.0, Vector3(-6.4, 7.9, -2.7)], [-0.14, 39.0, Vector3(-2.2, 1.6, 0.0)],
		[0.27, 56.0, Vector3(6.4, 7.9, -2.7)], [0.0, 78.0, Vector3(0.0, 6.2, -7.4)]]
## Alone, a sensible angler trolls only her two corner lines (five is a crew's spread): the other one.
const SOLO_SPREAD := [[-0.14, 39.0, Vector3(-2.2, 1.6, 0.0)]]
const FISH_TIP := Vector3(2.2, 2.0, 0.0)


func _ready() -> void:
	var only := ""
	var kgs: Array = KGS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--style="):
			only = a.substr(8)
		if a.begins_with("--pace="):
			Fight.pace = float(a.substr(7))       # (the dev panel's fight length)
		if a.begins_with("--heave="):
			heave_a = float(a.substr(8))
		if a.begins_with("--kg="):
			kgs = Array(a.substr(5).split(",")).map(func(k: String) -> float: return float(k))
	var styles := ["good", "sloppy", "distracted"]
	if not only.is_empty() and not only in styles:
		styles = [only]
	for style: String in styles:
		if not only.is_empty() and style != only:
			continue
		for n: int in ([1] if "--solo" in OS.get_cmdline_user_args() else ([2] if "--crew" in OS.get_cmdline_user_args() else [1, 2])):
			for kg: float in kgs:
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
				print("SIM %-10s %s %3d kg: landed %2d/%d, median %3.0f s, off the stern %2.0f%% of the time  %s"
						% [style, "alone" if n == 1 else "crew ", kg, times.size(), N, med, 100.0 * wide / total, ends])
	# and nobody ever reeling the other lines in: his line across them (a crew's whole spread, or alone the other
	# corner)
	for who: Array in [["sloppy", 2], ["good", 2], ["sloppy", 1], ["good", 1]]:
		for kg: float in ([] if "--quick" in OS.get_cmdline_user_args() else [35.0, 150.0, 300.0]):
			var ends := {}
			for s in N:
				var r := _fight(kg, 500 + s, str(who[0]), int(who[1]), true)
				ends[r[0]] = int(ends.get(r[0], 0)) + 1
			print("SIM %-6s %s %3d kg, the other lines left out: %s" % [who[0], "crew " if int(who[1]) >= 2 else "alone",
					kg, ends])
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
	var lines: Array = (SPREAD if n >= 2 else SOLO_SPREAD).duplicate(true)
	var foul := 0.0
	var look := 0.0
	var sides := {}
	var swept := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
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
			# (a good crew winds in the one he's heading for first, as the shouts say; the rest just go along them)
			var nearest := 0
			for k in lines.size():
				if absf(wrapf(f.bearing - float(lines[k][0]), -PI, PI)) \
						< absf(wrapf(f.bearing - float(lines[nearest][0]), -PI, PI)):
					nearest = k
			lines.remove_at(nearest if style == "good" else 0)
			wound += 1
		# his line against the others still out, as rods.gd's _host_lines has it: warned within WARN_GAP, and once that's
		# been up WARN_T s, within GAP his line sweeping across one fouls it (right over: always; else by the sweep)
		var b := wrapf(f.bearing, -PI, PI)
		var hd := sqrt(maxf(f.line_out * f.line_out - f.depth * f.depth, 0.0))
		look -= DT
		var crossing := -1
		var warned := false
		if look <= 0.0:
			look = Rods.TANGLE_EVERY
			for k in lines.size():
				var l: Array = lines[k]
				var bait := Vector2(sin(float(l[0])), cos(float(l[0]))) * float(l[1])
				var gap := Rods.line_gap(b, hd, f.depth, bait, l[2], FISH_TIP)
				var side := signf(wrapf(b - float(l[0]), -PI, PI))
				var was_side := float(sides.get(l[0], side))
				sides[l[0]] = side
				if gap < Rods.WARN_GAP:
					warned = true
				var crossed := side != was_side and Rods.line_gap(float(l[0]), hd, f.depth, bait, l[2], FISH_TIP) < Rods.GAP
				if (gap < Rods.GAP or crossed) and foul >= Rods.WARN_T and t > Rods.TANGLE_GRACE:
					var sweep := absf(wrapf(b - swept, -PI, PI)) * minf(hd, float(l[1])) / Rods.TANGLE_EVERY
					if Rods._fouls(crossed, sweep, rng.randf()):
						crossing = k
			swept = b
			foul = foul + Rods.TANGLE_EVERY if warned else 0.0
		if crossing >= 0 and tangled_t < 0.0:
			tangled_t = t
			tangled_k = crossing
			f.tangled = true
		if tangled_t >= 0.0 and t > tangled_t + (5.0 if n >= 2 else 7.0) and not left_out:
			if not lines.is_empty():
				lines.remove_at(mini(tangled_k, lines.size() - 1))
			tangled_t = -1.0
			f.tangled = false
		f.heave = heave_a * sin(TAU * t / HEAVE_T)
		f.step(DT, float(act["crank"]), float(act["pitch"]), float(act["side"]), float(act["drag"]))
		t += DT
		if f.angle_k() < 0.5:
			end[2] = float(end[2]) + DT
	end[1] = t
	return end
