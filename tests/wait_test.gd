extends Node
## While you wait for a bite: a bait goes off and gets changed, the live well's mackerel go on as bait and the jig
## fills it again, and chum brings a school up the slick and keeps it there. Run: godot --headless --path .
## res://tests/wait_test.tscn

const Sea := preload("res://sea/sea.gd")
const Rods := preload("res://rods/rods.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const Schools := preload("res://tuna/schools.gd")

var fails: Array[String] = []


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	var rods := sea.rods
	_check(hold.docked and hold.chum == 0, "at the dock: no chum out yet")
	# nothing bites at the dock
	sea.schools._start(50, 7, sea.schools.now(), Vector2(rods.rods[0].line_end.x, rods.rods[0].line_end.z),
			Vector2(1, 0), 0.0, 300.0, 300.0)
	await get_tree().create_timer(3.0).timeout
	var any := false
	for r in rods.rods:
		any = any or r.hooked
	_check(not any, "a school right on the baits at the dock: nothing bites")
	sea.schools.schools[0].life = 0.0
	await get_tree().process_frame
	# out with the well: four live mackerel, and the spread baited with them
	hold.gear = ["bait"]
	hold.head_out("skiff")
	await get_tree().create_timer(0.3).timeout
	_check(hold.chum == FishHold.CHUM, "a full chum bucket going out (%d)" % hold.chum)
	_check(rods.rods[0].live and rods.rods[1].live and hold.well == FishHold.WELL_START - 2,
			"the skiff's two baits are live mackerel, two left in the well (%d)" % hold.well)
	_check(is_equal_approx(rods.freshness(0), 1.0) or rods.freshness(0) > 0.99, "fresh on")
	var fresh_odds: float = rods.bite_odds(0)
	# a bait goes off
	rods.rods[0].baited_t -= Rods.LIVE_LIFE * 0.8
	_check(rods.freshness(0) < Rods.STALE and rods.bite_odds(0) < fresh_odds * 0.5,
			"an old bait gets fewer bites (%.2f against %.2f)" % [rods.bite_odds(0), fresh_odds])
	_check(rods.hint().contains("washed out"), "the HUD says so")
	_check(rods.rebait_prompt(0).begins_with("Rebait"), "and the rod's prompt is to rebait it")
	rods._ask_grab(0)
	await get_tree().process_frame
	_check(rods.rods[0].bait_in and rods.rods[0].holder == 0, "E on it reels it in (not picked up)")
	await get_tree().create_timer(Rods.REBAIT + 0.5).timeout
	_check(not rods.rods[0].bait_in and rods.freshness(0) > 0.95 and rods.rods[0].live,
			"and a fresh live one goes back out")
	_check(hold.well == FishHold.WELL_START - 3, "out of the well (%d left)" % hold.well)
	# the jig fills the well, not while she's under way, and not past full
	var helm: Node = sea.boat.helm
	sea.jig._ask_mackerel_as(1)
	_check(hold.well == FishHold.WELL_START - 2, "a jigged mackerel into the well")
	sea.jig._ask_mackerel_as(1)
	_check(hold.well == FishHold.WELL_START - 2, "not another straight away")
	sea.jig._last.clear()
	helm.set("speed", 5.0)
	sea.jig._ask_mackerel_as(1)
	_check(hold.well == FishHold.WELL_START - 2, "not under way")
	helm.set("speed", 0.0)
	hold.well = FishHold.WELL_MAX
	sea.jig._ask_mackerel_as(1)
	_check(hold.well == FishHold.WELL_MAX, "not past a full well")
	# chum: a school 350 m off comes up the slick and stays on it, working
	var t: float = sea.schools.now()
	var at: Vector2 = helm.get("at")
	sea.schools._start(60, 11, t, at + Vector2(350.0, 0.0), Vector2(0, 1), 1.5, 200.0, 200.0)
	var s = sea.schools.schools[sea.schools.schools.size() - 1]
	sea.chum._ask_scoop_as(1)
	_check(hold.chum == FishHold.CHUM - 1, "a scoop out of the bucket")
	sea.chum._ask_scoop_as(1)
	_check(hold.chum == FishHold.CHUM - 1, "not two at once")
	var slick: Vector2 = sea.schools.slick
	_check(slick.distance_to(at) < 60.0, "the slick's back among the baits (%.0f m off)" % slick.distance_to(at))
	_check(s.drawn_to == slick and s.speed == Schools.DRAW, "the school smells it and comes")
	var arrive: float = t + s.run + 1.0
	_check(s.center(arrive).distance_to(slick) < 13.0, "it gets there (%.1f m off)" % s.center(arrive).distance_to(slick))
	_check(s.center(arrive + 200.0).distance_to(slick) < 13.0, "and stays on it")
	_check(s.t0 + s.life > arrive + Schools.STAY - 1.0, "working it a while after it gets there")
	# the chum running out: it stops
	hold.chum = 0
	sea.chum._last = -1e9
	sea.chum._ask_scoop_as(1)
	_check(hold.chum == 0, "an empty bucket")
	_done()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("WAIT TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)
