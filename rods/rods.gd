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
const WHY := {"broke": "The line parted! Too much strain: when the ring goes red, ease off.",
		"pulled": "Pulled the hook! Keep the line tight through its headshakes.",
		"spooled": "Spooled! It took every metre of line. Don't crank against a run; back down on it.",
		"chafed": "The line wore through on the hull! It swung forward of her side: take it to that corner, or swing her stern to it.",
		"cut": "It went under the boat: the props cut the line! Out of gear when it's under her.",
		"tangle": "The lines tangled and sawed through! Clear the other lines when a fish is on (E on each rod)."}
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
var _send_in := 0.0
var _last_heading := 0.0
## Your rod's line out last frame, and how fast you're winning it back (m/s, smoothed; - while it takes line).
var _trend_out := -1.0
var _trend := 0.0
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
	r.wrong = 0.0
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
func _fight_state(i: int, out: float, strain: float, bearing: float, depth: float, energy: float, lift: float,
		move: String, wear: float, wrong: float, turn: float) -> void:
	if i < 0 or i >= rods.size():
		return        # (a rod she hasn't got: a word from before she was rebuilt)
	var r := rods[i]
	if r.holder == multiplayer.get_remote_sender_id() and r.hooked and not r.alongside:
		r.line_out = out
		r.strain = strain
		r.bearing = bearing
		r.depth = depth
		r.energy = energy
		r.lift = lift
		r.move = move
		r.wear = wear
		r.wrong = wrong
		r.turn_sign = turn


## The host's word on a fish on a rod in its holder (nobody holding it: the host plays it against the drag).
@rpc("authority", "call_remote", "unreliable_ordered")
func _holder_state(i: int, out: float, strain: float, bearing: float, depth: float, energy: float, move: String,
		wear: float, wrong: float, turn: float) -> void:
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
		r.wrong = wrong
		r.turn_sign = turn


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
	r.wrong = 0.0


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
			r.global_transform = _in_hands(p, r.lift)
		var end := boat.global_transform * baits[r.index]
		var tangled_in := r.tangled >= 0 and r.tangled < rods.size()
		var alongside: Vector3 = landing.call("fish_point", r.index) if r.alongside else Vector3.ZERO
		if r.alongside and alongside != Vector3.ZERO:
			end = alongside      # (straight to the fish lying astern)
		elif r.hooked:
			# where the line goes in: toward the fish, closer to the boat the deeper it is (a straight line down)
			var hd := sqrt(maxf(r.line_out * r.line_out - r.depth * r.depth, 0.0))
			var entry := hd * 2.5 / (2.5 + r.depth * 0.5)
			end = boat.global_transform * (stern + Vector3(sin(r.bearing), 0.0, cos(r.bearing)) * entry)
			end.y = ocean.call("height_at", end)
		elif tangled_in:
			end = rods[r.tangled].line_end      # (across the running fish's line)
		elif r.bait_in:
			end = r.tip_position() + Vector3(0.0, -0.3, 0.0)     # (reeled in: just the leader hanging)
		else:
			end = _tow(r, end, float(helm.get("speed")), ocean, delta)
		if r.hooked or r.bait_in or tangled_in:
			r.bait_p = Vector3.INF       # (out again, it starts from where her spread puts it)
			r.slack = 0.0
		r.line_end = end
		_show_fish(r, boat, ocean, delta)
	var hud := crew.get("hud") as Node
	var me_node := crew.get("me") as Node
	if me_node != null:
		# the fish in your arms: harder on a run or a headshake
		var surge := 1.0 if mine != null and mine.move in ["run", "shake"] else 0.6
		me_node.set("shake", mine.strain * surge if mine != null and mine.hooked else 0.0)
	if mine != null and mine.hooked:
		# the ring is how wrong you're fighting it, not how hard it pulls (that's the rod's bend)
		var wrong := (mine.fight as Fight).strain if mine.fight != null else 0.0
		var tell: String = (mine.fight as Fight).tell() if mine.fight != null else str(Fight.TELLS.get(mine.move, ""))
		# the line out, and whether you're winning it back: the angler's sense of how it's going
		if _trend_out >= 0.0:
			var rate := (_trend_out - mine.line_out) / maxf(delta, 1e-4)
			_trend = lerpf(_trend, rate, minf(delta * 2.0, 1.0))
		_trend_out = mine.line_out
		hud.call("fight", tell, maxf(wrong, 0.02), float(me_node.get("arms")), mine.line_out, _trend, mine.energy,
				mine.wear)
	else:
		_trend_out = -1.0
		_trend = 0.0
		# nothing on in your hands: what wants doing (a fish alongside to stick and haul, one on deck to bleed)
		var todo := str(landing.call("hint"))
		if todo.is_empty():
			todo = str((sea.get("fish_hold") as Node).call("hint"))
		if todo.is_empty() and not bool((sea.get("fish_hold") as Node).get("docked")):
			todo = hint()
			var glasses: Node = sea.get("binoculars")
			if todo.is_empty() and glasses != null and int(glasses.get("used")) < 3:
				todo = "Find the birds: hold B for the binoculars, look along the horizon, left click to call a flock"
				if (sea.get("boat") as Node).get("tower") != null:
					todo = "Find the birds: climb the tower, hold B for the binoculars, left click to call a flock"
		hud.call("fight", todo, 0.0)
	# the captain's plotter: where each fish on is, round the boat
	var fish := []
	if bool(helm.call("is_mine")):
		for r in rods:
			if r.hooked and not r.alongside:
				var hd := sqrt(maxf(r.line_out * r.line_out - r.depth * r.depth, 0.0))
				var b := absf(wrapf(r.bearing, -PI, PI))
				fish.append([r.bearing, hd, smoothstep(Fight.CHAFE_FROM, Fight.CHAFE_ALL, b)])
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
	if not is_instance_valid(r.fish_node):
		var f := Tuna.new(r.fish_kg)
		f.name = "Hooked%d" % r.index
		f.top_level = true
		add_child(f)
		f.global_position = at
		r.fish_node = f
		_splash.burst(r.line_end, 1.8, true)        # (the strike)
	var fish := r.fish_node as Tuna
	fish.visible = under < 6.0
	if delta > 0.0:
		fish.velocity = (at - fish.global_position) / delta
	fish.effort = clampf(r.strain + (0.6 if r.move in ["run", "shake"] else 0.0), 0.0, 1.0)
	# the surface: a boil as it takes off, slaps in a head shake, swirls as it circles near the top
	r.splash_in -= delta
	if r.move != r.seen_move:
		if r.move == "run" and r.seen_move != "":
			_splash.burst(r.line_end, 1.3)
		r.seen_move = r.move
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


## Your rod with a fish on: you fight it here (left mouse cranks, right mouse heaves the rod up) and tell the rest.
## `throttle`: the captain's (fight.gd: backing down on it helps).
func _fight_mine(r: Rod, delta: float, throttle: float, send: bool) -> void:
	var me := (sea.get("crew") as Node).get("me") as Node
	var live := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (me != null and bool(me.get("force_input")))
	var crank := live and Input.is_action_pressed("use_primary")
	var heave := live and Input.is_action_pressed("use_secondary")
	r.lift = move_toward(r.lift, 1.0 if heave else 0.0, delta * 3.5)
	var fight := r.fight as Fight
	if fight == null or fight.in_holder:
		fight = _new_fight(r)
		if me != null:
			fight.arms = float(me.get("arms"))      # (your arms are as tired as you left them)
	fight.throttle = throttle
	fight.moving = true
	fight.boat_vel = _boat_vel()
	fight.reach = _reach(me, fight.bearing)
	fight.seated = me != null and bool(me.call("in_chair"))
	fight.tangled = is_tangled(r.index)
	fight.step(delta, crank, r.lift)
	if me != null:
		me.set("arms", fight.arms)
	if not r.hooked or r.alongside:
		return       # (it ended this step: lost, or up alongside)
	_take(r, fight)
	var ans := fight.answer()
	r.reeling = 0.0 if not crank or ans == "hold" else (Fight.CRANK * 0.2 if ans == "ease" else Fight.CRANK)
	if send:
		_fight_state.rpc(r.index, r.line_out, r.strain, r.bearing, r.depth, r.energy, r.lift, r.move, r.wear,
				r.wrong, r.turn_sign)


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
	fight.step(delta, false, 0.0)
	if not r.hooked or r.alongside:
		return       # (it ended this step: lost, or up alongside)
	_take(r, fight)
	if send:
		_holder_state.rpc(r.index, r.line_out, r.strain, r.bearing, r.depth, r.energy, r.move, r.wear, r.wrong,
				r.turn_sign)


## The fight for rod r, picked up from where it is (whoever had it, or its holder): the same fish, as tired as it
## was, doing what it was doing.
func _new_fight(r: Rod) -> Fight:
	var f := Fight.new(r.fish_kg, r.line_out, r.energy, int(r.get_meta("seed", 0)) + int(r.free_t))
	f.bearing = r.bearing
	f.depth = r.depth
	f.wear = r.wear
	f.carry_on(r.move, r.wrong, r.turn_sign)
	# the gear she's got from the dock
	var hold: Node = sea.get("fish_hold")
	if hold:
		f.crank_mul = 1.25 if bool(hold.call("has_gear", "reel")) else 1.0
		f.chafe_mul = 1.5 if bool(hold.call("has_gear", "line")) else 1.0
		f.grace_add = 0.6 if bool(hold.call("has_gear", "line")) else 0.0
		f.arms_mul = 0.67 if bool(hold.call("has_gear", "harness")) else 1.0
	f.lost.connect(func(how: String) -> void: _end_mine(r, how))
	f.boatside.connect(func() -> void: _end_mine(r, "boatside"))
	r.fight = f
	return f


func _take(r: Rod, fight: Fight) -> void:
	r.wear = fight.wear
	r.line_out = fight.line_out
	r.strain = maxf(fight.pull, fight.strain)
	r.bearing = fight.bearing
	r.depth = fight.depth
	r.energy = fight.energy
	r.move = fight.move
	r.wrong = fight.strain
	r.turn_sign = fight.turn_sign()


## Her velocity in her own frame (x across, z astern: her bow's -z), for the fight.
func _boat_vel() -> Vector2:
	var helm: Node = (sea.get("boat") as Node).get("helm")
	return Vector2(0.0, -float(helm.get("speed")))


## How far out over the fish's side the angler's got the rod, 0..1: standing aft at the rail on the side it's on.
func _reach(p: Node, bearing: float) -> float:
	if p == null:
		return 0.0
	var at: Vector3 = p.call("local_position")
	var side := 1.0 if sin(bearing) >= 0.0 else -1.0      # (+ bearing: off the starboard quarter, + x)
	var out := clampf((at.x * side - (float((sea.get("boat") as Node).get("beam")) * 0.5 - 1.5)) / 1.0, 0.0, 1.0)
	var aft := smoothstep(stern.z - 3.5, stern.z - 1.5, at.z)
	return out * aft


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
func _in_hands(p: Node3D, lift: float) -> Transform3D:
	var pitch := clampf(float(p.get("_pitch")), -0.6, 0.9)
	var b := p.global_basis * Basis(Vector3.RIGHT, 0.55 + pitch * 0.6 + lift * 0.6) * Basis(Vector3.UP, PI)
	var at := p.global_transform * Vector3(0.2, 0.95, -0.3)
	if bool(p.call("is_seated")) and not bool(p.call("is_leaning")):
		at = p.global_transform * Vector3(0.0, 0.6, -0.4)      # (sitting: in the fighting chair, the butt in its gimbal)
	return Transform3D(b.orthonormalized(), at)
