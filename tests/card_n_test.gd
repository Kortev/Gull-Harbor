extends Node
## Rivals' results card (vs/card.gd) with any number of boats: made on its own (a stand-in for vs/vs.gd behind it),
## opened with what the host would send for two, three and four boats, for a day won, a tie, a match decided and a
## day fished together, and read back through lines(): who stands where, what each is called, the verdict, the
## stamp, each crew's word and the line under the buttons; that the columns fit the card; and that it draws through
## its whole tally without a murmur. Run:
##   godot --headless --fixed-fps 30 --path . tests/card_n_test.tscn
## With -- --shots (needs a window) it also saves each case to docs/shots/card_n_<case>.png.

const Card := preload("res://vs/card.gd")
const PixFont := preload("res://ui/pixfont.gd")


## vs/vs.gd, as far as the card knows it.
class Stub extends Node:
	var my_team := 0
	var on := true
	var pressed := 0
	func press_ready() -> void:
		pressed += 1
	func to_title() -> void:
		pass


## The same with the boats' names and colours its own (as vs/vs.gd's are to be).
class Named extends Stub:
	static func boat_name(i: int) -> String:
		return "ABCD"[i]
	static func boat_colour(i: int) -> Color:
		return [Color(1.0, 0.74, 0.32), Color(0.45, 0.8, 1.0), Color(0.95, 0.52, 0.86), Color(0.6, 0.9, 0.45)][i]


const BOATS := [{"fish": 3, "kg": 412.0, "big": 220.0, "money": 9800, "late": 0.0, "lb": 908.0},
		{"fish": 2, "kg": 260.0, "big": 180.0, "money": 6100, "late": 40.0, "lb": 485.0},
		{"fish": 4, "kg": 530.0, "big": 241.0, "money": 12400, "late": 0.0, "lb": 1168.0},
		{"fish": 0, "kg": 0.0, "big": 0.0, "money": 0, "late": 0.0, "lb": 0.0}]

var card: Card
var stub: Stub
var _failed := 0
var _shots := false


func _ready() -> void:
	_shots = OS.get_cmdline_user_args().has("--shots")
	if _shots:
		# (something of the harbour's colour behind it, to see the card's edge against)
		var sea := ColorRect.new()
		sea.color = Color(0.1, 0.24, 0.3)
		sea.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(sea)
	stub = Named.new() if OS.get_cmdline_user_args().has("--named") else Stub.new()
	add_child(stub)
	card = Card.new()
	card.vs = stub
	add_child(card)
	await get_tree().process_frame
	await _two()
	await _three()
	await _four()
	await _together()
	await _crews()
	await _names()
	card.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("CARD N TEST ", "PASSED" if _failed == 0 else "FAILED")
	get_tree().quit(0 if _failed == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print("ok   " if ok else "FAIL ", what)
	if not ok:
		_failed += 1


## What the host sends for boats `which` (indices into BOATS), boat `winner` taking it.
func _data(which: Array, winner: int, wins: Array, decided := false, day := 1, together := false) -> Dictionary:
	var boats: Array = which.map(func(i: int) -> Dictionary: return (BOATS[i] as Dictionary).duplicate())
	var d := {"decided": decided, "winner": winner, "day": day, "wins": wins, "boats": boats,
			"crewed": which.map(func(_i: int) -> bool: return true),
			"day_lb": boats.map(func(b: Dictionary) -> float: return float(b["lb"]))}
	if together:
		d["together"] = true
	return d


## Up with `d` as boat `mine`'s crew see it, through its whole tally (every frame of it drawn), the buttons live.
func _open(d: Dictionary, mine: int, shot := "") -> Dictionary:
	stub.my_team = mine
	card.open(d, mine)
	_check(card.states.size() == (d["boats"] as Array).size() and card.states.all(func(s: int) -> bool: return s == 0),
			"%s: one crew a boat, all deciding (%s)" % [shot, card.states])
	# the reveal: nothing's whole at once (the numbers count up, the stamp's still to come)
	await get_tree().process_frame
	var early := card.shown(5, 0)
	var steps := 0
	while card.t < card.T_BUTTONS + 0.7 and steps < 2000:
		if steps == 20:
			card.set("_fast", true)        # (a key hurries the tally, as in the game: it still counts every row)
		await get_tree().process_frame
		steps += 1
	_check(early < float((d["boats"] as Array)[0]["lb"]) or float((d["boats"] as Array)[0]["lb"]) == 0.0,
			"%s: it tallies up, not there at once (%.0f at first)" % [shot, early])
	_check(card.up() and card.stamped() and card._can_press(), "%s: up, stamped, the buttons live" % shot)
	_fits(shot)
	if _shots and shot != "":
		await _shot(shot)
	return card.lines()


## The columns stand on the card, clear of the rows' names and of each other, with the widest thing each says.
func _fits(what: String) -> void:
	var said := card.lines()
	var at := card.columns()
	var n := card.boats()
	var seats: Array = said["order"]
	var names_end := 30.0 + PixFont.width("LATE: HALF", 2)
	var worst := 0.0
	var ok := at.size() == n and seats.size() == n
	for k in at.size():
		var i: int = seats[k]
		var w := maxf(PixFont.width(str(said["heads"][k]), 4), PixFont.width(str(said["tags"][k]), 2))
		for c: String in ["DECIDING...", "READY", "NOBODY ABOARD", "LOST CONNECTION", "LEFT THE GAME"]:
			w = maxf(w, PixFont.width(c, 2))
		for r in card.ROWS.size():
			w = maxf(w, PixFont.width(card.cell(r, i, card._value(r, i)), 3))
		# (and the most a boat could weigh in a match: four figures a row)
		w = maxf(w, PixFont.width("-9999 LB", 3))
		worst = maxf(worst, w)
		ok = ok and at[k] - w * 0.5 >= names_end + 8.0 and at[k] + w * 0.5 <= card.W - 8.0
		if k > 0:
			ok = ok and at[k] - at[k - 1] >= w + 8.0
	for s: String in [str(said["verdict"]), str(said["status"]), str(said["sub"])]:
		ok = ok and PixFont.width(s, 3) <= card.W - 40
	_check(ok, "%s: %d columns fit the card (%s, the widest thing %d px, a column %d)" % [what, n, at, worst, card.span()])


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://docs/shots/card_n_%s.png" % what
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)


# ---- two boats: as it's always read ------------------------------------------------------------------------------

func _two() -> void:
	var l := await _open(_data([0, 1], 0, [1, 0]), 0, "2_day")
	_check(l["order"] == [0, 1] and l["heads"] == ["BOAT A", "BOAT B"] and l["tags"] == ["YOU", "THEM"],
			"two boats, on A: A then B, YOU and THEM (%s %s)" % [l["heads"], l["tags"]])
	_check(l["title"] == "DAY 1" and l["sub"] == "FIRST TO TWO DAYS WINS" and l["stamp"] == "DAY WON"
			and l["verdict"] == "THE DAY'S YOURS, BY 423 LB", "A's day: %s / %s" % [l["stamp"], l["verdict"]])
	_check(l["buttons"] == ["NEXT DAY", "BACK TO THE TITLE"] and l["status"] == "EVERYONE PRESSES NEXT DAY TO GO ON"
			and l["rows"] == card.ROWS, "NEXT DAY, and how to go on (%s)" % l["status"])
	_check(card.columns() == [380.0, 610.0], "the two columns where they've always stood (%s)" % [card.columns()])
	_check(card.cell(1, 0, 3.0) == "3" and card.cell(2, 0, 412.0) == "412 KG" and card.cell(3, 0, 220.0) == "220 KG"
			and card.cell(4, 0, 0.0) == "-" and card.cell(4, 1, 40.0) == "-40 LB" and card.cell(5, 1, 485.0) == "485 LB",
			"the numbers as they're written")
	l = await _open(_data([0, 1], 0, [1, 0]), 1, "2_day_theirs")
	_check(l["order"] == [1, 0] and l["heads"] == ["BOAT B", "BOAT A"] and l["tags"] == ["YOU", "THEM"]
			and l["verdict"] == "THEIR DAY, BY 423 LB", "on B: yours comes first, the day's theirs (%s, %s)"
			% [l["heads"], l["verdict"]])
	l = await _open(_data([0, 0], -1, [1, 0], false, 2), 0, "2_tie")
	_check(l["stamp"] == "TIE" and l["verdict"] == "DEAD EVEN: 908 LB EACH. NO DAY TO EITHER" and l["title"] == "DAY 2",
			"a tie: %s" % l["verdict"])
	l = await _open(_data([0, 1], 0, [2, 1], true, 3), 0, "2_match")
	_check(l["title"] == "THE MATCH" and l["sub"] == "OVER 3 DAYS, BEST OF THREE" and l["stamp"] == "WINNER"
			and l["verdict"] == "YOU TAKE THE MATCH, 2-1" and l["buttons"][0] == "REMATCH", "the match: %s" % l["verdict"])
	stub.my_team = 1
	_check(card.lines()["verdict"] == "THEY TAKE THE MATCH, 2-1", "and from B: %s" % card.lines()["verdict"])


# ---- three --------------------------------------------------------------------------------------------------------

func _three() -> void:
	var l := await _open(_data([0, 1, 2], 2, [0, 1, 1], false, 2), 1, "3_day")
	_check(l["order"] == [1, 0, 2] and l["heads"] == ["BOAT B", "BOAT A", "BOAT C"]
			and l["tags"] == ["YOU", "RIVAL", "RIVAL"], "three boats, on B: B, then A and C (%s %s)" % [l["heads"], l["tags"]])
	_check(l["stamp"] == "DAY WON" and l["verdict"] == "BOAT C WINS THE DAY, BY 260 LB",
			"C's day, over the next best: %s" % l["verdict"])
	stub.my_team = 2
	_check(card.lines()["verdict"] == "YOU WIN THE DAY, BY 260 LB" and card.lines()["order"] == [2, 0, 1],
			"and from C: %s" % card.lines()["verdict"])
	l = await _open(_data([0, 1, 0], -1, [1, 0, 0], false, 2), 0, "3_tie")
	_check(l["stamp"] == "TIE" and l["verdict"] == "A TIE AT 908 LB: NOBODY TAKES THE DAY", "a tie for the most: %s"
			% l["verdict"])
	l = await _open(_data([0, 1, 2], 0, [2, 0, 1], true, 3), 0, "3_match")
	_check(l["title"] == "THE MATCH" and l["sub"] == "OVER 3 DAYS, FIRST TO TWO" and l["stamp"] == "WINNER"
			and l["verdict"] == "YOU WIN THE MATCH, 2-1-0" and l["buttons"][0] == "REMATCH", "the match: %s" % l["verdict"])
	stub.my_team = 1
	_check(card.lines()["verdict"] == "BOAT A WINS THE MATCH, 2-1-0", "and from B: %s" % card.lines()["verdict"])


# ---- four ---------------------------------------------------------------------------------------------------------

func _four() -> void:
	var l := await _open(_data([0, 1, 2, 3], 2, [1, 0, 1, 0], false, 2), 0, "4_day")
	_check(l["order"] == [0, 1, 2, 3] and l["heads"] == ["BOAT A", "BOAT B", "BOAT C", "BOAT D"]
			and l["tags"] == ["YOU", "RIVAL", "RIVAL", "RIVAL"], "four boats, on A (%s)" % [l["heads"]])
	_check(l["verdict"] == "BOAT C WINS THE DAY, BY 260 LB" and l["stamp"] == "DAY WON", "C's day: %s" % l["verdict"])
	_check(card.cell(3, 3, 0.0) == "-" and card.cell(5, 3, 0.0) == "0 LB", "a boat with nothing: no biggest, 0 LB")
	l = await _open(_data([0, 1, 2, 3], 2, [1, 0, 1, 0], false, 2), 3, "4_day_from_d")
	_check(l["order"] == [3, 0, 1, 2] and l["heads"] == ["BOAT D", "BOAT A", "BOAT B", "BOAT C"],
			"on D: D first, then A, B, C (%s)" % [l["heads"]])
	l = await _open(_data([2, 1, 2, 3], -1, [1, 0, 1, 0], false, 3), 1, "4_tie")
	_check(l["stamp"] == "TIE" and l["verdict"] == "A TIE AT 1168 LB: NOBODY TAKES THE DAY", "a tie: %s" % l["verdict"])
	l = await _open(_data([0, 1, 2, 3], 3, [1, 1, 1, 2], true, 5), 3, "4_match")
	_check(l["verdict"] == "YOU WIN THE MATCH, 2-1-1-1" and l["stamp"] == "WINNER" and l["sub"] == "OVER 5 DAYS, FIRST TO TWO",
			"the match, the last boat's: %s" % l["verdict"])
	# nobody's boat (a watcher): the boats in their order, by name
	l = await _open(_data([0, 1, 2, 3], 2, [1, 0, 1, 0], false, 2), -1, "")
	_check(l["order"] == [0, 1, 2, 3] and not (l["tags"] as Array).has("YOU") and l["verdict"] == "BOAT C WINS THE DAY, BY 260 LB",
			"on no boat: nobody's YOU, the winner by name")


# ---- one fleet ----------------------------------------------------------------------------------------------------

func _together() -> void:
	for which: Array in [[0, 1], [0, 1, 2], [0, 1, 2, 3]]:
		var n := which.size()
		var wins := which.map(func(_i: int) -> int: return 0)
		var mine := n - 1
		var l := await _open(_data(which, -1, wins, false, 2, true), mine, "%d_together" % n)
		var lb := 0
		var fish := 0
		for i: int in which:
			lb += int(BOATS[i]["lb"])
			fish += int(BOATS[i]["fish"])
		_check(l["verdict"] == "THE FLEET'S DAY: %d LB, %d FISH" % [lb, fish] and l["stamp"] == ""
				and not (l["rows"] as Array).has("DAYS WON"), "%d together: no winner, no days won; %s" % [n, l["verdict"]])
		var sum := 0
		for s: String in l["shares"]:
			sum += int(s.trim_suffix("%"))
		_check((l["shares"] as Array).size() == n and absi(sum - 100) <= 2 and l["shares"][0] == "%d%%" % card.share(mine)
				and l["tags"][0] == "YOU" and l["tags"][1] == "WITH YOU" and l["order"][0] == mine,
				"each boat's share under it, yours first (%s, %s)" % [l["shares"], l["tags"]])
		_check(l["sub"] == "ONE FLEET: %d BOATS FISHING TOGETHER" % n and l["buttons"][0] == "NEXT DAY", str(l["sub"]))
	# nothing caught by anyone
	var l := await _open(_data([3, 3, 3], -1, [0, 0, 0], false, 1, true), 0, "")
	_check(l["verdict"] == "THE FLEET'S DAY: 0 LB, 0 FISH" and l["shares"] == ["-", "-", "-"], "an empty day: %s" % l["verdict"])


# ---- the crews under it -------------------------------------------------------------------------------------------

func _crews() -> void:
	var me := Net.my_id()
	# two boats: the words it's always had
	await _open(_data([0, 1], 0, [1, 0]), 0, "")
	card.states = [0, 1]
	_check(card._status() == "THEY'RE READY FOR THE NEXT DAY" and card._status_colour() == card.AMBER, "two: " + card._status())
	card.states = [1, 0]
	card.ready_ids = [me]
	_check(card._status() == "WAITING FOR THEM..." and card._primary() == "READY!", "two: " + card._status())
	card.states = [0, 0]
	_check(card._status() == "WAITING FOR YOUR CREW...", "two: " + card._status())
	card.ready_ids = []
	card.states = [0, 3]
	_check(card._status() == "THEY LOST CONNECTION. WAIT, OR NEXT DAY TO GO ON WITHOUT THEM", "two: " + card._status())
	card.states = [0, 4]
	_check(card._status() == "THEY'VE LEFT. NEXT DAY TO GO ON WITHOUT THEM" and card._can_press(), "two: " + card._status())
	# the host's gone, as vs/vs.gd says it: every other boat left, vs off, the card kept up for the boat you were on
	stub.on = false
	stub.my_team = 0
	card.mine = 0
	card.gone = true
	_check(card._status() == "THEY'VE LEFT THE GAME. BACK TO THE TITLE" and not card._can_press()
			and card._status_colour() == card.BAD, "two, the host gone: " + card._status())
	stub.on = true
	# four, from C
	var l := await _open(_data([0, 1, 2, 3], 2, [0, 0, 1, 0]), 2, "")
	card.states = [1, 0, 0, 2]
	l = card.lines()
	_check(l["crews"][0].begins_with("DECIDING") and l["crews"][1] == "READY" and l["crews"][3] == "NOBODY ABOARD",
			"four, from C: each crew's word under her own column (%s over %s)" % [l["crews"], l["heads"]])
	_check(card._status() == "BOAT A'S READY FOR THE NEXT DAY" and card._status_colour() == card.AMBER, "four: " + card._status())
	card.states = [1, 1, 0, 2]
	_check(card._status() == "BOATS A AND B ARE READY FOR THE NEXT DAY", "four: " + card._status())
	card.ready_ids = [me]
	card.states = [0, 1, 0, 0]
	_check(card._status() == "WAITING FOR YOUR CREW...", "four: " + card._status())
	card.states = [0, 1, 1, 0]
	_check(card._status() == "WAITING FOR BOATS A AND D..." and card._status_colour() == card.DIM, "four: " + card._status())
	card.states = [1, 1, 1, 0]
	_check(card._status() == "WAITING FOR BOAT D...", "four: " + card._status())
	card.ready_ids = []
	card.states = [3, 1, 0, 3]
	_check(card._status() == "BOATS A AND D LOST CONNECTION. WAIT, OR NEXT DAY TO GO ON WITHOUT THEM", "four: " + card._status())
	card.states = [0, 4, 0, 1]
	_check(card._status() == "BOAT B'S LEFT. NEXT DAY TO GO ON WITHOUT THEM", "four: " + card._status())
	card.states = [4, 4, 0, 4]
	_check(card._status() == "BOATS A, B AND D HAVE LEFT. NEXT DAY TO GO ON WITHOUT THEM" and card._can_press(),
			"four: " + card._status())
	# a word from a host that still counts two boats: the rest are deciding, nothing breaks
	card.states = [1, 0]
	l = card.lines()
	_check(card.state(3) == 0 and l["crews"][1] == "READY" and (l["crews"] as Array).size() == 4,
			"states short of the boats: the rest deciding (%s)" % [l["crews"]])
	await get_tree().process_frame
	# pressing goes to vs, as ever
	var before := stub.pressed
	card._press(0)
	_check(stub.pressed == before + 1, "NEXT DAY pressed: vs hears it")
	# four, the host gone: every other boat marked left
	card.states = [4, 4, 0, 4]
	stub.on = false
	card.mine = 2
	card.gone = true
	l = card.lines()
	_check(l["status"] == "THE HOST'S LEFT THE GAME. BACK TO THE TITLE" and not card._can_press() and l["order"] == [2, 0, 1, 3]
			and l["tags"][0] == "YOU" and l["crews"][0] == "" and l["crews"][1] == "LEFT THE GAME" and l["crews"][3] == "LEFT THE GAME",
			"four, the host gone: %s (%s)" % [l["status"], l["crews"]])
	for i in 3:
		await get_tree().process_frame
	if _shots:
		await _shot("4_host_gone")
	stub.on = true
	# the fade: the card goes to black over its time, never at once
	await _open(_data([0, 1, 2], 1, [0, 1, 0]), 0, "")
	card.fade_out()
	await get_tree().process_frame
	await get_tree().process_frame
	var d0 := card.dark()
	_check(d0 > 0.0 and d0 < 0.5 and card._status() == "", "all pressed: it starts to fade (%.2f dark)" % d0)
	var most := 0.0
	var last := d0
	var until := Time.get_ticks_msec() + 4000
	while card.dark() < 0.995 and Time.get_ticks_msec() < until:
		await get_tree().process_frame
		most = maxf(most, card.dark() - last)
		last = card.dark()
	_check(card.dark() > 0.99 and most < 0.2, "to black, a step at a time (the biggest %.2f)" % most)
	card.drop()
	_check(not card.up() and card.dark() == 0.0, "dropped: down")


# ---- whose names --------------------------------------------------------------------------------------------------

func _names() -> void:
	var named := Named.new()
	add_child(named)
	_check(named.has_method("boat_name") and named.has_method("boat_colour"), "a vs with the boats' names: the card can ask")
	card.vs = named
	named.my_team = 1
	card.open(_data([0, 1, 2, 3], 3, [0, 0, 0, 1]), 1)
	_check(card.boat_name(2) == "C" and card.boat_colour(3) == Color(0.6, 0.9, 0.45)
			and card.lines()["heads"] == ["BOAT B", "BOAT A", "BOAT C", "BOAT D"], "names and colours from vs (%s)"
			% [card.lines()["heads"]])
	card.vs = stub
	stub.my_team = 0
	_check(card.boat_name(3) == "D" and card.boat_colour(0) == card.COLOURS[0] and card.boat_colour(1) == card.COLOURS[1]
			and card.COLOURS.size() == 4, "and its own when vs has none: A and B the colours they've had")
	named.queue_free()
