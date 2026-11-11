extends Node
## Any number of boats over the network (vs/vs.gd, docs/BOATS_PLAN.md), THREE processes on this machine: the host and
## two friends who join, each with the title up (ui/title.gd) as in the real game.
## The host picks RIVALS and hosts (two boats, on from the lobby); both friends join a Rivals that's already on, and
## are seated. The host steps BOATS to 3 from the lobby's own row: everyone's shared out one a boat, each boat at a
## berth of her own, the same on every screen. Then they cross: the host to C, the second friend C to A, the first
## friend with CHANGE BOAT B to C to A, the second friend A to B: A the first friend's, B the second's, C the host's,
## and it can start. START: the titles down, the countdown, GO, all three out. The first friend lies A at a spot; the
## host runs C into her beam (the shove goes to the friend's machine: vs/contact.gd's _shoved_by with boat 2), then the
## second friend runs B into her (friend to friend). Fish put in the holds so C has the most; home, the weigh-in, the
## same result and card on all three; B presses NEXT DAY and everyone sees it, then the rest. Back at the dock, in the
## countdown: four boats (D with nobody), back to two (2 v 1), one fleet; and out again, two boats as a fleet.
## The three keep in step by marks said over the test's own RPC (_marked): nothing of the game's.
## Run (three shells, the host first; each one's output kept and looked through for errors):
##   godot --headless --fixed-fps 30 --path . res://tests/boats_net_test.tscn -- --role=host
##   godot --headless --fixed-fps 30 --path . res://tests/boats_net_test.tscn -- --role=join1
##   godot --headless --fixed-fps 30 --path . res://tests/boats_net_test.tscn -- --role=join2
## (on a port of its own, PORT; --port=N for another. Which friend is "first" goes by who got aboard first, their slot.)

const Sea := preload("res://sea/sea.gd")
const Vs := preload("res://vs/vs.gd")
const Title := preload("res://ui/title.gd")
const Contact := preload("res://vs/contact.gd")
const PORT := 7805
## Where the first friend lies A, still, bow north.
const SPOT := Vector2(300.0, -600.0)
## The whole test, at most (s by the clock on the wall: --fixed-fps runs the game's own clock as fast as it can).
const MOST := 420.0

var fails: Array[String] = []
var sea: Sea
var role := "host"
var marks := {}
var _began := 0
var _over := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.trim_prefix("--role=")
	_began = Time.get_ticks_msec()
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().process_frame
	var t := Title.new()
	t.name = "Title"
	t.sea = sea
	sea.add_child(t)
	sea.title = t
	await _secs(0.5)
	sea.schools.set("_next", 9999.0)
	if role == "host":
		await _as_host()
	else:
		await _as_friend()
	_done()


func _process(_delta: float) -> void:
	if not _over and Time.get_ticks_msec() - _began > MOST * 1000.0:
		_check(false, "finished in time (marks: %s)" % [marks.keys()])
		_done()


# ------------------------------------------------------------------ the host

func _as_host() -> void:
	var vs := sea.vs
	var t := sea.title
	t.call("_choose", "rivals")
	_check(Net.host(_port()) == OK, "hosting")
	await get_tree().process_frame
	_check(str(t.get("_page")) == "lobby" and vs.on and vs.boats == 2 and vs.sides.size() == 2,
			"RIVALS, HOST: the lobby, two boats on")
	await _until(func() -> bool: return sea.crew.slots.size() == 3, 120.0)
	_check(sea.crew.slots.size() == 3, "both friends aboard (%d)" % sea.crew.slots.size())
	await _secs(1.5)
	_check(vs.teams.size() == 3 and vs._aboard() == [2, 1], "seated as they came: 2 v 1 (%s)" % [vs._aboard()])
	# BOATS: 3, from the lobby's own row
	var labels := func() -> Array: return (t.get("_items") as Array).map(func(i: Array) -> String: return str(i[0]))
	t.set("_pick", labels.call().find("BOATS: 2"))
	t.call("_press")
	await _secs(1.5)
	_check(vs.boats == 3 and labels.call().has("BOATS: 3"), "BOATS stepped to 3, and it's stayed so (%d)" % vs.boats)
	_settled("three", 3, [0, 1, 2], false, true)
	_mark("three")
	await _all("three_ok")
	# crossing: the host to C
	vs.ask_team(2)
	await _until(func() -> bool: return vs.my_team == 2, 10.0)
	_check(vs.my_team == 2 and sea.boat == vs.sides[2].get("boat"), "the host's crossed to C")
	_mark("host_on_c")
	await _wait("crossed")
	await _secs(0.5)
	_settled("crossed", 3, [2, 0, 1], false, true)
	_check(vs.team_problem(Net.my_id()) == "", "it can start (%s)" % vs.team_problem(Net.my_id()))
	var cols: Array = t.call("crew_columns")
	_check(cols.size() == 3 and cols.all(func(c: Dictionary) -> bool: return (c["crew"] as Array).size() == 1),
			"the lobby's list: three columns, one aboard each")
	await _all("crossed_ok")
	# START
	t.call("_start_pressed")
	await _out_from_title()
	var boats: Array = vs.sides.map(func(s: Node) -> Node3D: return s.get("boat"))
	for b: Node3D in boats:
		b.set("carry", 0.0)       # (the shove's what's tested, not the sea's orbits nudging them apart: boat/boat.gd)
	var ha: Node = boats[0].get("helm")
	var hc: Node = boats[2].get("helm")
	await _wait("a_lying")
	await _secs(1.0)
	# C at A's beam, 5 m/s (nobody at C's wheel: the host moves her)
	hc.set("at", SPOT + Vector2(-20.0, 0.0))
	hc.set("heading", -PI * 0.5)
	await _secs(2.5)      # (the friends see her there first)
	hc.set("at", SPOT + Vector2(-20.0, 0.0))
	var closest := INF
	for i in 30 * 8:
		if closest == INF:
			hc.set("speed", 5.0)      # (5 m/s till they're about to touch, whatever the sea's doing to her way)
		await get_tree().process_frame
		var c := Contact.contact(boats[2], boats[0], 1.0)
		if not c.is_empty():
			closest = minf(closest, float(c["gap"]))
	_check(closest < 1.0 and closest > -1.5, "C met A, and didn't pass through (overlap at most %.2f m)" % -closest)
	if closest == INF:
		print("     (C at %s going %.1f, captain %d, towed %s; A at %s, captain %d; the spot %s)" % [hc.get("at"),
				float(hc.get("speed")), int(hc.get("captain")), hc.get("towed_by"), ha.get("at"), int(ha.get("captain")), SPOT])
	await _until(func() -> bool: return (ha.get("at") as Vector2).distance_to(SPOT) > 0.8, 5.0)
	_check((ha.get("at") as Vector2).distance_to(SPOT) > 0.8, "A shoved off, by the first friend's machine (%.1f m)"
			% (ha.get("at") as Vector2).distance_to(SPOT))
	hc.set("speed", 0.0)
	hc.set("at", SPOT + Vector2(-80.0, 60.0))      # (out of the way of the next)
	_mark("c_bumped")
	await _wait("b_bumped")
	# the catch: A 100 kg, B 60 + 50, C 150: C's day
	var holds: Array = vs.sides.map(func(s: Node) -> Node: return s.get("fish_hold"))
	holds[0].call("host_add", 100.0, 60.0)
	holds[1].call("host_add", 60.0, 60.0)
	holds[1].call("host_add", 50.0, 60.0)
	holds[2].call("host_add", 150.0, 60.0)
	await _secs(2.0)
	_check(vs.shown == [331, 220, 243], "the tally, mine first (%s)" % [vs.shown])
	_mark("fished")
	await _all("tally_ok")
	vs.host_bring_home()
	await _weighed_and_card()
	await _wait("b_ready")
	_check(vs.card.states == [0, 1, 0] and vs.card.up(), "B's pressed NEXT DAY: %s" % [vs.card.states])
	await _all("saw_ready")
	vs.press_ready()
	await _next_day()
	await _all("next_ok")
	# back at the dock, in the countdown: four boats, two, one fleet
	_check(vs._all_docked(), "all at the dock")
	vs.host_set_boats(4)
	await _secs(0.5)
	_settled("four", 4, [0, 1, 2], false, true)
	_check(vs.team_problem(Net.my_id()).contains("BOAT D"), "nobody on D: %s" % vs.team_problem(Net.my_id()))
	_mark("four")
	await _all("four_ok")
	_check(vs._all_docked(), "still at the dock")
	vs.host_set_boats(2)
	await _secs(0.5)
	_settled("two", 2, [0, 1, 0], false, true)
	_check(vs.team_problem(Net.my_id()) == "", "2 v 1 can start")
	_mark("two")
	await _all("two_ok")
	_check(vs._all_docked(), "and still")
	vs.host_set_together(true)
	await _secs(0.5)
	_settled("fleet", 2, [0, 1, 0], true, true)
	_mark("fleet")
	await _all("fleet_ok")
	await _fleet_out()
	await _all("done")
	await _secs(0.5)


# ------------------------------------------------------------------ the friends

func _as_friend() -> void:
	var vs := sea.vs
	var t := sea.title
	var err := Net.join("127.0.0.1", _port())
	_check(err == OK, "joining")
	await _until(func() -> bool: return vs.on and sea.crew.me != null and sea.crew.slots.has(Net.my_id()), 120.0)
	_check(vs.on and sea.crew.me != null, "aboard, a Rivals that was on already")
	if not vs.on or sea.crew.me == null:
		return
	var slot := int(sea.crew.slots[Net.my_id()])
	var first := slot == 1
	print("I'm the %s friend (slot %d)" % ["first" if first else "second", slot])
	await _secs(0.5)
	_check(str(t.get("_page")) == "lobby" and vs.sides.size() == vs.boats and sea.crew.me.boat == vs.boat_of(Net.my_id()),
			"in the lobby, on a boat (%s of %d)" % [Vs.boat_name(vs.my_team), vs.boats])
	await _wait("three", 150.0)
	await _secs(1.5)       # (the lobby's rows are made again on a tick)
	_settled("three", 3, [0, 1, 2], false, true)
	var labels := func() -> Array: return (t.get("_items") as Array).map(func(i: Array) -> String: return str(i[0]))
	var cols: Array = t.call("crew_columns")
	_check(cols.size() == 3 and str(cols[2]["head"]) == "BOAT C" and (cols[slot]["crew"] as Array).size() == 1
			and str(cols[slot]["crew"][0]).ends_with("(YOU)"), "the lobby's list: three columns, me on %s" % Vs.boat_name(slot))
	_check(labels.call().has("CHANGE BOAT") and not labels.call().has("START") and not labels.call().has("BOATS: 3"),
			"my rows: CHANGE BOAT, none of the host's (%s)" % [labels.call()])
	_mark("three_ok_" + role)
	await _wait("host_on_c")
	if first:
		await _wait("second_on_a")
		# B to C to A, by the lobby's own CHANGE BOAT
		t.call("_swap")
		await _until(func() -> bool: return vs.my_team == 2, 10.0)
		_check(vs.my_team == 2 and sea.boat == vs.sides[2].get("boat") and sea.crew.me.boat == sea.boat,
				"CHANGE BOAT: aboard C with the host")
		t.call("_swap")
		await _until(func() -> bool: return vs.my_team == 0, 10.0)
		_check(vs.my_team == 0 and sea.crew.me.boat == vs.sides[0].get("boat"), "and again: aboard A")
		_mark("first_on_a")
	else:
		await _secs(0.3)
		_check(vs.team_problem(Net.my_id()).contains("BOAT A") and vs.team_problem(Net.my_id()).contains("SKIPPER"),
				"the host and I on C, nobody on A: %s" % vs.team_problem(Net.my_id()))
		vs.ask_team(0)
		await _until(func() -> bool: return vs.my_team == 0, 10.0)
		_check(vs.my_team == 0 and sea.crew.me.boat == vs.sides[0].get("boat"), "crossed C to A")
		_mark("second_on_a")
		await _wait("first_on_a")
		vs.ask_team(1)
		await _until(func() -> bool: return vs.my_team == 1, 10.0)
		_check(vs.my_team == 1, "and A to B")
		_mark("crossed")
	await _wait("crossed")
	await _secs(0.5)
	_settled("crossed", 3, [2, 0, 1], false, true)
	_check(vs.team_problem(Net.my_id()) == "", "it can start (%s)" % vs.team_problem(Net.my_id()))
	_mark("crossed_ok_" + role)
	await _out_from_title()
	var boats: Array = vs.sides.map(func(s: Node) -> Node3D: return s.get("boat"))
	for b: Node3D in boats:
		b.set("carry", 0.0)
	var mine: Node = (sea.boat as Node).get("helm")
	var ha: Node = boats[0].get("helm")
	mine.call("request", true)
	await _until(func() -> bool: return bool(mine.call("is_mine")), 10.0)
	_check(bool(mine.call("is_mine")), "at my own boat's wheel")
	if first:
		mine.set("at", SPOT)
		mine.set("heading", 0.0)
		mine.set("speed", 0.0)
		_mark("a_lying")
		# C comes at her (the host's machine), then B (the second friend's): shoved each time, never passed through
		for from: int in [2, 1]:
			var lay: Vector2 = mine.get("at")
			var closest := INF
			var thud_was := float(vs.contact.get("_thud_t"))
			var done := "c_bumped" if from == 2 else "b_ran"
			var until := Time.get_ticks_msec() + 60000
			while Time.get_ticks_msec() < until and not (marks.has(done) and (mine.get("at") as Vector2).distance_to(lay) > 0.8):
				await get_tree().process_frame
				var c := Contact.contact(boats[0], boats[from])
				if not c.is_empty():
					closest = minf(closest, float(c["gap"]))
			await _secs(0.5)
			_check(closest > -1.5, "boat %s didn't pass through me (overlap at most %.2f m)" % [Vs.boat_name(from), -closest])
			_check((mine.get("at") as Vector2).distance_to(lay) > 0.8, "shoved off by boat %s (%.1f m)" % [Vs.boat_name(from),
					(mine.get("at") as Vector2).distance_to(lay)])
			_check(float(vs.contact.get("_thud_t")) > thud_was, "a thud")
			if from == 2:
				mine.set("speed", 0.0)
				mine.set("drift", Vector2.ZERO)
				mine.set("spin", 0.0)
				await _secs(1.5)
				_mark("a_still")
		_mark("b_bumped")
	else:
		await _wait("a_still")
		await _secs(1.0)
		# B at A's other beam, 5 m/s, from my own machine: A's the first friend's to move
		var a_at: Vector2 = ha.get("at")
		mine.set("at", a_at + Vector2(20.0, 0.0))
		mine.set("heading", PI * 0.5)
		await _secs(2.5)
		a_at = ha.get("at")
		mine.set("at", a_at + Vector2(20.0, 0.0))
		var closest := INF
		for i in 30 * 8:
			if closest == INF:
				mine.set("speed", 5.0)
			await get_tree().process_frame
			var c := Contact.contact(boats[1], boats[0], 1.0)
			if not c.is_empty():
				closest = minf(closest, float(c["gap"]))
		_check(closest < 1.0 and closest > -1.5, "B met A, and didn't pass through (overlap at most %.2f m)" % -closest)
		_mark("b_ran")
	await _wait("fished")
	await _secs(0.5)
	_check(vs.shown == ([220, 243, 331] if first else [243, 220, 331]), "my tally, mine first (%s)" % [vs.shown])
	_mark("tally_ok_" + role)
	await _weighed_and_card()
	var card := vs.card
	if not first:
		await _until(func() -> bool: return card.t > card.T_BUTTONS, 20.0)
		vs.press_ready()
		await _until(func() -> bool: return card.ready_ids.has(Net.my_id()), 10.0)
		_check(card.states == [0, 1, 0] and card.ready_ids.has(Net.my_id()), "pressed NEXT DAY: B ready (%s)" % [card.states])
		_mark("b_ready")
	else:
		await _wait("b_ready")
		_check(card.states == [0, 1, 0] and card.up(), "B's pressed NEXT DAY: %s" % [card.states])
	_mark("saw_ready_" + role)
	if first:
		await _secs(0.3)
		vs.press_ready()
	await _next_day()
	_mark("next_ok_" + role)
	await _wait("four")
	await _secs(0.5)
	_settled("four", 4, [0, 1, 2], false, true)
	_check(vs.team_problem(Net.my_id()).contains("BOAT D"), "nobody on D: %s" % vs.team_problem(Net.my_id()))
	_mark("four_ok_" + role)
	await _wait("two")
	await _secs(0.5)
	_settled("two", 2, [0, 1, 0], false, true)
	_check(vs.team_problem(Net.my_id()) == "", "2 v 1 can start")
	_mark("two_ok_" + role)
	await _wait("fleet")
	await _secs(0.5)
	_settled("fleet", 2, [0, 1, 0], true, true)
	_mark("fleet_ok_" + role)
	await _fleet_out()
	_mark("done_" + role)
	await _secs(1.0)


# ------------------------------------------------------------------ everyone

## START pressed: the title down on every screen, the countdown, GO, all three out from their own berths.
func _out_from_title() -> void:
	var vs := sea.vs
	var t := sea.title
	await _until(func() -> bool: return not t.up, 30.0)
	_check(not t.up, "START: the title's down")
	await _secs(0.3)
	t.call("_skip")
	await _until(func() -> bool: return vs.count_end > 0.0, 30.0)
	_check(vs.count_end > 0.0 and vs.day == 1, "the countdown (day %d, %.1f s to go, title busy %s)" % [vs.day,
			vs.count_end - vs._now(), t.busy()])
	var holds: Array = vs.sides.map(func(s: Node) -> Node: return s.get("fish_hold"))
	await _until(func() -> bool: return holds.all(func(h: Node) -> bool: return not bool(h.get("docked"))), 40.0)
	_check(holds.all(func(h: Node) -> bool: return not bool(h.get("docked"))) and vs.count_end < 0.0, "GO: all three out")
	_check(vs.home.size() == 3 and vs.shown.size() == 3, "three on the tally")
	await _secs(0.5)


## Home: the weigh-in read off, the same result on every screen, C's day; then the card, three columns of it.
func _weighed_and_card() -> void:
	var vs := sea.vs
	var holds: Array = vs.sides.map(func(s: Node) -> Node: return s.get("fish_hold"))
	var all_in := func() -> bool: return holds.all(func(h: Node) -> bool: return bool(h.get("docked")))
	await _until(func() -> bool: return vs.result.size() == 3 and bool(all_in.call()), 40.0)
	var lb: Array = vs.result.map(func(x: float) -> int: return roundi(x))
	_check(lb == [220, 243, 331], "all home, weighed: %s" % [lb])
	_check(vs.wins == [0, 0, 1] and Vs.winner_of(vs.result) == 2, "the day to C (%s)" % [vs.wins])
	_check(vs.catches.size() == 3 and (vs.catches[1] as Array).size() == 2, "each boat's fish to read off")
	var card := vs.card
	var said := ""
	var verdict := vs.get("_verdict") as Label
	var until := Time.get_ticks_msec() + 60000
	while not card.up() and Time.get_ticks_msec() < until:
		if verdict.visible and not vs.weighing:
			said = verdict.text
		await get_tree().process_frame
	var want := "YOU WIN THE DAY BY 88 LB" if vs.my_team == 2 else "BOAT C WINS THE DAY BY 88 LB"
	# (the card's the host's to put up, by his clock: it can be up before a slower screen's read the last fish off)
	_check(said.is_empty() or said.begins_with(want), "the verdict: %s" % ("(the card came first)" if said.is_empty()
			else said.replace("\n", " / ")))
	var d: Dictionary = card.data
	var bs: Array = d.get("boats", [])
	_check(card.up() and int(d.get("winner", -9)) == 2 and not bool(d.get("decided", true))
			and not bool(d.get("together", true)), "the card: day 1 to C")
	_check(bs.size() == 3 and (d.get("wins", []) as Array) == [0, 0, 1] and (d.get("day_lb", []) as Array).size() == 3
			and (d.get("crewed", []) as Array) == [true, true, true] and card.states.size() == 3 and card.mine == vs.my_team,
			"three long: boats, wins, day_lb, crewed (%s), states (%s); mine marked" % [d.get("crewed"), card.states])
	if bs.size() == 3:
		_check(int(bs[0]["fish"]) == 1 and roundi(bs[0]["kg"]) == 100 and int(bs[1]["fish"]) == 2 and roundi(bs[1]["kg"]) == 110
				and int(bs[2]["fish"]) == 1 and roundi(bs[2]["kg"]) == 150 and roundi(bs[1]["lb"]) == 243,
				"A 1 fish 100 kg, B 2 fish 110 kg, C 1 fish 150 kg")
		var rows: Array = bs.map(func(b: Dictionary) -> Array:
			return [int(b["fish"]), roundi(b["kg"]), roundi(b["lb"]), int(b["money"])])
		print("STATE card ", JSON.stringify([d["winner"], d["wins"], rows]))


## Everyone's pressed: the card down, the match goes on, the next day's countdown.
func _next_day() -> void:
	var vs := sea.vs
	await _until(func() -> bool: return not vs.card.up() and vs.count_end > 0.0, 30.0)
	_check(not vs.card.up() and vs.result.is_empty() and vs.wins == [0, 0, 1] and vs.count_end > 0.0,
			"all pressed: the next day, the countdown (%s)" % [vs.wins])


## One fleet of two: the countdown again, GO, both out, nothing gone wrong.
func _fleet_out() -> void:
	var vs := sea.vs
	await _until(func() -> bool: return vs.count_end > 0.0, 20.0)
	var holds: Array = vs.sides.map(func(s: Node) -> Node: return s.get("fish_hold"))
	await _until(func() -> bool: return holds.all(func(h: Node) -> bool: return not bool(h.get("docked"))), 40.0)
	_check(holds.size() == 2 and holds.all(func(h: Node) -> bool: return not bool(h.get("docked"))) and vs.together
			and vs.wins == [0, 0] and vs.shown.size() == 2, "the fleet's out: both boats, GO")
	_check(sea.crew.me != null and sea.crew.me.boat == sea.boat and sea.boat == vs.sides[vs.my_team].get("boat"),
			"me aboard my own")
	await _secs(1.5)


## How it stands on this screen, which has to be how it stands on every one: `n` boats (as a fleet or not), everyone
## on the boat `by_slot` says (the host, the first friend, the second), each aboard her on this screen, and (`moored`)
## every boat at a berth of her own. Said in a line (STATE) that reads the same from every process.
func _settled(tag: String, n: int, by_slot: Array, fleet: bool, moored: bool) -> void:
	var vs := sea.vs
	var crew := sea.crew
	var got := [-1, -1, -1]
	for id: int in crew.slots:
		if int(crew.slots[id]) < 3:
			got[int(crew.slots[id])] = int(vs.teams.get(id, -1))
	var my_slot := int(crew.slots.get(Net.my_id(), 0))
	_check(vs.on and vs.boats == n and vs.sides.size() == n and vs.together == fleet and vs.wins.size() == n
			and vs.home.size() == n, "%s: %d boats%s (%d sides, wins %s)" % [tag, n, ", one fleet" if fleet else "",
			vs.sides.size(), vs.wins])
	_check(vs.teams.size() == 3 and got == by_slot and vs.my_team == int(by_slot[my_slot]),
			"%s: who's on which: %s, me on %s" % [tag, got, Vs.boat_name(vs.my_team)])
	if vs.sides.size() != n:
		return
	var aboard: bool = crew.me != null and crew.me.boat == sea.boat and sea.boat == vs.sides[vs.my_team].get("boat") \
			and sea.boat == vs.boat_of(Net.my_id()) and sea.fish_hold == vs.sides[vs.my_team].get("fish_hold")
	for id: int in crew.slots:
		var p := crew.get_player(id)
		aboard = aboard and p != null and p.home == vs.boat_of(id) and is_instance_valid(p.home) and p.home.is_inside_tree()
	_check(aboard, "%s: me aboard my own boat, she's the sea's; everyone on theirs" % tag)
	var said := []
	var own := true
	for i in n:
		var b := vs.sides[i].get("boat") as Node3D
		var at: Vector2 = b.get("helm").get("at")
		var berth := vs._berth(i)
		said.append("%s %.1f %.1f" % [Vs.boat_name(i), berth.x, berth.y])
		own = own and (not moored or at.distance_to(berth) < 1.0)
		for j in i:
			var to := vs._berth(j)
			own = own and (absf(berth.x - to.x) > float(b.get("beam")) or absf(berth.y - to.y) > float(b.get("length")))
	_check(own, "%s: every boat at a berth of her own: %s" % [tag, ", ".join(PackedStringArray(said))])
	print("STATE %s boats=%d fleet=%s teams=%s wins=%s berths=%s" % [tag, vs.boats, vs.together, got, vs.wins,
			", ".join(PackedStringArray(said))])


## A mark, said to all three (the test's own word, not the game's): how they keep in step.
@rpc("any_peer", "call_local", "reliable")
func _marked(what: String) -> void:
	marks[what] = true


func _mark(what: String) -> void:
	if Net.in_session():
		_marked.rpc(what)
	else:
		_marked(what)


## Until `what`'s been said (at most `most` s by the wall's clock; a FAIL if it never is).
func _wait(what: String, most := 90.0) -> void:
	await _until(func() -> bool: return marks.has(what), most)
	if not marks.has(what):
		_check(false, "heard '%s' within %d s" % [what, int(most)])


## Until both friends have said `what`.
func _all(what: String, most := 90.0) -> void:
	await _wait(what + "_join1", most)
	await _wait(what + "_join2", most)


## Until `ok`, at most `most` s by the wall's clock.
func _until(ok: Callable, most: float) -> void:
	var until := Time.get_ticks_msec() + int(most * 1000.0)
	while not bool(ok.call()) and Time.get_ticks_msec() < until:
		await get_tree().process_frame


## `s` seconds by the wall's clock.
func _secs(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _done() -> void:
	if _over:
		return
	_over = true
	for f in fails:
		print("FAIL ", f)
	print("BOATS NET TEST (%s) " % role, "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)


## The port: PORT, or --port=N (another, to run beside something already on it).
static func _port() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			return int(a.trim_prefix("--port="))
	return PORT
