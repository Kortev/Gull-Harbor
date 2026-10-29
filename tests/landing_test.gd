extends Node
## Landing and selling, headless: a beaten fish comes up alongside; no harpoon with a rod in your hands (and no rod
## with the harpoon); a throw away from the fish misses and one straight at it sticks; hauling alone brings it
## aboard in HAUL_BASE + kg * HAUL_PER_KG seconds; it lies on deck; bleed it, ice it; head in: it sells, graded,
## into the bank; back out with an empty hold. And a fish left alongside unstuck gets away when the hook pulls.
## Run: godot --headless --path . res://tests/landing_test.tscn

const Sea := preload("res://sea/sea.gd")
const Landing := preload("res://tuna/landing.gd")
const FishHold := preload("res://boat/fish_hold.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var landing := sea.landing
	var hold := sea.fish_hold
	var bank0 := hold.bank
	var best0 := hold.best
	# a 200 kg fish on rod 0, fought out: up alongside
	sea.rods.strike(0, 200.0)
	await get_tree().process_frame
	var rod = sea.rods.rods[0]
	landing.host_alongside(0, 200.0, float(rod.bearing), float(rod.hook_t))
	await get_tree().process_frame
	_check(rod.hooked and rod.alongside and landing.fish.has(0), "a beaten fish comes up alongside")
	_check(landing.hint().begins_with("Boatside"), "the HUD says to stick it: %s" % landing.hint())
	# the harpoon and a rod: one or the other
	sea.rods.request_grab(1)
	landing._request_harpoon(true)
	_check(landing.harpoon_holder == 0, "no harpoon with a rod in your hands")
	sea.rods.request_return(1)
	landing._request_harpoon(true)
	_check(landing.harpoon_holder == 1, "E on the rack: the harpoon's yours")
	sea.rods.request_grab(1)
	_check(sea.rods.rods[1].holder == 0, "and no rod with the harpoon in your hands")
	# aiming: straight at it sticks, the other way doesn't
	var cam := sea.crew.me.get("cam") as Node3D
	var from := cam.global_position
	var at := landing.fish_point(0)
	_check(landing.aimed_at(from, (at - from).normalized()) == 0, "a throw straight at it would stick")
	_check(landing.aimed_at(from, (from - at).normalized()) == -1, "a throw the other way wouldn't")
	landing._ask_throw_as(1, -1)
	_check(landing.harpoon_holder == 0 and not bool(landing.fish[0]["stuck"]),
			"a miss: the harpoon's back in its rack, the fish still alongside")
	landing._request_harpoon(true)
	landing._ask_throw_as(1, 0)
	await get_tree().process_frame
	_check(bool(landing.fish[0]["stuck"]) and not rod.hooked, "a hit: stuck, and off the rod")
	_check(landing.hint().begins_with("Stuck"), "the HUD says to haul it: %s" % landing.hint())
	# the haul, alone (holding E on the door)
	var t := 0.0
	while landing.fish.has(0) and t < 30.0:
		landing._ask_pull_as(1, 0)
		await get_tree().process_frame
		t += get_process_delta_time()
	var expect := Landing.HAUL_BASE + 200.0 * Landing.HAUL_PER_KG
	_check(not landing.fish.has(0) and absf(t - expect) < 1.5, "hauled aboard alone in %.1f s (about %.0f)" % [t, expect])
	_check(hold.fish.size() == 1 and hold._deck.size() == 1, "it's on deck")
	_check(hold.hint().begins_with("A fish on deck"), "the HUD says to bleed it: %s" % hold.hint())
	var id := int(hold.fish[0]["id"])
	hold._work(id)
	_check(float(hold.fish[0]["bled_s"]) >= 0.0 and hold._deck.size() == 1, "E on it: bled, still on deck")
	hold._work(id)
	await get_tree().process_frame
	_check(float(hold.fish[0]["iced_s"]) >= 0.0 and hold._deck.is_empty(), "E again: iced, into the fish box")
	var worth := hold.worth()
	_check(worth > 0, "it's worth $%d" % worth)
	hold.head_in()
	_check(hold.fish.is_empty() and int(hold.sale["total"]) == worth and hold.bank == bank0 + worth,
			"headed in: sold for $%d, banked ($%d)" % [worth, hold.bank])
	var lines: Array = hold.sale["lines"]
	_check(lines.size() == 1 and str(lines[0][1]).begins_with("#"), "the slip: %s" % str(lines))
	hold.head_out()
	_check(hold.sale.is_empty(), "back out with an empty hold")
	# grading: handled well beats handled badly
	var good := FishHold.quality(200.0, 100.0, 20.0, 60.0)
	var bad := FishHold.quality(200.0, 1500.0, -1.0, -1.0)
	_check(FishHold.grade(good) == "#1" and FishHold.grade(bad) == "#3",
			"fought fast, bled and iced: %s; slow and left warm: %s" % [FishHold.grade(good), FishHold.grade(bad)])
	_check(FishHold._money(1234567) == "1,234,567" and FishHold._money(950) == "950", "money reads right")
	# a fish left alongside, never stuck: the hook pulls
	sea.rods.strike(2, 120.0)
	await get_tree().process_frame
	var rod2 = sea.rods.rods[2]
	landing.host_alongside(2, 120.0, float(rod2.bearing), float(rod2.hook_t))
	await get_tree().process_frame
	landing.fish[2]["t"] = Landing.HOOK_HOLDS - 0.2
	await get_tree().create_timer(0.5).timeout
	_check(not landing.fish.has(2) and not rod2.hooked, "left alongside unstuck, the hook pulls")
	# (the test sold a fish: put your bank back as it was)
	hold.bank = bank0
	hold.best = best0
	hold._save()
	_done()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("LANDING TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
