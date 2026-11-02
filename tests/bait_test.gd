extends Node
## Baiting by hand, headless: she heads out with every hook bare and a mackerel for each in the well (WELL_START more on
## top, whatever gear she has, so a Rivals day starts even); a bare hook never gets taken; a bait's netted out of the
## live well into your fist (a live one, or a dead one off the ice once there's no live one), stays there (no pocket:
## you can't pick up the knife) till it's hooked on or put back; hooking it is a press as the point comes to its nose
## (rods/rig.gd): clean, crooked (swims poorly, fewer bites), dead (through the eyes) or slipped off (again); a dead
## bait gets taken least; the jig fills the well, and with it full a mackerel goes on ice; and the words the player
## reads say so. Run: godot --headless --fixed-fps 30 --path . res://tests/bait_test.tscn

const Sea := preload("res://sea/sea.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const Tips := preload("res://ui/tips.gd")
const Manual := preload("res://ui/manual.gd")
const Rig := preload("res://rods/rig.gd")

var fails: Array[String] = []
var sea: Sea


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	var rods := sea.rods
	hold.save_path = "user://bluefin_test.cfg"
	_check(not FishHold.GEAR.has("bait"), "no live well for sale: it's standard")
	# out with no gear and out with all of it: the same bait, every hook bare
	hold.gear = []
	hold.head_out("skiff")
	await get_tree().process_frame
	for r in rods.rods:
		rods._host_line(r.index, true)      # (in the game her lines are in at the dock; a test's sea starts them out)
		rods._unbaited(r.index)
	await get_tree().process_frame
	var bare := hold.well
	var all_bare := true
	for r in rods.rods:
		all_bare = all_bare and r.bait_in and not r.baited
	_check(all_bare, "every hook goes out bare: the crew bait them")
	_check(bare == FishHold.WELL_START + rods.rods.size(), "a mackerel for each hook in the well, and %d more (%d)"
			% [FishHold.WELL_START, bare])
	hold.head_in()
	hold.gear = ["reel", "line"]
	hold.head_out("skiff")
	await get_tree().process_frame
	_check(hold.well == bare, "the same with all the gear (%d): both Rivals boats start even" % hold.well)
	# a bare hook never gets taken, and a bare rod won't cast
	rods.host_cast(0)
	while rods.flying(0):
		await get_tree().process_frame
	_check(rods.bite_odds(0) == 0.0, "a bare hook out never gets taken")
	rods._host_line(0, true)
	var me: Node = sea.crew.me
	me.force_input = true
	sea.boat.helm.set("speed", 0.0)
	# (aft, between the rods and the well)
	me.place(Vector3(0.0, float(sea.boat.spec["deck"]) + 0.05, float(sea.rods.stern.z) - 1.2), 0.0)
	await _frames(2)
	# no bait from nowhere
	me.hands.pick("bait")
	_check(me.hands.item == "", "slot 5 with nothing in your fist: nothing (it comes out of the well)")
	_check(str(sea.crew.hud._note.text).contains("live well"), "and you're told where: %s" % sea.crew.hud._note.text)
	# the well: open it, net one out
	var well: Node = sea.boat.live_well
	var act: Node = well.get("_act")
	var was := hold.well
	act.call("interact", me)
	await _frames(3)
	_check(hold.well_open, "E on the lid opens it")
	act.call("interact", me)
	await _frames(3)
	_check(me.hands.carrying() == "live" and hold.well == was - 1, "E again nets a live one into your fist (%d left)"
			% hold.well)
	me.hands.pick("knife")
	_check(me.hands.carrying() == "live", "a fish in your fist: no picking up the knife")
	# hooking it on: clean
	var r1 = rods.rods[1]
	(r1._grab as Node).call("interact", me)
	_check(rods.rig.busy(), "E on a rod with its line in: the hook comes up to it")
	await _until(func() -> bool: return rods.rig.phase == "aim", 3.0)
	rods.rig.point = Rig.NOSE
	rods.rig.press()
	await _until(func() -> bool: return r1.baited, 3.0)
	_check(r1.baited and r1.live and r1.bait_q >= 0.99 and me.hands.carrying() == "",
			"through the nose: bridled clean, on the hook, your fist empty")
	# crooked, slipped, dead
	_check(await _hook(rods, 0, "live", Rig.NOSE + Rig.CROOKED * 0.8) == [true, 0.5],
			"a bit back of the nose: on crooked (swims poorly)")
	var odds_crooked := 0.0
	rods.host_cast(0)
	rods.host_cast(1)
	while rods.flying(0) or rods.flying(1):
		await get_tree().process_frame
	odds_crooked = rods.bite_odds(0)
	var odds_clean := rods.bite_odds(1)
	_check(odds_clean > 0.99 and absf(odds_crooked - odds_clean * 0.5) < 0.02,
			"crooked gets half the bites (%.2f against %.2f)" % [odds_crooked, odds_clean])
	rods._host_line(0, true)
	rods._unbaited(0)              # (taken off it)
	me.hands.carry("live")
	rods.rig.begin(0, "live")
	await _until(func() -> bool: return rods.rig.phase == "aim", 3.0)
	rods.rig.point = Rig.RANGE.x
	rods.rig.press()
	await get_tree().process_frame
	_check(rods.rig.phase == "aim" and not rods.rods[0].baited, "ahead of the nose: the point slips off, again")
	rods.rig.point = Rig.RANGE.y
	rods.rig.press()
	await _until(func() -> bool: return rods.rods[0].baited, 3.0)
	_check(rods.rods[0].baited and not rods.rods[0].live, "back through the eyes: it's on, dead")
	rods.host_cast(0)
	while rods.flying(0):
		await get_tree().process_frame
	_check(rods.bite_odds(0) > 0.0 and rods.bite_odds(0) < odds_crooked, "a dead bait gets taken least (%.2f)"
			% rods.bite_odds(0))
	# put one back
	me.hands.carry("")
	act.call("interact", me)
	await _frames(3)
	act.call("interact", me)
	await _frames(3)
	var held_kind: String = me.hands.carrying()
	_check(not hold.well_open, "netted one out: the lid's down after it")
	var n := hold.well
	act.call("interact", me)
	await _frames(3)
	act.call("interact", me)
	await _frames(3)
	_check(held_kind == "live" and me.hands.carrying() == "" and hold.well == n + 1, "E with it in your fist: back in")
	# the well run dry, then the ice
	hold.well = 0
	hold.dead = 0
	act.call("interact", me)
	await _frames(3)
	act.call("interact", me)
	await _frames(3)
	_check(me.hands.carrying() == "" and not hold.well_open, "nothing in it: E shuts it")
	rods.request_take_bait()
	await _frames(3)
	_check(str(sea.crew.hud._note.text).contains("Jig"), "nothing to net: the HUD says to jig: %s"
			% sea.crew.hud._note.text)
	# the jig fills it, no gear needed; full, it's on ice
	sea.jig._last.clear()
	sea.jig._ask_mackerel_as(1)
	_check(hold.well == 1, "a jigged mackerel goes into the well (%d)" % hold.well)
	hold.well = FishHold.WELL_MAX
	sea.jig._last.clear()
	sea.jig._ask_mackerel_as(1)
	_check(hold.well == FishHold.WELL_MAX and hold.dead == 1, "the well full: on ice for dead bait (%d)" % hold.dead)
	hold.well = 0
	act.call("interact", me)
	await _frames(3)
	act.call("interact", me)
	await _frames(3)
	_check(me.hands.carrying() == "dead", "no live one left: a dead one off the ice")
	_check(me.hands.shown_item() == "dead", "a dead one's its own thing in your hand (and to the others)")
	# the words
	var tips: Dictionary = Tips.TIPS
	_check(tips.has("bait") and str(tips["bait"]).contains("live mackerel") and str(tips["bait"]).contains("3"),
			"Dale says a live mackerel, and where the jig is: %s" % tips.get("bait", ""))
	_check(tips.has("well") and str(tips["well"]).contains("jig"), "and what to do when the well's empty")
	_check(str(tips["cast"]).contains("bare"), "and that the hooks go out bare")
	var guide := ""
	for page: Array in Manual.CHAPTERS:
		guide += str(page[1])
	_check(guide.contains("LIVE MACKEREL") and guide.contains("bait them") and not guide.contains("$1,500"),
			"the field guide says how to bait up")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(hold.save_path))
	_done()


## Hooks a `kind` mackerel onto rod i with the point at `at`: [baited, its bait_q].
func _hook(rods: Node, i: int, kind: String, at: float) -> Array:
	var me: Node = sea.crew.me
	me.hands.carry(kind)
	rods.rig.begin(i, kind)
	await _until(func() -> bool: return rods.rig.phase == "aim", 3.0)
	rods.rig.point = at
	rods.rig.press()
	await _until(func() -> bool: return rods.rods[i].baited, 3.0)
	return [rods.rods[i].baited, snappedf(rods.rods[i].bait_q, 0.01)]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


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
