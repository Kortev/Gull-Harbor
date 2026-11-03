extends Node
## A double header: with a fish on out of a feeding school, a second bait across the same school still gets eaten (a
## twelfth of the usual rate: tuna/schools.gd's DOUBLE), while a stray loner hardly ever takes one (LONE). Then two
## fights at once, as the game has them: one rod in your hands (your fight, your reel on the HUD), the other fighting
## on its drag in its holder (the host's), both fish drawn, the crew's shouts and the captain's plotter keeping both,
## both up alongside for the harpoon one after the other.
## Run: godot --headless --fixed-fps 30 --path . res://tests/doubles_test.tscn

const Sea := preload("res://sea/sea.gd")
const Schools := preload("res://tuna/schools.gd")
const FightBot := preload("res://tests/fight_bot.gd")

var fails: Array[String] = []


func _ready() -> void:
	_check(is_equal_approx(Schools.DOUBLE, 0.08) and is_equal_approx(Schools.LONE, 0.015),
			"a second fish while one's on: %.2f of the usual in among the school, %.3f for a stray" % [Schools.DOUBLE,
			Schools.LONE])
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.head_out("sportfisher")
	await get_tree().process_frame
	for r in sea.rods.rods:
		sea.rods._baited(r.index, sea.rods._now(), true)
		sea.rods.host_cast(r.index)
	for r in sea.rods.rods:
		while sea.rods.flying(r.index):
			await get_tree().process_frame
	sea.schools.set("_next", 9999.0)
	# a feeding school sitting right over the spread (working a slick: it eats all round)
	var t: float = sea.schools.now()
	var heart: Vector2 = sea.schools.spread_heart()
	for seed in range(1, 500):
		if Sea.Schools.hash1(float(seed % 1000), 0.0) > 0.4 and Sea.Schools.hash1(float(seed % 977), 3.7) >= Sea.Schools.BAIT_ONLY:
			sea.schools._start(1, seed, t, heart, Vector2(1, 0), 0.0, 300.0)
			break
	var s: Node = sea.schools.schools.back()
	s.set("radius", 45.0)          # (a big one: every bait in the spread over it)
	var first := await _next_hook(sea, [], 40.0)
	_check(first >= 0, "a feeding school over the spread: a bite (rod %d)" % first)
	if first < 0:
		_done()
		return
	# keep him on (in his holder on the drag) and see a second go in among the same school
	var waited := [0.0]
	var second := await _next_hook(sea, [first], 60.0, waited)
	_check(second >= 0 and second != first, "and with him on, a second bait across the school goes: a double header "
			+ "(rod %d, after %.1f s)" % [second, waited[0]])
	for x in sea.schools.schools:
		x.life = 0.0          # (no third)
	if second < 0:
		_done()
		return
	# two fights at once: one in your hands, the other on its drag in its holder
	var rods := sea.rods
	for r in rods.rods:
		if not r.hooked and not r.bait_in:
			rods._host_line(r.index, true)
	rods.request_grab(first)
	var mine = rods.rods[first]
	var other = rods.rods[second]
	sea.crew.me.force_input = true
	var mem := {}
	var out0: float = other.line_out
	var shown := false
	var drawn := true
	var said := ""
	for k in 150:
		await get_tree().process_frame
		if mine.fight != null:
			var act := FightBot.act(mine.fight.cues(), get_process_delta_time(), "good", mem)
			rods.bot_aim = Vector3(float(act["pitch"]), float(act["side"]), 0.0)
			rods.set_drag(mine, float(act["drag"]))
		var hud: Node = rods.get("_fight_hud")
		shown = shown or (hud != null and float(hud.get("_spool")) > 0.0)
		drawn = drawn and is_instance_valid(mine.fish_node) and is_instance_valid(other.fish_node)
		if said.is_empty():
			said = str(rods.crew_says(false, 0.0))
	rods.bot_aim = Vector3(NAN, 0.0, 0.0)
	_check(mine.hooked and other.hooked and mine.holder == 1 and other.holder == 0,
			"two fish on: one in your hands, one in its holder")
	_check(mine.fight != null and not mine.fight.in_holder and other.fight != null and other.fight.in_holder,
			"two fights going: yours on your arms, the other on its drag")
	_check(absf(other.line_out - out0) > 0.5 or other.move != "", "the one in the holder fights on (%.0f m, was %.0f)"
			% [other.line_out, out0])
	_check(shown, "your reel on the HUD")
	_check(drawn, "both fish drawn, out on their lines")
	_check(not said.is_empty(), "the crew's still saying what the fight needs: %s" % said)
	# the captain's plotter: both of them
	var hud_node: Node = sea.crew.hud
	rods.request_return(first)
	await get_tree().create_timer(0.5).timeout
	sea.boat.helm.call("request", true)
	await get_tree().create_timer(0.3).timeout
	var plotted := (hud_node.get("_fish") as Array).size()
	_check(bool(sea.boat.helm.call("is_mine")) and plotted == 2, "at the wheel, the plotter has both of them (%d)" % plotted)
	sea.boat.helm.call("request", false)
	# both beaten: up alongside, one after the other, the harpoon's for each
	rods._host_end(first, "boatside")
	rods._host_end(second, "boatside")
	await get_tree().process_frame
	_check(sea.landing.fish.has(first) and sea.landing.fish.has(second) and mine.alongside and other.alongside,
			"both up alongside for the harpoon")
	_done()


## The next rod hooked that isn't one of `skip` (its index), waiting up to `secs` s (-1: none). waited[0]: how long.
func _next_hook(sea: Sea, skip: Array, secs: float, waited := [0.0]) -> int:
	var w := 0.0
	while w < secs:
		await get_tree().create_timer(0.25).timeout
		w += 0.25
		for r in sea.rods.rods:
			if r.hooked and not skip.has(r.index):
				waited[0] = w
				return r.index
	waited[0] = w
	return -1


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("DOUBLES TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
