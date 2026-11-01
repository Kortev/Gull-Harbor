extends Node
## Boat to boat over the network (crew/player.gd), Rivals, two processes on this machine: A and B lie 2 m apart, the
## friend (B's crew) gets up on B's rail and leaps to A, landing on her deck on their own machine; the host watches
## them go, smoothly the whole way (off B's deck into the air, into A's deck space) and sees them on A's deck. Then
## the host leaps from A to B and the friend watches the same.
## Run (two shells, the host first):
##   godot --headless --fixed-fps 30 --path . res://tests/board_net_test.tscn -- --role=host
##   godot --headless --fixed-fps 30 --path . res://tests/board_net_test.tscn -- --role=join
## (on a port of its own, PORT, so a game already hosting on this machine doesn't get in the way)

const Sea := preload("res://sea/sea.gd")
const Player := preload("res://crew/player.gd")
const PORT := 7796
## Where B lies, and A 2 m off her starboard side; both bow north, stopped.
const SPOT := Vector2(300.0, -600.0)
const GAP := 2.0

var fails: Array[String] = []
var sea: Sea
var _host := false
var _a: Node3D
var _b: Node3D


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


func _process(_delta: float) -> void:
	# (the host holds the boats where the test wants them: nobody's at either wheel, so its word goes)
	if not _host or _a == null:
		return
	var beam := float(_b.get("beam"))
	for pair: Array in [[_b, SPOT], [_a, SPOT + Vector2(beam + GAP, 0.0)]]:
		var h: Node = (pair[0] as Node3D).get("helm")
		h.set("at", pair[1])
		h.set("heading", 0.0)
		h.set("speed", 0.0)
		h.set("drift", Vector2.ZERO)


func _as_host() -> void:
	while sea.crew.slots.size() < 2:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	sea.vs.host_set_on(true)
	await get_tree().create_timer(1.5).timeout
	sea.fish_hold.call("head_out", "sportfisher")
	await get_tree().create_timer(0.5).timeout
	_a = sea.vs.sides[0].get("boat") as Node3D
	_b = sea.vs.sides[1].get("boat") as Node3D
	var me := sea.crew.me
	var friend: Player = null
	for id: int in sea.crew.slots:
		if id != 1:
			friend = sea.crew.get_player(id)
	# the friend's leap, B to A, watched from here
	var seen := await _watch(friend, _a, 25.0)
	_check(seen[0], "I saw the friend leap from B and land on A's deck (%s)" % seen[2])
	_check(float(seen[1]) < 0.4, "smoothly, the whole way, into her deck space too (at most %.2f m a frame)" % seen[1])
	await get_tree().create_timer(2.0).timeout
	# my turn: A to B
	await _leap(me, _a, _b, -1)
	_check(me.boat == _b and me.mode == Player.DECK and me.frame == _b, "I leapt from A onto B's deck")
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
	# till the boats lie where the host has them
	var beam := float(_b.get("beam"))
	await _until(func() -> bool: return (_b.get("helm").get("at") as Vector2).distance_to(SPOT) < 0.1 \
			and (_a.get("helm").get("at") as Vector2).distance_to(SPOT + Vector2(beam + GAP, 0.0)) < 0.1, 20.0)
	await get_tree().create_timer(1.5).timeout
	await _leap(me, _b, _a, 1)
	_check(me.boat == _a and me.mode == Player.DECK and me.frame == _a and me.get("home") == _b,
			"I leapt from B onto A's deck, still B's crew")
	await get_tree().create_timer(0.5).timeout
	_check(me.body.is_on_floor(), "standing on A's deck")
	# the host's leap, A to B, watched from here
	var host := sea.crew.get_player(1)
	var seen := await _watch(host, _b, 25.0)
	_check(seen[0], "I saw the host leap from A and land on B's deck (%s)" % seen[2])
	_check(float(seen[1]) < 0.4, "smoothly, the whole way (at most %.2f m a frame)" % seen[1])


## You up on `from`'s rail on the side toward `to` (way: +1 her starboard: a walk at it and a jump), then Shift, W
## and Space: the leap, till you're down.
func _leap(me: Player, from: Node3D, to: Node3D, way: int) -> void:
	me.force_input = true
	me.place(Vector3((float(from.get("beam")) * 0.5 - 0.7) * way, float(from.get("deck")) + 0.02, 3.5),
			-PI * 0.5 * way, from)
	await get_tree().create_timer(0.5).timeout
	Input.action_press("move_forward")
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	await get_tree().create_timer(0.25).timeout
	Input.action_release("move_forward")
	await _until(func() -> bool: return me.on_rail() != Vector3.ZERO, 1.5)
	await get_tree().create_timer(0.2).timeout
	Input.action_press("sprint")
	Input.action_press("move_forward")
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	await _until(func() -> bool: return me.mode == Player.SWIM or (me.mode == Player.DECK and me.boat == to
			and me.body.is_on_floor()), 4.0)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	me.force_input = false


## Watches `p` (someone else) till they've left their deck and come down on `to`'s: [landed there, the biggest step
## they took in a frame (world) from the moment they left, where they ended up].
func _watch(p: Player, to: Node3D, s: float) -> Array:
	var t0 := Time.get_ticks_msec()
	var prev := p.global_position
	var went := false
	var step := 0.0
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await get_tree().process_frame
		var d := p.global_position.distance_to(prev)
		prev = p.global_position
		if p.mode == Player.AIR:
			went = true
		if went:
			step = maxf(step, d)
			if p.mode == Player.DECK and p.frame == to:
				# (and a moment more on her deck: no jump after it)
				for k in 15:
					await get_tree().process_frame
					step = maxf(step, p.global_position.distance_to(prev))
					prev = p.global_position
				break
			if p.mode == Player.SWIM:
				break
	var where := "%s, %s" % ["on her" if p.frame == to else "elsewhere", ["deck", "sea", "ladder", "air"][p.mode]]
	return [went and p.mode == Player.DECK and p.frame == to, step, where]


func _until(ok: Callable, s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not bool(ok.call()) and Time.get_ticks_msec() - t0 < s * 1000.0:
		await get_tree().process_frame


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("BOARD NET TEST (%s) " % ("host" if _host else "friend"), "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
