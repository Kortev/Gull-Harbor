extends Node
## Hooking up and the fight: a feeding school crosses the spread and a bait gets eaten; the line pours off with the
## drag screaming; grab the rod and fight it right (let it run, pump it up when it sounds, crank otherwise) till it's
## boatside, with a captain (the test's stand-in, swinging her heading) keeping the stern on it. Run: godot --headless --path . res://tests/strike_test.tscn

const Sea := preload("res://sea/sea.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout      # (the rods have put their baits out)
	sea.schools.set("_next", 9999.0)
	# a school right on the spread, crawling along it (seeded so it feeds early)
	var t: float = sea.schools.now()
	var aim: Vector3 = sea.rods.rods[0].line_end
	for seed in range(1, 500):
		if Sea.Schools.hash1(float(seed % 1000), 0.0) > 0.4:
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
	if hooked < 0:
		_done()
		return
	var rod = sea.rods.rods[hooked]
	var out0: float = rod.line_out
	await get_tree().create_timer(2.0).timeout
	_check(rod.line_out > out0 + 8.0, "the fish runs: %.0f m of line gone in 2 s" % (rod.line_out - out0))
	_check(rod._scream.playing, "the drag screams")
	_check(rod.strain > 0.8, "the rod's bent double (strain %.2f)" % rod.strain)
	sea.crew.me.force_input = true
	sea.rods.request_grab(hooked)
	_check(rod.holder == 1, "grabbed it")
	var w := 0.0
	var moves := {}
	var helm: Node = sea.boat.get("helm")
	while rod.hooked and w < 400.0:
		await get_tree().process_frame
		w += get_process_delta_time()
		var b := wrapf(float(rod.bearing), -PI, PI)
		helm.set("heading", float(helm.get("heading")) + clampf(b * 1.5, -1.0, 1.0) * 0.3 * get_process_delta_time())
		moves[rod.move] = true
		var ans: String = rod.fight.answer() if rod.fight != null else "reel"
		var lift := ans == "pump" and fmod(w, 2.5) < 1.0
		_hold("use_secondary", lift)
		_hold("use_primary", ans == "reel" or ans == "tight" or (ans == "pump" and not lift))
	_hold("use_primary", false)
	_hold("use_secondary", false)
	_check(moves.has("run") and moves.size() >= 3, "it fought: %s" % ", ".join(moves.keys()))
	_check(not rod.hooked and rod.line_out == 0.0 and sea.crew.hud._note.text.begins_with("Boatside"),
			"fought it to the boat (%.0f s): %s" % [w, sea.crew.hud._note.text])
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
