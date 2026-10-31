extends Node
## Two jobs that want two people (docs/COOP_DESIGN.md), headless, in the skiff:
## - boatside: a beaten fish alongside on a rod nobody's holding kicks off and goes down now and then (out of the
##   harpoon's reach, the rod bending over), then comes back up; with someone on the rod it lies quiet the whole
##   time. Alone you can still stick it between kicks.
## - spotting: at the wheel with her running you can't pick birds out; slowed down, or off the wheel, you can.
## Run: godot --headless --fixed-fps 30 --path . res://tests/coop_test.tscn

const Sea := preload("res://sea/sea.gd")
const Landing := preload("res://tuna/landing.gd")
const Spotter := preload("res://crew/spotter.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var landing := sea.landing
	var hold := sea.fish_hold
	hold.save_path = "user://bluefin_test.cfg"
	hold.head_out("skiff")
	for r in sea.rods.rods:
		sea.rods.host_cast(r.index)
	await get_tree().process_frame
	var me := sea.crew.me
	var cam := me.get("cam") as Node3D
	# a 150 kg fish up alongside on rod 0, nobody on the rod
	sea.rods.strike(0, 150.0)
	await get_tree().process_frame
	var rod = sea.rods.rods[0]
	landing.host_alongside(0, 150.0, float(rod.bearing), float(rod.hook_t))
	# (the hook's clock stood still, as the tutor does: it runs on frames, and the waits below on the sea's clock, real
	# time; a run fast enough gets through HOOK_HOLDS of frames before they're done and the hook pulls)
	landing.hold_clock(0, true)
	await get_tree().process_frame
	_check(landing.fish.has(0) and rod.holder == 0, "up alongside, the rod in its holder")
	_check(str(rod.call("interact_prompt", me)) == "Hold it", "the rod says: %s" % rod.call("interact_prompt", me))
	# (how deep it lies under the water just there: the swell lifts and drops it all the while)
	var rest_at := landing.fish_point(0)
	var rest_y := rest_at.y - float(sea.ocean.height_at(rest_at))
	# not held: within a cycle it kicks off and down, then comes back up
	var most := 0.0
	var missed_down := false
	var bent := 0.0
	var low := INF
	# (the kicks run on the sea's clock, real time: --fixed-fps frames go faster than that)
	var t0 := landing._now()
	while landing._now() - t0 < Landing.SHEER_EVERY + 1.0:
		await get_tree().process_frame
		var s := float(landing.fish[0]["sheer"])
		most = maxf(most, s)
		if s > 0.9:
			var at := landing.fish_point(0)
			low = minf(low, at.y - float(sea.ocean.height_at(at)))
			bent = maxf(bent, float(rod.strain))
			missed_down = missed_down or landing.aimed_at(cam.global_position, (at - cam.global_position).normalized()) == -1
	_check(most > 0.95, "not held, it kicks off (sheer %.2f)" % most)
	_check(low < rest_y - 0.8, "and goes down (%.1f m under where it lay)" % (rest_y - low))
	_check(bent > 0.8, "the rod in its holder bends over (%.2f)" % bent)
	_check(missed_down, "down there the harpoon can't reach it")
	t0 = landing._now()
	while float(landing.fish[0]["sheer"]) > 0.0 and landing._now() - t0 < Landing.SHEER_FOR + 3.0:
		await get_tree().process_frame
	_check(float(landing.fish[0]["sheer"]) == 0.0, "then it wallows back up")
	# someone on the rod: it lies quiet a whole cycle
	sea.rods.request_grab(0)
	_check(rod.holder == 1, "E on the rod: holding it")
	_check(landing.hint().begins_with("Q: rod back"), "alone, the HUD says put it back for the harpoon: %s" % landing.hint())
	most = 0.0
	t0 = landing._now()
	while landing._now() - t0 < Landing.SHEER_EVERY + 1.0:
		await get_tree().process_frame
		most = maxf(most, float(landing.fish[0]["sheer"]))
	_check(most < 0.01, "held, it lies quiet a whole cycle (sheer %.2f)" % most)
	# alone: rod back, harpoon, wait for it to come up, stick it
	sea.rods.request_return(0)
	landing._request_harpoon(true)
	_check(landing.harpoon_holder == 1, "the harpoon")
	t0 = landing._now()
	while (landing.down(0) or landing.sheer_goal(0) > 0.5) and landing._now() - t0 < Landing.SHEER_EVERY:
		await get_tree().process_frame
	var at := landing.fish_point(0)
	var hit := landing.aimed_at(cam.global_position, (at - cam.global_position).normalized())
	landing._ask_throw_as(1, hit)
	await get_tree().process_frame
	_check(hit == 0 and bool(landing.fish[0]["stuck"]), "alone, between its kicks, stuck it")
	_check(float(landing.fish[0]["sheer"]) == 0.0 and landing.sheer_goal(0) == 0.0, "stuck, it stays up for the haul")
	landing.host_clear()
	# spotting from the wheel
	var helm: Node = sea.boat.get("helm")
	_check(Spotter.can_spot(me), "on deck you can pick out birds")
	helm.call("interact", me)
	_check(bool(me.get("steering")), "at the wheel")
	helm.set("speed", 9.0)
	_check(not Spotter.can_spot(me), "at the wheel with her running, you can't")
	helm.set("speed", 2.5)
	_check(Spotter.can_spot(me), "eased down to trolling, you can")
	helm.call("interact", me)
	helm.set("speed", 9.0)
	_check(Spotter.can_spot(me), "off the wheel, running, you can")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(hold.save_path))
	_done()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("COOP TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
