extends Node
## Hooking up: a feeding school crosses the spread and a bait gets eaten; the line pours off with the drag
## screaming; grab the rod and crank it in to the boat. Run: godot --headless --path . res://tests/strike_test.tscn

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
	Input.action_press("use_primary")
	var w := 0.0
	while rod.hooked and w < 90.0:
		await get_tree().create_timer(0.5).timeout
		w += 0.5
	Input.action_release("use_primary")
	_check(not rod.hooked, "cranked it to the boat (%.0f s)" % w)
	_done()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("STRIKE TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
