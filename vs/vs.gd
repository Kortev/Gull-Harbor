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
## schools turn up round one boat, then the other, then between them (spawn_anchor). Out there they're solid to each
## other, rock in each other's wakes and cut each other's lines (vs/contact.gd). Top left, small: both boats' pounds
## aboard, and a blinking dot and the squelch on the radio when the other crew hooks up. An air horn at each console
## (vs/horn.gd) to rattle the other crew. It ends at dusk, or when the
## skipper heads in: both come in alongside the fish pier, and what each had aboard (on deck and iced) is weighed, a
## fish at a time, A's then B's, and the winner said. Best of three days: the first to two wins the match.
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
const Contact := preload("res://vs/contact.gd")
const Horn := preload("res://vs/horn.gd")
const Hud := preload("res://ui/hud.gd")
const Sfx := preload("res://audio/sfx.gd")
## Each boat's things, the sea's and a side's (the sea's point at the boat you're on).
const PARTS := ["boat", "rods", "landing", "fish_hold", "chum", "jig"]
## The boats set out from the harbour (sea/landmarks.gd): side by side inside the breakwaters, IN m off the beach,
## APART m either side of the middle, bows out to sea.
const APART := 25.0
const IN := 110.0
const LB_PER_KG := 2.20462
## Each boat's colour (the tally, the weigh-in).
const COLOURS := [Color(1.0, 0.74, 0.32), Color(0.45, 0.8, 1.0)]
## The weigh-in: a fish read off every this many s (quicker with a lot of them), and a pause between the boats.
const READ := 0.8
const BETWEEN := 1.2
## Days won to win the match.
const MATCH := 2

var sea: Node                 # sea/sea.gd
var on := false
## Peer id -> 0 (boat A) or 1 (boat B): the host's word.
var teams := {}
## The boat you're on (0 A, 1 B).
var my_team := 0
## [A, B] (vs/side.gd) while it's on.
var sides: Array = []
## The last trip's weigh-in, pounds [A, B] ([] till both are in), and each boat's fish (lb, in the order caught).
var result: Array = []
var catches: Array = []
## Days each boat has won this match (best of three); and the weigh-in's still being read off.
var wins := [0, 0]
var weighing := false
## Where the boats meet (vs/contact.gd).
var contact: Contact
## What the tally shows: your boat's pounds, theirs (rounded).
var shown := [0, 0]
var _out := false
var _last := [0.0, 0.0]
var _anchor := 0
var _draw_in := 0.0
var _ui: CanvasLayer
var _race: Control
var _verdict: Label
var _board: VBoxContainer
var _steps: Array = []
var _step_in := 0.0
var _hooked := -1             # the other boat's fish on, last frame
var _their_on := 0.0          # s since they hooked up (the dot blinks)


func _ready() -> void:
	_build_ui()
	contact = Contact.new()
	contact.name = "Contact"
	contact.vs = self
	add_child(contact)
	Net.peer_joined.connect(func(id: int) -> void:
		if not on or not multiplayer.is_server():
			return
		var n := [0, 0]
		for t: int in teams.values():
			n[t] += 1
		teams[id] = 0 if n[0] <= n[1] else 1
		_switch.rpc_id(id, true, teams, result, wins)
		_teams.rpc(teams))
	Net.peer_left.connect(func(id: int) -> void: teams.erase(id))
	# (joining someone's boat: their skipper's word on VS from here; leaving or dropped: your own one boat)
	Net.joined.connect(func() -> void: _switch(false, {}, [], [0, 0]))
	Net.left.connect(func(_was_host: bool) -> void: _switch(false, {}, [], [0, 0]))
	Net.dropped.connect(func(_reason: String) -> void: _switch(false, {}, [], [0, 0]))


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
	wins = [0, 0]
	if Net.in_session():
		_switch.rpc(want, t, [], wins)
	else:
		_switch(want, t, [], wins)


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


## The helm of a boat that's just moved (boat/helm.gd, whoever moves her): kept out of the other boat.
func fend(helm: Node) -> void:
	contact.fend(helm)


func _process(delta: float) -> void:
	if not on:
		return
	_show(delta)
	_weigh(delta)
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
	# the trip's over (the skipper headed in, or it's dusk): both in alongside the fish pier, and the weigh-in
	_out = false
	var fish := [[], []]
	for i in 2:
		# (the one the skipper headed in has sold hers already: they're on her slip)
		var kgs: Array = ((holds[i].get("sale") as Dictionary).get("lines", []) as Array).map(
				func(l: Array) -> float: return float(l[0])) if docked[i] \
				else (holds[i].get("fish") as Array).map(func(f: Dictionary) -> float: return float(f["kg"]))
		fish[i] = kgs.map(func(kg: float) -> float: return kg * LB_PER_KG)
		if not docked[i]:
			_last[i] = _pounds(holds[i])
			holds[i].call("head_in")
	_moor()
	if roundi(_last[0]) != roundi(_last[1]):
		wins[0 if _last[0] > _last[1] else 1] += 1
	if Net.in_session():
		_result.rpc(_last, fish, wins)
	else:
		_result(_last, fish, wins)


## Host: both alongside the fish pier (sea/harbour.gd), A at her berth on its west side, B on its east, bows out.
func _moor() -> void:
	var harbour: Node = sea.get("harbour")
	if harbour == null:
		return
	for i in 2:
		var boat: Node = sides[i].get("boat")
		var helm: Node = boat.get("helm")
		var at: Vector2 = harbour.call("berth", float(boat.get("beam")) * 0.5, float(boat.get("length")))
		if i == 1:
			at.x = 2.0 * float(harbour.get("PIER_X")) - at.x
		helm.set("at", at)
		helm.set("heading", 0.0)
		helm.set("speed", 0.0)
		helm.set("throttle", 0.0)
		helm.set("drift", Vector2.ZERO)
		helm.set("spin", 0.0)
		if Net.in_session():
			helm.rpc("_sync", int(helm.get("captain")), 0.0, at, 0.0)


## Host: one boat's headed out (`first`): the other goes with her in the same kind of boat, and they set off from the
## harbour side by side.
func _host_set_out(holds: Array, first: int) -> void:
	_out = true
	_last = [0.0, 0.0]
	if wins.max() >= MATCH:
		wins = [0, 0]         # (a new match)
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
		_result.rpc([], [], wins)
	else:
		_result([], [], wins)


## Host: the schools' doings round the boat that isn't the sea's own (tuna/schools.gd does the sea's own boat's):
## bites on her baits, schools she runs over going down, schools finding her spread.
func _others_fish(delta: float) -> void:
	var schools: Node = sea.get("schools")
	if schools == null:
		return
	var keep: Node = schools.get("sea")
	schools.set("sea", sides[1 - my_team])
	schools.call("_strikes", delta)
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
func _switch(want: bool, t: Dictionary, weighed: Array, won: Array) -> void:
	if not want and not on:
		return
	result = weighed
	wins = won
	catches = []
	weighing = false
	_clear_board()
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
func _result(weighed: Array, fish: Array, won: Array) -> void:
	result = weighed
	catches = fish
	wins = won
	_clear_board()
	weighing = false
	_verdict.visible = false
	if weighed.size() == 2:
		_weigh_in()


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
	for i in 2:
		var horn := Horn.new()
		horn.name = "Horn"
		horn.vs = self
		horn.team = i
		horn.boat = sides[i].get("boat")
		horn.boat.add_child(horn)
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
	_verdict.position = Vector2(-300, 14)
	_verdict.size = Vector2(600, 70)
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict.add_theme_font_size_override("font_size", 30)
	_verdict.add_theme_constant_override("outline_size", 8)
	_verdict.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_ui.add_child(_verdict)
	# the weigh-in: a column for each boat, right of the dock's slip, her fish read off down it
	_board = VBoxContainer.new()
	_board.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_board.position = Vector2(-380, 110)
	_board.size = Vector2(340, 0)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_board)


## Out there: each boat's pounds aboard (yours on top), a bar each against the leader's, a pip a day won, and a red dot
## blinking by theirs while they've a fish on. In after a trip: the weigh-in, then who won and by how much.
func _show(delta: float) -> void:
	var lbs := [_pounds(sides[0].get("fish_hold")), _pounds(sides[1].get("fish_hold"))]
	shown = [roundi(lbs[my_team]), roundi(lbs[1 - my_team])]
	_race.set_meta("lbs", lbs)
	var docked := bool((sea.get("fish_hold") as Node).get("docked"))
	_race.visible = not docked
	# the other crew hooking up: a squawk on your radio, and their dot blinks while they're on
	var hooked := 0
	for r: Node in (sides[1 - my_team].get("rods") as Node).get("rods"):
		if bool(r.get("hooked")) and not bool(r.get("alongside")):
			hooked += 1
	if not docked and _hooked >= 0 and hooked > _hooked:
		_their_on = 0.0
		_radio("fish_on", 1.4)
	_hooked = hooked
	_their_on += delta
	_race.queue_redraw()
	_board.visible = docked
	_verdict.visible = docked and result.size() == 2 and not weighing
	if not _verdict.visible:
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


func _draw_race() -> void:
	var lbs: Array = _race.get_meta("lbs", [0.0, 0.0])
	var top := maxf(maxf(float(lbs[0]), float(lbs[1])), 1.0)
	for k in 2:
		var t := my_team if k == 0 else 1 - my_team
		var y := k * 18.0
		var col: Color = COLOURS[t]
		var lit := 1.0 if k == 0 else 0.75
		_text(Vector2(0, y + 11), "AB"[t], Color(col, lit))
		_race.draw_rect(Rect2(16, y + 2, 120, 9), Color(0, 0, 0, 0.45))
		_race.draw_rect(Rect2(16, y + 2, 120.0 * float(lbs[t]) / top, 9), Color(col, 0.85 * lit))
		_text(Vector2(142, y + 11), "%d" % roundi(float(lbs[t])), Color(Hud.CREAM, lit))
		for d in int(wins[t]):
			_race.draw_circle(Vector2(188 + d * 10, y + 6), 3.0, Color(col, lit))
		if t != my_team and _hooked > 0 and fmod(_their_on, 0.8) < 0.5:
			_race.draw_circle(Vector2(-8, y + 6), 3.5, Hud.RED)


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


## Both in alongside the fish pier: the screen fades up on them, and the fish are read off, A's then B's.
func _weigh_in() -> void:
	if sea.has_method("arrive"):
		sea.call("arrive")
	_steps = []
	for t in 2:
		var fish: Array = catches[t] if catches.size() == 2 else []
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
				var head := _line("AB"[int(s[1])], 26, COLOURS[int(s[1])])
				col.add_child(head)
				var rows := HFlowContainer.new()
				rows.name = "Fish"
				rows.add_theme_constant_override("h_separation", 14)
				rows.custom_minimum_size = Vector2(340, 0)
				col.add_child(rows)
				var sum := _line("0 lb", 22, Hud.CREAM)
				sum.name = "Sum"
				sum.set_meta("lb", 0.0)
				col.add_child(sum)
				Sfx.play("ui.page", 0.7)
				_step_in += 0.7
			"fish":
				var col := _board.get_node("Boat%d" % int(s[1]))
				col.get_node("Fish").add_child(_line("%d" % roundi(float(s[2])), 18, Color(Hud.CREAM, 0.85)))
				var sum := col.get_node("Sum") as Label
				sum.set_meta("lb", float(sum.get_meta("lb")) + float(s[2]))
				sum.text = "%d lb" % roundi(float(sum.get_meta("lb")))
				Sfx.play("kit.chain", 0.5, randf_range(0.95, 1.05))
				Sfx.play("kit.clank", 0.6)
				_step_in += float(s[3])
			"total":
				var sum := _board.get_node("Boat%d/Sum" % int(s[1])) as Label
				sum.text = "%d lb" % roundi(float(result[int(s[1])]))
				sum.add_theme_color_override("font_color", COLOURS[int(s[1])])
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
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return l
