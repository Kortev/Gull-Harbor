extends Node
## Two of you in the skiff over the network (docs/COOP_DESIGN.md), two processes on this machine: the host and a friend.
## A fish comes up alongside on rod 0. The friend grabs the rod and holds it: on both machines it lies quiet a whole
## cycle, and the friend's HUD says to hold it there. The friend puts the rod back: on both it kicks off and down.
## The host sticks it between kicks (the friend sees it stuck), and both haul it in together, twice as fast as alone.
## Run (two shells, the host first):
##   godot --headless --fixed-fps 30 --path . res://tests/coop_net_test.tscn -- --role=host
##   godot --headless --fixed-fps 30 --path . res://tests/coop_net_test.tscn -- --role=join
## (on a port of its own, PORT, so a game already hosting on this machine doesn't get in the way)

const Sea := preload("res://sea/sea.gd")
const Landing := preload("res://tuna/landing.gd")
const PORT := 7792
const KG := 150.0

var fails: Array[String] = []
var sea: Sea
var _host := false


func _ready() -> void:
	_host = OS.get_cmdline_user_args().has("--role=host")
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	if _host:
		sea.fish_hold.set("save_path", "user://bluefin_test.cfg")
		Net.host(PORT)
	else:
		Net.join("127.0.0.1", PORT)
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
	sea.rods.strike(0, KG)
	await get_tree().create_timer(0.3).timeout
	var rod = sea.rods.rods[0]
	var landing := sea.landing
	landing.host_alongside(0, KG, float(rod.bearing), float(rod.hook_t))
	# the friend takes the rod: quiet here too
	var friend := 0
	for id: int in sea.crew.slots:
		if id != 1:
			friend = id
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
	await get_tree().create_timer(3.0).timeout       # (the friend's last look)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://bluefin_test.cfg"))


func _as_friend() -> void:
	var landing := sea.landing
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
	landing._ask_pull.rpc_id(1, 0)       # (on the haul with them)
	await _until(func() -> bool: return not landing.fish.has(0), 20.0)
	await get_tree().create_timer(0.5).timeout
	_check(not landing.fish.has(0) and (sea.fish_hold.get("fish") as Array).size() == 1, "aboard, on deck")


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
