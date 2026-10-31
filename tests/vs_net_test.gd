extends Node
## VS over the network (vs/vs.gd), two processes on this machine: the host and a friend who joins.
## The host turns VS on once the friend's aboard, so the friend lands on boat B; both head out, and the friend takes
## B's wheel and lies still at a spot. The host runs A into her beam (each moves their own boat: the friend's machine
## keeps B out of A and takes the shove), hooks a fish on A (the friend's radio squawks), and runs A across B's stern
## through her lines (nothing's cut: the friend's baits are still out), then blows her horn alongside (the friend's view
## rattles). A fish is landed on each boat (60 kg on A, 90 on B), and
## the skipper heads in: both alongside the fish pier, the weigh-in read off, the result (B by 66 lb). Then the results
## card (vs/card.gd), up on both screens at once with the same numbers: the friend presses NEXT DAY first (the host
## sees B ready), then the host; a fade, both boats back at their berths, the countdown. Day 2 to B again (40 kg to
## 70): the match's card, REMATCH from both, a fresh match with the same new weather on both machines.
## Run (two shells, the host first):
##   godot --headless --fixed-fps 30 --path . res://tests/vs_net_test.tscn -- --role=host
##   godot --headless --fixed-fps 30 --path . res://tests/vs_net_test.tscn -- --role=join
## (on a port of its own, PORT, so a game already hosting on this machine doesn't get in the way)

const Sea := preload("res://sea/sea.gd")
const Contact := preload("res://vs/contact.gd")
const PORT := 7791
## Where the friend lies B, still, bow north.
const SPOT := Vector2(300.0, -600.0)

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
	if _host:
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
	sea.vs.host_set_on(true)
	await get_tree().create_timer(1.5).timeout
	_check(sea.vs.teams.values().count(1) == 1, "the friend's put on boat B (%s)" % sea.vs.teams)
	sea.fish_hold.call("head_out", "skiff")
	var a_boat := sea.vs.sides[0].get("boat") as Node3D
	var b_boat := sea.vs.sides[1].get("boat") as Node3D
	var ha: Node = a_boat.get("helm")
	var hb: Node = b_boat.get("helm")
	# the friend at B's wheel, lying at SPOT
	while int(hb.get("captain")) == 0 or (hb.get("at") as Vector2).distance_to(SPOT) > 1.0:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	# A at her beam, 5 m/s
	ha.set("at", SPOT + Vector2(-20.0, 0.0))
	ha.set("heading", -PI * 0.5)
	await get_tree().create_timer(2.5).timeout      # (the friend sees her there first)
	ha.set("at", SPOT + Vector2(-20.0, 0.0))
	var closest := INF
	for i in 30 * 5:
		if i < 20:
			ha.set("speed", 5.0)
		await get_tree().process_frame
		var c := Contact.contact(a_boat, b_boat, 1.0)
		if not c.is_empty():
			closest = minf(closest, float(c["gap"]))
	_check(closest < 1.0 and closest > -1.5, "they met, and didn't pass through (overlap at most %.2f m)" % -closest)
	_check((hb.get("at") as Vector2).distance_to(SPOT) > 0.8, "B shoved off, by the friend's machine (%.1f m)"
			% (hb.get("at") as Vector2).distance_to(SPOT))
	# a fish on A: the friend's radio squawks
	var a_rods: Node = sea.vs.sides[0].get("rods")
	a_rods.call("host_cast", 0)
	await get_tree().create_timer(1.5).timeout
	a_rods.call("strike", 0, 150.0)
	await get_tree().create_timer(2.0).timeout
	a_rods.call("host_clear")
	# B's baits out; A runs across her stern
	var b_rods: Node = sea.vs.sides[1].get("rods")
	for i in (b_rods.get("rods") as Array).size():
		b_rods.call("host_cast", i)
	await get_tree().create_timer(3.0).timeout
	ha.set("at", (hb.get("at") as Vector2) + Vector2(-45.0, 25.0))
	ha.set("heading", -PI * 0.5)
	for i in 30 * 10:
		ha.set("speed", 9.0)
		await get_tree().process_frame
	ha.set("speed", 0.0)
	# A alongside, 30 m off: her horn
	ha.set("at", (hb.get("at") as Vector2) + Vector2(-30.0, 0.0))
	await get_tree().create_timer(2.0).timeout
	a_boat.get_node("Horn").call("interact", sea.crew.me)
	_check(int(a_boat.get_node("Horn").get("blasts")) == 1, "A's horn blown")
	await get_tree().create_timer(2.0).timeout
	(sea.vs.sides[0].get("fish_hold") as Node).call("host_add", 60.0, 60.0)
	(sea.vs.sides[1].get("fish_hold") as Node).call("host_add", 90.0, 60.0)
	await get_tree().create_timer(3.0).timeout
	sea.vs.host_bring_home()
	await get_tree().create_timer(1.0).timeout
	while sea.vs.weighing:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.3).timeout
	_check((sea.vs.get("_verdict") as Label).text.begins_with("They won by 66 lb"), "the skipper (A) reads: %s"
			% (sea.vs.get("_verdict") as Label).text.replace("\n", " / "))
	await _host_card()
	await get_tree().create_timer(3.0).timeout       # (the friend reads theirs before the host goes)


## The card, the next day, the match and a rematch: the host's side.
func _host_card() -> void:
	var vs := sea.vs
	var card := vs.card
	await _until(func() -> bool: return card.up(), 6.0)
	var boats: Array = card.data.get("boats", [{}, {}])
	_check(card.up() and not bool(card.data["decided"]) and int(card.data["winner"]) == 1 and int(boats[0]["fish"]) == 1
			and roundi(boats[0]["kg"]) == 60 and roundi(boats[1]["kg"]) == 90, "the card: day 1 to B, 60 kg to 90")
	await _until(func() -> bool: return int(card.states[1]) == 1, 20.0)
	_check(card.states == [0, 1] and card.up(), "the friend's pressed NEXT DAY: B ready, A deciding, still up")
	vs.press_ready()
	await _until(func() -> bool: return not card.up(), 5.0)
	await get_tree().create_timer(0.3).timeout
	var a_boat := vs.sides[0].get("boat") as Node3D
	var b_boat := vs.sides[1].get("boat") as Node3D
	_check(not card.up() and vs.wins == [0, 1] and vs.count_end > 0.0, "both pressed: the next day, the countdown")
	_check((a_boat.get("helm").get("at") as Vector2).distance_to(vs._berth(0)) < 1.0
			and (b_boat.get("helm").get("at") as Vector2).distance_to(vs._berth(1)) < 1.0, "both boats at their berths")
	await get_tree().create_timer(2.0).timeout
	sea.fish_hold.call("head_out", "skiff")
	await get_tree().create_timer(2.0).timeout
	(vs.sides[0].get("fish_hold") as Node).call("host_add", 40.0, 60.0)
	(vs.sides[1].get("fish_hold") as Node).call("host_add", 70.0, 60.0)
	await get_tree().create_timer(2.0).timeout
	vs.host_bring_home()
	await _until(func() -> bool: return card.up(), 40.0)
	boats = card.data.get("boats", [{}, {}])
	_check(bool(card.data["decided"]) and int(card.data["winner"]) == 1 and vs.wins == [0, 2] and int(boats[1]["fish"]) == 2
			and roundi(boats[1]["kg"]) == 160, "day 2 to B: the match's card (B 2 fish, 160 kg over it)")
	await _until(func() -> bool: return int(card.states[1]) == 1, 20.0)
	var seed := int(sea.weather.seed)
	vs.press_ready()
	await _until(func() -> bool: return not card.up(), 5.0)
	await get_tree().create_timer(0.3).timeout
	_check(not card.up() and vs.wins == [0, 0] and vs.count_end > 0.0 and int(sea.weather.seed) != seed,
			"REMATCH from both: a fresh match, new weather (%d)" % int(sea.weather.seed))
	print("HOST SEED %d" % int(sea.weather.seed))


func _as_friend() -> void:
	while not sea.vs.on:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.5).timeout
	var vs := sea.vs
	_check(vs.sides.size() == 2 and vs.my_team == 1, "VS came on: I'm on boat B")
	var b_boat := vs.sides[1].get("boat") as Node3D
	var a_boat := vs.sides[0].get("boat") as Node3D
	_check(sea.boat == b_boat and sea.crew.me != null and sea.crew.me.boat == b_boat, "aboard B, B's my sea's boat")
	_check(sea.crew.get_player(1) != null and sea.crew.get_player(1).boat == a_boat, "the skipper's on A")
	while bool(sea.fish_hold.get("docked")):
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(2.5).timeout
	_check(not bool((vs.sides[0].get("fish_hold") as Node).get("docked")), "both boats out")
	var ax := a_boat.global_position.x
	var bx := b_boat.global_position.x
	_check(ax < sea.harbour.PIER_X and bx > sea.harbour.PIER_X, "from their own berths either side of the pier (%.0f, %.0f)"
			% [ax, bx])
	# take B's wheel and lie at SPOT
	var hb: Node = b_boat.get("helm")
	hb.call("request", true)
	while not bool(hb.call("is_mine")):
		await get_tree().create_timer(0.1).timeout
	hb.set("at", SPOT)
	hb.set("heading", 0.0)
	hb.set("speed", 0.0)
	# A comes at her: she's shoved, never passed through
	var closest := INF
	var thud := false
	var after := 0
	for i in 30 * 14:
		await get_tree().process_frame
		var c := Contact.contact(b_boat, a_boat)
		if not c.is_empty():
			closest = minf(closest, float(c["gap"]))
		if not thud and float(vs.contact.get("_thud_t")) > -INF:
			thud = true
			after = i
		if thud and i > after + 60:
			break
	_check(closest > -1.0, "on my screen they don't pass through (overlap at most %.2f m)" % -closest)
	_check(hb.get("at").distance_to(SPOT) > 0.8, "I was shoved off (%.1f m)" % hb.get("at").distance_to(SPOT))
	_check(thud, "a thud")
	# their fish on: a squawk, their dot blinking
	var squawked := false
	for i in 30 * 6:
		await get_tree().process_frame
		squawked = squawked or (int(vs.get("_hooked")) > 0 and float(vs.get("_their_on")) < 1.0)
		if squawked:
			break
	_check(squawked, "their hook-up came over my radio")
	# A across my stern: my lines left be
	var b_rods: Node = vs.sides[1].get("rods")
	var cut := false
	var out := 0
	for i in 30 * 14:
		await get_tree().process_frame
		var rods := b_rods.get("rods") as Array
		out = maxi(out, rods.filter(func(r: Node) -> bool: return not bool(r.get("bait_in"))).size())
		cut = cut or rods.any(func(r: Node) -> bool: return not bool(r.get("bait_in")) and not bool(r.get("baited")))
	_check(out >= 1 and not cut, "A ran across my stern and my lines are still out (%d)" % out)
	# A's horn, close: my view rattled
	var rattled := false
	for i in 30 * 30:
		rattled = rattled or float(sea.crew.me.get("shake")) > 0.3
		if vs.shown != [0, 0] or bool(sea.fish_hold.get("docked")):
			break
		await get_tree().process_frame
	_check(rattled and int(a_boat.get_node("Horn").get("blasts")) == 1, "A's horn heard, my view rattled")
	await get_tree().create_timer(0.5).timeout
	_check(vs.shown == [198, 132], "my tally: %s" % [vs.shown])
	while not bool(sea.fish_hold.get("docked")):
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.5).timeout
	_check(vs.weighing, "the weigh-in")
	while vs.weighing:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.3).timeout
	var col := (vs.get("_board") as Node).get_node_or_null("Boat1")
	_check(col != null and col.get_node("Fish").get_child_count() == 1, "my one fish read off")
	var verdict := (vs.get("_verdict") as Label).text
	_check(verdict.begins_with("You won by 66 lb"), "the result: %s" % verdict.replace("\n", " / "))
	var pier_x := float(sea.harbour.PIER_X)
	_check((b_boat.get("helm").get("at") as Vector2).x > pier_x and (a_boat.get("helm").get("at") as Vector2).x < pier_x,
			"both in alongside the fish pier")
	# the card, the same as the host's; NEXT DAY first
	var card := vs.card
	await _until(func() -> bool: return card.up(), 6.0)
	var boats: Array = card.data.get("boats", [{}, {}])
	_check(card.up() and int(card.data["winner"]) == 1 and roundi(boats[0]["kg"]) == 60 and roundi(boats[1]["kg"]) == 90,
			"the card on my screen too: day 1 to us, 60 kg to 90")
	await _until(func() -> bool: return card.t > card.T_BUTTONS, 6.0)
	vs.press_ready()
	await _until(func() -> bool: return card.ready_ids.has(Net.my_id()), 3.0)
	_check(card.states == [0, 1] and card._status() == "WAITING FOR THEM...", "pressed: waiting for them")
	var black := 0.0
	while card.up():
		black = maxf(black, card.dark())
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_check(black > 0.9 and vs.wins == [0, 1] and vs.count_end > 0.0, "they pressed: a fade, the next day's countdown")
	_check((b_boat.get("helm").get("at") as Vector2).distance_to(vs._berth(1)) < 1.0, "B back at her berth")
	# day 2: the match's card, REMATCH
	await _until(func() -> bool: return card.up() and bool(card.data.get("decided", false)), 60.0)
	_check(card.up() and int(card.data["winner"]) == 1 and vs.wins == [0, 2], "the match is ours, 2-0")
	await _until(func() -> bool: return card.t > card.T_BUTTONS, 6.0)
	_check(card._primary() == "REMATCH", "REMATCH")
	vs.press_ready()
	await _until(func() -> bool: return not card.up(), 20.0)
	await get_tree().create_timer(0.5).timeout
	_check(not card.up() and vs.wins == [0, 0] and vs.count_end > 0.0, "a fresh match, the countdown")
	print("FRIEND SEED %d" % int(sea.weather.seed))


func _until(ok: Callable, most: float) -> void:
	var t := 0.0
	while not bool(ok.call()) and t < most:
		await get_tree().process_frame
		t += 1.0 / 30.0


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("VS NET TEST (%s) " % ("host" if _host else "friend"), "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
