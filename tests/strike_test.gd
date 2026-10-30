extends Node
## Hooking up and the fight: a feeding school crosses the spread and a bait gets eaten; the line pours off with the
## drag screaming; grab the rod and fight it right (let it run, pump it up when it sounds, crank otherwise, ease off
## as a spiralling fish goes under her, and take a breather when your arms are gone) till it's up alongside for the
## harpoon, with a captain (the test's stand-in, swinging her heading) keeping the stern on it. Run: godot --headless --path . res://tests/strike_test.tscn

const Sea := preload("res://sea/sea.gd")

const FightBot := preload("res://tests/fight_bot.gd")
var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.head_out("sportfisher")           # (off the dock: nothing bites there)
	await get_tree().process_frame
	for r in sea.rods.rods:
		sea.rods.host_cast(r.index)                 # (the crew cast every bait out: tests/cast_test.tscn)
	for r in sea.rods.rods:
		while sea.rods.flying(r.index):
			await get_tree().process_frame          # (and they've landed)
	sea.schools.set("_next", 9999.0)
	# a school right on the spread, crawling along it (seeded so it feeds early)
	var t: float = sea.schools.now()
	var aim: Vector3 = sea.rods.rods[0].line_end
	for seed in range(1, 500):
		if Sea.Schools.hash1(float(seed % 1000), 0.0) > 0.4 and Sea.Schools.hash1(float(seed % 977), 3.7) >= Sea.Schools.BAIT_ONLY:
			sea.schools._start(1, seed, t, Vector2(aim.x - 3.0, aim.z), Vector2(1, 0), 0.4, 200.0)
			break
	var hooked := -1
	var waited := 0.0
	while hooked < 0 and waited < 40.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
		for r in sea.rods.rods:
			if r.hooked:
				hooked = r.index
	_check(hooked >= 0, "a feeding school over the spread got a bite (after %.1f s)" % waited)
	for s in sea.schools.schools:
		s.life = 0.0          # (one fish: no second one or tangles from it while this one's fought)
	if hooked < 0:
		_done()
		return
	var rod = sea.rods.rods[hooked]
	var out0: float = rod.line_out
	await get_tree().create_timer(2.0).timeout
	_check(rod.line_out > out0 + 8.0, "the fish runs: %.0f m of line gone in 2 s" % (rod.line_out - out0))
	_check(rod._scream.playing, "the drag screams")
	_check(rod.strain > 0.65, "the rod's bent double (strain %.2f)" % rod.strain)
	# like a player: clear the other lines first (E on each), so the running fish can't tangle them
	for r in sea.rods.rods:
		if r.index != hooked and not r.bait_in:
			sea.rods._host_line(r.index, true)
	sea.crew.me.force_input = true
	sea.rods.request_grab(hooked)
	_check(rod.holder == 1, "grabbed it")
	var w := 0.0
	var moves := {}
	var helm: Node = sea.boat.get("helm")
	var mem := {}
	while rod.hooked and not rod.alongside and w < 900.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		w += dt
		var b := wrapf(float(rod.bearing), -PI, PI)
		helm.set("heading", float(helm.get("heading")) + clampf(b * 1.5, -1.0, 1.0) * 0.3 * dt)
		moves[rod.move] = true
		# a test angler reading the rod, the reel and the line (tests/fight_bot.gd) in place of the mouse
		if rod.fight != null:
			var act := FightBot.act(rod.fight.cues(), dt, "good", mem)
			sea.rods.bot_aim = Vector3(float(act["pitch"]), float(act["side"]), 0.0)
			_hold("use_primary", float(act["crank"]) > 0.5)
	_hold("use_primary", false)
	sea.rods.bot_aim = Vector3(NAN, 0.0, 0.0)
	_check(moves.has("run") and moves.size() >= 3, "it fought: %s" % ", ".join(moves.keys()))
	_check(rod.alongside and sea.landing.fish.has(rod.index),
			"fought it to the boat, up alongside for the harpoon (%.0f s): %s" % [w, sea.crew.hud._note.text])
	_done()


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("STRIKE TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
