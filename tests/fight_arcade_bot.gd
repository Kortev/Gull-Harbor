extends RefCounted
## A test angler for tuna/fight_arcade.gd: reads only what the HUD draws (FightArcade.view()) and presses A and B.
## Styles: "good" (plays each set-piece as it's meant), "sloppy" (a first-timer: late on the needle, off the beat and
## missing some, pumps short or holds the top, takes some kicks, slow on the handle, late round the laps, sometimes
## hangs on through a jump), "nothing" (hands off).

const Arcade := preload("res://tuna/fight_arcade.gd")


## -> {a 0..1, b 0..1}. `mem` keeps the angler's state between calls (start with {}).
static func act(v: Dictionary, dt: float, style: String, mem: Dictionary) -> Dictionary:
	var out := {"a": 0.0, "b": 0.0}
	if style == "nothing":
		return out
	var sloppy := style == "sloppy"
	var rng: RandomNumberGenerator = mem.get("rng", null)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = int(mem.get("seed", 11))
		mem["rng"] = rng
	var t := float(v["t"])
	var piece := str(v["piece"])
	if str(mem.get("piece", "")) != piece or t < float(mem.get("t", 0.0)):
		mem["piece_n"] = int(mem.get("piece_n", 0)) + 1
		mem["hang"] = sloppy and rng.randf() < 0.3
		mem["sw"] = rng.randf_range(0.55, 1.0)
		mem["over"] = rng.randf() < 0.25
		mem["off"] = {}
		mem["tap_t"] = 0.0
		mem["turn_t"] = -1.0
	mem["piece"] = piece
	mem["t"] = t
	match piece:
		"run", "surge":
			var n := float(v["needle"])
			var vel := (n - float(mem.get("n", n))) / maxf(dt, 0.001)
			mem["n"] = n
			var aim := float(v["band_c"])
			if sloppy:
				# (sees the band a third of a second late)
				var seen: Array = mem.get("seen", [])
				seen.append(aim)
				while seen.size() > maxi(int(0.33 / maxf(dt, 0.001)), 1):
					seen.pop_front()
				mem["seen"] = seen
				aim = float(seen[0])
			out["b"] = 1.0 if n + vel * (0.05 if sloppy else 0.16) < aim else 0.0
		"shake":
			var beats: PackedFloat32Array = v["beats"]
			var hit: PackedByteArray = v["beat_hit"]
			var off: Dictionary = mem["off"]
			for i in beats.size():
				if hit[i] != 0:
					continue
				if not off.has(i):
					off[i] = (rng.randfn(0.0, 0.085) if rng.randf() > 0.15 else 9.0) if sloppy else 0.0
				var at := beats[i] + float(off[i])
				if t >= at - 0.02 and t <= at + 0.05:
					out["b"] = 1.0
				break
		"jump":
			var air := float(v["air"])
			if bool(mem["hang"]) and air < 0.3:
				out["b"] = 1.0
			elif int(v["landed"]) == 0 and air >= Arcade.AIR - 0.03 + (rng.randfn(0.0, 0.1) if sloppy else 0.0) \
					and air < Arcade.AIR + 0.2:
				out["a"] = 1.0
		"sound", "dog":
			var rod := float(v["rod"])
			var kick := int(v["kick"])
			var top := Arcade.GOLD + 0.05
			if sloppy:
				top = float(mem["sw"]) + (0.6 if bool(mem["over"]) else 0.0)
			var dodge := kick == 2 or (kick == 1 and not sloppy)
			if sloppy and bool(mem["over"]):
				dodge = false
			if int(v["dir"]) == -1 and rod > 0.0:
				out["a"] = 1.0
			elif dodge:
				out["a"] = 1.0 if rod >= 0.62 else 0.0
			elif rod >= minf(top, 1.0) and (top <= 1.0 or float(v["top"]) > top - 1.0):
				out["a"] = 1.0
			else:
				out["b"] = 1.0
			if rod <= 0.0 and int(v["dir"]) != 1:
				mem["sw"] = rng.randf_range(0.55, 1.0)
				mem["over"] = sloppy and rng.randf() < 0.2
		"charge":
			# (hammering it: so many presses a second)
			var every := 1.0 / (3.0 if sloppy else 6.0)
			mem["tap_t"] = float(mem["tap_t"]) + dt
			out["a"] = 1.0 if fmod(float(mem["tap_t"]), every) < every * 0.5 else 0.0
		"circle", "spiral":
			var green := float(v["lap"]) < float(v["green"]) and float(v["intro"]) <= 0.0
			if sloppy:
				# (a third of a second behind him, both ways)
				if green != bool(mem.get("g", false)):
					mem["g_t"] = float(mem.get("g_t", 0.0)) + dt
					if float(mem["g_t"]) > 0.35:
						mem["g"] = green
						mem["g_t"] = 0.0
				green = bool(mem.get("g", false))
			if green:
				out["a"] = 1.0
			else:
				out["b"] = 1.0
	return out
