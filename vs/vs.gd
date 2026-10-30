extends Node
## VS (docs/VISION.md): two boats on the same sea, a crew each, after the same birds. Whoever has the most pounds
## aboard when the trip ends wins.
##
## The skipper (the host) turns it on at the dock; everyone's put on boat A or boat B (the host's word, `teams`), and
## each can cross to the other at the dock. Boat A is the boat the sea always had; boat B is a second one with all
## her own things (her rods, the landing, her fish hold, her chum and jig: vs/side.gd is "the sea" to them), made on
## every peer at the same path, so the host runs both and each peer sees both, exactly as it sees its own boat in
## co-op. The sea's own `boat`, `rods`, ... are whichever boat you're on (your camera, your HUD, your screens).
##
## The trip: when one boat heads out the other goes too, both from the harbour side by side, in the same kind of boat. The
## schools turn up round one boat, then the other, then between them (spawn_anchor). It ends at dusk, or when the
## skipper heads in: both come in, and what each had aboard (on deck and iced) is weighed against the other's.
##
## Dev and tests: --vs turns it on at the start (with --team=b, the host takes boat B).

const BoatSide := preload("res://vs/side.gd")
const Boat := preload("res://boat/boat.gd")
const Rods := preload("res://rods/rods.gd")
const Landing := preload("res://tuna/landing.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const Chum := preload("res://boat/chum.gd")
const Jig := preload("res://boat/jig.gd")
const Landmarks := preload("res://sea/landmarks.gd")
## Each boat's things, the sea's and a side's (the sea's point at the boat you're on).
const PARTS := ["boat", "rods", "landing", "fish_hold", "chum", "jig"]
## The boats set out from the harbour (sea/landmarks.gd): side by side inside the breakwaters, IN m off the beach,
## APART m either side of the middle, bows out to sea.
const APART := 25.0
const IN := 110.0
const LB_PER_KG := 2.20462

var sea: Node                 # sea/sea.gd
var on := false
## Peer id -> 0 (boat A) or 1 (boat B): the host's word.
var teams := {}
## The boat you're on (0 A, 1 B).
var my_team := 0
## [A, B] (vs/side.gd) while it's on.
var sides: Array = []
## The last trip's weigh-in, pounds [A, B] ([] till both are in).
var result: Array = []
var _out := false
var _last := [0.0, 0.0]
var _anchor := 0
var _draw_in := 0.0
var _ui: CanvasLayer
var _tally: Label
var _verdict: Label


func _ready() -> void:
	_build_ui()
	Net.peer_joined.connect(func(id: int) -> void:
		if not on or not multiplayer.is_server():
			return
		var n := [0, 0]
		for t: int in teams.values():
			n[t] += 1
		teams[id] = 0 if n[0] <= n[1] else 1
		_switch.rpc_id(id, true, teams, result)
		_teams.rpc(teams))
	Net.peer_left.connect(func(id: int) -> void: teams.erase(id))
	# (joining someone's boat: their skipper's word on VS from here; leaving or dropped: your own one boat)
	Net.joined.connect(func() -> void: _switch(false, {}, []))
	Net.left.connect(func(_was_host: bool) -> void: _switch(false, {}, []))
	Net.dropped.connect(func(_reason: String) -> void: _switch(false, {}, []))


# ------------------------------------------------------------------ the host

## Skipper, at the dock: two boats (everyone shared out between them), or back to the one.
func host_set_on(want: bool) -> void:
	if not Net.is_host() or want == on or not _all_docked():
		return
	var t := {}
	if want:
		var ids: Array = (sea.get("crew") as Node).get("slots").keys()
		ids.sort()
		for i in ids.size():
			t[ids[i]] = i % 2
	result = []
	if Net.in_session():
		_switch.rpc(want, t, [])
	else:
		_switch(want, t, [])


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
	if not on or not _all_docked() or t < 0 or t > 1:
		return
	teams[who] = t
	if Net.in_session():
		_teams.rpc(teams)
	else:
		_teams(teams)


func _process(delta: float) -> void:
	if not on:
		return
	_show()
	# (the sea lights the boat you're on: hers come on with them)
	(sides[1 - my_team].get("boat") as Node).call("set_lights", bool((sea.get("boat") as Node).get("_lights_on")))
	if not Net.is_host():
		return
	var holds: Array = sides.map(func(s: Node) -> Node: return s.get("fish_hold"))
	var docked: Array = holds.map(func(h: Node) -> bool: return bool(h.get("docked")))
	if not _out:
		if docked[0] != docked[1]:
			_host_set_out(holds, 0 if docked[1] else 1)
		return
	if not docked[0] and not docked[1] and float(holds[0].call("day_fraction")) < 1.0:
		for i in 2:
			_last[i] = _pounds(holds[i])
		_others_fish(delta)
		return
	# the trip's over (the skipper headed in, or it's dusk): both in, and the weigh-in
	_out = false
	for i in 2:
		if not docked[i]:
			_last[i] = _pounds(holds[i])
			holds[i].call("head_in")
	if Net.in_session():
		_result.rpc(_last)
	else:
		_result(_last)


## Host: one boat's headed out (`first`): the other goes with her in the same kind of boat, and they set off from the
## harbour side by side.
func _host_set_out(holds: Array, first: int) -> void:
	_out = true
	_last = [0.0, 0.0]
	holds[1 - first].call("head_out", str(holds[first].get("kind")))
	var marks: Node = sea.get("landmarks")
	var x := Landmarks.HARBOUR_X
	var z: float = float(marks.call("shore_z", x)) - IN if marks != null else 0.0
	for i in 2:
		var helm: Node = (sides[i].get("boat") as Node).get("helm")
		helm.set("at", Vector2(x + APART * (i * 2 - 1), z))
		helm.set("heading", 0.0)
		helm.set("speed", 0.0)
		if Net.in_session():
			helm.rpc("_sync", int(helm.get("captain")), 0.0, helm.get("at"), 0.0)
	if Net.in_session():
		_result.rpc([])
	else:
		_result([])


## Host: the schools' doings round the boat that isn't the sea's own (tuna/schools.gd does the sea's own boat's):
## bites on her baits, schools she runs over going down, schools finding her spread.
func _others_fish(delta: float) -> void:
	var schools: Node = sea.get("schools")
	if schools == null:
		return
	var keep: Node = schools.get("sea")
	schools.set("sea", sides[1 - my_team])
	schools.call("_strikes", delta)
	schools.call("_spooking")
	_draw_in -= delta
	if _draw_in <= 0.0:
		_draw_in = 1.0
		schools.call("_drawing")
	schools.set("sea", keep)


## Where the next school turns up round (tuna/schools.gd): one boat, the other, then between them, in turn.
func spawn_anchor() -> Vector2:
	_anchor = (_anchor + 1) % 3
	var a: Vector2 = ((sides[0].get("boat") as Node).get("helm") as Node).get("at")
	var b: Vector2 = ((sides[1].get("boat") as Node).get("helm") as Node).get("at")
	return [a, b, (a + b) * 0.5][_anchor]


# ------------------------------------------------------------------ everyone

@rpc("authority", "call_local", "reliable")
func _switch(want: bool, t: Dictionary, weighed: Array) -> void:
	if not want and not on:
		return
	result = weighed
	if want and not on:
		_build()
	elif not want and on:
		_tear_down()
	_teams(t)


@rpc("authority", "call_local", "reliable")
func _teams(t: Dictionary) -> void:
	teams = t
	my_team = int(teams.get(Net.my_id(), 0)) if on else 0
	_point_sea()
	var crew := sea.get("crew") as Node
	for id: int in crew.get("slots").keys():
		crew.call("reseat", id)


@rpc("authority", "call_local", "reliable")
func _result(weighed: Array) -> void:
	result = weighed


## Which boat crew member `id` is on.
func boat_of(id: int) -> Node3D:
	return sides[int(teams.get(id, 0))].get("boat") if on else sea.get("boat")


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


## Boat B and all her things, and boat A's things pointed at their side.
func _build() -> void:
	var a := _side(0)
	for k: String in PARTS:
		a.set(k, sea.get(k))
		(sea.get(k) as Node).set("sea", a)
	var b := _side(1)
	var boat := Boat.new()
	boat.name = "Boat"
	boat.ocean = sea.get("ocean")
	boat.sea = b
	b.boat = boat
	b.add_child(boat)
	b.rods = _part(b, Rods.new(), "Rods")
	b.landing = _part(b, Landing.new(), "Landing")
	b.fish_hold = _part(b, FishHold.new(), "FishHold")
	b.chum = _part(b, Chum.new(), "Chum")
	b.jig = _part(b, Jig.new(), "Jig")
	boat.use_kind(str((sea.get("fish_hold") as Node).get("kind")))
	boat.rebuilt.connect(func() -> void:
		(sea.get("crew") as Node).call("_on_rebuilt")
		_point_sea())
	sides = [a, b]
	on = true
	_out = false
	_ui.visible = true


func _side(team: int) -> BoatSide:
	var s := BoatSide.new()
	s.name = ["A", "B"][team]
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


## Back to the one boat: everyone aboard A, A's things the sea's again, B gone.
func _tear_down() -> void:
	on = false
	teams = {}
	var a: Node = sides[0]
	for k: String in PARTS:
		sea.set(k, a.get(k))
		(a.get(k) as Node).set("sea", sea)
	_point_sea()
	var crew := sea.get("crew") as Node
	for id: int in crew.get("slots").keys():
		crew.call("reseat", id)
	for s: Node in sides:
		remove_child(s)
		s.queue_free()
	sides = []
	_ui.visible = false


## The sea's boat (and rods, ...) are the boat you're on: your camera, your HUD, the screens on your dash.
func _point_sea() -> void:
	if on:
		for k: String in PARTS:
			sea.set(k, sides[my_team].get(k))
	var boat := sea.get("boat") as Node3D
	(sea.get("ocean") as Node).set("follow", boat)
	for screen: String in ["Sonar", "Radar"]:
		var n := sea.get_node_or_null(screen)
		if n != null:
			n.call("attach", boat)


# ------------------------------------------------------------------ the tally and the weigh-in

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 11
	_ui.visible = false
	add_child(_ui)
	_tally = Label.new()
	_tally.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tally.position = Vector2(-220, 12)
	_tally.size = Vector2(204, 60)
	_tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tally.add_theme_font_size_override("font_size", 16)
	_tally.add_theme_constant_override("outline_size", 5)
	_tally.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_tally.modulate = Color(1, 1, 1, 0.8)
	_ui.add_child(_tally)
	_verdict = Label.new()
	_verdict.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_verdict.position = Vector2(-300, 14)
	_verdict.size = Vector2(600, 70)
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict.add_theme_font_size_override("font_size", 30)
	_verdict.add_theme_constant_override("outline_size", 8)
	_verdict.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_ui.add_child(_verdict)


## Top right, out there: your boat's pounds over theirs. At the dock after a trip: who won, by how much.
func _show() -> void:
	var mine := my_team
	var lbs := [_pounds(sides[0].get("fish_hold")), _pounds(sides[1].get("fish_hold"))]
	var docked := bool((sea.get("fish_hold") as Node).get("docked"))
	_tally.visible = not docked
	_tally.text = "You  %d lb\nThem  %d lb" % [roundi(lbs[mine]), roundi(lbs[1 - mine])]
	_verdict.visible = docked and result.size() == 2
	if not _verdict.visible:
		return
	var us := roundi(float(result[mine]))
	var them := roundi(float(result[1 - mine]))
	if us == them:
		_verdict.text = "Dead even: %d lb each" % us
		_verdict.modulate = Color(1.0, 0.92, 0.6)
	else:
		_verdict.text = "%s by %d lb\n%d lb to %d" % ["You won" if us > them else "They won", absi(us - them),
				maxi(us, them), mini(us, them)]
		_verdict.modulate = Color(0.6, 1.0, 0.6) if us > them else Color(1.0, 0.55, 0.45)
