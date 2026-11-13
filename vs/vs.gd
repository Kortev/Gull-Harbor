extends Node
## VS (docs/VISION.md, docs/BOATS_PLAN.md): two, three or four boats (`boats`) on the same sea, a crew each (any
## number aboard, the crews needn't be even), after the same birds. Against each other, whoever has the most pounds
## aboard when the trip ends wins the day; `together`, they're one fleet: the pounds add up and nobody wins or loses.
##
## The skipper (the host) turns it on at the dock; everyone's put on a boat, A to D (the host's word, `teams`), and
## each can cross to another at the dock. Boat A is the boat the sea always had; the others are more of her with all
## their own things (her rods, the landing, her fish hold, her chum and jig: vs/side.gd is "the sea" to them), made on
## every peer at the same path, so the host runs them all and each peer sees them all, exactly as it sees its own boat
## in co-op. The sea's own `boat`, `rods`, ... are whichever boat you're on (your camera, your HUD, your screens).
## (Below, "both" and "the other" are from when there were only ever two: read "all" and "the others".)
##
## The start: both boats wait at their berths either side of the fish pier, mirrored (neither's nearer the harbour
## mouth), the crews free to walk about. Once the title's down (and after a trip, once everyone's pressed on from the
## results card), a countdown runs at the top of everyone's screen with a tick a second, and on GO the horns blow and
## both are let go at once: each crew takes her out through the harbour mouth themselves. No skipper's button, no
## moving the boats anywhere.
## The trip: when one boat heads out the other goes too, in the same kind of boat. The
## schools turn up between them first, then round one boat and the other in turn (spawn_anchor). Out there they're solid to each
## other and rock in each other's wakes (vs/contact.gd), and you can jump across to board her. Top left, small: both boats' pounds
## aboard, and a blinking dot and the squelch on the radio when the other crew hooks up. An air horn at each console
## (vs/horn.gd) to rattle the other crew. At dusk the race home: HOME s to bring her in alongside her own berth
## (slow, TIE s, and she's tied up and her catch sold there, no cut); once both are in, or time's up, what each had
## aboard (on deck and iced) is weighed, a fish at a time, A's then B's, and the winner said. A boat not home in time
## is towed in (the one cut left) and her catch weighs half (and sells for half). Best of three days: the first to two
## wins the match. After each weigh-in the results card (vs/card.gd) comes up on every screen at once: the day's (or,
## once it's won, the match's) numbers side by side and the winner stamped; everyone presses NEXT DAY (REMATCH), the
## screen fades to black, both boats are back at their berths, fresh weather from the host, and the countdown again.
##
## A crewmate whose line drops mid-match: their boat carries on without them (coasting to a stop, her baits fishing),
## everyone told who we're waiting on (crew/crew.gd), and when they join again they're back aboard her with the
## match as it stands: the wins, both holds, the countdown or the race home, the card if it's up. Gone at the card:
## it says they lost connection, and the rest can go on without them (NEXT DAY) or wait.
##
## Dev and tests: --vs turns it on at the start (with --team=b, the host takes boat B; --boats=3, three of them;
## --together, one fleet).

const BoatSide := preload("res://vs/side.gd")
const Boat := preload("res://boat/boat.gd")
const Rods := preload("res://rods/rods.gd")
const Landing := preload("res://tuna/landing.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const Chum := preload("res://boat/chum.gd")
const Jig := preload("res://boat/jig.gd")
const Landmarks := preload("res://sea/landmarks.gd")
const Contact := preload("res://vs/contact.gd")
const Horn := preload("res://vs/horn.gd")
const Hud := preload("res://ui/hud.gd")
const Sfx := preload("res://audio/sfx.gd")
const PixFont := preload("res://ui/pixfont.gd")
const Kit := preload("res://ui/kit.gd")
const Card := preload("res://vs/card.gd")
## Each boat's things, the sea's and a side's (the sea's point at the boat you're on).
const PARTS := ["boat", "rods", "landing", "fish_hold", "chum", "jig"]
## The boats set out from the harbour (sea/landmarks.gd): side by side inside the breakwaters, IN m off the beach,
## APART m either side of the middle, bows out to sea.
const APART := 25.0
const IN := 110.0
const LB_PER_KG := 2.20462
## The most boats (there are at most four aboard in all: Net.MAX_CREW).
const MAX_BOATS := 4
## Each boat's colour (the tally, the weigh-in, the card, the lobby): boat_colour(i).
const COLOURS := [Color(1.0, 0.74, 0.32), Color(0.45, 0.8, 1.0), Color(0.56, 0.92, 0.5), Color(0.96, 0.58, 0.9)]
## The weigh-in: a fish read off every this many s (quicker with a lot of them), and a pause between the boats.
const READ := 0.8
const BETWEEN := 1.2
## Days won to win the match.
const MATCH := 2
## The countdown to casting off (s); after a weigh-in, how long before the results card comes up (s).
const COUNT := 10.0
const CARD_IN := 2.5
## The race home at dusk: how long they've got (s), how long alongside her berth, slow, ties her up (s).
const HOME := 360.0
const TIE := 2.0

var sea: Node                 # sea/sea.gd
var on := false
## How many boats (2 .. MAX_BOATS; the host's word, host_set_boats), and whether they fish as one fleet rather than
## against each other (host_set_together). Every array a boat below is `boats` long.
var boats := 2
var together := false
## Peer id -> the boat they're on (0 A .. boats - 1): the host's word.
var teams := {}
## The boat you're on (0 A ..).
var my_team := 0
## One a boat, A first (vs/side.gd), while it's on.
var sides: Array = []
## The last trip's weigh-in, pounds a boat ([] till all are in), and each boat's fish (lb, in the order caught).
var result: Array = []
var catches: Array = []
## Days each boat has won this match (best of three); and the weigh-in's still being read off.
var wins := [0, 0]
var weighing := false
## Where the boats meet (vs/contact.gd).
var contact: Contact
## What the tally shows: your boat's pounds, then the others' in their order (rounded).
var shown := [0, 0]
var _out := false
var _last := [0.0, 0.0]
var _anchor := 0
var _draw_in := 0.0
## When (the sea clock) both boats are let go, while the countdown's running (-1: it isn't).
var count_end := -1.0
## The race home: when time's up (the sea clock; -1 before dusk), and which boats are in alongside their berths.
var home_by := -1.0
var home := [false, false]
var _alongside_for := [0.0, 0.0]
## This trip: each boat's had her lines aboard (been away from the floats), and the launch has gone for her.
var _away := [false, false]
var _late := [false, false]
## s since the weigh-in was read off (-1: it hasn't been): the card comes up CARD_IN after it.
var _weighed_for := -1.0
## The results card (vs/card.gd).
var card: Card
## Host: who's pressed NEXT DAY / REMATCH (peer id -> true), the card waiting to go up, the days weighed this match and
## each boat's numbers over them, s since the fade to the next began (-1: it hasn't).
var pressed := {}
var _pending := {}
var _days := 0
var _match: Array = []
## The match's day out there now (everyone's: the HUD's top left).
var day := 1
var _fading_for := -1.0
var _go_shown := -10.0
var _ticked := -1
var _count: Control
var _kit := Kit.new()
var _ui: CanvasLayer
var _race: Control
var _verdict: Label
var _board: VBoxContainer
var _steps: Array = []
var _step_in := 0.0
var _hooked := -1             # the other boats' fish on, last frame (all of them; -1: not looked yet)
var _on_by: Array = []        # and a boat (yours left at 0): whose dot blinks
var _their_on := 0.0          # s since one of them hooked up (the dots blink)


func _ready() -> void:
	_build_ui()
	card = Card.new()
	card.name = "Card"
	card.vs = self
	add_child(card)
	contact = Contact.new()
	contact.name = "Contact"
	contact.vs = self
	add_child(contact)
	var after := After.new()
	after.name = "After"
	after.vs = self
	after.process_priority = 1000
	add_child(after)
	Net.peer_joined.connect(func(id: int) -> void:
		if not on or not multiplayer.is_server():
			return
		# (back after a drop: their own boat, crew/crew.gd's word; anyone new, the boat with fewer aboard)
		var was: Dictionary = ((sea.get("crew") as Node).get("back") as Dictionary).get(id, {})
		if was.has("team") and int(was["team"]) < boats:
			teams[id] = int(was["team"])
		else:
			teams.erase(id)        # (a boat that's since been taken away: the emptiest instead)
			seat_new(id)
		_switch.rpc_id(id, true, teams, result, wins, boats, together)
		# (every hold again: their start set A's aside, wiping what A's hold had just told them)
		for s: Node in sides:
			var hold: Node = s.get("fish_hold")
			hold.rpc_id(id, &"_sync", hold.call("_state"))
		_teams.rpc(teams)
		_counting.rpc_id(id, count_end)
		_day_is.rpc_id(id, day)
		_homeward.rpc_id(id, home_by, home)
		if card.up():
			_card_open.rpc_id(id, card.data)
			_send_states())
	Net.peer_left.connect(func(id: int) -> void:
		var away: Dictionary = (sea.get("crew") as Node).get("away")
		if on and away.has(id) and teams.has(id):
			(away[id] as Dictionary)["team"] = int(teams[id])     # (their boat kept for them)
		teams.erase(id)
		pressed.erase(id)
		if on and card.up():
			_send_states())
	# (joining someone's boat: their skipper's word on VS from here; leaving or dropped: your own one boat)
	Net.joined.connect(func() -> void:
		card.drop()        # (a card kept up from a boat we were dropped from: gone, the host's word follows)
		_switch(false, {}, [], [0, 0])
		boats = 2              # (and how many boats, and whether as a fleet)
		together = false
		var was := int(Net.last_join.get("was", 0))
		Net.last_join.erase("was")
		if was > 1:
			_was.rpc_id(1, was))
	Net.left.connect(func(_was_host: bool) -> void:
		_switch(false, {}, [], [0, 0])
		boats = 2
		together = false)
	Net.dropped.connect(func(_reason: String) -> void:
		# (the host's gone: the card stays up, saying so, with only the title left)
		var keep := card.up()
		if keep:
			card.gone = true
			for i in card.states.size():
				if i != card.mine:
					card.states[i] = 4
		_switch(false, {}, [], [0, 0], 2, false, keep)
		boats = 2
		together = false)


# ------------------------------------------------------------------ the host

## Skipper, at the dock: `boats` boats (everyone shared out over them), or back to the one.
func host_set_on(want: bool) -> void:
	if not Net.is_host() or want == on or not _all_docked():
		return
	result = []
	_host_switch(want, _share(boats) if want else {}, boats, together)


## Skipper, at the dock: how many boats, 2 .. MAX_BOATS. While it's on they're built or taken away there and then on
## every screen, the crew shared out over them afresh and every boat moored at her berth; a match begun starts over.
func host_set_boats(n: int) -> void:
	n = clampi(n, 2, MAX_BOATS)
	if not Net.is_host() or n == boats or not _all_docked():
		return
	if not on:
		boats = n          # (told to the rest when it comes on)
		return
	result = []
	_host_switch(true, _share(n), n, together)


## Skipper, at the dock: the boats as one fleet (true: no winner, the pounds add up) or against each other.
func host_set_together(yes: bool) -> void:
	if not Net.is_host() or yes == together or not _all_docked():
		return
	if not on:
		together = yes
		return
	result = []
	_host_switch(true, teams.duplicate(), boats, yes)


func _host_switch(want: bool, t: Dictionary, n: int, fleet: bool) -> void:
	var none := []
	none.resize(n)
	none.fill(0)
	if Net.in_session():
		_switch.rpc(want, t, [], none, n, fleet)
	else:
		_switch(want, t, [], none, n, fleet)


## Everyone aboard shared out over `n` boats, round and round in the order they came aboard (their slots).
func _share(n: int) -> Dictionary:
	var slots: Dictionary = (sea.get("crew") as Node).get("slots")
	var ids: Array = slots.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(slots[a]) < int(slots[b]))
	var t := {}
	for i in ids.size():
		t[ids[i]] = i % n
	return t


## `v`, once a boat.
func _each(v: Variant) -> Array:
	var a := []
	a.resize(boats)
	a.fill(v)
	return a


## How many are aboard each boat (the host's word, `teams`).
func _aboard() -> Array:
	var n := _each(0)
	for t: int in teams.values():
		if t >= 0 and t < boats:
			n[t] += 1
	return n


static func boat_name(i: int) -> String:
	return "ABCD"[clampi(i, 0, MAX_BOATS - 1)]


static func boat_colour(i: int) -> Color:
	return COLOURS[clampi(i, 0, MAX_BOATS - 1)]


## Why the boats as they're crewed can't set out ("" if they can): for the lobby (ui/title.gd won't START). The crews
## needn't be even (2 v 1, 3 v 1, 1 v 1 v 1 are all fine); what won't do is nobody to fish against (or with), or a boat
## with nobody aboard her. `who` (a peer id, or 0): whose screen it is (the skipper's told what he can do about it).
func team_problem(who := 0) -> String:
	var crew: Node = sea.get("crew")
	var slots: Dictionary = crew.get("slots") if crew != null else {}
	var n := _each(0)
	for id: int in slots:
		n[clampi(int(teams.get(id, 0)), 0, boats - 1)] += 1
	var total := 0
	for k: int in n:
		total += k
	if total < 2:
		return "IT TAKES TWO ABOARD AT LEAST: SEND A FRIEND THE CODE"
	var skipper := who == 0 or who == 1
	for i in boats:
		if int(n[i]) == 0:
			if total < boats:
				return "%d ABOARD FOR %d BOATS: BOAT %s HAS NOBODY. %s" % [total, boats, boat_name(i),
						"TAKE A BOAT AWAY" if skipper else "THE SKIPPER CAN TAKE A BOAT AWAY"]
			return "BOAT %s HAS NOBODY ABOARD. SOMEONE CHANGE BOAT, OR %s" % [boat_name(i),
					"TAKE A BOAT AWAY" if skipper else "THE SKIPPER CAN TAKE A BOAT AWAY"]
	return ""


## Host: someone new aboard, on the boat with fewest (crew/crew.gd asks before making them, so they're made on her,
## not made on A and straight away again on another).
func seat_new(id: int) -> void:
	if teams.has(id):
		return
	var n := _aboard()
	teams[id] = n.find(n.min())


## Host: someone back (REJOIN) saying who they were. If their old line's still here (we hadn't noticed it go: they
## noticed first), it's cut now and they're put back on their own boat, not the emptier one seat_new gave them.
@rpc("any_peer", "call_remote", "reliable")
func _was(old: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not on or not multiplayer.is_server() or old == id or not teams.has(old) or not teams.has(id):
		return
	var team := int(teams[old])
	if multiplayer.get_peers().has(old):
		Net.quit[old] = false        # (gone, but not to be waited on or called out: they're here)
		(multiplayer.multiplayer_peer as MultiplayerPeer).disconnect_peer(old)
	teams.erase(old)
	pressed.erase(old)
	teams[id] = team
	_teams.rpc(teams)
	if card.up():
		_send_states()


## Crossing to boat `t` (at the dock).
func ask_team(t: int) -> void:
	if Net.is_host():
		_host_team(Net.my_id(), t)
	else:
		_ask_team.rpc_id(1, t)


@rpc("any_peer", "call_remote", "reliable")
func _ask_team(t: int) -> void:
	_host_team(multiplayer.get_remote_sender_id(), t)


func _host_team(who: int, t: int) -> void:
	if not on or not _all_docked() or t < 0 or t >= boats:
		return
	teams[who] = t
	if Net.in_session():
		_teams.rpc(teams)
	else:
		_teams(teams)


## The helm of a boat that's just moved (boat/helm.gd, whoever moves her): kept out of the other boats.
func fend(helm: Node) -> void:
	contact.fend(helm)


func _process(delta: float) -> void:
	if not on:
		return
	_show(delta)
	_weigh(delta)
	_count.queue_redraw()
	# (the HUD's notes go under the banner while there's one, not over it)
	var banner := count_end > 0.0 or _now() - _go_shown < 2.0 or home_by > 0.0
	var hud: Node = (sea.get("crew") as Node).get("hud")
	if hud != null:
		hud.call("note_at", 104.0 if banner else 40.0)
	if count_end > 0.0:
		var left := ceili(count_end - _now())
		if left != _ticked and left <= 5 and left > 0:
			_ticked = left
			Sfx.play("ui.tick", 1.0, 1.0 if left > 3 else 1.3)
	# (the sea lights the boat you're on: the others' come on with them)
	var mine: Node = sea.get("boat")
	for i in sides.size():
		if i != my_team:
			(sides[i].get("boat") as Node).call("set_lights", bool(mine.get("_lights_on")), bool(mine.get("_night")))
	if not Net.is_host():
		return
	var holds: Array = sides.map(func(s: Node) -> Node: return s.get("fish_hold"))
	var docked: Array = holds.map(func(h: Node) -> bool: return bool(h.get("docked")))
	if not _out:
		# (one's let go: the rest go with her; all at the dock: the countdown)
		if not docked.has(false):
			_host_count(holds, delta)
		elif docked.has(true):
			_host_set_out(holds, docked.find(false))
		return
	for i in boats:
		if not docked[i]:
			_last[i] = _pounds(holds[i])
	_others_fish(delta)
	if home_by < 0.0:
		if holds.all(func(h: Node) -> bool: return float(h.call("day_fraction")) < 1.0):
			return
		# dusk: the race home
		_say(&"_homeward", [_now() + HOME, _each(false)])
	# a boat tied up at the floats (both her lines fast: boat/lines.gd), having been away from them: in, her catch
	# still aboard for the weigh-in; in time, she's home
	for i in boats:
		if docked[i]:
			continue
		var lines: Node = (sides[i].get("boat") as Node).get("lines")
		_away[i] = bool(_away[i]) or bool(lines.call("all_aboard"))
		if bool(_away[i]) and bool(lines.call("tied")):
			var now_home := home.duplicate()
			now_home[i] = not bool(_late[i]) and _now() < home_by
			_say(&"_homeward", [home_by, now_home])
			Sfx.play_point(sides[i].get("boat"), (sides[i].get("boat") as Node3D).global_position, "kit.thud", 0.6, 0.6)
			holds[i].call("head_in", not bool(now_home[i]))
			docked[i] = true
	# time's up: a harbour launch goes out for each boat still out (sea/tow.gd), and brings her in
	if _now() >= home_by:
		for i in boats:
			if not docked[i] and not bool(_late[i]):
				_late[i] = true
				sea.call("send_tow", sides[i].get("boat"))
	if docked.has(false):
		return
	# the trip's over: all in (the late ones towed in), and the weigh-in: what each had aboard, then sold
	_out = false
	var fish := []
	var day := []
	for i in boats:
		var kgs: Array = (holds[i].get("fish") as Array).map(func(f: Dictionary) -> float: return float(f["kg"]))
		var late := not bool(home[i])
		fish.append(kgs.map(func(kg: float) -> float: return kg * LB_PER_KG * (0.5 if late else 1.0)))
		_last[i] = _pounds(holds[i]) * (0.5 if late else 1.0)
		holds[i].call("host_sell_all")
		var sum := 0.0
		for k: float in kgs:
			sum += k
		day.append({"fish": kgs.size(), "kg": sum, "big": kgs.max() if not kgs.is_empty() else 0.0,
				"money": int((holds[i].get("sale") as Dictionary).get("total", 0)),
				"late": sum * LB_PER_KG * 0.5 if late else 0.0, "lb": float(_last[i])})
	_say(&"_homeward", [-1.0, home])
	var winner := winner_of(_last, together)
	if winner >= 0:
		wins[winner] += 1
	_card_after(day, winner)
	_say(&"_result", [_last, fish, wins])


## The day's winner: the boat with the most pounds (to the pound); a tie for the most is nobody's (-1), and so is every
## day fished as one fleet.
static func winner_of(lbs: Array, fleet := false) -> int:
	var best := -1
	var top := -1
	for i in lbs.size():
		var lb := roundi(float(lbs[i]))
		if lb > top:
			top = lb
			best = i
		elif lb == top:
			best = -1
	return -1 if fleet else best


## Host, a day weighed: the card that goes up after it (the day's numbers, or the match's once it's won).
func _card_after(day: Array, winner: int) -> void:
	if _match.size() != boats:
		_match = _fresh_match()
	_days += 1
	for i in boats:
		var m: Dictionary = _match[i]
		var d: Dictionary = day[i]
		for k: String in ["fish", "kg", "money", "late", "lb"]:
			m[k] = m.get(k, 0) + d[k]
		m["big"] = maxf(float(m.get("big", 0.0)), float(d["big"]))
	var decided := not together and int(wins.max()) >= MATCH
	var crewed := _each(false)
	for t: int in teams.values():
		if t < boats:
			crewed[t] = true
	for w: Dictionary in ((sea.get("crew") as Node).get("away") as Dictionary).values():
		if w.has("team") and int(w["team"]) < boats:
			crewed[int(w["team"])] = true
	_pending = {"decided": decided, "winner": wins.find(wins.max()) if decided else winner,
			"day": _days, "wins": wins.duplicate(), "crewed": crewed, "day_lb": _last.duplicate(),
			"boats": _match.duplicate(true) if decided else day, "together": together}


func _fresh_match() -> Array:
	var m := []
	for i in boats:
		m.append({})
	return m


## Boat i's berth (world x, z): the harbour's word (sea/harbour.gd's berth_at). A's on the fish pier's west side, B's
## on its east, set out along the pier as far as makes her run to the harbour mouth as long as A's (the mouth's west
## of the pier: A heads straight for it, B has to clear the pier's end first): neither starts nearer, the same run,
## the same boat. C and D: wherever the harbour has floats for them (without its word, further out along the pier).
func _berth(i: int) -> Vector2:
	var harbour: Node = sea.get("harbour")
	var boat: Node = sides[i].get("boat")
	var half := float(boat.get("beam")) * 0.5
	var length := float(boat.get("length"))
	if harbour.has_method("berth_at"):
		return harbour.call("berth_at", i, half, length)
	# (a harbour without berths for four: A's and B's as they always were, C and D a boat's length and a bit beyond)
	if i >= 2:
		return _berth(i - 2) - Vector2(0.0, length + 6.0)
	var at: Vector2 = harbour.call("berth", half, length)
	if i == 0:
		return at
	at.x = 2.0 * float(harbour.get("PIER_X")) - at.x
	var a := _berth(0)
	var mouth := _mouth()
	var px := float(harbour.get("PIER_X"))
	var corner := Vector2(px + float(harbour.get("PIER_W")) * 0.5 + half + 1.0,
			float((sea.get("landmarks") as Node).call("shore_z", px)) - float(harbour.get("PIER_OUT")) - 1.0)
	var z := corner.y + a.distance_to(mouth) - corner.distance_to(mouth)
	at.y = clampf(z, corner.y + length * 0.5, at.y)
	return at


## The middle of the harbour mouth, between the breakwaters' ends (world x, z).
func _mouth() -> Vector2:
	var arms: Array = (sea.get("landmarks") as Node).call("breakwater_arms")
	return ((arms[0][1] as Vector2) + (arms[1][1] as Vector2)) * 0.5


## How far boat i has to run from her berth to the harbour mouth (m): the harbour's word (run_out_at); without it,
## straight there from the pier's west side, round the pier's end from its east.
func run_out(i: int) -> float:
	var harbour: Node = sea.get("harbour")
	var half := float((sides[i].get("boat") as Node).get("beam")) * 0.5
	if harbour.has_method("run_out_at"):
		return harbour.call("run_out_at", i, half, float((sides[i].get("boat") as Node).get("length")))
	var b := _berth(i)
	var px := float(harbour.get("PIER_X"))
	if b.x < px:
		return b.distance_to(_mouth())
	var corner := Vector2(px + float(harbour.get("PIER_W")) * 0.5 + half + 1.0,
			float((sea.get("landmarks") as Node).call("shore_z", px)) - float(harbour.get("PIER_OUT")) - 1.0)
	return maxf(b.y - corner.y, 0.0) + corner.distance_to(_mouth())


## Host, as a match is set up (the lobby, the start) and in tests: every boat alongside the floats at her own berth
## (_berth), bows out, her lines made fast where she lies; but not a boat that's already come in herself (`keep`, one
## a boat: true for each one that has). Never mid-match: after a day they're wherever they tied up, or the launch tied
## them up.
func _moor(keep := []) -> void:
	var harbour: Node = sea.get("harbour")
	if harbour == null:
		return
	for i in sides.size():
		if i < keep.size() and bool(keep[i]):
			continue
		var boat: Node = sides[i].get("boat")
		var helm: Node = boat.get("helm")
		var at := _berth(i)
		helm.set("at", at)
		helm.set("heading", 0.0)
		helm.set("speed", 0.0)
		helm.set("throttle", 0.0)
		helm.set("drift", Vector2.ZERO)
		helm.set("spin", 0.0)
		if Net.in_session():
			helm.rpc("_sync", int(helm.get("captain")), 0.0, at, 0.0)
		(boat as Node3D).global_transform = boat.call("pose")
		var lines: Node = boat.get("lines")
		if lines != null:
			lines.call("host_make_fast_here")


## Host, both at the dock: once the title's down and everyone's pressed on from the last weigh-in's card, the
## countdown; at its end, both let go together.
func _host_count(holds: Array, delta: float) -> void:
	var now := _now()
	if count_end < 0.0:
		var title: Node = sea.get("title")
		if (title != null and bool(title.call("busy"))) or weighing:
			return
		if not result.is_empty():
			# the card, a moment after the weigh-in; once everyone's pressed on, the next day from where they lie
			_weighed_for = maxf(_weighed_for, 0.0) + delta
			if not card.up():
				if _weighed_for >= CARD_IN and not _pending.is_empty():
					_say(&"_card_open", [_pending])
					_send_states()
				return
			if _all_ready():
				_next()
			return
		_weighed_for = -1.0
		if Net.in_session():
			_counting.rpc(now + COUNT)
		else:
			_counting(now + COUNT)
	elif now >= count_end:
		holds[0].call("head_out")
		_host_set_out(holds, 0)


@rpc("authority", "call_local", "reliable")
func _day_is(n: int) -> void:
	day = n
	(sea.get("fish_hold") as Node).call("_tally")


@rpc("authority", "call_local", "reliable")
func _counting(end: float) -> void:
	count_end = end
	_ticked = -1


## Everyone's: an RPC to every peer and here (or just here, alone).
func _say(method: StringName, args: Array) -> void:
	if Net.in_session():
		callv(&"rpc", [method] + args)
	else:
		callv(method, args)


## Pressed NEXT DAY / REMATCH on the card (pressed again: taken back).
func press_ready() -> void:
	if Net.is_host():
		_host_ready(Net.my_id())
	else:
		_ask_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _ask_ready() -> void:
	_host_ready(multiplayer.get_remote_sender_id())


func _host_ready(who: int) -> void:
	if not on or not card.up() or _fading_for >= 0.0 or not teams.has(who):
		return
	if bool(pressed.get(who, false)):
		pressed.erase(who)
	else:
		pressed[who] = true
	_send_states()


## Host: each boat's crew on the card (0 deciding, 1 all pressed, 2 nobody ever aboard her, 3 their line dropped and
## we're waiting on them, 4 they've left), one a boat, to all.
func _send_states() -> void:
	var states := _each(0)
	var crewed: Array = card.data.get("crewed", [])
	var lost := _each(false)
	for w: Dictionary in ((sea.get("crew") as Node).get("away") as Dictionary).values():
		if w.has("team") and int(w["team"]) < boats:
			lost[int(w["team"])] = true
	for i in boats:
		var ids := teams.keys().filter(func(id: int) -> bool: return int(teams[id]) == i)
		if ids.is_empty():
			states[i] = 3 if bool(lost[i]) else (4 if i >= crewed.size() or bool(crewed[i]) else 2)
		else:
			states[i] = 1 if ids.all(func(id: int) -> bool: return bool(pressed.get(id, false))) else 0
	_say(&"_readied", [states, pressed.keys()])


## Everyone there's pressed (a crew that's gone doesn't hold the rest up; someone has to be there and press).
func _all_ready() -> bool:
	return card.states.all(func(s: int) -> bool: return s >= 1) and card.states.has(1)


@rpc("authority", "call_local", "reliable")
func _card_open(d: Dictionary) -> void:
	_verdict.visible = false
	card.open(d, my_team)


@rpc("authority", "call_local", "reliable")
func _readied(states: Array, ids: Array) -> void:
	card.states = states
	card.ready_ids = ids


@rpc("authority", "call_local", "reliable")
func _fading() -> void:
	card.fade_out()


## Host, everyone pressed on: the next day (or a fresh match, the last one won): both boats lying where they tied up,
## everyone where they are (they walk aboard their own), new weather for the day, and the countdown follows.
func _next() -> void:
	if int(wins.max()) >= MATCH:
		wins = _each(0)
		_days = 0
		_match = _fresh_match()
	pressed = {}
	_pending = {}
	_weighed_for = -1.0
	_fading_for = -1.0
	var weather: Object = sea.get("weather")
	if str(weather.get("pinned")).is_empty():
		var s := randi() % 1000000
		sea.call("_weather_seed", s, "")
		if Net.in_session():
			sea.rpc("_weather_seed", s, "")
	_say(&"_fresh", [wins])


@rpc("authority", "call_local", "reliable")
func _fresh(won: Array) -> void:
	result = []
	catches = []
	wins = won
	weighing = false
	_clear_board()
	_verdict.visible = false
	card.close()
	var title: Node = sea.get("title")
	if title == null or not bool(title.call("busy")):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Back to the title from the card (ui/menu.gd's own way: off the crew, the game from the top).
func to_title() -> void:
	for n: Node in sea.get_children():
		if n.has_method("_to_title"):
			n.call("_to_title")
			return


func _now() -> float:
	return float((sea.get("ocean") as Node).get("wave_time"))


## Host: one boat's let go (`first`): the others go with her, in the same kind of boat, each from her own berth.
func _host_set_out(holds: Array, first: int) -> void:
	_out = true
	_last = _each(0.0)
	if wins.max() >= MATCH:
		wins = _each(0)         # (a new match)
	_say(&"_day_is", [_days + 1])
	_anchor = 0
	for i in boats:
		if i != first and bool(holds[i].get("docked")):
			holds[i].call("head_out", str(holds[first].get("kind")))
	_alongside_for = _each(0.0)
	_away = _each(false)
	_late = _each(false)
	_say(&"_homeward", [-1.0, _each(false)])
	_say(&"_go", [])
	_say(&"_result", [[], [], wins])


## Host: the schools' doings round each boat that isn't the sea's own (tuna/schools.gd does the sea's own boat's), one
## after another: bites on her baits, schools she runs over going down, schools finding her spread.
func _others_fish(delta: float) -> void:
	var schools: Node = sea.get("schools")
	if schools == null:
		return
	var keep: Node = schools.get("sea")
	_draw_in -= delta
	var draw := _draw_in <= 0.0
	if draw:
		_draw_in = 1.0
	for i in sides.size():
		if i == my_team:
			continue
		schools.set("sea", sides[i])
		schools.call("_strikes", delta)
		if draw:
			schools.call("_drawing")
	schools.set("sea", keep)


## Where the next school turns up round (tuna/schools.gd): each day in the middle of the boats first, then round each
## boat in turn (A first on day one, B on day two, and so on round: nobody always gets the early one); only round
## boats that are out on the grounds (one still under the coast: round the others).
func spawn_anchor() -> Vector2:
	var at := _ats()
	var schools: Node = sea.get("schools")
	var out := []
	for i in at.size():
		if not bool(schools.call("_in_close", at[i])):
			out.append(i)
	if out.is_empty():
		out = range(at.size())
	var turn := _anchor % (at.size() + 1)
	_anchor += 1
	if turn == 0:
		var mid := Vector2.ZERO
		for i: int in out:
			mid += (at[i] as Vector2) / float(out.size())
		return mid
	var pick := (turn - 1 + maxi(day, 1) - 1) % at.size()
	if not out.has(pick):
		pick = out[(turn - 1 + maxi(day, 1) - 1) % out.size()]
	return at[pick]


## Both boats still in the harbour or close in under the coast: no schools yet (tuna/schools.gd).
func all_in_close() -> bool:
	var schools: Node = sea.get("schools")
	return _ats().all(func(p: Vector2) -> bool: return bool(schools.call("_in_close", p)))


func _ats() -> Array:
	return sides.map(func(s: Node) -> Vector2: return ((s.get("boat") as Node).get("helm") as Node).get("at"))


# ------------------------------------------------------------------ everyone

## Everyone: on (`n` boats, as one fleet or not, everyone on the boat `t` says) or off. On while it's on already: the
## boats or the fleet changed in the lobby, and whatever match there was starts over.
@rpc("authority", "call_local", "reliable")
func _switch(want: bool, t: Dictionary, weighed: Array, won: Array, n := 2, fleet := false, keep_card := false) -> void:
	if not want and not on:
		return
	result = weighed
	wins = won
	catches = []
	weighing = false
	_clear_board()
	if not keep_card:
		card.close()
	if want:
		n = clampi(n, 2, MAX_BOATS)
		var changed := on and (n != boats or fleet != together)
		together = fleet
		if not on:
			boats = n
			_build()
		elif n != boats:
			_resize(n, t)
		if changed:
			_start_over()
			if Net.is_host():
				_moor()
		if wins.size() != boats:
			wins = _each(0)
	elif on:
		_tear_down()
	_teams(t)
	if on:
		(sea.get("fish_hold") as Node).call("_tally")       # (the HUD's top left says which it is)


@rpc("authority", "call_local", "reliable")
func _teams(t: Dictionary) -> void:
	teams = t
	my_team = clampi(int(teams.get(Net.my_id(), 0)), 0, sides.size() - 1) if on else 0
	_point_sea()
	var crew := sea.get("crew") as Node
	for id: int in crew.get("slots").keys():
		crew.call("reseat", id)


## Everyone: the race home (until `by`, the sea clock; -1 when it's over) and which boats are in.
@rpc("authority", "call_local", "reliable")
func _homeward(by: float, in_: Array) -> void:
	var was := home_by
	home_by = by
	home = in_
	if was < 0.0 and by > 0.0:
		_radio("dusk", 2.0)


## Host (tests, dev): the race home run for them: every boat alongside her berth, tied up, in time.
func host_bring_home() -> void:
	if not _out:
		return
	_say(&"_homeward", [_now() + HOME, _each(true)])
	_moor()
	for side: Node in sides:
		(side.get("fish_hold") as Node).call("head_in")
	_away = _each(true)


## Whether boat `t` brought herself home this trip (so there's no cut to black for her crew).
func came_home(t: int) -> bool:
	return t >= 0 and t < home.size() and bool(home[t])


## Everyone: GO, the horns blow, the countdown's done.
@rpc("authority", "call_local", "reliable")
func _go() -> void:
	count_end = -1.0
	_go_shown = _now()
	for side: Node in sides:
		var horn := (side.get("boat") as Node).get_node_or_null("Horn")
		if horn != null:
			(horn.get("_player") as AudioStreamPlayer3D).play()


@rpc("authority", "call_local", "reliable")
func _result(weighed: Array, fish: Array, won: Array) -> void:
	result = weighed
	catches = fish
	wins = won
	_clear_board()
	weighing = false
	_verdict.visible = false
	if not weighed.is_empty():
		_weigh_in()
		# (achievements: the day yours alone, the match; none of it as one fleet)
		if together:
			return
		if winner_of(weighed) == my_team:
			Net.achievements.unlock("RIVALS_DAY")
		if my_team < won.size() and int(won[my_team]) >= MATCH:
			Net.achievements.unlock("RIVALS_MATCH")


## Which boat crew member `id` is on.
func boat_of(id: int) -> Node3D:
	return sides[clampi(int(teams.get(id, 0)), 0, sides.size() - 1)].get("boat") if on else sea.get("boat")


## Pounds aboard a boat now: on deck and iced.
static func _pounds(hold: Node) -> float:
	var kg := 0.0
	for f: Dictionary in hold.get("fish"):
		kg += float(f["kg"])
	return kg * LB_PER_KG


func _all_docked() -> bool:
	if not on:
		return bool((sea.get("fish_hold") as Node).get("docked"))
	return sides.all(func(s: Node) -> bool: return bool((s.get("fish_hold") as Node).get("docked")))


## Every boat but A and all their things, and boat A's things pointed at their side.
func _build() -> void:
	(sea.get("fish_hold") as Node).call("set_career", false)      # (an even start for all: the career set aside)
	var a := _side(0)
	for k: String in PARTS:
		a.set(k, sea.get(k))
		(sea.get(k) as Node).set("sea", a)
	sides = [a]
	_horn(0)
	for i in range(1, boats):
		_add_side(i)
	on = true
	_start_over()
	_ui.visible = true
	if Net.is_host():
		_moor()


## Boat i (not A) and all her own things: a boat of A's kind, her rods, landing, fish hold, chum and jig, her horn.
func _add_side(i: int) -> void:
	var b := _side(i)
	var boat := Boat.new()
	boat.name = "Boat"
	boat.ocean = sea.get("ocean")
	boat.sea = b
	b.boat = boat
	b.add_child(boat)
	b.rods = _part(b, Rods.new(), "Rods")
	b.landing = _part(b, Landing.new(), "Landing")
	var hold := FishHold.new()
	hold.career = false
	b.fish_hold = _part(b, hold, "FishHold")
	b.chum = _part(b, Chum.new(), "Chum")
	b.jig = _part(b, Jig.new(), "Jig")
	# (the kind of boat A is, as she lies there: the berths are set out for boats all alike, sea/harbour.gd)
	boat.use_kind(str((sides[0].get("boat") as Node).get("kind")))
	boat.rebuilt.connect(func() -> void:
		(sea.get("crew") as Node).call("_on_rebuilt")
		_point_sea())
	sides.append(b)
	_horn(i)


func _horn(i: int) -> void:
	var horn := Horn.new()
	horn.name = "Horn"
	horn.vs = self
	horn.team = i
	horn.boat = sides[i].get("boat")
	horn.boat.add_child(horn)


## A match from the top (it's just come on, or the boats or the fleet changed): nothing weighed, nobody out, day one.
func _start_over() -> void:
	_out = false
	count_end = -1.0
	_ticked = -1
	_weighed_for = -1.0
	_fading_for = -1.0
	_pending = {}
	_days = 0
	_match = _fresh_match()
	day = 1
	pressed = {}
	home_by = -1.0
	home = _each(false)
	_last = _each(0.0)
	_alongside_for = _each(0.0)
	_away = _each(false)
	_late = _each(false)
	_hooked = -1
	_on_by = _each(0)


## The boats, now `n` of them (it's on; the lobby): the new ones built first, then everyone where `t` puts them (off
## any boat that's going), then the ones over taken away.
func _resize(n: int, t: Dictionary) -> void:
	boats = maxi(boats, n)
	while sides.size() < n:
		_add_side(sides.size())
	teams = t
	my_team = clampi(int(teams.get(Net.my_id(), 0)), 0, n - 1)
	_point_sea()
	var crew := sea.get("crew") as Node
	for id: int in crew.get("slots").keys():
		crew.call("reseat", id, true)
	while sides.size() > n:
		var s: Node = sides.pop_back()
		remove_child(s)
		s.queue_free()
	boats = n
	_no_hulls()


func _side(team: int) -> BoatSide:
	var s := BoatSide.new()
	s.name = boat_name(team)
	s.sea = sea
	s.vs = self
	s.team = team
	add_child(s)
	return s


func _part(side: BoatSide, n: Node, called: String) -> Node:
	n.name = called
	n.set("sea", side)
	side.add_child(n)
	return n


## Back to the one boat: everyone aboard A, A's things the sea's again, the others gone.
func _tear_down() -> void:
	_no_hulls()
	on = false
	teams = {}
	var a: Node = sides[0]
	for k: String in PARTS:
		sea.set(k, a.get(k))
		(a.get(k) as Node).set("sea", sea)
	_point_sea()
	var crew := sea.get("crew") as Node
	for id: int in crew.get("slots").keys():
		crew.call("reseat", id, true)
	for s: Node in sides:
		remove_child(s)
		s.queue_free()
	var horn := (a.get("boat") as Node).get_node_or_null("Horn")
	if horn != null:
		horn.get_parent().remove_child(horn)
		horn.queue_free()
	sides = []
	_ui.visible = false
	var hud: Node = (sea.get("crew") as Node).get("hud")
	if hud != null:
		hud.call("note_at", 40.0)
	(sea.get("fish_hold") as Node).call("set_career", true)       # (the career back, and her boat)
	(sea.get("boat") as Node).call("use_kind", str((sea.get("fish_hold") as Node).get("kind")))


## The sea let be round no other boat (sea/ocean.gd).
func _no_hulls() -> void:
	var ocean: Node = sea.get("ocean")
	if ocean.has_method("set_other_hulls"):
		ocean.call("set_other_hulls", [])
	else:
		ocean.call("set_other_hull", Transform3D(), 0.0, 0.0, false)


## The sea parts round every boat but the one you're on (sea/ocean.gd's set_other_hulls: up to three of them, in the
## boats' order), each frame once they've all moved (After, below), and round none that's gone. (Each boat that isn't
## the sea's own says so herself too as she moves, boat/boat.gd. An ocean that only knows of one other: the first.)
func _hulls() -> void:
	if not on:
		return
	var ocean: Node = sea.get("ocean")
	var many := ocean.has_method("set_other_hulls")
	if not many and sides.size() <= 2:
		return
	var mine: Node = sea.get("boat")
	var list := []
	for s: Node in sides:
		var b := s.get("boat") as Node3D
		if b == null or b == mine or not b.is_inside_tree():
			continue
		var helm: Node = b.get("helm")
		var floating: Object = b.get("floating")
		list.append({"xf": b.global_transform, "length": float(b.get("length")), "beam": float(b.get("beam")),
				"deck": float(b.get("deck")), "speed": float(helm.get("speed")) if helm != null else 0.0,
				"sheer": floating.get("sheer") if floating != null else Vector2(1.45, 0.95)})
	if many:
		ocean.call("set_other_hulls", list)
	elif not list.is_empty():
		var h: Dictionary = list[0]
		ocean.call("set_other_hull", h["xf"], h["length"], h["beam"], true, h["deck"], h["speed"], h["sheer"])


## Last each frame, after every boat's moved: the sea round the others (_hulls).
class After extends Node:
	var vs: Node

	func _process(_delta: float) -> void:
		vs.call("_hulls")


## The sea's boat (and rods, ...) are the boat you're on: your camera, your HUD, the screens on your dash.
func _point_sea() -> void:
	if on:
		for k: String in PARTS:
			sea.set(k, sides[my_team].get(k))
	var boat := sea.get("boat") as Node3D
	(sea.get("ocean") as Node).set("follow", boat)
	for screen: String in ["Sonar", "Radar", "Plotter"]:
		var n := sea.get_node_or_null(screen)
		if n != null:
			n.call("attach", boat)


# ------------------------------------------------------------------ the tally and the weigh-in

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 11
	_ui.visible = false
	add_child(_ui)
	# top left, under the trip's own tally (ui/hud.gd)
	_race = Control.new()
	_race.position = Vector2(18, 66)
	_race.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_race.draw.connect(_draw_race)
	_ui.add_child(_race)
	_verdict = Label.new()
	_verdict.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_verdict.position = Vector2(-400, 60)        # (under the crew's notices at the very top)
	_verdict.size = Vector2(800, 110)
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict.add_theme_font_size_override("font_size", 30)
	_shade(_verdict, 3)
	_ui.add_child(_verdict)
	# the weigh-in: a column for each boat, right of the dock's slip, her fish read off down it
	# the countdown, big, top middle (the pixel font, ui/pixfont.gd)
	_count = Control.new()
	_count.set_anchors_preset(Control.PRESET_FULL_RECT)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.draw.connect(_draw_count)
	_ui.add_child(_count)
	_board = VBoxContainer.new()
	_board.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_board.position = Vector2(-380, 110)
	_board.size = Vector2(340, 0)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_board)


## The boats in the order the tally and the board have them: yours, then the others as they come.
func _order() -> Array:
	var o := [my_team]
	for i in sides.size():
		if i != my_team:
			o.append(i)
	return o


## Out there: each boat's pounds aboard (yours on top), a bar each against the leader's, a pip a day won, and a red dot
## blinking by any other boat that has a fish on. In after a trip: the weigh-in, then who won and by how much.
func _show(delta: float) -> void:
	var lbs: Array = sides.map(func(s: Node) -> float: return _pounds(s.get("fish_hold")))
	shown = _order().map(func(i: int) -> int: return roundi(float(lbs[i])))
	_race.set_meta("lbs", lbs)
	var docked := bool((sea.get("fish_hold") as Node).get("docked"))
	_race.visible = not docked
	# another crew hooking up: a squawk on your radio, and their dot blinks while they're on
	var all := 0
	var by := _each(0)
	var more := false
	for i in sides.size():
		if i == my_team:
			continue
		for r: Node in (sides[i].get("rods") as Node).get("rods"):
			if bool(r.get("hooked")) and not bool(r.get("alongside")):
				by[i] += 1
		all += int(by[i])
		more = more or (i < _on_by.size() and int(by[i]) > int(_on_by[i]))
	if not docked and _hooked >= 0 and more:
		_their_on = 0.0
		_radio("fish_on", 1.4)
	_hooked = all
	_on_by = by
	_their_on += delta
	_race.queue_redraw()
	_board.visible = docked and not card.up()
	_verdict.visible = docked and result.size() == sides.size() and not weighing and not card.up()
	if not _verdict.visible:
		return
	if together:
		_verdict.text = "THE FLEET: %d LB\n%s" % [_fleet_lb(), _scores()]
		_verdict.modulate = Color(0.6, 1.0, 0.6)
		return
	if sides.size() > 2:
		_verdict_many()
		return
	var us := roundi(float(result[my_team]))
	var them := roundi(float(result[1 - my_team]))
	if us == them:
		_verdict.text = "Dead even: %d lb each" % us
		_verdict.modulate = Color(1.0, 0.92, 0.6)
	else:
		_verdict.text = "%s by %d lb\n%d lb to %d" % ["You won" if us > them else "They won", absi(us - them),
				maxi(us, them), mini(us, them)]
		_verdict.modulate = Color(0.6, 1.0, 0.6) if us > them else Color(1.0, 0.55, 0.45)
	if int(wins.max()) >= MATCH:
		var ours := int(wins[my_team])
		_verdict.text += "\nThe match: %s, %d-%d" % ["yours" if ours >= MATCH else "theirs", int(wins.max()),
				int(wins.min())]


## Three or four boats weighed: the winning boat named (yours as YOU) and by how much over the next, or the tie for
## the most; every boat's pounds under it; the match once it's won.
func _verdict_many() -> void:
	var lb: Array = result.map(func(x: float) -> int: return roundi(x))
	var winner := winner_of(result)
	var top: int = lb.max()
	if winner < 0:
		var level := []
		for i in lb.size():
			if int(lb[i]) == top:
				level.append(boat_name(i))
		_verdict.text = "A TIE FOR THE MOST: %s, %d LB EACH. NOBODY'S DAY" % [" AND ".join(PackedStringArray(level)), top]
		_verdict.modulate = Color(1.0, 0.92, 0.6)
	else:
		var rest := lb.duplicate()
		rest.remove_at(winner)
		_verdict.text = "%s BY %d LB" % ["YOU WIN THE DAY" if winner == my_team else "BOAT %s WINS THE DAY"
				% boat_name(winner), top - int(rest.max())]
		_verdict.modulate = Color(0.6, 1.0, 0.6) if winner == my_team else Color(1.0, 0.55, 0.45)
	_verdict.text += "\n" + _scores()
	if int(wins.max()) >= MATCH:
		var won := wins.find(wins.max())
		_verdict.text += "\nTHE MATCH: %s, %s" % ["YOURS" if won == my_team else "BOAT %s'S" % boat_name(won),
				"-".join(PackedStringArray(wins.map(func(w: int) -> String: return str(w))))]


## Every boat's pounds weighed, in a line: "A 220   B 243   C 310".
func _scores() -> String:
	var parts := []
	for i in result.size():
		parts.append("%s %d" % [boat_name(i), roundi(float(result[i]))])
	return "   ".join(PackedStringArray(parts))


## The fleet's pounds weighed, all the boats' together.
func _fleet_lb() -> int:
	var sum := 0.0
	for x: float in result:
		sum += x
	return roundi(sum)


func _px() -> float:
	return clampf(get_viewport().get_visible_rect().size.y / 1080.0, 0.7, 2.5)


func _draw_count() -> void:
	var now := _now()
	var p := _px()
	_kit.px = p
	_kit.defer = true
	var mid := _count.size.x * 0.5
	var label := ""
	var big := ""
	var col: Color = Kit.PAPER
	var sub := ""
	var go := false
	if count_end > 0.0:
		var left := ceili(count_end - now)
		label = "CAST OFF IN"
		big = str(maxi(left, 0))
		col = Kit.PAPER if left > 3 else Kit.ORANGE
		sub = "%s BOATS LET GO TOGETHER. TAKE THE WHEEL!" % ("BOTH" if sides.size() <= 2 else "ALL %d" % sides.size())
	elif now - _go_shown < 2.0:
		go = true
	elif home_by > 0.0:
		var left := maxi(ceili(home_by - now), 0)
		big = "%d:%02d" % [left / 60, left % 60]
		var in_ := came_home(my_team)
		label = "HOME. WAITING FOR THEM" if in_ else "DUSK: BRING HER HOME"
		col = Kit.YELLOW if in_ else (Kit.PAPER if left > 60 else Kit.ORANGE)
		sub = "ALONGSIDE YOUR BERTH AT THE FISH PIER, SLOW. LATE: HALF WEIGHT."
		var theirs := []          # (the other boats already in)
		for i in home.size():
			if i != my_team and bool(home[i]):
				theirs.append(boat_name(i))
		if in_:
			sub = "THEY'RE STILL OUT THERE. IN LATE, THEIR CATCH WEIGHS HALF."
		elif not theirs.is_empty():
			sub = ("THEY'RE IN!" if home.size() <= 2 else "BOAT %s'S IN!" % " AND ".join(PackedStringArray(theirs))) 					+ " ALONGSIDE YOUR BERTH AT THE FISH PIER, SLOW."
	if go:
		_kit.stamp(_count, Vector2(mid, 52.0 * p), "GO", 44.0 * p, Kit.YELLOW, Kit.slam(now - _go_shown, 2.2))
	elif big != "":
		_kit.label(_count, Vector2(mid, 20.0 * p), label, 17.0 * p, Color(Kit.PAPER, 0.85))
		_kit.num(_count, Vector2(mid, 60.0 * p), big, 66.0 * p, col)
		_kit.text(_count, Vector2(mid, 100.0 * p), sub, 19.0 * p, Kit.PAPER, 0, 600, 1.0 * p)
	_kit.flush()
	_kit.defer = false


func _draw_race() -> void:
	var lbs: Array = _race.get_meta("lbs", [])
	if lbs.size() != sides.size():
		return
	var p := _px()
	_kit.px = p
	_race.position = Vector2(18.0, 84.0) * p
	_kit.defer = true
	var top := 1.0
	for lb: float in lbs:
		top = maxf(top, lb)
	var order := _order()
	var step := 26.0 * p
	for k in order.size():
		var t: int = order[k]
		var y := k * step + 10.0 * p
		var lit := 1.0 if k == 0 else 0.8
		_kit.square(_race, Vector2(6.0 * p, y), 13.0 * p, boat_colour(t))
		_kit.num(_race, Vector2(22.0 * p, y), "%d" % roundi(float(lbs[t])), 22.0 * p, Color(Kit.PAPER, lit), -1)
		if not together and t < wins.size():
			for d in int(wins[t]):
				_kit.square(_race, Vector2(124.0 * p + d * 14.0 * p, y), 9.0 * p, Kit.PAPER)
		if t != my_team and t < _on_by.size() and int(_on_by[t]) > 0 and fmod(_their_on, 0.8) < 0.5:
			_kit.square(_race, Vector2(-8.0 * p, y), 9.0 * p, Kit.ORANGE)
	# one fine ruler under them: each boat's square sits on it at her share of the leader's pounds
	var ry := order.size() * step + 12.0 * p
	var rw := 190.0 * p
	_kit.scale(_race, Vector2(0, ry), Vector2(rw, ry), 10, 5, Color(Kit.PAPER, 0.8), 1.0, 4.0 * p, 8.0 * p)
	for t: int in order:
		_kit.square(_race, Vector2(rw * float(lbs[t]) / top, ry - 8.0 * p), 9.0 * p, boat_colour(t))
	_kit.flush()
	_kit.defer = false


func _text(at: Vector2, text: String, col: Color) -> void:
	var f := ThemeDB.fallback_font
	_race.draw_string(f, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Hud.SMALL, Color(0, 0, 0, 0.8 * col.a))
	_race.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Hud.SMALL, col)


## A squawk on the VHF (ui/radio.gd: the squelch, the hiss, a voice if one's been recorded for it).
func _radio(line: String, seconds: float) -> void:
	var tips: Node = sea.get("tips")
	var radio: Node = tips.get("radio") if tips != null else null
	if radio != null:
		radio.call("call_in", "vs", line, seconds)


## All in alongside the fish pier: the screen fades up on them, and the fish are read off, each boat's in turn, A's
## first.
func _weigh_in() -> void:
	_steps = []
	_board.add_theme_constant_override("separation", 4 if result.size() <= 2 else 0)
	for t in result.size():
		var fish: Array = catches[t] if t < catches.size() else []
		_steps.append(["boat", t])
		var each := clampf(8.0 / maxf(fish.size(), 1.0), 0.35, READ)
		for lb: float in fish:
			_steps.append(["fish", t, lb, each])
		_steps.append(["total", t])
	_steps.append(["verdict"])
	weighing = true
	_step_in = 1.8


func _weigh(delta: float) -> void:
	if not weighing:
		return
	_step_in -= delta
	while weighing and _step_in <= 0.0 and not _steps.is_empty():
		var s: Array = _steps.pop_front()
		match str(s[0]):
			"boat":
				var col := VBoxContainer.new()
				col.name = "Boat%d" % int(s[1])
				col.add_theme_constant_override("separation", 0)
				_board.add_child(col)
				# (three or four boats: a size down, so they all fit down the screen)
				var big := 24 if result.size() <= 2 else 20
				var head := _line("BOAT %s%s" % [boat_name(int(s[1])), "  (YOU)" if int(s[1]) == my_team else ""], big,
						boat_colour(int(s[1])))
				col.add_child(head)
				var rows := HFlowContainer.new()
				rows.name = "Fish"
				rows.add_theme_constant_override("h_separation", 14)
				rows.custom_minimum_size = Vector2(340, 0)
				col.add_child(rows)
				var sum := _line("0 lb", big, Hud.CREAM)
				sum.name = "Sum"
				sum.set_meta("lb", 0.0)
				col.add_child(sum)
				Sfx.play("ui.page", 0.7)
				_step_in += 0.7
			"fish":
				var col := _board.get_node("Boat%d" % int(s[1]))
				col.get_node("Fish").add_child(_line("%d" % roundi(float(s[2])), 18 if result.size() <= 2 else 16,
						Color(Hud.CREAM, 0.85)))
				var sum := col.get_node("Sum") as Label
				sum.set_meta("lb", float(sum.get_meta("lb")) + float(s[2]))
				sum.text = "%d lb" % roundi(float(sum.get_meta("lb")))
				Sfx.play("kit.chain", 0.5, randf_range(0.95, 1.05))
				Sfx.play("kit.clank", 0.6)
				_step_in += float(s[3])
			"total":
				var sum := _board.get_node("Boat%d/Sum" % int(s[1])) as Label
				sum.text = "%d lb" % roundi(float(result[int(s[1])]))
				sum.add_theme_color_override("font_color", boat_colour(int(s[1])))
				Sfx.play("ui.stamp", 0.8)
				_step_in += BETWEEN
			"verdict":
				weighing = false
				Sfx.play("ui.reveal")
				_radio("weighed", 2.0)


func _clear_board() -> void:
	_steps = []
	for c in _board.get_children():
		_board.remove_child(c)
		c.queue_free()


func _line(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	_shade(l, 2)
	return l


## A hard shadow under a label's letters (the pixel font has no outline to give).
static func _shade(l: Label, px: int) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", px)
	l.add_theme_constant_override("shadow_offset_y", px)
