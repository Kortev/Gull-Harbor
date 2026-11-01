extends Node
## Boat to boat under way over the network (crew/player.gd), Rivals, two processes on this machine: A and B run north
## side by side, a metre apart, at RUN m/s, in a heavy sea. The friend (B's crew) gets up on B's rail and leaps to
## A; the host watches them go: smoothly the whole way (off B's deck, over the gap, into A's deck space), nothing
## jumping as they go into her frame, however their words come in. Then the host leaps from A to B and the friend
## watches the same.
## Run (two shells, the host first):
##   godot --headless --fixed-fps 30 --path . res://tests/leap_moving_net_test.tscn -- --role=host
##   godot --headless --fixed-fps 30 --path . res://tests/leap_moving_net_test.tscn -- --role=join
## (on a port of its own, PORT, so a game already hosting on this machine doesn't get in the way)

const Sea := preload("res://sea/sea.gd")
const Player := preload("res://crew/player.gd")
const PORT := 7802
## Where B starts, and A a metre off her starboard side (a gap cleared in any sea: 2 m off, a heavy swell now and then
## lifts the other's side into the way, and a leap knocking off her hull is a knock, not what's watched here; tests/
## leap_moving_test leaps 2 m); both bow north, under way.
const SPOT := Vector2(300.0, -600.0)
const GAP := 1.0
const RUN := 6.0
## Most a frame's step across the sea may change by, watching someone leap (m: a pop, a frame of her way, is more).
const JERK := 0.15

var fails: Array[String] = []
var sea: Sea
var _host := false
var _a: Node3D
var _b: Node3D


func _ready() -> void:
	_host = OS.get_cmdline_user_args().has("--role=host")
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(150.0).timeout.connect(func() -> void:
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


func _process(_delta: float) -> void:
	# (the host keeps them going, A held off B's side: nobody's at either wheel, so its word goes)
	if not _host or _a == null:
		return
	var hb: Node = _b.get("helm")
	var ha: Node = _a.get("helm")
	for h: Node in [ha, hb]:
		h.set("heading", 0.0)
		h.set("speed", RUN)
		h.set("drift", Vector2.ZERO)
		h.set("spin", 0.0)
	ha.set("at", (hb.get("at") as Vector2) + Vector2(float(_b.get("beam")) + GAP, 0.0))


func _as_host() -> void:
	while sea.crew.slots.size() < 2:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	sea.vs.host_set_on(true)
	await get_tree().create_timer(1.5).timeout
	sea.fish_hold.call("head_out", "sportfisher")
	await get_tree().create_timer(0.5).timeout
	sea.set_condition("heavy")
	_a = sea.vs.sides[0].get("boat") as Node3D
	_b = sea.vs.sides[1].get("boat") as Node3D
	(_b.get("helm") as Node).set("at", SPOT)
	var me := sea.crew.me
	var friend: Player = null
	for id: int in sea.crew.slots:
		if id != 1:
			friend = sea.crew.get_player(id)
	# the friend's leap, B to A, watched from here
	var seen := await _watch(friend, _a, 30.0)
	_check(seen[0], "I saw the friend leap from B and land on A's deck, both under way (%s)" % seen[2])
	_check(float(seen[1]) < JERK, "smoothly, the whole way, into her deck space too (%.3f m a frame's change at most)"
			% seen[1])
	await get_tree().create_timer(2.0).timeout
	# my turn: A to B
	await _leap(me, _a, _b, -1)
	_check(me.boat == _b and me.mode == Player.DECK and me.frame == _b, "I leapt from A onto B's deck, under way")
	await get_tree().create_timer(3.0).timeout      # (the friend's last look)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://bluefin_test.cfg"))


func _as_friend() -> void:
	while not sea.vs.on:
		await get_tree().create_timer(0.2).timeout
	while bool(sea.fish_hold.get("docked")):
		await get_tree().create_timer(0.2).timeout
	_a = sea.vs.sides[0].get("boat") as Node3D
	_b = sea.vs.sides[1].get("boat") as Node3D
	var me := sea.crew.me
	# till the boats are going, side by side, where the host has them
	var beam := float(_b.get("beam"))
	await _until(func() -> bool: return float(_b.get("helm").get("speed")) > RUN - 0.1 \
			and (_a.get("helm").get("at") as Vector2).distance_to((_b.get("helm").get("at") as Vector2)
			+ Vector2(beam + GAP, 0.0)) < 0.3, 25.0)
	await get_tree().create_timer(2.0).timeout
	await _leap(me, _b, _a, 1)
	_check(me.boat == _a and me.mode == Player.DECK and me.frame == _a and me.get("home") == _b,
			"I leapt from B onto A's deck, both under way, still B's crew")
	await get_tree().create_timer(0.8).timeout
	_check(me.body.is_on_floor() and me.boat == _a, "standing on A's deck")
	# the host's leap, A to B, watched from here
	var host := sea.crew.get_player(1)
	var seen := await _watch(host, _b, 30.0)
	_check(seen[0], "I saw the host leap from A and land on B's deck, both under way (%s)" % seen[2])
	_check(float(seen[1]) < JERK, "smoothly, the whole way (%.3f m a frame's change at most)" % seen[1])


## You up on `from`'s rail on the side toward `to` (way: +1 her starboard), Space again: the leap, till you're down.
func _leap(me: Player, from: Node3D, to: Node3D, way: int) -> void:
	me.force_input = true
	me.place(Vector3((float(from.get("beam")) * 0.5 - 0.7) * way, float(from.get("deck")) + 0.02, 3.5),
			-PI * 0.5 * way, from)
	await get_tree().create_timer(0.5).timeout
	for k in 2:
		Input.action_press("jump")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("jump")
		if k == 0:
			await _until(func() -> bool: return int(me.get("_cap")) == Player.CAP_ON, 1.5)
	await _until(func() -> bool: return me.mode == Player.SWIM or (me.mode == Player.DECK and me.boat == to), 4.0)
	me.force_input = false


## Watches `p` (someone else) till they've left their deck and come down on `to`'s: [landed there, the biggest change
## in a frame's step across the sea (world) from the moment they left till a moment after, where they ended up].
func _watch(p: Player, to: Node3D, s: float) -> Array:
	var t0 := Time.get_ticks_msec()
	var seen: Array[Vector3] = []
	var went := false
	var jerk := 0.0
	var after := -1
	while Time.get_ticks_msec() - t0 < s * 1000.0 and after != 0:
		await get_tree().process_frame
		if p.mode == Player.AIR:
			went = true
		if not went:
			seen = [p.global_position]
			continue
		seen.append(p.global_position)
		if seen.size() >= 3:
			var j := seen[-1] - 2.0 * seen[-2] + seen[-3]
			jerk = maxf(jerk, Vector2(j.x, j.z).length())
			if Vector2(j.x, j.z).length() > JERK * 0.6:
				print("  (a step changing by %.3f m: %s, %s)" % [Vector2(j.x, j.z).length(),
						["deck", "sea", "ladder", "air"][p.mode], "on her" if p.frame == to else "not on her yet"])
		if after > 0:
			after -= 1
		elif p.mode == Player.DECK and p.frame == to:
			after = 20      # (and a moment more on her deck: no jump after it)
		elif p.mode == Player.SWIM:
			break
	var where := "%s, %s" % ["on her" if p.frame == to else "elsewhere", ["deck", "sea", "ladder", "air"][p.mode]]
	return [went and p.mode == Player.DECK and p.frame == to, jerk, where]


func _until(ok: Callable, s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not bool(ok.call()) and Time.get_ticks_msec() - t0 < s * 1000.0:
		await get_tree().process_frame


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("LEAP MOVING NET TEST (%s) " % ("host" if _host else "friend"), "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
