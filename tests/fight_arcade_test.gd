extends Node
## The arcade fight (tuna/fight_arcade.gd and its minigames, tuna/minigames/), headless: test anglers
## (tests/fight_arcade_bot.gd) who ask each game what the right input is (its hint()).
## - Every game in the registry: begun at three tiers, played to its end by the hint with a high score and by no
##   input with a low one, the same again from the same seed, its variants playable, and drawn without error.
## - Whole fights: a good angler lands a 60 kg fish in a couple of minutes and a 300 kg one in seven to twelve; hands
##   off loses him, but not at once; a sloppy one still lands most small fish. In a giant's fight no game comes twice
##   running, at least ten different ones come up, bosses are met and BIG PULLs are had.
## - The sequencer: a game that runs past its cap is swapped out and scored on what was done; a miss halves the combo;
##   the fifth step of the combo gives a BIG PULL, which can't be failed and hauls him in fast but never in a jump.
## - What the rest of the game relies on: cues() has its keys; the host's fight length (Fight.pace) halves it; a rod
##   changing hands carries the combo; left in its holder the fish isn't lost to the hook.
## - Then the real game: a fish struck, the rod taken, fought on the two buttons through rods.gd to boatside, with the
##   new HUD up and its sounds climbing, and the classic one away; and the host's switch back to the classic.
## Run: godot --headless --fixed-fps 30 --path . tests/fight_arcade_test.tscn

const Sea := preload("res://sea/sea.gd")
const Fight := preload("res://tuna/fight.gd")
const Arcade := preload("res://tuna/fight_arcade.gd")
const Minigame := preload("res://tuna/minigames/minigame.gd")
const Games := preload("res://tuna/minigames/all.gd")
const Pull := preload("res://tuna/minigames/pull.gd")
const Kit := preload("res://ui/kit.gd")
const Bot := preload("res://tests/fight_arcade_bot.gd")
const Sim := preload("res://tests/fight_arcade_sim.gd")
const TIME_SCALE := 2.0
const DT := 1.0 / 30.0

var fails: Array[String] = []
var _to_draw: Array = []
var _drawn := 0


## A game that never ends and never scores more than it's given (for the cap).
class Stuck:
	extends Minigame

	func _init() -> void:
		id = "stuck"
		length = 999.0


func _ready() -> void:
	Fight.arcade = true
	Fight.pace = 1.0
	Arcade.force_piece = ""
	await _every_game()
	# a good angler
	var small := _many(60.0, "good", 8)
	_check(int(small["ends"].get("boatside", 0)) == 8, "a good angler lands every 60 kg fish (%s)" % str(small["ends"]))
	_check(small["med"] >= 90.0 and small["med"] <= 180.0, "in a minute and a half to three (%.0f s, %s)" % [small["med"], str(small["times"])])
	var giant := _many(300.0, "good", 5)
	_check(int(giant["ends"].get("boatside", 0)) == 5, "and every 300 kg one (%s)" % str(giant["ends"]))
	_check(giant["med"] >= 420.0 and giant["med"] <= 720.0, "in seven to twelve minutes (%.0f s, %s)" % [giant["med"], str(giant["times"])])
	_check(int(giant["twice"]) == 0 and int(small["twice"]) == 0, "no game ever comes twice running (%d times)" % (int(giant["twice"]) + int(small["twice"])))
	_check(int(giant["kinds"]) >= 10, "at least ten different games in every giant's fight (the fewest: %d)" % int(giant["kinds"]))
	_check(giant["idle"] < 3.0 and small["idle"] < 3.0, "never long with nothing to do (the longest breath %.1f s)" % maxf(giant["idle"], small["idle"]))
	_check(giant["longest"] <= Arcade.CAP_BOSS + 0.1, "no game runs past the cap (the longest %.1f s)" % giant["longest"])
	_check(int(giant["pulls"]) >= 5 and int(small["pulls"]) >= 1, "played well, the combo's cashed in for BIG PULLs (%d in a 60 kg fight, %d in a giant's; a combo of x%d)"
			% [small["pulls"], giant["pulls"], giant["best"]])
	_check(int(giant["bosses"]) >= 3, "and each stage ends on a boss (%d won in a giant's fight)" % int(giant["bosses"]))
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
	var sloppy_giant := _many(300.0, "sloppy", 4)
	print("     (a sloppy angler on 300 kg fish: %s, %.0f s)" % [str(sloppy_giant["ends"]), sloppy_giant["med"]])
	_sequencer()
	# the cues the music, the reel and the crew read
	var f := Arcade.new(150.0, 45.0, 1.0, 5)
	f.step(DT, 0.0, 0.6, 0.0, 0.6)
	var c := f.cues()
	var missing := []
	for key: String in ["tension", "spool", "line_out", "slack", "airborne", "surging", "contact", "props", "tangled",
			"paying", "bend", "slipping", "grinding", "bearing", "angle", "arms", "leader", "drag", "holder", "visible",
			"jumping", "charging", "thrash", "arcade"]:
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
	while not a.done and a.combo < 4 and t < 200.0:
		_play(a, mem, "good")
		t += DT
	var b := Arcade.new(150.0, a.line_out, a.energy, 10)
	b.bearing = a.bearing
	b.depth = a.depth
	b.carry_on(a.move, a.stretch, a.turn_sign(), a.hold)
	b.arc_load(a.arc_save())
	_check(b.combo == a.combo and b.combo >= 4 and b.best == a.best and b.games_done == a.games_done and b.next_pull() == a.next_pull()
			and is_equal_approx(b.energy, a.energy) and b.game == null and b.breath > 1.0 and b.grace > 0.0,
			"handed to a crewmate, the combo comes with it (x%d, %d games in), with a moment to get hands on it" % [b.combo, b.games_done])
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
	_check(not h.done and h.hold >= 0.99 and h.line_out > 80.0 and h.game == null,
			"left in its holder 45 s: nobody's playing, the hook's as it was, he's taken line (%.0f m)" % h.line_out)
	await _real_game()
	for fail in fails:
		print("FAIL ", fail)
	print("FIGHT ARCADE TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


## One game played to its end: by its hint, or hands off. -> [score, s, events]
func _one(id: String, tier: float, v: Dictionary, hands: bool, seed_value := 77) -> Array:
	var g := Games.make(id)
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	g.begin(tier, r, v)
	var aw := false
	var bw := false
	var n := 0
	while not g.done and g.t < 40.0:
		var hint := g.hint() if hands else {"a": false, "b": false}
		var a := bool(hint["a"])
		var b := bool(hint["b"])
		g.step(DT, a, b, a and not aw, b and not bw)
		aw = a
		bw = b
		n += g.events.size()
		# (and what it says it's doing to the fish stays where it's meant to)
		if absf(g.gain) > 1.001 or g.tire < -0.001 or g.tire > 1.001 or g.tension < 0.0 or g.tension > 1.0:
			return [-1.0, g.t, n]
	return [g.score, g.t, n]


## Every game in the registry, alone.
func _every_game() -> void:
	var ids := Games.ids()
	_check(ids.size() >= 12, "the registry has its games (%d: %s)" % [ids.size(), ", ".join(ids)])
	var about := Games.about()
	var low_hint := []
	var high_none := []
	var long := []
	var unsure := []
	var variants := []
	for id: String in ids:
		var g0 := about[id] as Minigame
		if g0.title == "" or g0.id != id:
			unsure.append(id + " (no title)")
		for tier: float in [0.0, 0.5, 1.0]:
			var good := _one(id, tier, {}, true)
			var none := _one(id, tier, {}, false)
			var again := _one(id, tier, {}, true)
			if float(good[0]) < 0.85:
				low_hint.append("%s@%.1f %.2f" % [id, tier, good[0]])
			if float(none[0]) > 0.45 or float(none[0]) < 0.0:
				high_none.append("%s@%.1f %.2f" % [id, tier, none[0]])
			if float(good[1]) > Arcade.CAP or float(good[1]) < 1.5:
				long.append("%s@%.1f %.1f s" % [id, tier, good[1]])
			if good != again:
				unsure.append("%s@%.1f %s then %s" % [id, tier, good, again])
			for v: Dictionary in [{"mirror": true}, {"fast": 1.2}, {"twist": true}, {"boss": true}]:
				var var_run := _one(id, tier, v, true, 78)
				if float(var_run[0]) < 0.6 or float(var_run[1]) > Arcade.CAP_BOSS:
					variants.append("%s@%.1f %s %.2f %.1f s" % [id, tier, v.keys()[0], var_run[0], var_run[1]])
	_check(low_hint.is_empty(), "every game, at tiers 0, 0.5 and 1: played by its hint, a high score (low: %s)" % str(low_hint))
	_check(high_none.is_empty(), "hands off, a low one (high: %s)" % str(high_none))
	_check(long.is_empty(), "each over in a few seconds (%s)" % str(long))
	_check(unsure.is_empty(), "the same seed plays the same game (%s)" % str(unsure))
	_check(variants.is_empty(), "mirrored, faster, with its twist and as a boss they still play (%s)" % str(variants))
	# drawn: every game at each tier, part-way through, and the BIG PULL, onto a real canvas
	_to_draw = []
	for id: String in ids + ["pull"]:
		for tier: float in [0.0, 0.5, 1.0]:
			for part: float in [0.1, 0.5, 0.9]:
				var g: Minigame = Games.make(id) if id != "pull" else Pull.new()
				var r := RandomNumberGenerator.new()
				r.seed = 5
				g.begin(tier, r, {"twist": part > 0.6, "mirror": part > 0.8})
				var aw := false
				var bw := false
				var stop := g.length * part if id in ["ride", "jump", "pump", "dog", "charge", "laps", "steady", "tug", "beats", "lanes", "twohands"] else 6.0 * part
				while not g.done and g.t < stop:
					var hint := g.hint() if part < 0.8 else {"a": false, "b": false}
					g.step(DT, bool(hint["a"]), bool(hint["b"]), bool(hint["a"]) and not aw, bool(hint["b"]) and not bw)
					aw = bool(hint["a"])
					bw = bool(hint["b"])
				_to_draw.append(g)
				var cue := g.cue()
				if cue.size() != 2:
					unsure.append(id + " cue")
	var canvas := Control.new()
	canvas.size = Vector2(1152, 648)
	canvas.draw.connect(_draw_all.bind(canvas))
	add_child(canvas)
	_drawn = 0
	for i in 4:
		await get_tree().process_frame
	_check(_drawn == _to_draw.size(), "every game draws itself without error (%d of %d drawn)" % [_drawn, _to_draw.size()])
	canvas.queue_free()


func _draw_all(canvas: Control) -> void:
	if _drawn > 0:
		return
	var kit := Kit.new()
	for g: Minigame in _to_draw:
		g.draw(canvas, Rect2(400, 300, 230, 96), kit, 1.3)
		_drawn += 1
	for side in 2:
		for cue: int in [Kit.NONE, Kit.HOLD, Kit.TAP, Kit.MASH, Kit.RELEASE, Kit.OFF]:
			kit.button(canvas, Vector2(100, 100), 46.0, side, cue, 0.4, side == 0, cue == Kit.TAP)


## The sequencer's own rules, on fights set up by hand.
func _sequencer() -> void:
	# a game that runs past its cap is swapped for the next, scored on what was done
	var f := Arcade.new(150.0, 60.0, 1.0, 3)
	for i in 40:
		f.step(DT, 0.0, 0.6, 0.0, 0.6)
	var stuck := Stuck.new()
	stuck.begin(0.5, f.rng, {})
	stuck.score = 0.7
	f.game = stuck
	f.combo = 2
	f.take_events()
	var t := 0.0
	while f.game == stuck and t < 20.0:
		f.step(DT, 0.0, 0.6, 0.0, 0.6)
		t += DT
	var got := ""
	for e: Array in f.take_events():
		if e[0] == "grade" and e[3] == "stuck":
			got = str(e[1])
	_check(f.game != stuck and t >= Arcade.CAP - 0.1 and t < Arcade.CAP + 0.5 and got == "great" and f.combo == 3,
			"a game held past its cap (%.1f s) is swapped out, scored on what was done so far (%s, the combo x%d)" % [t, got, f.combo])
	while f.game == null:
		f.step(DT, 0.0, 0.6, 0.0, 0.6)
	_check(f.game != null and f.game.id != "stuck", "and the next one's on after a breath (%s)" % f.game.id)
	# a miss halves the combo, never to nothing at once
	f.combo = 9
	f.game.done = true
	f.game.score = 0.0
	f.step(DT, 0.0, 0.6, 0.0, 0.6)
	_check(f.combo == 4 and f.grade == "miss", "a miss halves the combo (x9 to x%d)" % f.combo)
	# the fifth step: a BIG PULL, which can't be failed
	for hands: bool in [true, false]:
		var p := Arcade.new(150.0, 120.0, 1.0, 4)
		for i in 40:
			p.step(DT, 0.0, 0.6, 0.0, 0.6)
		p.combo = 4
		p.game.done = true
		p.game.score = 1.0
		p.step(DT, 0.0, 0.6, 0.0, 0.6)
		var ready := false
		for e: Array in p.take_events():
			ready = ready or e[0] == "pull_ready"
		while p.game == null:
			p.step(DT, 0.0, 0.6, 0.0, 0.6)
		var is_pull := p.game is Pull
		var out0 := p.line_out
		var metres := 0.0
		var worst := 0.0
		t = 0.0
		var mem := {}
		while p.game is Pull and t < 6.0:
			var was := p.line_out
			if hands:
				_play(p, mem, "good")
			else:
				p.step(DT, 0.0, 0.6, 0.0, 0.6)
			worst = maxf(worst, (was - p.line_out) / DT)
			t += DT
			for e: Array in p.take_events():
				if e[0] == "pull":
					metres = float(e[1])
		_check(p.combo == 5 and ready and is_pull and metres >= Arcade.PULL_M and out0 - p.line_out > metres * 0.85,
				"at x5 a BIG PULL, %s: %.0f m of line in %.1f s (%.0f m to %.0f m)" % ["pressed" if hands else "left alone (it goes by itself)",
				metres, t, out0, p.line_out])
		_check(worst <= Arcade.PULL_RATE + Arcade.HAUL_RATE + 6.0, "and he comes in fast but never in a jump (%.0f m/s at the most)" % worst)


func _play(f: Arcade, mem: Dictionary, style: String) -> void:
	var act := Bot.act(f, DT, style, mem)
	f.pull_btn = float(act["b"])
	f.step(DT, float(act["a"]), 0.6, 0.0, 0.6)
	f.bearing = move_toward(wrapf(f.bearing, -PI, PI), 0.0, 0.2 * DT)


func _many(kg: float, style: String, n: int) -> Dictionary:
	var ends := {}
	var times := []
	var idle := 0.0
	var far := 0.0
	var best := 0
	var twice := 0
	var kinds := 99
	var pulls := 99
	var bosses := 99
	var longest := 0.0
	for s in n:
		var r := Sim.run(kg, 300 + s, style)
		ends[r["end"]] = int(ends.get(r["end"], 0)) + 1
		times.append(int(r["t"]))
		idle = maxf(idle, float(r["idle"]))
		far = maxf(far, float(r["far"]))
		best = maxi(best, int(r["best"]))
		twice += int(r["twice"])
		kinds = mini(kinds, (r["games"] as Dictionary).size())
		pulls = mini(pulls, int(r["pulls"]))
		bosses = mini(bosses, int((r["bosses"] as Array)[0]))
		longest = maxf(longest, float(r["longest"]))
	times.sort()
	return {"ends": ends, "times": times, "med": float(times[times.size() / 2]), "least": float(times[0]),
			"idle": idle, "far": far, "best": best, "twice": twice, "kinds": kinds, "pulls": pulls, "bosses": bosses,
			"longest": longest}


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
	_check(rod.fight is Arcade and (rod.fight as Arcade).in_holder and (rod.fight as Arcade).game == null,
			"in its holder it's the arcade fight, on its drag, nobody playing")
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
	_check(Arcade.beat_fn.is_valid() and (Arcade.beat_fn.call() as Array).size() == 2, "the games can ask it for the music's beat")
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
	var games := {}
	var pitch := Vector2(9.0, -9.0)
	var w := 0.0
	var best := 0
	Engine.time_scale = TIME_SCALE
	while rod.hooked and not rod.alongside and w < 900.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		w += dt
		var bb := wrapf(float(rod.bearing), -PI, PI)
		helm.set("heading", float(helm.get("heading")) + clampf(bb * 1.5, -1.0, 1.0) * 0.3 * dt)
		pitch = Vector2(minf(pitch.x, rod.aim_pitch), maxf(pitch.y, rod.aim_pitch))
		var f := rod.fight as Arcade
		if f != null:
			var act := Bot.act(f, dt, "good", mem)
			_hold("use_primary", float(act["a"]) > 0.5)
			_hold("use_secondary", float(act["b"]) > 0.5)
			best = maxi(best, f.best)
			if f.game != null:
				games[f.game.id] = true
	_hold("use_primary", false)
	_hold("use_secondary", false)
	Engine.time_scale = 1.0
	_check(rod.alongside and sea.landing.fish.has(rod.index),
			"fought on the two buttons to the boat, up alongside for the harpoon (%.0f s): %s" % [w, ", ".join(games.keys())])
	_check(games.size() >= 5, "a run of different games (%d)" % games.size())
	_check(pitch.y - pitch.x > 0.5, "the rod was lifted and dropped by them (%.2f .. %.2f)" % [pitch.x, pitch.y])
	var ticks := {}
	var played: Array = hud.get("juice").get("played") if hud != null else []
	for p: Array in played:
		if p[0] == "ui.tick":
			ticks[snappedf(float(p[1]), 0.01)] = true
	_check(ticks.size() >= 3, "its hits rang up a ladder of pitches (%d of them; a combo of x%d)" % [ticks.size(), best])
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
