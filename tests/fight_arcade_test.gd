extends Node
## The arcade fight (tuna/fight_arcade.gd), headless: test anglers (tests/fight_arcade_bot.gd) reading only what the
## HUD draws. One that plays each set-piece well lands a 60 kg fish in a couple of minutes and a 300 kg one in eight to
## fifteen; one that does nothing loses line and then the fish, but not at once; a sloppy one still lands small fish;
## a long fight has every set-piece in it and never a long wait with nothing to do; the cues the music reads are all
## there; the host's fight length (Fight.pace) halves it; a rod changing hands carries the streak; left in its holder
## the fish isn't lost to the hook. Then the real game: a fish struck, the rod taken, fought on the two buttons through
## rods.gd to boatside, with the arcade HUD up and the classic one away; and the host's switch back to the classic.
## Run: godot --headless --fixed-fps 30 --path . tests/fight_arcade_test.tscn

const Sea := preload("res://sea/sea.gd")
const Fight := preload("res://tuna/fight.gd")
const Arcade := preload("res://tuna/fight_arcade.gd")
const Bot := preload("res://tests/fight_arcade_bot.gd")
const Sim := preload("res://tests/fight_arcade_sim.gd")
const TIME_SCALE := 4.0
const DT := 1.0 / 30.0

var fails: Array[String] = []


func _ready() -> void:
	Fight.arcade = true
	Fight.pace = 1.0
	Arcade.force_piece = ""
	# a good angler
	var small := _many(60.0, "good", 8)
	_check(int(small["ends"].get("boatside", 0)) == 8, "a good angler lands every 60 kg fish (%s)" % str(small["ends"]))
	_check(small["med"] >= 90.0 and small["med"] <= 180.0, "in a couple of minutes (%.0f s, %s)" % [small["med"], str(small["times"])])
	var giant := _many(300.0, "good", 5)
	_check(int(giant["ends"].get("boatside", 0)) == 5, "and every 300 kg one (%s)" % str(giant["ends"]))
	_check(giant["med"] >= 480.0 and giant["med"] <= 900.0, "in eight to fifteen minutes (%.0f s, %s)" % [giant["med"], str(giant["times"])])
	var all := true
	for m: String in Arcade.PIECES:
		all = all and (giant["pieces"] as Dictionary).has(m)
	_check(all, "every set-piece comes up in a giant's fight: %s" % str((giant["pieces"] as Dictionary).keys()))
	_check(giant["idle"] < 8.0 and small["idle"] < 8.0, "never long with nothing to do (the longest telegraph %.1f s)" % maxf(giant["idle"], small["idle"]))
	_check(int(giant["best"]) >= 5, "played well, a streak builds (x%d)" % int(giant["best"]))
	# hands off
	for kg: float in [60.0, 300.0]:
		var none := _many(kg, "nothing", 6)
		_check(int(none["ends"].get("boatside", 0)) == 0 and not (none["ends"] as Dictionary).has("timeout"),
				"hands off a %d kg fish, he's lost (%s)" % [kg, str(none["ends"])])
		_check(none["least"] > 20.0, "but not in the first twenty seconds (the soonest %.0f s)" % none["least"])
		_check(none["far"] > 150.0, "and he takes line first (out to %.0f m)" % none["far"])
	# a first-timer
	var sloppy := _many(60.0, "sloppy", 12)
	_check(int(sloppy["ends"].get("boatside", 0)) >= 9, "a sloppy angler still lands most 60 kg fish (%s)" % str(sloppy["ends"]))
	_check(sloppy["med"] > small["med"], "slower than a good one (%.0f s against %.0f)" % [sloppy["med"], small["med"]])
	var sloppy_giant := _many(300.0, "sloppy", 6)
	print("     (a sloppy angler on 300 kg fish: %s, %.0f s)" % [str(sloppy_giant["ends"]), sloppy_giant["med"]])
	# the cues the music, the reel and the crew read
	var f := Arcade.new(150.0, 45.0, 1.0, 5)
	f.step(DT, 0.0, 0.6, 0.0, 0.6)
	var c := f.cues()
	var missing := []
	for key: String in ["tension", "spool", "line_out", "slack", "airborne", "surging", "contact", "props", "tangled",
			"paying", "bend", "slipping", "grinding", "bearing", "angle", "arms", "leader", "drag", "holder", "visible"]:
		if not c.has(key):
			missing.append(key)
	_check(missing.is_empty(), "cues() has all its keys (missing: %s)" % str(missing))
	_check(f.move == "run" and bool(c["surging"]) and float(c["paying"]) > 1.0 and bool(c["slipping"]),
			"struck, he's running and the reel's paying out (%.1f m/s)" % float(c["paying"]))
	# the host's fight length
	Fight.pace = 0.5
	var quick := _many(60.0, "good", 6)
	Fight.pace = 1.0
	var ratio: float = quick["med"] / small["med"]
	_check(int(quick["ends"].get("boatside", 0)) == 6 and ratio > 0.35 and ratio < 0.72,
			"at half the fight length it takes about half as long (%.0f s against %.0f)" % [quick["med"], small["med"]])
	# the rod changing hands
	var a := Arcade.new(150.0, 45.0, 1.0, 9)
	var mem := {}
	var t := 0.0
	while not a.done and a.streak < 4 and t < 200.0:
		_play(a, mem, "good")
		t += DT
	var b := Arcade.new(150.0, a.line_out, a.energy, 10)
	b.bearing = a.bearing
	b.depth = a.depth
	b.carry_on(a.move, a.stretch, a.turn_sign(), a.hold)
	b.arc_load(a.arc_save())
	_check(b.streak == a.streak and b.streak >= 4 and is_equal_approx(b.energy, a.energy) and b.intro > 1.0 and b.grace > 0.0,
			"handed to a crewmate, the streak comes with it (x%d), with a moment to get hands on it" % b.streak)
	var end := ["timeout"]
	b.boatside.connect(func() -> void: end[0] = "boatside")
	b.lost.connect(func(why: String) -> void: end[0] = why)
	mem = {}
	while not b.done and t < 900.0:
		_play(b, mem, "good")
		t += DT
	_check(end[0] == "boatside", "and they land it (%s, %.0f s in all)" % [end[0], t])
	# left in its holder
	var h := Arcade.new(150.0, 45.0, 1.0, 12)
	h.in_holder = true
	t = 0.0
	while not h.done and t < 45.0:
		h.step(DT, 1.0, 0.6, 0.0, 0.6)
		h.bearing = move_toward(wrapf(h.bearing, -PI, PI), 0.0, 0.2 * DT)
		t += DT
	_check(not h.done and h.hold >= 0.99 and h.line_out > 80.0,
			"left in its holder 45 s: the hook's as it was, he's taken line (%.0f m)" % h.line_out)
	await _real_game()
	for fail in fails:
		print("FAIL ", fail)
	print("FIGHT ARCADE TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _play(f: Arcade, mem: Dictionary, style: String) -> void:
	var act := Bot.act(f.view(), DT, style, mem)
	f.pull_btn = float(act["b"])
	f.step(DT, float(act["a"]), 0.6, 0.0, 0.6)
	f.bearing = move_toward(wrapf(f.bearing, -PI, PI), 0.0, 0.2 * DT)


func _many(kg: float, style: String, n: int) -> Dictionary:
	var ends := {}
	var times := []
	var pieces := {}
	var idle := 0.0
	var far := 0.0
	var best := 0
	for s in n:
		var r := Sim.run(kg, 300 + s, style)
		ends[r["end"]] = int(ends.get(r["end"], 0)) + 1
		times.append(int(r["t"]))
		(pieces as Dictionary).merge(r["pieces"])
		idle = maxf(idle, float(r["idle"]))
		far = maxf(far, float(r["far"]))
		best = maxi(best, int(r["best"]))
	times.sort()
	return {"ends": ends, "times": times, "med": float(times[times.size() / 2]), "least": float(times[0]),
			"pieces": pieces, "idle": idle, "far": far, "best": best}


## The real game: a fish on rod 0, taken, fought with the two buttons through rods.gd.
func _real_game() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.head_out("sportfisher")
	await get_tree().process_frame
	sea.schools.set("_next", 9999.0)
	sea.rods.host_cast(0)
	while sea.rods.flying(0):
		await get_tree().process_frame
	sea.rods.strike(0, 60.0)
	var rod = sea.rods.rods[0]
	_check(rod.hooked, "the real game: a 60 kg fish on rod 1")
	await get_tree().create_timer(1.0).timeout
	_check(rod.fight is Arcade and (rod.fight as Arcade).in_holder, "in its holder it's the arcade fight, on its drag")
	sea.crew.me.force_input = true
	sea.rods.request_grab(0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(rod.holder == 1 and rod.fight is Arcade and not (rod.fight as Arcade).in_holder, "taken: the arcade fight in my hands")
	for i in 4:
		await get_tree().process_frame
	var hud: Node = sea.crew.hud.get_node_or_null("FightArcadeHud")
	var old: Node = sea.crew.hud.get_node_or_null("FightHud")
	_check(hud != null and hud.visible and hud.get("_f") == rod.fight, "its HUD's up (%s, showing %.2f)" % [hud, float(hud.get("_a")) if hud != null else -1.0])
	_check(old != null and not bool(old.get("_on")), "and the classic reel plate and coach are away")
	# the host's switch: the classic fight, and back, the fish as it was
	var e0: float = rod.energy
	sea.rods.host_set_arcade(false)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(rod.hooked and rod.fight != null and not (rod.fight is Arcade), "the host's switch: the same fish in the classic fight")
	sea.rods.host_set_arcade(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(rod.hooked and rod.fight is Arcade and absf(rod.energy - e0) < 0.05, "and back in the arcade one, as tired as he was")
	var helm: Node = sea.boat.get("helm")
	var mem := {}
	var moves := {}
	var pitch := Vector2(9.0, -9.0)
	var w := 0.0
	Engine.time_scale = TIME_SCALE
	while rod.hooked and not rod.alongside and w < 500.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		w += dt
		var bb := wrapf(float(rod.bearing), -PI, PI)
		helm.set("heading", float(helm.get("heading")) + clampf(bb * 1.5, -1.0, 1.0) * 0.3 * dt)
		moves[rod.move] = true
		pitch = Vector2(minf(pitch.x, rod.aim_pitch), maxf(pitch.y, rod.aim_pitch))
		if rod.fight is Arcade:
			var act := Bot.act((rod.fight as Arcade).view(), dt, "good", mem)
			_hold("use_primary", float(act["a"]) > 0.5)
			_hold("use_secondary", float(act["b"]) > 0.5)
	_hold("use_primary", false)
	_hold("use_secondary", false)
	Engine.time_scale = 1.0
	_check(rod.alongside and sea.landing.fish.has(rod.index),
			"fought on the two buttons to the boat, up alongside for the harpoon (%.0f s): %s" % [w, ", ".join(moves.keys())])
	_check(moves.size() >= 4, "a run of set-pieces: %s" % ", ".join(moves.keys()))
	_check(pitch.y - pitch.x > 0.5, "the rod was lifted and dropped by them (%.2f .. %.2f)" % [pitch.x, pitch.y])
	await get_tree().process_frame
	_check(hud != null and hud.get("_f") == null, "and its HUD's gone with the fight")


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
