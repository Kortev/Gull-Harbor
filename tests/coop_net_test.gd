extends Node
## Two of you in the skiff over the network (docs/COOP_DESIGN.md), two processes on this machine: the host and a friend.
## First a fish on rod 1, fought by the friend: the host sees it from their word, the drag lever they eased, the line
## going out, and hears the crew shout as it passes half the spool, the same as them; then the line goes and both see
## the rod spring back. Then a fish comes up alongside on rod 0. The friend grabs the rod and holds it: on both machines it lies quiet a whole
## cycle, and the friend's HUD says to hold it there. The friend puts the rod back: on both it kicks off and down.
## The host sticks it between kicks (the friend sees it stuck), the friend ropes its tail as it swings in (the host
## sees it roped), and both haul it in together, twice as fast as alone. On deck the friend pins it down while the
## host spikes it (the friend sees it go limp), then the friend cuts it and pumps its tail (the host's books say so).
## Run (two shells, the host first):
##   godot --headless --fixed-fps 30 --path . res://tests/coop_net_test.tscn -- --role=host
##   godot --headless --fixed-fps 30 --path . res://tests/coop_net_test.tscn -- --role=join
## (on a port of its own, PORT, so a game already hosting on this machine doesn't get in the way; --port=N for another)

const Sea := preload("res://sea/sea.gd")
const Landing := preload("res://tuna/landing.gd")
const Handling := preload("res://tuna/handling.gd")
const PORT := 7792
const KG := 150.0

var fails: Array[String] = []
var sea: Sea
var _host := false


func _ready() -> void:
	_host = OS.get_cmdline_user_args().has("--role=host")
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var port := PORT
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			port = a.trim_prefix("--port=").to_int()
	if _host:
		sea.fish_hold.set("save_path", "user://bluefin_test.cfg")
		Net.host(port)
	else:
		Net.join("127.0.0.1", port)
	if _host:
		await _as_host()
	else:
		await _as_friend()
	_done()


func _as_host() -> void:
	while sea.crew.slots.size() < 2:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	sea.fish_hold.call("head_out", "skiff")
	await get_tree().create_timer(1.0).timeout
	for r in sea.rods.rods:
		sea.rods.host_cast(r.index)
	await get_tree().create_timer(0.5).timeout
	var friend := 0
	for id: int in sea.crew.slots:
		if id != 1:
			friend = id
	# a fish on rod 1, the friend on it: drawn here from their word
	var r1 = sea.rods.rods[1]
	sea.rods.strike(1, KG)
	await _until(func() -> bool: return r1.holder == friend, 10.0)
	_check(r1.holder == friend and r1.hooked, "the friend's fighting rod 1's fish")
	await _until(func() -> bool: return absf(float(r1.drag) - 0.4) < 0.01, 10.0)
	_check(absf(float(r1.drag) - 0.4) < 0.01, "here, their drag lever's where they eased it (%.1f)" % float(r1.drag))
	var shouts := int(sea.rods.calls.count)
	await _until(func() -> bool: return float(r1.line_out) > 255.0, 15.0)
	await get_tree().create_timer(0.5).timeout
	_check(float(r1.line_out) > 255.0 and float(r1.strain) > 0.05,
			"his run, here: %.0f m out, the rod bent (%.2f)" % [float(r1.line_out), float(r1.strain)])
	_check(int(sea.rods.calls.count) > shouts and str(sea.rods.calls.last).contains("SPOOL"),
			"and the crew's shout here as he passed half the spool (%s)" % sea.rods.calls.last)
	sea.rods.host_off(1, sea.rods.WHY["broke"])          # (the line goes)
	await get_tree().create_timer(0.3).timeout
	_check(not r1.hooked and float(r1.get("_recoil")) > 0.0, "the line gone: the rod springs back here")
	await _until(func() -> bool: return r1.holder == 0, 10.0)
	sea.rods.strike(0, KG)
	await get_tree().create_timer(0.3).timeout
	var rod = sea.rods.rods[0]
	var landing := sea.landing
	landing.host_alongside(0, KG, float(rod.bearing), float(rod.hook_t))
	landing.hold_clock(0, true)      # (slow under load, it'd outlast HOOK_HOLDS and the hook would pull)
	# the friend takes the rod: quiet here too
	await _until(func() -> bool: return rod.holder == friend, 10.0)
	_check(rod.holder == friend, "the friend's on the rod")
	var most := await _watch(Landing.SHEER_EVERY + 0.5)
	_check(most < 0.01, "held by the friend, it lies quiet here (sheer %.2f)" % most)
	# they put it back: it kicks here too
	await _until(func() -> bool: return rod.holder == 0, 15.0)
	most = await _watch(Landing.SHEER_EVERY + 0.5)
	_check(most > 0.95, "rod back in its holder, it kicks off here (sheer %.2f)" % most)
	# the harpoon, between kicks
	landing._request_harpoon(true)
	await _until(func() -> bool: return not landing.down(0) and landing.sheer_goal(0) == 0.0, Landing.SHEER_EVERY)
	landing._ask_throw_as(1, 0)
	_check(bool(landing.fish[0]["stuck"]), "stuck it between kicks")
	await _until(func() -> bool: return bool(landing.fish[0].get("roped", false)), 30.0)
	_check(bool(landing.fish[0].get("roped", false)), "the friend roped its tail")
	# both of us on the haul (the friend says so)
	# (the haul goes by frame time, not the sea's clock)
	var took := 0.0
	var two := false
	while landing.fish.has(0) and took < 20.0:
		landing._ask_pull_as(1, 0)
		two = two or landing.hands_on(0) == 2
		await get_tree().process_frame
		took += get_process_delta_time()
	var alone := Landing.HAUL_BASE + KG * Landing.HAUL_PER_KG
	_check(two and not landing.fish.has(0), "two of us on the haul")
	_check(took < alone * 0.7, "hauled in %.1f s (alone: %.1f)" % [took, alone])
	# on deck: the friend pins it, I spike it; the friend cuts it and pumps its tail
	var hold := sea.fish_hold
	await _until(func() -> bool: return hold.fish.size() == 1 and int(hold.fish[0].get("pins", 0)) == 1, 15.0)
	_check(hold.fish.size() == 1 and int(hold.fish[0]["pins"]) == 1, "the friend's pinning it down")
	var id := int(hold.fish[0]["id"])
	hold._send_act(id, "spike", 0.0, 0.0)
	_check(float(hold.fish[0]["spiked_s"]) >= 0.0, "I spiked it")
	await _until(func() -> bool: return int(hold.fish[0].get("pumps", 0)) >= 3, 20.0)
	_check(float(hold.fish[0]["cut_q"]) > 0.9 and int(hold.fish[0]["pins"]) == 0, "the friend let go and cut it clean")
	_check(int(hold.fish[0]["pumps"]) >= 3, "and pumped its tail (%d)" % int(hold.fish[0]["pumps"]))
	await get_tree().create_timer(3.0).timeout       # (the friend's last look)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://bluefin_test.cfg"))


func _as_friend() -> void:
	var landing := sea.landing
	# rod 1's fish: on it, the drag eased two notches, and he runs out past half the spool
	# (her rods are made again when she heads out: the rod's the one there once he's on)
	await _until(func() -> bool: return sea.rods.rods.size() > 1 and bool(sea.rods.rods[1].hooked), 30.0)
	var r1 = sea.rods.rods[1]
	sea.rods.request_grab(1)
	await _until(func() -> bool: return r1.holder == Net.my_id() and r1.fight != null, 5.0)
	_check(r1.holder == Net.my_id() and r1.fight != null, "on rod 1: the fight runs here, on my machine")
	sea.rods.set_drag(r1, 0.5)
	sea.rods.set_drag(r1, 0.4)
	await get_tree().create_timer(1.0).timeout
	var shouts := int(sea.rods.calls.count)
	if r1.fight != null:
		r1.fight.set("grace", 999.0)
		r1.fight.call("carry_on", "run", float(r1.fight.get("stretch")), 1.0, 1.0)
		r1.fight.set("line_out", 262.0)
	await _until(func() -> bool: return not r1.hooked, 20.0)
	_check(int(sea.rods.calls.count) > shouts and str(sea.rods.calls.last).contains("SPOOL"),
			"the crew shouted it here too (%s)" % sea.rods.calls.last)
	_check(not r1.hooked and float(r1.get("_recoil")) > 0.0, "the host says the line's gone: it springs back here")
	sea.rods.request_return(1)
	await _until(func() -> bool: return landing.fish.has(0), 30.0)
	_check(landing.fish.has(0), "a fish up alongside")
	var rod = sea.rods.rods[0]
	sea.rods.request_grab(0)
	await _until(func() -> bool: return rod.holder == Net.my_id(), 5.0)
	_check(rod.holder == Net.my_id(), "I'm on the rod")
	_check(landing.hint() == "Hold it there", "with a mate aboard my HUD says: %s" % landing.hint())
	var most := await _watch(Landing.SHEER_EVERY + 1.5)
	_check(most < 0.01, "held, it lies quiet here (sheer %.2f)" % most)
	sea.rods.request_return(0)
	await _until(func() -> bool: return rod.holder == 0, 5.0)
	most = await _watch(Landing.SHEER_EVERY + 0.5)
	_check(most > 0.95, "rod back, it kicks off here too (sheer %.2f)" % most)
	await _until(func() -> bool: return landing.fish.has(0) and bool(landing.fish[0]["stuck"]), 15.0)
	_check(landing.fish.has(0) and bool(landing.fish[0]["stuck"]), "the host stuck it")
	# its tail roped from here as it swings in (judged here, told to the host)
	await _until(func() -> bool: return landing.tail_near(0), 15.0)
	landing._throw_rope(0)
	await _until(func() -> bool: return bool(landing.fish[0].get("roped", false)), 5.0)
	_check(bool(landing.fish[0].get("roped", false)), "I roped its tail (the host says so)")
	landing._ask_pull.rpc_id(1, 0)       # (on the haul with them)
	await _until(func() -> bool: return not landing.fish.has(0), 20.0)
	await get_tree().create_timer(0.5).timeout
	_check(not landing.fish.has(0) and (sea.fish_hold.get("fish") as Array).size() == 1, "aboard, on deck")
	# pin it down for the host's spike: it goes limp here too
	var hold := sea.fish_hold
	var id := int(hold.fish[0]["id"])
	hold._send_act(id, "pin", 1.0)
	await _until(func() -> bool: return float(hold.fish[0].get("spiked_s", -1.0)) >= 0.0, 15.0)
	await get_tree().create_timer(0.2).timeout
	var t: Node = hold._deck.get(id)
	_check(t != null and bool(t.get("limp")), "the host spiked it: limp here too")
	hold._send_act(id, "pin", 0.0)
	hold._send_act(id, "cut", 0.6, 0.0)
	for k in 3:
		await get_tree().create_timer(Handling.PUMP_EVERY + 0.05).timeout
		hold._send_act(id, "pump")
	await _until(func() -> bool: return int(hold.fish[0].get("pumps", 0)) >= 3, 5.0)
	_check(float(hold.fish[0]["cut_q"]) > 0.9 and int(hold.fish[0]["pumps"]) == 3, "cut and pumped (the host's books say)")
	await get_tree().create_timer(0.4).timeout
	_check(hold._streams.has(id), "its blood running here")


## The most fish 0 sheered off over `s` s of the sea's clock (real time).
func _watch(s: float) -> float:
	var landing := sea.landing
	var t0 := landing._now()
	var most := 0.0
	while landing._now() - t0 < s and landing.fish.has(0):
		most = maxf(most, float(landing.fish[0]["sheer"]))
		await get_tree().process_frame
	return most


func _until(ok: Callable, s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not bool(ok.call()) and Time.get_ticks_msec() - t0 < s * 1000.0:
		await get_tree().process_frame


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("COOP NET TEST (%s) " % ("host" if _host else "friend"), "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
