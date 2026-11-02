extends Node
## While you wait for a bite: a bait goes off and gets changed (wound in by hand, a fresh one netted out and hooked
## on), the live well's mackerel go on as bait and the jig fills it again (full, on ice), and chum brings a school up the slick and keeps it there. Run: godot --headless --path .
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
	sea.schools._start(50, 11, sea.schools.now(), Vector2(rods.rods[0].line_end.x, rods.rods[0].line_end.z),
			Vector2(1, 0), 0.0, 300.0, 300.0)
	await get_tree().create_timer(3.0).timeout
	var any := false
	for r in rods.rods:
		any = any or r.hooked
	_check(not any, "a school right on the baits at the dock: nothing bites")
	sea.schools.schools[0].life = 0.0
	await get_tree().process_frame
	# out (no gear bought: every boat has the well): a mackerel for every hook in it and four more, every hook bare,
	# every line in for the crew to bait and send out
	hold.gear = []
	hold.head_out("skiff")
	await get_tree().create_timer(0.3).timeout
	for r in rods.rods:
		rods._host_line(r.index, true)      # (in the game her lines are in at the dock; a test's sea starts them out)
		rods._unbaited(r.index)
	_check(hold.chum == FishHold.CHUM, "a full chum bucket going out (%d)" % hold.chum)
	var n := rods.rods.size()
	_check(rods.rods[0].bait_in and not rods.rods[0].baited and hold.well == FishHold.WELL_START + n,
			"lines in, bare hooks, a mackerel for each and four more in the well (%d)" % hold.well)
	# a mackerel out of the well and hooked on each rod (rods/rig.gd's press: tests/bait_test)
	var me: Node = sea.crew.me
	await _bait(rods, me, 0)
	await _bait(rods, me, 1)
	_check(rods.rods[0].live and rods.rods[1].live and hold.well == FishHold.WELL_START,
			"one netted out and hooked on each rod: %d left in the well" % hold.well)
	rods.host_cast(0)
	rods.host_cast(1)
	while rods.flying(0) or rods.flying(1):
		await get_tree().process_frame
	_check(rods.freshness(0) > 0.99, "fresh on")
	var fresh_odds: float = rods.bite_odds(0)
	# a bait goes off
	rods.rods[0].baited_t -= Rods.LIVE_LIFE * 0.8
	_check(rods.freshness(0) < Rods.STALE and rods.bite_odds(0) < fresh_odds * 0.5,
			"an old bait gets fewer bites (%.2f against %.2f)" % [rods.bite_odds(0), fresh_odds])
	# wound in by hand, a fresh one on
	me.force_input = true
	rods.request_grab(0)
	Input.action_press("use_primary")
	for k in 120:
		await get_tree().create_timer(0.25).timeout
		if rods.rods[0].bait_in:
			break
	Input.action_release("use_primary")
	rods.request_return(0)
	me.force_input = false
	await _bait(rods, me, 0)
	_check(rods.rods[0].bait_in and rods.rods[0].holder == 0 and rods.freshness(0) > 0.95 and rods.rods[0].live,
			"wound in by hand and a fresh live one on")
	_check(hold.well == FishHold.WELL_START - 1, "out of the well (%d left)" % hold.well)
	# the jig fills the well, not while she's under way; full, on ice for dead bait
	var helm: Node = sea.boat.helm
	sea.jig._ask_mackerel_as(1)
	_check(hold.well == FishHold.WELL_START, "a jigged mackerel into the well")
	sea.jig._ask_mackerel_as(1)
	_check(hold.well == FishHold.WELL_START, "not another straight away")
	sea.jig._last.clear()
	helm.set("speed", 5.0)
	sea.jig._ask_mackerel_as(1)
	_check(hold.well == FishHold.WELL_START, "not under way")
	helm.set("speed", 0.0)
	hold.well = FishHold.WELL_MAX
	var dead := hold.dead
	sea.jig._ask_mackerel_as(1)
	_check(hold.well == FishHold.WELL_MAX and hold.dead == dead + 1, "not past a full well: on ice instead")
	# a school near her baits doesn't come to them: it goes its own way (putting the baits across its head is her job)
	var at0: Vector2 = helm.get("at")
	sea.schools._start(55, 11, sea.schools.now(), at0 + Vector2(0.0, -90.0), Vector2(1, 0), 1.5, 200.0, 200.0)
	var near = sea.schools.schools[sea.schools.schools.size() - 1]
	sea.schools._drawing()
	_check(near.drawn_to == Vector2.INF and near.heading == Vector2(1, 0),
			"a school 90 m off goes its own way, not to her baits")
	near.life = 0.0
	await get_tree().process_frame
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
	# the quota: made on its last day, a bigger one; missed, the bank takes the boat and a new run starts
	hold.day = FishHold.DAYS
	hold.earned = 0
	hold.quota = 100
	hold.fish = [{"id": 99, "kg": 100.0, "fight_s": 100.0, "aboard_t": 0.0, "bled_s": 10.0, "iced_s": 20.0, "spot": 0}]
	hold.head_in()
	hold.host_sell_all()      # (the buyer's scale: the last fish sold, the day's settled)
	_check(str(hold.sale["verdict"]) == "met" and hold.quota_n == 2 and hold.day == 1
			and hold.quota == FishHold.quota_for(2) and hold.earned == 0, "quota made: the next one's bigger")
	hold.head_out("skiff")
	_check(not hold.docked and hold.day == 1, "out on day 1 of the next")
	hold.head_in()
	_check(hold.day == 2 and str(hold.sale["verdict"]).is_empty(), "a day without the last: day 2")
	hold.head_out("skiff")
	hold.day = FishHold.DAYS
	hold.gear = ["bait", "reel"]
	hold.head_in()
	_check(str(hold.sale["verdict"]) == "lost" and hold.quota_n == 1 and hold.bank == FishHold.START_CASH
			and hold.gear.is_empty() and int(hold.sale["run"]["quotas"]) == 1,
			"missed: the bank takes the boat, a fresh run (%s)" % str(hold.sale.get("run", {})))
	_check(hold.best_run == 1, "the best run's kept")
	_done()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("WAIT TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


## A mackerel netted out of the well and hooked on rod i (its line in).
func _bait(rods: Node, me: Node, i: int) -> void:
	rods.request_take_bait()
	await get_tree().process_frame
	rods.request_bait(i, str(me.hands.carrying()), 1.0)
	me.hands.carry("")
	await get_tree().process_frame
