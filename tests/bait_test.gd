extends Node
## Live bait only, headless: every boat has the live well, nothing to buy; she heads out with a live mackerel on every
## hook and WELL_START in the well whatever gear she has (so a Rivals day starts even); only a live mackerel ever
## gets bitten (a bare hook, or anything that isn't one, never); a fresh one goes on from the well, and with the well
## empty nothing goes on and you're told to jig; a jigged mackerel goes into the well; and the words the player reads
## (the rod, Dale's tips, the field guide) say so. Run: godot --headless --fixed-fps 30 --path . res://tests/bait_test.tscn

const Sea := preload("res://sea/sea.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const Tips := preload("res://ui/tips.gd")
const Manual := preload("res://ui/manual.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	var rods := sea.rods
	hold.save_path = "user://bluefin_test.cfg"
	_check(not FishHold.GEAR.has("bait"), "no live well for sale: it's standard")
	# out with no gear and out with all of it: the same bait
	hold.gear = []
	hold.head_out("skiff")
	await get_tree().process_frame
	var bare := hold.well
	var all_live := true
	for r in rods.rods:
		all_live = all_live and r.bait_in and r.baited and r.live
	_check(all_live, "a live mackerel on every hook going out")
	_check(bare == FishHold.WELL_START, "and %d in the well with no gear bought" % bare)
	hold.head_in()
	hold.gear = ["reel", "line"]
	hold.head_out("skiff")
	await get_tree().process_frame
	_check(hold.well == bare, "the same with all the gear (%d): both Rivals boats start even" % hold.well)
	# only a live one gets bitten
	rods.host_cast(0)
	rods.host_cast(1)
	while rods.flying(0) or rods.flying(1):
		await get_tree().process_frame
	_check(rods.bite_odds(0) > 0.99, "a fresh live mackerel out: full odds (%.2f)" % rods.bite_odds(0))
	rods.rods[1].live = false
	_check(rods.bite_odds(1) == 0.0, "anything that isn't a live mackerel never gets taken")
	rods.rods[1].live = true
	rods.rods[1].baited = false
	_check(rods.bite_odds(1) == 0.0, "nor a bare hook")
	# a fresh one from the well
	var me: Node = sea.crew.me
	me.hands.pick("bait")
	var was := hold.well
	rods.request_bait(1)
	await _until(func() -> bool: return rods.rods[1].bait_in, 20.0)
	_check(rods.rods[1].baited and rods.rods[1].live and hold.well == was - 1,
			"bait in hand, E on the rod: a live one on from the well (%d left)" % hold.well)
	# the well run dry: nothing goes on, and you're told where bait comes from
	hold.well = 0
	rods.host_cast(1)
	while rods.flying(1):
		await get_tree().process_frame
	rods.rods[1].baited = false
	rods.request_bait(1)
	await get_tree().process_frame
	_check(not rods.rods[1].baited and rods.rods[1].auto_in == 0, "the well empty: no bait goes on")
	var note: String = sea.crew.hud._note.text
	_check(note.contains("empty") and note.contains("Jig"), "and the HUD says to jig: %s" % note)
	_check(str(rods.rods[0].interact_prompt(me)).contains("jig"), "the rod says so too: %s"
			% rods.rods[0].interact_prompt(me))
	# the jig fills it, no gear needed
	sea.boat.helm.set("speed", 0.0)
	sea.jig._last.clear()
	sea.jig._ask_mackerel_as(1)
	_check(hold.well == 1, "a jigged mackerel goes into the well (%d)" % hold.well)
	# the words
	var tips: Dictionary = Tips.TIPS
	_check(tips.has("bait") and str(tips["bait"]).contains("live mackerel") and str(tips["bait"]).contains("3"),
			"Dale says only a live mackerel, and where the jig is: %s" % tips.get("bait", ""))
	_check(tips.has("well") and str(tips["well"]).contains("jig"), "and what to do when the well's empty")
	var guide := ""
	for page: Array in Manual.CHAPTERS:
		guide += str(page[1])
	_check(guide.contains("ONLY A LIVE MACKEREL") and not guide.contains("$1,500"), "the field guide says live bait only")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(hold.save_path))
	_done()


func _until(ok: Callable, limit: float) -> void:
	var t := 0.0
	while not ok.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("BAIT TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
