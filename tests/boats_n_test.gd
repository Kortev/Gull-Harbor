extends Node
## Any number of boats (vs/vs.gd, docs/BOATS_PLAN.md): Rivals with three and four boats, and the boats as one fleet.
## Three boats: three sides, each her own boat, rods and fish hold, each at her own berth, none on another's; cross to
## C and she's the sea's boat. One lets go and all three do, in the same kind of boat. The schools turn up in the
## middle of them and round each in turn. Fish put straight into the holds so C has the most: weighed, the day's C's
## (wins 0-0-1), read off as BOAT C WINS THE DAY on A and YOU WIN on C, the card's numbers three long. The next day, A
## and C level for the most: nobody's. Then four boats there and then in the lobby (the fourth built, the crew shared
## out again, a fresh match), as one fleet (a day weighed: no winner, no wins, the card told so), back to two (C and D
## gone) and to the one boat (nothing left). And what the lobby says of a boat with nobody aboard (uneven's fine).
## Run: godot --headless --fixed-fps 30 --path . res://tests/boats_n_test.tscn

const Sea := preload("res://sea/sea.gd")
const Vs := preload("res://vs/vs.gd")

## The screen's height the HUD's laid out to (px: the project's, a headless run has no window to ask).
const SCREEN_H := 648.0

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(200.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var vs := sea.vs
	var a_boat := sea.boat
	_check(Vs.MAX_BOATS == 4 and Vs.boat_name(0) == "A" and Vs.boat_name(3) == "D", "up to four boats, A to D")
	var cols: Array = [Vs.boat_colour(0), Vs.boat_colour(1), Vs.boat_colour(2), Vs.boat_colour(3)]
	var apart := true
	for i in 4:
		for j in i:
			apart = apart and absf(cols[i].r - cols[j].r) + absf(cols[i].g - cols[j].g) + absf(cols[i].b - cols[j].b) > 0.4
	_check(apart and cols[0].is_equal_approx(Color(1.0, 0.74, 0.32)) and cols[1].is_equal_approx(Color(0.45, 0.8, 1.0)),
			"a colour each, none like another's (A's and B's the ones they had)")
	# three boats, set before it's on
	vs.host_set_boats(3)
	_check(vs.boats == 3 and not vs.on, "three boats picked in the lobby")
	vs.host_set_on(true)
	await get_tree().process_frame
	_check(vs.on and vs.sides.size() == 3 and vs.wins == [0, 0, 0], "three boats (%d), 0-0-0" % vs.sides.size())
	var own := true
	for i in 3:
		var s: Node = vs.sides[i]
		own = own and vs.get_node_or_null("ABC"[i]) == s and int(s.get("team")) == i and (s.get("boat") as Node).is_inside_tree()
		for j in i:
			for k: String in Vs.PARTS:
				own = own and s.get(k) != null and s.get(k) != vs.sides[j].get(k)
	_check(own and vs.sides[0].get("boat") == a_boat, "each her own boat, rods, landing, fish hold, chum and jig; A's the sea's")
	for i in 3:
		_check((vs.sides[i].get("boat") as Node).get_node_or_null("Horn") != null
				and int((vs.sides[i].get("boat") as Node).get_node("Horn").get("team")) == i, "a horn at boat %s's console" % "ABC"[i])
	_berths(vs, 3)
	for i in 3:
		_check(bool(vs.sides[i].get("boat").get("lines").call("tied")), "boat %s lies on her lines at her float" % "ABC"[i])
	# the lobby's word on the crews: alone it can't; a boat with nobody can't; uneven can
	_check(not vs.team_problem().is_empty(), "alone: %s" % vs.team_problem())
	var slots: Dictionary = sea.crew.slots
	slots[2] = 1
	slots[3] = 2
	slots[4] = 3
	vs.teams = {1: 0, 2: 0, 3: 1, 4: 1}
	var empty := vs.team_problem(1)
	_check(empty.contains("BOAT C") and empty.contains("NOBODY") and empty.contains("TAKE A BOAT AWAY"),
			"nobody on C: %s" % empty)
	_check(vs.team_problem(3).contains("SKIPPER"), "and to the rest: %s" % vs.team_problem(3))
	vs.teams = {1: 0, 2: 0, 3: 1, 4: 2}
	_check(vs.team_problem(1) == "", "2 v 1 v 1: uneven's fine")
	vs.teams = {1: 0, 2: 2, 3: 2, 4: 1}
	_check(vs.team_problem(4) == "", "1 v 1 v 2 too")
	slots.erase(4)
	vs.teams = {1: 0, 2: 1, 3: 2}
	_check(vs.team_problem(1) == "", "1 v 1 v 1")
	slots.erase(3)
	vs.teams = {1: 0, 2: 1}
	var short := vs.team_problem(1)
	_check(short.contains("2 ABOARD FOR 3 BOATS") and short.contains("BOAT C"), "two aboard, three boats: %s" % short)
	vs.seat_new(9)
	_check(int(vs.teams[9]) == 2, "someone new goes aboard the emptiest (C)")
	vs.teams.erase(9)
	slots.erase(2)
	vs.teams = {1: 0}
	# cross to C: she's the sea's boat; and not to a boat that isn't there
	var c: Node = vs.sides[2]
	var c_boat := c.get("boat") as Node3D
	vs.ask_team(3)
	await get_tree().process_frame
	_check(vs.my_team == 0, "no boat D to cross to")
	vs.ask_team(2)
	await get_tree().process_frame
	_check(vs.my_team == 2 and sea.boat == c_boat and sea.crew.me.boat == c_boat and sea.fish_hold == c.get("fish_hold")
			and sea.ocean.follow == c_boat, "crossed to C: aboard her, she's the sea's boat")
	_check(vs.sides[0].get("crew").get("me") == null and vs.sides[1].get("crew").get("me") == null
			and c.get("crew") == sea.crew, "A's and B's things don't see you aboard; C's do")
	vs.ask_team(0)
	await get_tree().process_frame
	_check(vs.my_team == 0 and sea.boat == a_boat, "and back to A")
	# one lets go: all three do
	await get_tree().process_frame
	_check(vs.count_end > 0.0, "at the dock, the countdown")
	var holds: Array = vs.sides.map(func(s: Node) -> Node: return s.get("fish_hold"))
	holds[1].call("head_out", "sportfisher")
	await get_tree().create_timer(0.3).timeout
	_check(holds.all(func(h: Node) -> bool: return not bool(h.get("docked"))), "B lets go: A and C go with her")
	_check(vs.sides.all(func(s: Node) -> bool: return str(s.get("boat").get("kind")) == "sportfisher"),
			"all in the same kind of boat")
	_check(vs.home.size() == 3 and vs.shown.size() == 3 and vs.day == 1, "day 1, three boats out")
	# the schools: the middle of them, then round each
	var ats: Array = vs.sides.map(func(s: Node) -> Vector2: return s.get("boat").get("helm").get("at"))
	var mid: Vector2 = (ats[0] + ats[1] + ats[2]) / 3.0
	var anchors: Array = [vs.spawn_anchor(), vs.spawn_anchor(), vs.spawn_anchor(), vs.spawn_anchor()]
	var near := func(p: Vector2, q: Vector2) -> bool: return p.distance_to(q) < 1.0
	_check(near.call(anchors[0], mid) and near.call(anchors[1], ats[0]) and near.call(anchors[2], ats[1])
			and near.call(anchors[3], ats[2]), "schools turn up in the middle of them, then round A, B and C in turn")
	# a strike on C's rod is C's alone, and A's crew hear of it
	(c.get("rods") as Node).call("host_cast", 0)
	(c.get("rods") as Node).call("strike", 0, 150.0)
	await get_tree().create_timer(0.3).timeout
	var on_by: Array = vs.sides.map(func(s: Node) -> bool:
		return (s.get("rods").get("rods") as Array).any(func(r: Node) -> bool: return bool(r.get("hooked"))))
	_check(on_by == [false, false, true], "a strike on C's rod is C's alone (%s)" % [on_by])
	_check(int(vs.get("_hooked")) == 1 and (vs.get("_on_by") as Array) == [0, 0, 1], "and C's dot's lit on A's tally")
	(c.get("rods") as Node).call("host_clear")
	# the catch: A 100 kg, B 60 + 50, C 150: C's day
	holds[0].call("host_add", 100.0, 60.0)
	holds[1].call("host_add", 60.0, 60.0)
	holds[1].call("host_add", 50.0, 60.0)
	holds[2].call("host_add", 150.0, 60.0)
	await get_tree().create_timer(0.2).timeout
	_check((vs.get("_race") as Control).visible and vs.shown == [220, 243, 331],
			"the tally: yours, then the others (%s)" % [vs.shown])
	vs.host_bring_home()
	await get_tree().create_timer(0.3).timeout
	_check(holds.all(func(h: Node) -> bool: return bool(h.get("docked"))), "all three home, tied up")
	_check(vs.result.size() == 3 and roundi(vs.result[0]) == 220 and roundi(vs.result[1]) == 243
			and roundi(vs.result[2]) == 331, "weighed: %s" % [vs.result.map(func(x: float) -> int: return roundi(x))])
	_check(vs.wins == [0, 0, 1], "the day to C (%s)" % [vs.wins])
	_check(vs.catches.size() == 3 and (vs.catches[1] as Array).size() == 2, "each boat's fish to read off")
	var verdict := vs.get("_verdict") as Label
	while vs.weighing:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.1).timeout
	var board := vs.get("_board") as Control
	_check(board.get_child_count() == 3 and (board.get_node("Boat2/Sum") as Label).text == "331 lb"
			and board.get_node("Boat1/Fish").get_child_count() == 2, "read off, a boat at a time: three on the board")
	await get_tree().process_frame
	_check(board.position.y + board.get_combined_minimum_size().y < SCREEN_H,
			"and they fit down the screen (%.0f px)" % board.get_combined_minimum_size().y)
	_check(verdict.visible and verdict.text.begins_with("BOAT C WINS THE DAY BY 88 LB"), "on A: %s"
			% verdict.text.replace("\n", " / "))
	vs.ask_team(2)
	await get_tree().create_timer(0.2).timeout
	_check(verdict.text.begins_with("YOU WIN THE DAY BY 88 LB"), "on C: %s" % verdict.text.replace("\n", " / "))
	vs.ask_team(0)
	await get_tree().create_timer(0.2).timeout
	# the card: three boats' numbers
	var card := vs.card
	await _until(func() -> bool: return card.up(), 6.0)
	var d: Dictionary = card.data
	_check(card.up() and int(d["winner"]) == 2 and not bool(d["decided"]) and not bool(d["together"]),
			"the card: day 1 to C")
	_check((d["boats"] as Array).size() == 3 and (d["wins"] as Array) == [0, 0, 1] and (d["day_lb"] as Array).size() == 3
			and (d["crewed"] as Array) == [true, false, false] and card.states.size() == 3,
			"three long: boats, wins, day_lb, crewed (%s), states (%s)" % [d["crewed"], card.states])
	_check(int(d["boats"][2]["fish"]) == 1 and roundi(d["boats"][2]["kg"]) == 150 and roundi(d["boats"][1]["lb"]) == 243,
			"C 1 fish 150 kg, B 243 lb")
	await _until(func() -> bool: return card.t > card.T_BUTTONS, 8.0)
	vs.press_ready()
	await _until(func() -> bool: return not card.up(), 5.0)
	await get_tree().process_frame
	_check(not card.up() and vs.result.is_empty() and vs.wins == [0, 0, 1] and vs.count_end > 0.0,
			"NEXT DAY: the match goes on, the countdown")
	# day 2: A and C level for the most: nobody's
	holds[0].call("head_out", "sportfisher")
	await get_tree().create_timer(0.3).timeout
	anchors = [vs.spawn_anchor(), vs.spawn_anchor()]
	ats = vs.sides.map(func(s: Node) -> Vector2: return s.get("boat").get("helm").get("at"))
	_check(vs.day == 2 and near.call(anchors[1], ats[1]), "day 2: the first school of a boat's own is B's")
	holds[0].call("host_add", 90.0, 60.0)
	holds[1].call("host_add", 40.0, 60.0)
	holds[2].call("host_add", 90.0, 60.0)
	await get_tree().create_timer(0.2).timeout
	vs.host_bring_home()
	await get_tree().create_timer(0.3).timeout
	_check(vs.result.size() == 3 and vs.wins == [0, 0, 1] and Vs.winner_of(vs.result) == -1,
			"A and C level for the most: nobody's day (%s)" % [vs.wins])
	await _until(func() -> bool: return card.up(), 30.0)
	_check(int(card.data["winner"]) == -1 and int(card.data["day"]) == 2, "and the card says nobody")
	while vs.weighing:
		await get_tree().create_timer(0.2).timeout
	_check(verdict.text.begins_with("A TIE FOR THE MOST: A AND C"), "the verdict under it: %s" % verdict.text.replace("\n", " / "))
	await _until(func() -> bool: return card.t > card.T_BUTTONS, 8.0)
	vs.press_ready()
	await _until(func() -> bool: return not card.up(), 5.0)
	await get_tree().process_frame
	# four boats, there and then
	var b_boat := vs.sides[1].get("boat") as Node3D
	vs.host_set_boats(4)
	await get_tree().create_timer(0.3).timeout
	_check(vs.on and vs.boats == 4 and vs.sides.size() == 4 and vs.wins == [0, 0, 0, 0] and vs.day == 1,
			"four boats: the fourth built, a fresh match")
	_check(vs.sides[1].get("boat") == b_boat and vs.sides[2].get("boat") == c_boat and vs.get_node_or_null("D") == vs.sides[3]
			and vs.get_node_or_null("D/Boat") != null, "B and C the boats they were, D new")
	_check(sea.boat == a_boat and sea.crew.me.boat == a_boat, "you still aboard A")
	_berths(vs, 4)
	for i in 4:
		_check(bool(vs.sides[i].get("boat").get("lines").call("tied")), "boat %s on her lines" % "ABCD"[i])
	slots[2] = 1
	slots[3] = 2
	slots[4] = 3
	_check(vs._share(4) == {1: 0, 2: 1, 3: 2, 4: 3} and vs._share(3) == {1: 0, 2: 1, 3: 2, 4: 0},
			"the crew shared out round the boats in the order they came aboard")
	for id: int in [2, 3, 4]:
		slots.erase(id)
	# as one fleet: a day, no winner, no wins
	vs.host_set_together(true)
	await get_tree().create_timer(0.2).timeout
	_check(vs.together and vs.sides.size() == 4, "one fleet, the same four boats")
	holds = vs.sides.map(func(s: Node) -> Node: return s.get("fish_hold"))
	await _until(func() -> bool: return vs.count_end > 0.0, 3.0)
	holds[3].call("head_out", "sportfisher")
	await get_tree().create_timer(0.3).timeout
	_check(holds.all(func(h: Node) -> bool: return not bool(h.get("docked"))), "D lets go: all four out")
	holds[0].call("host_add", 50.0, 60.0)
	holds[3].call("host_add", 100.0, 60.0)
	await get_tree().create_timer(0.2).timeout
	_check(vs.shown == [110, 0, 0, 220], "four rows on the tally (%s)" % [vs.shown])
	vs.host_bring_home()
	await get_tree().create_timer(0.3).timeout
	_check(vs.result.size() == 4 and vs.wins == [0, 0, 0, 0], "weighed: nobody's day, no wins (%s)" % [vs.wins])
	while vs.weighing:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.1).timeout
	_check(verdict.visible and verdict.text.begins_with("THE FLEET: 331 LB"), "the fleet's day: %s"
			% verdict.text.replace("\n", " / "))
	_check(board.get_child_count() == 4
			and board.position.y + board.get_combined_minimum_size().y < SCREEN_H,
			"four on the board, and they fit (%.0f px)" % board.get_combined_minimum_size().y)
	await _until(func() -> bool: return card.up(), 6.0)
	d = card.data
	_check(bool(d.get("together", false)) and int(d["winner"]) == -1 and not bool(d["decided"])
			and (d["wins"] as Array) == [0, 0, 0, 0] and (d["boats"] as Array).size() == 4, "the card told so: together, no winner")
	await _until(func() -> bool: return card.t > card.T_BUTTONS, 8.0)
	vs.press_ready()
	await _until(func() -> bool: return not card.up(), 5.0)
	# back to two, then to the one boat
	var d_boat := vs.sides[3].get("boat") as Node3D
	vs.ask_team(3)
	await get_tree().process_frame
	_check(sea.boat == d_boat, "aboard D")
	vs.host_set_boats(2)
	await get_tree().create_timer(0.3).timeout
	_check(vs.sides.size() == 2 and vs.boats == 2 and not is_instance_valid(c_boat) and not is_instance_valid(d_boat)
			and vs.get_node_or_null("C") == null and vs.get_node_or_null("D") == null, "two boats: C and D gone")
	_check(vs.together and vs.my_team == 0 and sea.boat == a_boat and sea.crew.me != null and sea.crew.me.boat == a_boat,
			"you off D and aboard A, still one fleet")
	vs.host_set_together(false)
	vs.host_set_boats(4)
	await get_tree().create_timer(0.3).timeout
	_check(vs.sides.size() == 4 and not vs.together, "and four again, against each other")
	var a_hold: Node = vs.sides[0].get("fish_hold")
	vs.host_set_on(false)
	await get_tree().create_timer(0.3).timeout
	var left := vs.get_children().filter(func(n: Node) -> bool: return n.get_script() == Vs.BoatSide)
	_check(not vs.on and vs.sides.is_empty() and left.is_empty() and not is_instance_valid(b_boat),
			"back to the one boat: no side left (%d)" % left.size())
	_check(sea.boat == a_boat and sea.crew.me.boat == a_boat and a_hold.get("sea") == sea and sea.fish_hold == a_hold
			and a_boat.get_node_or_null("Horn") == null, "and the sea's as it always was")
	_done()


## Every boat at a berth of her own, none lying on another.
func _berths(vs: Vs, n: int) -> void:
	var ok := true
	var said := ""
	for i in n:
		var bi: Node = vs.sides[i].get("boat")
		var at := vs._berth(i)
		said += "%s (%.0f, %.0f) " % ["ABCD"[i], at.x, at.y]
		ok = ok and (bi.get("helm").get("at") as Vector2).distance_to(at) < 0.5
		for j in i:
			var to := vs._berth(j)
			# (bows out, side by side or one ahead of the other: clear by a beam across, or a length along)
			ok = ok and (absf(at.x - to.x) > float(bi.get("beam")) or absf(at.y - to.y) > float(bi.get("length")))
	_check(ok, "%d berths, each her own, none on another: %s" % [n, said])


func _until(ok: Callable, most: float) -> void:
	var t := 0.0
	while not bool(ok.call()) and t < most:
		await get_tree().process_frame
		t += 1.0 / 30.0


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("BOATS N TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
