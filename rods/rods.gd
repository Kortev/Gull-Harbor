extends Node3D
## The spread: the boat's rods in their holders (boat/kinds.gd: the skiff's two aft corners, the sportfisher's four),
## each with its bait out astern. Who holds which rod is the host's call: E on a rod asks it (request_grab), Q puts the one you
## hold back (request_return); the answer comes to every peer (_set_holder). A rod in someone's hands rides on
## them, its butt in their belt and the blank up ahead of them.

const Rod := preload("res://rods/rod.gd")
const Fight := preload("res://tuna/fight.gd")
const Sfx := preload("res://audio/sfx.gd")
const Tuna := preload("res://tuna/tuna.gd")
const Splash := preload("res://sea/splash.gd")
## A rod nobody's holding sits in its holder with the drag set: the host plays the fish against the drag (it takes
## line on its runs and tires doing it; between them nobody wins any back) and tells everyone how it's going.
const WHY := {"broke": "Line parted.", "broke_rail": "Line parted on the rail.", "pulled": "Hook pulled.",
		"thrown": "Thrown on the jump.", "spooled": "Spooled.", "chafed": "Chafed through on the hull.",
		"cut": "Cut on the props.", "tangle": "Lines tangled and parted."}
## How heavy the rod's tip feels with a fish on (0: not at all .. 1: it fights your heave and drags the tip down).
const ROD_WEIGHT := 1.0
## The scroll wheel steps the drag no faster than this (s a notch).
const NOTCH := 0.2
## While a fish is on, how often (s) the host looks for its run crossing another line that's still out, and the
## chance each time it does that tangles them; quiet this long after a fish (s) and the baits go back out.
const TANGLE_EVERY := 1.0
const TANGLE_CHANCE := 0.2
const BAITS_BACK := 20.0
## A bait out goes off: washed out, chewed by little fish, swimming tired (s till it's no good: a dead bait, a live
## mackerel); worse than STALE and it's worth putting a fresh one on (E on the rod: in, a new one, out in REBAIT s).
## A fresh live bait gets LIVE_BITES times the bites; a washed-out one a quarter of a fresh one's.
const BAIT_LIFE := 300.0
const LIVE_LIFE := 600.0
const STALE := 0.5
const REBAIT := 4.0
const LIVE_BITES := 1.5
## Faster than this (m/s: tuna/schools.gd's BITE_SPEED) the baits skip along the top.
const BITE_SPEED_SKIP := 6.0

var sea: Node                 # sea/sea.gd
var rods: Array[Rod] = []
## From the boat's kind (boat/kinds.gd): the holders the rods sit in, where each bait is (boat-local: x across, z
## astern), each rod's name, and where the lines go over the transom (bearings and line out are measured from here).
var holders: Array[int] = []
var baits: Array[Vector3] = []
var names: Array[String] = []
var stern := Vector3(0.0, 0.0, 7.05)
## Her outline for the line rubbing (tuna/fight.gd's rub): half her beam, her transom, her house's aft face and her
## bow (z, her frame).
var _half_beam := 2.4
var _aft := 7.3
var _house := 0.4
var _fore := -6.7
var _send_in := 0.0
var _last_heading := 0.0
## Your rod's line out last frame, and how fast you're winning it back (m/s, smoothed; - while it takes line).
var _trend_out := -1.0
var _trend := 0.0
var _notch_t := 0.0
## (tests) set x to a rod elevation and the fight-sense side goes in y: a test angler's hands instead of the mouse
var bot_aim := Vector3(NAN, 0.0, 0.0)
var _look_off := 0.0
var _spill_t := 0.0
var _tangle_in := 0.0
var _quiet := 0.0
var _splash: Splash


func _ready() -> void:
	_splash = Splash.new()
	_splash.name = "Splash"
	add_child(_splash)
	_lay_out()
	(sea.get("boat") as Node).connect("rebuilt", _lay_out)
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_sync.rpc_id(id, _states()))
	Net.peer_left.connect(func(id: int) -> void:
		if Net.is_host():
			for r in rods:
				if r.holder == id:
					_host_set(r.index, 0))
	Net.dropped.connect(func(_reason: String) -> void: _own_boat(false))
	Net.left.connect(_own_boat)


## Her rods, as her kind has them: new rods in her holders, baits out (and again whenever she's rebuilt as another
## kind: at the dock, so nothing's on).
func _lay_out() -> void:
	var spec: Dictionary = (sea.get("boat") as Node).get("spec")
	holders.clear()
	baits.clear()
	names.clear()
	for h in spec["rods"]:
		holders.append(int(h))
	for b in spec["baits"]:
		baits.append(b)
	for n in spec["rod_names"]:
		names.append(str(n))
	stern = spec["stern"]
	_half_beam = float(spec["beam"]) * 0.5
	_aft = (spec.get("transom", stern) as Vector3).z
	_fore = _aft - float(spec["length"])
	_house = float(spec.get("house", 0.0))
	for r in rods:
		if is_instance_valid(r.fish_node):
			r.fish_node.queue_free()
		remove_child(r)
		r.queue_free()
	rods.clear()
	for i in holders.size():
		var r := Rod.new()
		r.name = "Rod%d" % i
		r.index = i
		r.spread = self
		r.baited_t = _now()
		add_child(r)
		rods.append(r)


## Back on your own boat (you left the crew, or the host went). `kept`: it was our boat (we were hosting), so our
## fish stay on and only crewmates' hands come off the rods; otherwise those were the host's fish, and they go.
func _own_boat(kept: bool) -> void:
	for r in rods:
		if kept:
			if r.holder != Net.my_id():
				r.holder = 0
				r.fight = null
			continue
		r.holder = 0
		r.hooked = false
		r.alongside = false
		r.fight = null
		r.line_out = 0.0
		r.strain = 0.05
		r.move = ""


func held_by(peer: int) -> Rod:
	for r in rods:
		if r.holder == peer:
			return r
	return null


func request_grab(i: int) -> void:
	if Net.is_host():
		_ask_grab(i)
	else:
		_ask_grab.rpc_id(1, i)


func request_return(i: int) -> void:
	if Net.is_host():
		_ask_return(i)
	else:
		_ask_return.rpc_id(1, i)


@rpc("any_peer", "call_remote", "reliable")
func _ask_grab(i: int) -> void:
	var who := _sender()
	if i < 0 or i >= rods.size() or held_by(who) != null:
		return
	# a free rod, or taking over a crewmate's fish (their arms are going); not one whose fish is up alongside
	if rods[i].holder != 0 and not rods[i].hooked or rods[i].alongside:
		return
	# an empty rod while a fish is on: E clears its line (reels it in); with nothing on, puts its bait back out
	if not rods[i].hooked and rods[i].holder == 0:
		if fighting() and not rods[i].bait_in:
			_host_line(i, true)
			return
		if not fighting() and rods[i].bait_in:
			_host_line(i, false)
			return
		if not fighting() and _wants_bait(i):
			_host_rebait(i)
			return
	var helm: Node = (sea.get("boat") as Node).get("helm")
	if int(helm.get("captain")) == who:
		return        # (the captain's hands are on the wheel)
	if int((sea.get("landing") as Node).get("harpoon_holder")) == who:
		return        # (and the harpoon's in yours)
	_host_set(i, who)


@rpc("any_peer", "call_remote", "reliable")
func _ask_return(i: int) -> void:
	if i >= 0 and i < rods.size() and rods[i].holder == _sender():
		_host_set(i, 0)


func _sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return s if s != 0 else Net.my_id()


func _host_set(i: int, who: int) -> void:
	if Net.in_session():
		_set_holder.rpc(i, who)
	else:
		_set_holder(i, who)


@rpc("authority", "call_local", "reliable")
func _set_holder(i: int, who: int) -> void:
	if i < 0 or i >= rods.size():
		return        # (a rod she hasn't got: a word from before she was rebuilt)
	var r := rods[i]
	var handed := r.holder != 0 and who != 0
	if r.holder != 0:
		r.last_holder = r.holder
	r.holder = who
	r.fight = null
	r.lift = 0.0
	r.aim_pitch = 0.6
	r.aim_side = 0.0
	_look_off = 0.0
	# (changing hands: the fight carries on from where it is, on the new holder's machine or the host's)
	r.free_t = _now()
	if handed and r.hooked and who == Net.my_id():
		_hud_note("You've got it!")


## A fish is on somewhere (hooked, still fighting: not up alongside).
func fighting() -> bool:
	for r in rods:
		if r.hooked and not r.alongside:
			return true
	return false


## Host: rod i's line reeled in (cleared: no bait out, any tangle off it), or a fresh bait put back out on it (a live
## mackerel if there's one in the well).
func _host_line(i: int, reel_in: bool) -> void:
	var live := false
	if not reel_in:
		var hold: Node = sea.get("fish_hold")
		live = hold != null and bool(hold.call("host_take_live"))
	if Net.in_session():
		_line.rpc(i, reel_in, _now(), live)
	else:
		_line(i, reel_in, _now(), live)


@rpc("authority", "call_local", "reliable")
func _line(i: int, reel_in: bool, t := 0.0, live := false) -> void:
	if i < 0 or i >= rods.size():
		return
	var r := rods[i]
	if r.tangled >= 0 and reel_in:
		_hud_note("Cleared the %s line!" % _name_of(i))
	if reel_in != r.bait_in:
		Sfx.play_point(self, r.global_position, "dock.reel", 0.9, 1.2 if reel_in else 0.9)
	r.bait_in = reel_in
	r.tangled = -1
	if not reel_in:
		r.baited_t = t
		r.live = live


## How good rod i's bait still is, 1 (just on) .. 0 (washed out).
func freshness(i: int) -> float:
	if i < 0 or i >= rods.size():
		return 0.0
	var r := rods[i]
	return clampf(1.0 - (_now() - r.baited_t) / (LIVE_LIFE if r.live else BAIT_LIFE), 0.0, 1.0)


## How readily rod i's bait gets eaten (tuna/schools.gd), against a fresh dead bait's 1.
func bite_odds(i: int) -> float:
	if i < 0 or i >= rods.size() or rods[i].bait_in:
		return 0.0
	return (0.25 + 0.75 * freshness(i)) * (LIVE_BITES if rods[i].live else 1.0)


## Whether rod i's bait wants changing: gone off, or a dead one while there's a live mackerel in the well.
func _wants_bait(i: int) -> bool:
	var r := rods[i]
	var hold: Node = sea.get("fish_hold")
	if r.hooked or r.bait_in or r.tangled >= 0 or (hold != null and bool(hold.get("docked"))):
		return false
	var live_in_well := hold != null and bool(hold.call("has_gear", "bait")) and int(hold.get("well")) > 0
	return freshness(i) < STALE or (not r.live and live_in_well)


## Host: rod i's bait changed: reeled in, a fresh one on, out again REBAIT s later (unless a fish came on meanwhile).
func _host_rebait(i: int) -> void:
	var r := rods[i]
	_host_line(i, true)
	get_tree().create_timer(REBAIT).timeout.connect(func() -> void:
		if is_instance_valid(r) and rods.has(r) and r.bait_in and not r.hooked and not fighting() \
				and not bool((sea.get("fish_hold") as Node).get("docked")):
			_host_line(r.index, false))


## The E prompt on an idle rod (rod.gd): rebait it if it wants it, else just grab it.
func rebait_prompt(i: int) -> String:
	if not _wants_bait(i):
		return "Grab the rod"
	if freshness(i) < STALE:
		return "Rebait: this one's washed out"
	return "Rebait with a live mackerel"


## For the HUD while nothing else wants doing: a bait gone off.
func hint() -> String:
	if fighting():
		return ""
	for r in rods:
		if not r.hooked and not r.bait_in and r.tangled < 0 and freshness(r.index) < STALE:
			return "The %s bait's washed out: E on that rod to rebait" % _name_of(r.index)
	return ""


@rpc("authority", "call_local", "reliable")
func _tangle(i: int, with_rod: int) -> void:
	if i < 0 or i >= rods.size():
		return
	rods[i].tangled = with_rod
	Sfx.play_point(self, rods[i].global_position, "kit.jolt")
	_hud_note("TANGLED! The fish ran across the %s line: clear it, E on that rod" % _name_of(i))


func _name_of(i: int) -> String:
	return names[i] if i >= 0 and i < names.size() else "other"


## Whether another rod's line is tangled in rod i's fish.
func is_tangled(i: int) -> bool:
	for r in rods:
		if r.tangled == i:
			return true
	return false


## Host, while a fish is on: its run crossing a line that's still out tangles them now and then; quiet a while after
## a fish, the crew put the baits back out.
func _host_lines(delta: float) -> void:
	var landing: Node = sea.get("landing")
	var docked := bool((sea.get("fish_hold") as Node).get("docked")) if sea.get("fish_hold") != null else false
	if docked or fighting() or (landing != null and not (landing.get("fish") as Dictionary).is_empty()):
		_quiet = 0.0
	else:
		_quiet += delta
		if _quiet > BAITS_BACK:
			_quiet = 0.0
			for r in rods:
				if r.bait_in or r.tangled >= 0:
					_host_line(r.index, false)
	_tangle_in -= delta
	if _tangle_in > 0.0:
		return
	_tangle_in = TANGLE_EVERY
	for a in rods:
		if not a.hooked or a.alongside:
			continue
		var hd := sqrt(maxf(a.line_out * a.line_out - a.depth * a.depth, 0.0))
		for b in rods:
			if b == a or b.hooked or b.bait_in or b.tangled >= 0:
				continue
			var bait := baits[b.index] - stern
			var crossing := absf(wrapf(a.bearing - atan2(bait.x, bait.z), -PI, PI)) < 0.3
			if crossing and hd > bait.length() * 0.6 and randf() < TANGLE_CHANCE:
				if Net.in_session():
					_tangle.rpc(b.index, a.index)
				else:
					_tangle(b.index, a.index)


## Host: a fish takes rod i's bait.
func strike(i: int, kg: float) -> void:
	if i < 0 or i >= rods.size():
		return        # (a rod she hasn't got: a word from before she was rebuilt)
	var r := rods[i]
	if r.hooked or r.bait_in or (sea.get("landing") as Node).get("fish").has(i):
		return        # (its last fish is still astern on the harpoon: no bait out yet)
	var bait := baits[i] - stern
	var bearing := atan2(bait.x, bait.z) + randf_range(-0.5, 0.5)
	if Net.in_session():
		_strike.rpc(i, kg, _now(), bearing, randi())
	else:
		_strike(i, kg, _now(), bearing, randi())


@rpc("authority", "call_local", "reliable")
func _strike(i: int, kg: float, t: float, bearing: float, seed_value: int) -> void:
	if i < 0 or i >= rods.size():
		return        # (a rod she hasn't got: a word from before she was rebuilt)
	var r := rods[i]
	r.hooked = true
	r.fish_kg = kg
	r.hook_t = t
	r.bearing = bearing
	r.depth = 2.0
	r.energy = 1.0
	r.move = "run"
	r.line_out = (baits[i] - stern).length()
	r.free_t = t
	r.alongside = false
	r.stretch = 0.0
	r.hold = 1.0
	r.drag = Fight.STRIKE_DRAG
	r.aim_pitch = 0.6
	r.aim_side = 0.0
	r.turn_sign = 0.0
	r.fight = null
	r.wear = 0.0
	r.set_meta("seed", seed_value)
	_hud_note("FISH ON!  The %s rod!" % (names[i] if i < names.size() else "a"))


@rpc("authority", "call_local", "reliable")
func _off(i: int, why: String) -> void:
	if i < 0 or i >= rods.size():
		return        # (a rod she hasn't got: a word from before she was rebuilt)
	var r := rods[i]
	r.hooked = false
	r.alongside = false
	r.fight = null
	r.line_out = 0.0
	# (the lines that were tangled in it: free, reeled in)
	for other in rods:
		if other.tangled == i:
			other.tangled = -1
			other.bait_in = true
	r.strain = 0.05
	r.move = ""
	_hud_note(why)


## The holder's word on how the fight's going (any peer: the holder's own; everyone else draws it).
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _fight_state(i: int, out: float, strain: float, bearing: float, depth: float, energy: float, aim: Vector2,
		move: String, wear: float, stretch: float, turn: float, drag: float, hold: float, reeling: float) -> void:
	if i < 0 or i >= rods.size():
		return        # (a rod she hasn't got: a word from before she was rebuilt)
	var r := rods[i]
	if r.holder == multiplayer.get_remote_sender_id() and r.hooked and not r.alongside:
		r.line_out = out
		r.strain = strain
		r.bearing = bearing
		r.depth = depth
		r.energy = energy
		r.aim_pitch = aim.x
		r.aim_side = aim.y
		r.lift = clampf((aim.x - 0.6) / 0.75, 0.0, 1.0)
		r.move = move
		r.wear = wear
		r.stretch = stretch
		r.turn_sign = turn
		r.drag = drag
		r.hold = hold
		r.reeling = reeling


## The host's word on a fish on a rod in its holder (nobody holding it: the host plays it against the drag).
@rpc("authority", "call_remote", "unreliable_ordered")
func _holder_state(i: int, out: float, strain: float, bearing: float, depth: float, energy: float, move: String,
		wear: float, stretch: float, turn: float, drag: float, hold: float) -> void:
	if i < 0 or i >= rods.size():
		return        # (a rod she hasn't got: a word from before she was rebuilt)
	var r := rods[i]
	if r.holder == 0 and r.hooked and not r.alongside:
		r.line_out = out
		r.strain = strain
		r.bearing = bearing
		r.depth = depth
		r.energy = energy
		r.move = move
		r.wear = wear
		r.stretch = stretch
		r.turn_sign = turn
		r.drag = drag
		r.hold = hold


## The holder's fight ended (lost, or boatside): the host says so to everyone. It counts from whoever held it
## last too: the fight can end on their machine while the rod's changing hands.
@rpc("any_peer", "call_remote", "reliable")
func _report_end(i: int, how: String) -> void:
	if i < 0 or i >= rods.size():
		return        # (a rod she hasn't got: a word from before she was rebuilt)
	var r := rods[i]
	var who := multiplayer.get_remote_sender_id()
	if r.hooked and not r.alongside and (r.holder == who or r.last_holder == who):
		_host_end(i, how)


## Host: rod i's fight is over: up alongside for the harpoon (tuna/landing.gd), or lost.
func _host_end(i: int, how: String) -> void:
	var r := rods[i]
	if how == "boatside":
		(sea.get("landing") as Node).call("host_alongside", i, r.fish_kg, r.bearing, r.hook_t)
	else:
		_host_off(i, str(WHY.get(how, "Lost it.")))


## Everyone (tuna/landing.gd): rod i's fish is up alongside, beaten: no more fight on it.
func set_alongside(i: int) -> void:
	if i < 0 or i >= rods.size():
		return        # (a rod she hasn't got: a word from before she was rebuilt)
	var r := rods[i]
	r.hooked = true
	r.alongside = true
	r.fight = null
	r.move = ""
	r.strain = 0.35
	r.stretch = 0.0


## Host, heading in: every fish still on is let go and the baits come in (host_baits_out when she's out again).
func host_clear() -> void:
	for r in rods:
		if r.hooked:
			_host_off(r.index, "")
		if not r.bait_in:
			_host_line(r.index, true)


## Host, heading out: a fresh bait out on every rod.
func host_baits_out() -> void:
	_quiet = 0.0
	for r in rods:
		if not r.hooked:
			_host_line(r.index, false)


## Host: rod i's fish is gone (lost alongside, or stuck and on the harpoon now), with why.
func host_off(i: int, why: String) -> void:
	_host_off(i, why)


func _now() -> float:
	return float((sea.get("ocean") as Node).get("wave_time"))


func _hud_note(text: String) -> void:
	if text.is_empty():
		return
	var crew := sea.get("crew") as Node
	(crew.get("hud") as Node).call("notify", text)


func _host_off(i: int, why: String) -> void:
	if i < 0 or i >= rods.size():
		return        # (a rod she hasn't got: a word from before she was rebuilt)
	if Net.in_session():
		_off.rpc(i, why)
	else:
		_off(i, why)


## A late joiner: who holds what, and every fish on.
@rpc("authority", "call_remote", "reliable")
func _sync(states: Array) -> void:
	for i in mini(states.size(), rods.size()):
		var st: Array = states[i]
		var r := rods[i]
		r.holder = int(st[0])
		r.hooked = bool(st[1])
		r.fish_kg = float(st[2])
		r.line_out = float(st[3])
		r.bearing = float(st[4])
		r.depth = float(st[5])
		r.energy = float(st[6])
		r.free_t = float(st[7])
		r.wear = float(st[8])
		r.move = str(st[9])
		r.alongside = bool(st[10])
		r.bait_in = bool(st[11])
		r.tangled = int(st[12])
		r.baited_t = float(st[13])
		r.live = bool(st[14])


func _states() -> Array:
	var out := []
	for r in rods:
		out.append([r.holder, r.hooked, r.fish_kg, r.line_out, r.bearing, r.depth, r.energy, r.free_t, r.wear, r.move,
				r.alongside, r.bait_in, r.tangled, r.baited_t, r.live])
	return out


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drop"):
		var mine := held_by(Net.my_id())
		if mine:
			request_return(mine.index)
	# the drag lever, a notch at a time on the wheel, while you've a fish on
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var r := held_by(Net.my_id())
		if r != null and r.hooked and not r.alongside:
			notch_drag(r, 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)


## The drag on rod r a notch tighter (+1) or looser (-1), with the click of the lever.
func notch_drag(r: Rod, way: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _notch_t < NOTCH:
		return
	var at := 0
	var best := 9.0
	for k in Fight.DETENTS.size():
		if absf(float(Fight.DETENTS[k]) - r.drag) < best:
			best = absf(float(Fight.DETENTS[k]) - r.drag)
			at = k
	var to := clampi(at + way, 0, Fight.DETENTS.size() - 1)
	if to == at:
		return
	_notch_t = now
	r.drag = float(Fight.DETENTS[to])
	Sfx.play_point(self, r.global_position, "kit.switch", 0.4, 1.4 if way > 0 else 1.1)


func _process(delta: float) -> void:
	var boat := sea.get("boat") as Node3D
	var ocean := sea.get("ocean") as Node
	var crew := sea.get("crew") as Node
	var landing := sea.get("landing") as Node
	var me := Net.my_id()
	var mine: Rod = null
	if Net.is_host():
		_host_lines(delta)
	_send_in -= delta
	var send := _send_in <= 0.0 and Net.in_session()
	if send:
		_send_in = 0.1
	# the captain swinging her round swings every fish's bearing the other way (they stay where they are)
	var helm: Node = boat.get("helm")
	var heading := float(helm.get("heading"))
	var turned := wrapf(heading - _last_heading, -PI, PI)
	_last_heading = heading
	for r in rods:
		if r.hooked and r.alongside:
			r.reeling = 0.0
		elif r.hooked:
			if r.fight != null:
				(r.fight as Fight).bearing -= turned
			if r.holder == 0:
				# nobody on it: in its holder, the drag working the fish (the host plays it, everyone else draws it)
				r.reeling = 0.0
				r.bearing -= turned
				if Net.is_host():
					_fight_holder(r, delta, float(helm.get("throttle")), send)
			elif r.holder == me:
				mine = r
				r.bearing -= turned
				_fight_mine(r, delta, float(helm.get("throttle")), send)
			else:
				r.bearing -= turned     # (till their next word, which has it)
			# (someone else's: their peer sends how it's going)
		else:
			r.strain = 0.05
			r.reeling = 0.0
		var p: Node3D = crew.call("get_player", r.holder) if r.holder != 0 else null
		if p == null:
			# in its holder: the holder's tube, the butt down in it
			var ht: Transform3D = boat.call("holder_transform", holders[r.index])
			r.global_transform = ht.translated_local(Vector3(0, 0, -0.42))
		else:
			r.global_transform = _in_hands(p, r)
		var end := boat.global_transform * baits[r.index]
		var tangled_in := r.tangled >= 0 and r.tangled < rods.size()
		var alongside: Vector3 = landing.call("fish_point", r.index) if r.alongside else Vector3.ZERO
		if r.alongside and alongside != Vector3.ZERO:
			end = alongside      # (straight to the fish lying astern)
		elif r.hooked:
			# a fish on pulls the line straight from the rod tip to it: it goes in where that straight line meets the
			# water (close in for a deep fish, out toward it for one near the top)
			var tip := r.tip_position()
			var to := fish_point(r, boat)
			var sea_y := float(ocean.call("height_at", tip))
			var k := clampf((tip.y - sea_y) / maxf(tip.y - to.y, 0.01), 0.0, 1.0)
			end = tip.lerp(to, k)
			end.y = ocean.call("height_at", end)
		elif tangled_in:
			end = rods[r.tangled].line_end      # (across the running fish's line)
		elif r.bait_in:
			end = r.tip_position() + Vector3(0.0, -0.3, 0.0)     # (reeled in: just the leader hanging)
		else:
			end = _tow(r, end, float(helm.get("speed")), ocean, delta)
		if r.hooked or r.bait_in or tangled_in:
			r.bait_p = Vector3.INF       # (out again, it starts from where her spread puts it)
			# (a fish on: the line droops when it's come at you or she's backed onto it, bar-tight when it pulls)
			r.slack = clampf(-r.stretch / 4.0, 0.0, 1.0) if r.hooked and not r.alongside else 0.0
		r.line_end = end
		_show_fish(r, boat, ocean, delta)
	var hud := crew.get("hud") as Node
	var me_node := crew.get("me") as Node
	if me_node != null:
		# the fish in your arms: a jolt in a head shake or a jump landing, a steady shudder while the drag slips
		var shook := 0.0
		if mine != null and mine.hooked and mine.fight != null:
			var f := mine.fight as Fight
			shook = clampf(f.shock * 1.5 + (0.25 * f.strain if f.slipping else 0.0), 0.0, 1.0)
		me_node.set("shake", shook)
	if mine != null and mine.hooked:
		# nothing to read: the rod, the reel and the line say it all
		hud.call("fight", "", 0.0)
	else:
		_trend_out = -1.0
		_trend = 0.0
		# nothing on in your hands: what wants doing (a fish alongside to stick and haul, one on deck to bleed)
		var todo := str(landing.call("hint"))
		if todo.is_empty():
			todo = str((sea.get("fish_hold") as Node).call("hint"))
		if todo.is_empty() and not bool((sea.get("fish_hold") as Node).get("docked")):
			todo = hint()
			var spotter: Node = sea.get("spotter")
			if todo.is_empty() and spotter != null and int(spotter.get("used")) < 3:
				todo = "Find the birds: look along the horizon for a flock and head for it"
		hud.call("fight", todo, 0.0)
	# the captain's plotter: where each fish on is, round the boat
	var fish := []
	if bool(helm.call("is_mine")):
		for r in rods:
			if r.hooked and not r.alongside:
				var hd := sqrt(maxf(r.line_out * r.line_out - r.depth * r.depth, 0.0))
				# (how hard it'd rub even with the angler at its corner: then it's the captain's to swing her)
				var tip := Fight.corner_tip(r.bearing, hd, 1.0, _half_beam, _aft, stern.z)
				var fish_at := Vector2(0.0, stern.z) + Vector2(sin(r.bearing), cos(r.bearing)) * hd
				fish.append([r.bearing, hd, Fight.rub(tip, fish_at, _half_beam, _house, _fore)])
		if not fish.is_empty() and mine == null:
			var worst := 0.0
			var spiral := false
			for f: Array in fish:
				worst = maxf(worst, float(f[2]))
			for r in rods:
				spiral = spiral or (r.hooked and not r.alongside and r.move == "spiral")
			var under := false
			var cutting := false
			for r in rods:
				if r.hooked and not r.alongside and absf(wrapf(r.bearing, -PI, PI)) > Fight.UNDER - 0.2 and r.depth < 25.0:
					under = true
					cutting = cutting or absf(float(helm.get("throttle"))) > 0.05
			var say := "Keep the stern on it!"
			if cutting:
				say = "OUT OF GEAR! It's under the props!"
			elif spiral:
				say = "Death spiral! Out of gear: it's going under her"
			elif under:
				say = "It's under her! Out of gear: steer her stern round to it, A/D only"
			elif worst >= 0.3:
				say = "It's on the hull! Swing her stern to it!"
			hud.call("fight", say, 0.0)
	hud.call("plot", fish, float(helm.get("throttle")))


## The fish on rod r, seen: mostly it's down there out of sight, but it boils the water where the line goes in when it
## takes off on a run (the strike itself an explosion of white water), slaps it in its head shakes, and in the death
## spiral it's up near the top, circling, its back and tail breaking the surface ("colour!"). Every peer draws it
## from the rod's state.
func _show_fish(r: Rod, boat: Node3D, ocean: Node, delta: float) -> void:
	if not r.hooked or r.alongside:
		if is_instance_valid(r.fish_node):
			r.fish_node.queue_free()
		r.fish_node = null
		r.seen_move = ""
		return
	var hd := sqrt(maxf(r.line_out * r.line_out - r.depth * r.depth, 0.0))
	var at := boat.global_transform * (stern + Vector3(sin(r.bearing), 0.0, cos(r.bearing)) * hd)
	var top := float(ocean.call("height_at", at))
	var t := _now()
	var spiral := r.move == "spiral"
	# how deep it shows: where it is, but in the spiral right up under the surface, its back out now and then
	var under := r.depth if not spiral else 0.25 + 0.35 * (0.5 + 0.5 * sin(t * 1.3 + r.index))
	at.y = top - maxf(under, 0.25)
	# a jump: up out of the water in an arc, clear of it for most of a second, and back in (fight.gd's phases)
	var air := -1.0
	if r.move == "jump":
		if r.seen_move != "jump":
			r.set_meta("jump_t", t)
		var jt := t - float(r.get_meta("jump_t", t))
		if jt >= 0.5 and jt < 1.2:
			air = (jt - 0.5) / 0.7
			at.y = top + (1.0 + r.fish_kg / 80.0) * sin(PI * air)
	if not is_instance_valid(r.fish_node):
		var f := Tuna.new(r.fish_kg)
		f.name = "Hooked%d" % r.index
		f.top_level = true
		add_child(f)
		f.global_position = at
		r.fish_node = f
		_splash.burst(r.line_end, 1.8, true)        # (the strike)
	var fish := r.fish_node as Tuna
	# (close in, near the top, you can see it down there; and in the air, of course)
	fish.visible = under < 6.0 or (r.line_out < 30.0 and r.depth < 10.0) or air >= 0.0
	if delta > 0.0:
		fish.velocity = (at - fish.global_position) / delta
	fish.effort = clampf(r.strain + (0.6 if r.move in ["run", "shake"] else 0.0), 0.0, 1.0)
	# the surface: a boil as it takes off, slaps in a head shake, swirls as it circles near the top
	r.splash_in -= delta
	if r.move != r.seen_move:
		if r.move == "run" and r.seen_move != "":
			_splash.burst(r.line_end, 1.3)
		r.seen_move = r.move
	if air >= 0.0 and not bool(r.get_meta("left_water", false)):
		r.set_meta("left_water", true)
		_splash.burst(Vector3(at.x, top, at.z), 1.4, true)     # (out it comes)
	elif air < 0.0 and bool(r.get_meta("left_water", false)):
		r.set_meta("left_water", false)
		_splash.burst(Vector3(at.x, top, at.z), 1.8, true)     # (and back in)
	if r.splash_in <= 0.0:
		if r.move == "shake" and r.depth < 20.0:
			r.splash_in = randf_range(0.4, 0.8)
			_splash.burst(r.line_end, 0.9, true)
		elif spiral:
			r.splash_in = randf_range(1.6, 3.0)
			_splash.burst(Vector3(at.x, top, at.z), 0.8, randf() < 0.5)
		elif r.move == "run" and r.depth < 8.0:
			r.splash_in = randf_range(0.8, 1.6)
			_splash.burst(r.line_end, 0.6)


## A bait being towed (its line out, nothing on): dragged along behind the rod tip on its line, held out to its side
## of the spread while she's moving (the outriggers' job: `spot` is where her spread puts it), swinging wide round
## her turns, carrying on and dropping back when she stops (the line going slack), riding the swell, and skipping
## along the top at speed. Every peer tows its own (it's for the eye; the host's is the one the tuna bite).
func _tow(r: Rod, spot: Vector3, speed: float, ocean: Node, delta: float) -> Vector3:
	var tip := r.tip_position()
	if r.bait_p == Vector3.INF or r.bait_p.distance_to(spot) > 150.0:
		r.bait_p = spot
		r.bait_v = Vector3.ZERO
	var reach := maxf(tip.distance_to(Vector3(spot.x, tip.y - 1.5, spot.z)), 5.0)
	var p := r.bait_p
	var held := clampf(absf(speed) / 3.0, 0.0, 1.0)
	r.bait_v += Vector3(spot.x - p.x, 0.0, spot.z - p.z) * 0.9 * held * delta
	r.bait_v *= exp(-1.1 * delta)
	var was := p
	p += r.bait_v * delta
	# on its line: no further from the tip than the line out; pulled along it when she tows it
	var off := Vector3(p.x - tip.x, 0.0, p.z - tip.z)
	if off.length() > reach:
		var n := off.normalized()
		p = Vector3(tip.x, p.y, tip.z) + n * reach
	# (its way through the water is what it actually did: dragged along, it carries on when she stops)
	if delta > 0.0:
		r.bait_v = Vector3(p.x - was.x, 0.0, p.z - was.z) / delta
	r.slack = clampf(1.0 - minf(off.length(), reach) / reach, 0.0, 1.0)
	p.y = float(ocean.call("height_at", p))
	if absf(speed) > BITE_SPEED_SKIP:
		p.y += absf(sin(_now() * 7.0 + r.index * 1.9)) * 0.3     # (skipping)
	r.bait_p = p
	return p


## Your rod with a fish on: you fight it here and tell the rest. The mouse is the rod (up and down its elevation,
## side to side laid over off the line), the camera following it part of the way so the line and the water stay in
## view; left mouse cranks, right mouse raises the rod too, the wheel sets the drag. `throttle`: the captain's.
func _fight_mine(r: Rod, delta: float, throttle: float, send: bool) -> void:
	var me := (sea.get("crew") as Node).get("me") as Node
	var live := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (me != null and bool(me.get("force_input")))
	var crank := 1.0 if live and Input.is_action_pressed("use_primary") else 0.0
	var heave := live and Input.is_action_pressed("use_secondary")
	var fight := r.fight as Fight
	if fight == null or fight.in_holder:
		fight = _new_fight(r)
	var side := _aim(r, me, fight, delta, heave)
	r.lift = clampf((r.aim_pitch - 0.6) / 0.75, 0.0, 1.0)
	fight.throttle = throttle
	fight.moving = true
	fight.boat_vel = _boat_vel()
	fight.tip = _tip_local(r)
	fight.rub_now = rub_on_hull(r)
	fight.tangled = is_tangled(r.index)
	fight.step(delta, crank, r.aim_pitch, side, r.drag)
	if not r.hooked or r.alongside:
		return       # (it ended this step: lost, or up alongside)
	_take(r, fight)
	if send:
		_fight_state.rpc(r.index, r.line_out, r.strain, r.bearing, r.depth, r.energy, Vector2(r.aim_pitch, r.aim_side),
				r.move, r.wear, r.stretch, r.turn_sign, r.drag, r.hold, r.reeling)


## The rod in your hands, from the mouse: its elevation (heavier going up with a fish on, dragged down by it) and how
## far it's laid over off the line (past the stop, the rest turns your look). The camera's aimed at where the line
## goes in, following the rod part of the way. Returns the side in the fight's sense (+ toward increasing bearing).
func _aim(r: Rod, me: Node, fight: Fight, delta: float, heave: bool) -> float:
	var t := r.strain
	if not is_nan(bot_aim.x):
		r.aim_pitch = clampf(bot_aim.x, 0.15, 1.35)
	elif me != null:
		var m: Vector2 = me.get("fight_mouse")
		me.set("fight_mouse", Vector2.ZERO)
		var dp := -m.y * 0.0035
		if dp > 0.0:
			dp *= 1.0 - 0.55 * t * ROD_WEIGHT
		r.aim_pitch += dp + (0.9 * delta if heave else 0.0)
		if t > 0.3:
			r.aim_pitch -= 0.35 * t * ROD_WEIGHT * delta
		r.aim_pitch = clampf(r.aim_pitch, 0.15, 1.35)
		var s := r.aim_side - m.x * 0.003
		var spill := s - clampf(s, -0.9, 0.9)
		r.aim_side = clampf(s, -0.9, 0.9)
		_look_off = clampf(_look_off + spill, -1.4, 1.4)
		_spill_t = 0.0 if absf(spill) > 0.0 else _spill_t + delta
		if _spill_t > 1.0:
			_look_off = move_toward(_look_off, 0.0, 0.8 * delta)
		if fight.slipping:
			r.aim_side = move_toward(r.aim_side, 0.0, 0.08 * t * delta)     # (a run pulls the rod round to it)
	# where the line goes, from where you stand
	var boat := sea.get("boat") as Node3D
	var p: Node3D = (sea.get("crew") as Node).call("get_player", r.holder)
	var line_yaw := 0.0
	if p != null and boat != null:
		var hands := p.global_transform * Vector3(0.2, 0.95, -0.3)
		var d := boat.global_basis.inverse() * (r.line_end - hands)
		line_yaw = atan2(-d.x, -d.z)
		if me != null and is_nan(bot_aim.x):
			# look out toward where the fish is (on the water along its bearing, no further than 30 m), not down
			# where a steep line goes in under the transom
			var head := p.global_position + Vector3.UP * 1.6
			var hd := sqrt(maxf(r.line_out * r.line_out - r.depth * r.depth, 0.0))
			var out := boat.global_transform * (stern + Vector3(sin(r.bearing), 0.0, cos(r.bearing)) * clampf(hd, 8.0, 30.0))
			out.y = boat.global_position.y
			var to := out - head
			var entry_pitch := clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.5, 0.05)
			var yaw := line_yaw + 0.4 * r.aim_side + _look_off
			var pitch := clampf(entry_pitch + 0.35 * (r.aim_pitch - 0.75), entry_pitch - 0.12, entry_pitch + 0.28)
			me.set("cam_goal", Vector2(yaw, pitch))
			me.set("rod_lease_frame", Engine.get_process_frames())
	r.set_meta("line_yaw", line_yaw)
	if not is_nan(bot_aim.x):
		r.aim_side = 0.0
		return clampf(bot_aim.y, -1.0, 1.0)
	# laid over to the left of the line pushes the fish's bearing which way, from her frame
	var left := Vector2(-cos(line_yaw), sin(line_yaw))
	var dir_b := Vector2(cos(r.bearing), -sin(r.bearing))
	var dot := left.dot(dir_b)
	return clampf(r.aim_side / 0.9, -1.0, 1.0) * (signf(dot) if absf(dot) > 0.01 else 1.0)


## Host: a fish on a rod in its holder, nobody on it. The drag still works it: it takes line on its runs and tires
## doing it, but nobody cranks or pumps, so between runs nobody wins line back and it doesn't tire.
func _fight_holder(r: Rod, delta: float, throttle: float, send: bool) -> void:
	var fight := r.fight as Fight
	if fight == null or not fight.in_holder:
		fight = _new_fight(r)
		fight.in_holder = true
	fight.throttle = throttle
	fight.moving = true
	fight.boat_vel = _boat_vel()
	fight.tangled = is_tangled(r.index)
	fight.tip = _tip_local(r)
	fight.rub_now = rub_on_hull(r)
	fight.step(delta, 0.0, 0.6, 0.0, r.drag)
	if not r.hooked or r.alongside:
		return       # (it ended this step: lost, or up alongside)
	_take(r, fight)
	if send:
		_holder_state.rpc(r.index, r.line_out, r.strain, r.bearing, r.depth, r.energy, r.move, r.wear, r.stretch,
				r.turn_sign, r.drag, r.hold)


## The fight for rod r, picked up from where it is (whoever had it, or its holder): the same fish, as tired as it
## was, doing what it was doing.
func _new_fight(r: Rod) -> Fight:
	var f := Fight.new(r.fish_kg, r.line_out, r.energy, int(r.get_meta("seed", 0)) + int(r.free_t))
	f.bearing = r.bearing
	f.depth = r.depth
	f.wear = r.wear
	f.carry_on(r.move, r.stretch, r.turn_sign, r.hold)
	f.half_beam = _half_beam
	f.aft = _aft
	f.house = _house
	f.fore = _fore
	f.from = stern.z
	# the gear she's got from the dock
	var hold: Node = sea.get("fish_hold")
	if hold:
		f.crank_mul = 1.25 if bool(hold.call("has_gear", "reel")) else 1.0
		f.chafe_mul = 1.5 if bool(hold.call("has_gear", "line")) else 1.0
		f.grace_add = 0.6 if bool(hold.call("has_gear", "line")) else 0.0
	f.lost.connect(func(how: String) -> void: _end_mine(r, how))
	f.boatside.connect(func() -> void: _end_mine(r, "boatside"))
	r.fight = f
	return f


func _take(r: Rod, fight: Fight) -> void:
	r.wear = fight.wear
	r.line_out = fight.line_out
	r.strain = clampf(fight.strain + 0.5 * fight.shock, 0.0, 1.2)      # (the rod's bend: the tension, and a jolt)
	r.bearing = fight.bearing
	r.depth = fight.depth
	r.energy = fight.energy
	r.move = fight.move
	r.stretch = fight.stretch
	r.hold = fight.hold
	r.reeling = fight.wind
	r.grinding = fight.grinding
	r.turn_sign = fight.turn_sign()


## Her velocity in her own frame (x across, z astern: her bow's -z), for the fight.
func _boat_vel() -> Vector2:
	var helm: Node = (sea.get("boat") as Node).get("helm")
	return Vector2(0.0, -float(helm.get("speed")))


## Where rod r's fish is (world): out along its bearing from her stern, at its depth.
func fish_point(r: Rod, boat: Node3D) -> Vector3:
	var hd := sqrt(maxf(r.line_out * r.line_out - r.depth * r.depth, 0.0))
	var p := boat.global_transform * (stern + Vector3(sin(r.bearing), 0.0, cos(r.bearing)) * hd)
	p.y = boat.global_position.y - r.depth
	return p


## How hard rod r's line is rubbing on her (0..1), from the line itself against her hull: the straight line from the
## rod tip to the fish (what's drawn) ray-cast against her collision shape, in and back out, with a few lines just
## beside it (a line grazing her rail rubs too). Only where it really lies on her house or her bow: over the open
## cockpit (her rail, her transom) the angler leans out and holds the line clear, so only the part of the line forward
## of her house's aft face is cast; and a line well clear over her cabin or bow doesn't touch.
func rub_on_hull(r: Rod) -> float:
	var boat := sea.get("boat") as Node3D
	if boat == null or not boat.is_inside_tree():
		return 0.0
	var space := boat.get_world_3d().direct_space_state
	var to_her := boat.global_transform.affine_inverse()
	var tip := r.tip_position()
	var to := fish_point(r, boat)
	# the stretch of line forward of her house's aft face (her frame: her bow's -z)
	var lt := to_her * tip
	var lf := to_her * to
	var cut := _house + 0.3
	if lt.z < cut and lf.z < cut:
		pass
	elif lt.z >= cut and lf.z >= cut:
		return 0.0
	elif lt.z >= cut:
		tip = tip.lerp(to, (lt.z - cut) / (lt.z - lf.z))
	else:
		to = tip.lerp(to, (cut - lt.z) / (lf.z - lt.z))
	var along := (to - tip).normalized()
	var side := along.cross(Vector3.UP).normalized()
	if side == Vector3.ZERO:
		side = Vector3.RIGHT
	var down := side.cross(along).normalized()
	var worst := 0.0
	for off: Vector3 in [Vector3.ZERO, side * Fight.HULL_MARGIN, -side * Fight.HULL_MARGIN, -down * Fight.HULL_MARGIN]:
		var a := tip + off
		var b := to + off
		var hit_in := _hull_hit(space, boat, a, b)
		if hit_in == Vector3.INF:
			continue
		var hit_out := _hull_hit(space, boat, b, a)
		var inside := hit_in.distance_to(hit_out) if hit_out != Vector3.INF else 0.0
		worst = maxf(worst, inside + 0.25)        # (even a touch rubs a little)
	return smoothstep(0.0, Fight.RUB_ALL, worst) if worst > 0.0 else 0.0


## Where the segment a..b first meets her hull (world), or INF: other things aboard (the chair, the wheel, the rods)
## are looked through.
func _hull_hit(space: PhysicsDirectSpaceState3D, boat: Node3D, a: Vector3, b: Vector3) -> Vector3:
	var skip: Array[RID] = []
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(a, b, 1, skip)
		q.hit_back_faces = true
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return Vector3.INF
		if hit["collider"] == boat:
			return hit["position"]
		skip.append(hit["rid"])
	return Vector3.INF


## The rod tip as drawn, in her frame from above (x across, z astern): where the line to the fish starts.
func _tip_local(r: Rod) -> Vector2:
	var boat := sea.get("boat") as Node3D
	var at := boat.global_transform.affine_inverse() * r.tip_position()
	return Vector2(at.x, at.z)


func _end_mine(r: Rod, how: String) -> void:
	if Net.is_host():
		_host_end(r.index, how)
		return
	# (till the host's word comes back: alongside, or gone)
	r.fight = null
	if how == "boatside":
		r.alongside = true
	else:
		r.hooked = false
	_report_end.rpc_id(1, r.index, how)


## A rod in someone's hands: the butt at their belt, the rod out in front and up, following where they look; heaved
## up toward the sky in a pump (`lift`).
func _in_hands(p: Node3D, r: Rod) -> Transform3D:
	var b: Basis
	if r.hooked and not r.alongside:
		# with a fish on: where the angler's pointing it, off the line (every peer has the synced aim)
		var rod_yaw := float(r.get_meta("line_yaw", 0.0)) + r.aim_side
		var boat := sea.get("boat") as Node3D
		var own := wrapf(float(p.get("_yaw")), -PI, PI)
		var rel := clampf(wrapf(rod_yaw - own, -PI, PI), -1.2, 1.2) if boat != null else 0.0
		b = p.global_basis * Basis(Vector3.UP, rel) * Basis(Vector3.RIGHT, r.aim_pitch) * Basis(Vector3.UP, PI)
	else:
		var pitch := clampf(float(p.get("_pitch")), -0.6, 0.9)
		b = p.global_basis * Basis(Vector3.RIGHT, 0.55 + pitch * 0.6 + r.lift * 0.6) * Basis(Vector3.UP, PI)
	var at := p.global_transform * Vector3(0.2, 0.95, -0.3)
	return Transform3D(b.orthonormalized(), at)
