extends Node
## A friend's line dropping in Rivals and them getting back aboard (crew/crew.gd, vs/vs.gd, core/net.gd), two
## processes on this machine: the host and the friend, who's on boat B. Day 1 is weighed (B's, 90 kg to 60) and the
## card comes up; the friend's game stops talking for a few seconds (a real drop: ENet times out on both machines). The
## host's card says they lost connection and the notice tops the screen ("ORANGE LOST CONNECTION — WAITING..."); the
## host goes on without them (NEXT DAY), out for day 2, and while they're gone a fish strikes on B, a fish goes into
## B's box, and B's left lying at a spot. The friend, back on their own sea, joins again in the same game: back on
## boat B in their own oilskins (fading in on the host's deck), the match 0-1, B's 50 kg aboard, the fish still on, B
## where she was left, the new day's weather; they take her wheel. Then the host quits: the friend's back on their own
## boat, nothing hung, REJOIN offered.
## Run (two shells, the host first):
##   godot --headless --fixed-fps 30 --path . res://tests/rejoin_net_test.tscn -- --role=host
##   godot --headless --fixed-fps 30 --path . res://tests/rejoin_net_test.tscn -- --role=join
## (on a port of its own, PORT, so a game already hosting on this machine doesn't get in the way)

const Sea := preload("res://sea/sea.gd")
const PORT := 7801
## Where B's left lying while her crew's away.
const SPOT := Vector2(260.0, -640.0)

var fails: Array[String] = []
var sea: Sea
var _host := false
var _dropped := 0


func _ready() -> void:
	_host = OS.get_cmdline_user_args().has("--role=host")
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	sea.fish_hold.set("save_path", "user://bluefin_rejoin_test.cfg")
	# (a drop noticed in a second or three, not ENet's half a minute)
	Net.peer_joined.connect(func(id: int) -> void:
		var p := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if p != null and p.get_peer(id) != null:
			p.get_peer(id).set_timeout(8, 1000, 3000))
	Net.dropped.connect(func(_reason: String) -> void: _dropped += 1)
	if _host:
		Net.host(PORT)
		await _as_host()
	else:
		Net.join("127.0.0.1", PORT)
		await _as_friend()
	_done()


func _as_host() -> void:
	var crew := sea.crew
	var vs := sea.vs
	var card := vs.card
	while crew.slots.size() < 2:
		await get_tree().create_timer(0.2).timeout
	var friend := 0
	for id: int in crew.slots:
		if id != 1:
			friend = id
	var slot := int(crew.slots[friend])
	await get_tree().create_timer(1.0).timeout
	vs.host_set_on(true)
	await get_tree().create_timer(1.5).timeout
	_check(int(vs.teams.get(friend, -1)) == 1, "the friend's on boat B")
	# day 1: B's
	sea.fish_hold.call("head_out", "skiff")
	await get_tree().create_timer(2.0).timeout
	(vs.sides[0].get("fish_hold") as Node).call("host_add", 60.0, 60.0)
	(vs.sides[1].get("fish_hold") as Node).call("host_add", 90.0, 60.0)
	await get_tree().create_timer(2.0).timeout
	vs.host_bring_home()
	await _until(func() -> bool: return card.up(), 40.0)
	_check(card.up() and int(card.data["winner"]) == 1, "day 1 to B: the card's up")
	# the friend's line drops
	await _until(func() -> bool: return crew.away.has(friend), 40.0)
	_check(crew.away.has(friend) and int((crew.away[friend] as Dictionary).get("team", -1)) == 1
			and int(crew.away[friend]["slot"]) == slot, "dropped: their spot kept, on B (%s)" % [crew.away])
	await get_tree().process_frame
	_check(crew.notice_text() == "ORANGE LOST CONNECTION — WAITING", "the notice: %s" % crew.notice_text())
	_check(crew.get_player(friend) == null and not vs.teams.has(friend), "their deckhand's gone from B's deck")
	await _until(func() -> bool: return card.t > card.T_BUTTONS, 6.0)
	_check(int(card.states[1]) == 3 and card._status().begins_with("THEY LOST CONNECTION") and card._can_press(),
			"the card: B lost connection, NEXT DAY still ours to press (%s, %s)" % [card.states, card._status()])
	vs.press_ready()
	await _until(func() -> bool: return not card.up(), 5.0)
	await get_tree().create_timer(0.3).timeout
	_check(not card.up() and vs.wins == [0, 1] and vs.count_end > 0.0, "on without them: day 2's countdown")
	# day 2, still without them: B lies at SPOT, a fish on her rod 0, 50 kg in her box
	sea.fish_hold.call("head_out", "skiff")
	await get_tree().create_timer(1.5).timeout
	var b_boat := vs.sides[1].get("boat") as Node3D
	var hb: Node = b_boat.get("helm")
	hb.set("at", SPOT)
	hb.set("heading", 0.0)
	hb.set("speed", 0.0)
	hb.rpc("_sync", 0, 0.0, SPOT, 0.0)
	var b_rods: Node = vs.sides[1].get("rods")
	b_rods.call("host_cast", 0)
	await get_tree().create_timer(1.5).timeout
	b_rods.call("strike", 0, 40.0)
	(vs.sides[1].get("fish_hold") as Node).call("host_add", 50.0, 60.0)
	await get_tree().create_timer(1.0).timeout
	_check(vs.on and not bool((vs.sides[1].get("fish_hold") as Node).get("docked")) and crew.notice_text() != "",
			"the world goes on: B out fishing without them, still waiting")
	# back
	var newer := func() -> int:
		for id: int in vs.teams:
			if id != 1 and id != friend:
				return id
		return 0
	await _until(func() -> bool: return int(newer.call()) != 0, 60.0)
	var back := int(newer.call())
	_check(back != 0 and int(vs.teams[back]) == 1, "they're back: on B again (%s)" % [vs.teams])
	_check(int(crew.slots.get(back, -1)) == slot and crew.call_sign(back) == "Orange", "in their own oilskins")
	var p := crew.get_player(back)
	var part: MeshInstance3D = (p.get("_parts") as Dictionary).values()[0] if p != null else null
	_check(p != null and p.boat == b_boat and part != null and part.transparency > 0.2,
			"on B's deck, fading in (%.2f)" % (part.transparency if part else -1.0))
	await get_tree().create_timer(1.6).timeout
	_check(part != null and is_instance_valid(part) and part.transparency == 0.0, "and there")
	_check(crew.away.is_empty() and crew.notice_text() == "", "the notice's gone")
	await _until(func() -> bool: return int(hb.get("captain")) == back, 30.0)
	_check(int(hb.get("captain")) == back, "they've taken B's wheel")
	_check(vs.on and vs.wins == [0, 1] and crew.me != null, "and the host never broke")
	await get_tree().create_timer(1.0).timeout
	print("HOST SEED %d" % int(sea.weather.seed))
	# the host quits: the friend's told
	Net.leave()
	await get_tree().create_timer(1.0).timeout


func _as_friend() -> void:
	var crew := sea.crew
	var vs := sea.vs
	var card := vs.card
	await _until(func() -> bool: return Net.in_session(), 10.0)
	_short_timeout()
	await _until(func() -> bool: return vs.on and vs.sides.size() == 2, 20.0)
	await get_tree().create_timer(0.5).timeout
	_check(vs.my_team == 1, "VS on: I'm on boat B")
	var slot := int(crew.slots.get(Net.my_id(), -1))
	await _until(func() -> bool: return card.up(), 60.0)
	await _until(func() -> bool: return card.t > card.T_BUTTONS, 6.0)
	var seed := int(sea.weather.seed)
	# the line drops: nothing in or out for a few seconds, and both ends give up on it
	get_tree().multiplayer_poll = false
	var until := Time.get_ticks_msec() + 6000          # (on the wall clock: ENet gives up by it, the frames here may race)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	get_tree().multiplayer_poll = true
	await _until(func() -> bool: return _dropped == 1, 20.0)
	_check(_dropped == 1, "dropped")
	await get_tree().process_frame
	_check(not vs.on and crew.slots.size() == 1 and crew.me != null, "back on my own boat, nothing hung")
	_check(card.up() and card.gone, "the card says the host's gone")
	_check(not Net.last_join.is_empty(), "REJOIN offered (%s)" % [Net.last_join])
	await get_tree().create_timer(3.0).timeout
	# back aboard
	_check(Net.rejoin() == OK, "rejoining")
	await _until(func() -> bool: return Net.in_session(), 10.0)
	_short_timeout()
	await _until(func() -> bool: return vs.on and vs.sides.size() == 2, 20.0)
	await get_tree().create_timer(2.5).timeout
	var b_boat := vs.sides[1].get("boat") as Node3D
	_check(vs.my_team == 1 and sea.boat == b_boat and crew.me != null and crew.me.boat == b_boat, "back aboard B")
	_check(int(crew.slots.get(Net.my_id(), -2)) == slot, "in my own oilskins (slot %d)" % slot)
	_check(vs.wins == [0, 1] and not card.up() and card.dark() == 0.0, "the match as it stands: 0-1, the card gone")
	var hold := vs.sides[1].get("fish_hold") as Node
	_check(not bool(hold.get("docked")) and float(hold.call("day_fraction")) > 0.0, "out on day 2, its clock running (%.3f)"
			% float(hold.call("day_fraction")))
	_check(vs.shown[0] == 110, "B's 50 kg aboard: my tally %s" % [vs.shown])
	var r0: Node = (vs.sides[1].get("rods") as Node).get("rods")[0]
	_check(bool(r0.get("hooked")), "the fish on B's rod still on")
	var hb: Node = b_boat.get("helm")
	_check((hb.get("at") as Vector2).distance_to(SPOT) < 3.0, "B where she was left (%s)" % [hb.get("at")])
	_check(int(sea.weather.seed) != seed, "the new day's weather (%d, was %d)" % [int(sea.weather.seed), seed])
	_check(crew.waiting.is_empty(), "nobody waited on")
	print("FRIEND SEED %d" % int(sea.weather.seed))
	hb.call("request", true)
	await _until(func() -> bool: return bool(hb.call("is_mine")), 5.0)
	_check(bool(hb.call("is_mine")), "B's wheel's mine")
	# the host quits
	await _until(func() -> bool: return _dropped == 2, 30.0)
	await get_tree().create_timer(1.0).timeout
	_check(_dropped == 2 and not vs.on and crew.slots.size() == 1 and crew.me != null and not card.up(),
			"the host's gone: on my own boat, nothing hung")
	_check(not Net.last_join.is_empty() and not Net.in_session_or_hosting(), "REJOIN offered")


func _short_timeout() -> void:
	var p := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if p != null and p.get_peer(1) != null:
		p.get_peer(1).set_timeout(8, 1000, 3000)


func _until(ok: Callable, most: float) -> void:
	var t := 0.0
	while not bool(ok.call()) and t < most:
		await get_tree().process_frame
		t += 1.0 / 30.0


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("REJOIN NET TEST (%s) " % ("host" if _host else "friend"), "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
