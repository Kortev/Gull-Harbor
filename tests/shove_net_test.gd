extends Node
## Shoving and swimming over the network (crew/player.gd), two of you in the skiff, two processes on this machine.
## The friend stands at the starboard rail; the host winds up behind them and shoves: the host decides it, the
## friend's own machine sends them over the rail and into the sea, and both machines see them swimming at the
## waves' height. Up the ladder (both see the climb go smoothly, and them back on deck). Then the friend shoves the
## host (asked of the host, decided there): over the host goes, and the friend sees it.
## Run (two shells, the host first):
##   godot --headless --fixed-fps 30 --path . res://tests/shove_net_test.tscn -- --role=host
##   godot --headless --fixed-fps 30 --path . res://tests/shove_net_test.tscn -- --role=join
## (on a port of its own, PORT, so a game already hosting on this machine doesn't get in the way)

const Sea := preload("res://sea/sea.gd")
const Player := preload("res://crew/player.gd")
const PORT := 7793
## Where the one shoved stands (by the starboard rail) and the shover (inboard of them, facing out), boat-local.
const RAIL := Vector3(0.8, 0.0, 2.0)
const BEHIND := Vector3(-0.15, 0.0, 2.0)

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
	await get_tree().create_timer(1.5).timeout
	var me := sea.crew.me
	var friend: Player = null
	for id: int in sea.crew.slots:
		if id != 1:
			friend = sea.crew.get_player(id)
	var deck := float(sea.boat.deck)
	me.place(BEHIND + Vector3(0.0, deck + 0.02, 0.0), -PI * 0.5)
	await _until(func() -> bool: return friend.local_position().distance_to(RAIL + Vector3(0, deck, 0)) < 0.35, 15.0)
	await get_tree().create_timer(1.0).timeout
	me.shove()
	_check(me.shoves == 1, "I wind up")
	await _until(func() -> bool: return friend.mode == Player.SWIM, 5.0)
	_check(friend.mode == Player.SWIM, "the friend went over the rail and in, on my screen too")
	await get_tree().create_timer(3.0).timeout
	var at := friend.global_position
	var off := at.y - (float(sea.ocean.height_at(at)) - Player.FLOAT)
	_check(absf(off) < 0.8, "swimming at the waves' height here (%.2f m off)" % off)
	# they climb the ladder: smooth here as well
	var step := 0.0
	var climbed := false
	var prev := sea.boat.global_transform.affine_inverse() * friend.global_position
	for i in 30 * 15:
		await get_tree().process_frame
		var here := sea.boat.global_transform.affine_inverse() * friend.global_position
		if friend.mode == Player.CLIMB:
			step = maxf(step, here.distance_to(prev))
			climbed = true
		prev = here
		if climbed and friend.mode == Player.DECK:
			break
	_check(climbed and friend.mode == Player.DECK and friend.boat == sea.boat, "they climbed back aboard")
	_check(step < 0.3, "smoothly, on my screen (at most %.2f m a frame)" % step)
	# now they shove me
	await get_tree().create_timer(1.0).timeout
	me.place(RAIL + Vector3(0.0, deck + 0.02, 0.0), -PI * 0.5)
	var shoved := false
	for i in 30 * 15:
		await get_tree().process_frame
		shoved = shoved or str(friend.get("_gesture")) == "shove"
		if me.mode != Player.DECK:
			break
	_check(shoved, "I saw their windup")
	await _until(func() -> bool: return me.mode == Player.SWIM, 3.0)
	_check(me.mode == Player.SWIM, "and over I went")
	await get_tree().create_timer(3.0).timeout       # (the friend's last look)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://bluefin_test.cfg"))


func _as_friend() -> void:
	await _until(func() -> bool: return not bool(sea.fish_hold.get("docked")) and sea.crew.me != null, 30.0)
	await get_tree().create_timer(1.0).timeout
	var me := sea.crew.me
	var host := sea.crew.get_player(1)
	var deck := float(sea.boat.deck)
	await get_tree().create_timer(1.0).timeout      # (the host behind first)
	me.place(RAIL + Vector3(0.0, deck + 0.02, 0.0), -PI * 0.5)
	var wound := false
	for i in 30 * 30:
		await get_tree().process_frame
		wound = wound or str(host.get("_gesture")) == "shove"
		if me.mode != Player.DECK:
			break
	_check(wound, "I saw the host wind up")
	await _until(func() -> bool: return me.mode == Player.SWIM and me.splashes > 0, 4.0)
	_check(me.mode == Player.SWIM and me.splashes == 1, "shoved over the rail and in, with a splash")
	await get_tree().create_timer(3.0).timeout
	# up the ladder
	var ladder: Node3D = sea.boat.ladder
	me.overboard(ladder.global_transform * Vector3(0.0, 0.0, 1.0), ladder.global_position)
	await get_tree().create_timer(1.0).timeout
	ladder.call("interact", me)
	me.force_climb = true
	await _until(func() -> bool: return me.mode == Player.DECK, 8.0)
	me.force_climb = false
	_check(me.mode == Player.DECK and me.boat == sea.boat, "up the ladder and aboard")
	# my turn: the host at the rail, me behind
	await get_tree().create_timer(1.5).timeout
	me.place(BEHIND + Vector3(0.0, deck + 0.02, 0.0), -PI * 0.5)
	await _until(func() -> bool: return host.local_position().distance_to(RAIL + Vector3(0, deck, 0)) < 0.2, 10.0)
	await get_tree().create_timer(1.0).timeout
	me.shove()
	me.shove()
	await _until(func() -> bool: return host.mode == Player.SWIM, 5.0)
	_check(host.mode == Player.SWIM, "I shoved the host in")
	_check(me.shoves == 0, "(the host decided it, not me)")
	await get_tree().create_timer(1.0).timeout


func _until(ok: Callable, s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not bool(ok.call()) and Time.get_ticks_msec() - t0 < s * 1000.0:
		await get_tree().process_frame


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("SHOVE NET TEST (%s) " % ("host" if _host else "friend"), "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
