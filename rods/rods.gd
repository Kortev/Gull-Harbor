extends Node3D
## The spread: the boat's rods in their holders (boat/kinds.gd: the skiff's two aft corners, the sportfisher's four),
## each with its bait out astern. Who holds which rod is the host's call: E on a rod asks it (request_grab), Q puts the one you
## hold back (request_return); the answer comes to every peer (_set_holder). A rod in someone's hands rides on
## them, its butt in their belt and the blank up ahead of them.
##
## The baits go out by hand. She heads out with every line in and a bait on each hook. Pick a rod up (E), hold left
## mouse to wind up and let go to cast: the bait flies out where you're looking, as far as you wound it, and lands
## with a splash; then drop the rod back in its holder (Q) and it trolls from there, swinging in behind her as she
## goes. With its line out, holding left mouse winds it back in. A fish takes the bait off the hook: hold a bait (the
## hotbar) and E on a rod to put a fresh one on (a live mackerel while the well has one), and cast it again.

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
		"chafed": "The line wore through on the hull! It swung round over her bow: take it to that corner, or swing her stern to it.",
		"cut": "It went under the boat: the props cut the line! Out of gear when it's under her.",
		"tangle": "The lines tangled and sawed through! Clear the other lines when a fish is on (E on each rod)."}
## While a fish is on, how often (s) the host looks for its run crossing another line that's still out, and the
## chance each time it does that tangles them.
const TANGLE_EVERY := 1.0
const TANGLE_CHANCE := 0.2
## A bait out goes off: washed out, chewed by little fish, swimming tired (s till it's no good: a dead bait, a live
## mackerel); worse than STALE and it's worth putting a fresh one on (its colour's going). A fresh live bait gets
## LIVE_BITES times the bites; a washed-out one a quarter of a fresh one's.
const BAIT_LIFE := 300.0
const LIVE_LIFE := 600.0
const STALE := 0.5
const LIVE_BITES := 1.5
## A cast: how long to wind it all the way up (s), how far it goes from a flick to everything you've got (m), how high
## it arcs for each metre out, and how fast it flies (m/s, plus a moment to leave the tip). Winding a line in takes
## REEL_IN s of holding left mouse.
const WIND := 1.1
const CAST := Vector2(10.0, 55.0)
const ARC := 0.12
const FLY := 34.0
const REEL_IN := 1.4
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
var _tangle_in := 0.0
var _splash: Splash
## Your rod with no fish on: how long you've held left mouse winding its line in, and whether you've let go since
## (a cast starts on a fresh press, not the end of winding in).
var _reel_hold := 0.0
var _fresh_press := false
var _whoosh: AudioStreamPlayer3D


func _ready() -> void:
	_splash = Splash.new()
	_splash.name = "Splash"
	add_child(_splash)
	_whoosh = AudioStreamPlayer3D.new()
	_whoosh.stream = preload("res://audio/fish/whoosh.wav")
	_whoosh.unit_size = 5.0
	_whoosh.top_level = true
	add_child(_whoosh)
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
		r.spot = baits[i]
		r.land = baits[i]
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
	# an empty rod while a fish is on: E clears its line (reels it in)
	if not rods[i].hooked and rods[i].holder == 0 and fighting():
		if not rods[i].bait_in:
			_host_line(i, true)
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


## A fresh bait on rod i (E on it with a bait in your hands): its line comes in if it's out, and on goes a live
## mackerel from the well if there's one, else a dead bait. Then it wants casting.
func request_bait(i: int) -> void:
	if Net.is_host():
		_ask_bait(i)
	else:
		_ask_bait.rpc_id(1, i)


@rpc("any_peer", "call_remote", "reliable")
func _ask_bait(i: int) -> void:
	if i < 0 or i >= rods.size() or rods[i].hooked or rods[i].holder != 0 or fighting():
		return
	var hold: Node = sea.get("fish_hold")
	if hold != null and bool(hold.get("docked")):
		return
	var live := hold != null and bool(hold.call("host_take_live"))
	if Net.in_session():
		_baited.rpc(i, _now(), live)
	else:
		_baited(i, _now(), live)


@rpc("authority", "call_local", "reliable")
func _baited(i: int, t: float, live: bool) -> void:
	if i < 0 or i >= rods.size():
		return
	var r := rods[i]
	if not r.bait_in:
		Sfx.play_point(self, r.global_position, "dock.reel", 0.9, 1.2)
	r.bait_in = true
	r.tangled = -1
	r.baited = true
	r.baited_t = t
	r.live = live
	Sfx.play_point(self, r.tip_position(), "dock.slap", 0.4, 1.7)


## Cast rod i (yours, its line in) so its bait lands at `land` (boat-local). The host says it went (_cast).
func request_cast(i: int, land: Vector3) -> void:
	if Net.is_host():
		_ask_cast(i, land)
	else:
		_ask_cast.rpc_id(1, i, land)


@rpc("any_peer", "call_remote", "reliable")
func _ask_cast(i: int, land: Vector3) -> void:
	if i < 0 or i >= rods.size():
		return
	var r := rods[i]
	if r.holder != _sender() or r.hooked or not r.bait_in:
		return
	host_cast(i, land)


## Host: rod i's bait out, landing at `land` (boat-local; INF: its place in her spread, as the tests put it).
func host_cast(i: int, land := Vector3.INF) -> void:
	if land == Vector3.INF:
		land = baits[i]
	if Net.in_session():
		_cast.rpc(i, land, _now())
	else:
		_cast(i, land, _now())


@rpc("authority", "call_local", "reliable")
func _cast(i: int, land: Vector3, t: float) -> void:
	if i < 0 or i >= rods.size():
		return
	var r := rods[i]
	r.cast_from = r.tip_position()
	r.bait_in = false
	r.tangled = -1
	r.land = land
	r.cast_t = t
	r.whip = 1.0
	r.wind = 0.0
	r.bait_p = Vector3.INF
	# where it trolls from: as far back as it went, on the side it went (she drags it round behind her)
	var off := Vector2(land.x - stern.x, land.z - stern.z)
	var x := clampf(land.x, -25.0, 25.0)
	r.spot = Vector3(x, 0.0, stern.z + sqrt(maxf(off.length_squared() - x * x, 100.0)))
	_whoosh.global_position = r.cast_from
	_whoosh.pitch_scale = randf_range(0.9, 1.1)
	_whoosh.play()


## How long rod i's cast flies (s), and whether it's still in the air.
func fly_time(i: int) -> float:
	var r := rods[i]
	return 0.25 + Vector2(r.land.x - stern.x, r.land.z - stern.z).length() / FLY


func flying(i: int) -> bool:
	if i < 0 or i >= rods.size():
		return false
	var r := rods[i]
	return not r.bait_in and _now() - r.cast_t < fly_time(i)


## Your hands winding a cast up (sent to the others ten times a second while you do).
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _wind_state(i: int, wind: float) -> void:
	if i >= 0 and i < rods.size() and rods[i].holder == multiplayer.get_remote_sender_id():
		rods[i].wind = wind


## Your rod, nothing on it: left mouse winds the line in if it's out; with it in, hold to wind up and let go to cast.
func _handle_mine(r: Rod, delta: float, send: bool) -> void:
	var me := (sea.get("crew") as Node).get("me") as Node3D
	var live := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (me != null and bool(me.get("force_input")))
	var held := live and Input.is_action_pressed("use_primary")
	if not held:
		_fresh_press = true
	if not r.bait_in:
		r.wind = 0.0
		_reel_hold = _reel_hold + delta if held and not flying(r.index) else 0.0
		r.reeling = Fight.CRANK if _reel_hold > 0.0 else 0.0
		if _reel_hold >= REEL_IN:
			_reel_hold = 0.0
			_fresh_press = false
			request_reel_in(r.index)
		return
	r.reeling = 0.0
	if held and _fresh_press:
		r.wind = minf(r.wind + delta / WIND, 1.0)
	elif r.wind > 0.0:
		cast_mine(r.wind)
	if send and r.wind > 0.0:
		_wind_state.rpc(r.index, r.wind)


## Lets your cast go, wound up `power` (0..1): where you're looking, out over the water (tests call it too).
func cast_mine(power: float) -> void:
	var me := (sea.get("crew") as Node).get("me") as Node3D
	var r := held_by(Net.my_id())
	if me == null or r == null or not r.bait_in or r.hooked:
		return
	var cam := me.get("cam") as Camera3D
	var look := -cam.global_basis.z
	var flat := Vector3(look.x, 0.0, look.z)
	if flat.length() < 0.05:
		flat = -me.global_basis.z
	var tip := r.tip_position()
	var at := tip + flat.normalized() * lerpf(CAST.x, CAST.y, clampf(power, 0.0, 1.0))
	var boat := sea.get("boat") as Node3D
	var land := boat.global_transform.affine_inverse() * at
	land.y = 0.0
	r.wind = 0.0
	_fresh_press = false
	me.call("gesture", "cast")
	request_cast(r.index, land)


## Winds your rod's line in (no fish on it): the bait comes back to the tip.
func request_reel_in(i: int) -> void:
	if Net.is_host():
		_ask_reel_in(i)
	else:
		_ask_reel_in.rpc_id(1, i)


@rpc("any_peer", "call_remote", "reliable")
func _ask_reel_in(i: int) -> void:
	if i >= 0 and i < rods.size() and rods[i].holder == _sender() and not rods[i].hooked and not rods[i].bait_in:
		_host_line(i, true)


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


## Host: rod i's line reeled in (cleared: no bait out, any tangle off it). (`reel_in` false: cast back to its place
## in the spread, for the tests.)
func _host_line(i: int, reel_in: bool) -> void:
	if not reel_in:
		host_cast(i)
		return
	if Net.in_session():
		_line.rpc(i)
	else:
		_line(i)


@rpc("authority", "call_local", "reliable")
func _line(i: int) -> void:
	if i < 0 or i >= rods.size():
		return
	var r := rods[i]
	if r.tangled >= 0:
		_hud_note("Cleared the %s line!" % _name_of(i))
	if not r.bait_in:
		Sfx.play_point(self, r.global_position, "dock.reel", 0.9, 1.2)
	r.bait_in = true
	r.tangled = -1


## How good rod i's bait still is, 1 (just on) .. 0 (washed out).
func freshness(i: int) -> float:
	if i < 0 or i >= rods.size():
		return 0.0
	var r := rods[i]
	return clampf(1.0 - (_now() - r.baited_t) / (LIVE_LIFE if r.live else BAIT_LIFE), 0.0, 1.0)


## How readily rod i's bait gets eaten (tuna/schools.gd), against a fresh dead bait's 1 (none in, flying or bare).
func bite_odds(i: int) -> float:
	if i < 0 or i >= rods.size() or rods[i].bait_in or not rods[i].baited or flying(i):
		return 0.0
	return (0.25 + 0.75 * freshness(i)) * (LIVE_BITES if rods[i].live else 1.0)


## For the HUD while nothing else wants doing (the baits show it themselves: nothing).
func hint() -> String:
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


## Host, while a fish is on: its run crossing a line that's still out tangles them now and then.
func _host_lines(delta: float) -> void:
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
			var bait := b.spot - stern
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
	var bait := r.spot - stern
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
	r.baited = false       # (it's in the fish)
	r.fish_kg = kg
	r.hook_t = t
	r.bearing = bearing
	r.depth = 2.0
	r.energy = 1.0
	r.move = "run"
	r.line_out = (r.spot - stern).length()
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
	r.bait_in = true       # (what's left of the line wound in: a bare hook)
	r.baited = false
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


## Host, heading out: every line in, a fresh bait on every hook, for the crew to cast.
func host_baits_out() -> void:
	for r in rods:
		if r.hooked:
			continue
		_host_line(r.index, true)
		if Net.in_session():
			_baited.rpc(r.index, _now(), false)
		else:
			_baited(r.index, _now(), false)


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
		if st.size() > 18:
			r.baited = bool(st[15])
			r.spot = st[16]
			r.land = st[17]
			r.cast_t = float(st[18])


func _states() -> Array:
	var out := []
	for r in rods:
		out.append([r.holder, r.hooked, r.fish_kg, r.line_out, r.bearing, r.depth, r.energy, r.free_t, r.wear, r.move,
				r.alongside, r.bait_in, r.tangled, r.baited_t, r.live, r.baited, r.spot, r.land, r.cast_t])
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
			if r.holder == me and me != 0:
				_handle_mine(r, delta, send)
			elif r.holder == 0:
				r.wind = 0.0
			if flying(r.index):
				r.reeling = FLY * 0.3       # (line peeling off the reel)
		r.whip = move_toward(r.whip, 0.0, delta * 3.0)
		var p: Node3D = crew.call("get_player", r.holder) if r.holder != 0 else null
		if p == null:
			# in its holder: the holder's tube, the butt down in it
			var ht: Transform3D = boat.call("holder_transform", holders[r.index])
			r.global_transform = ht.translated_local(Vector3(0, 0, -0.42))
		else:
			r.global_transform = _in_hands(p, r.lift, r.wind, r.whip)
		var end := boat.global_transform * r.spot
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
		elif flying(r.index):
			# the cast: up off the tip and out in an arc, down to where it lands, with a splash
			var k := clampf((_now() - r.cast_t) / fly_time(r.index), 0.0, 1.0)
			var to := boat.global_transform * r.land
			to.y = float(ocean.call("height_at", to))
			end = r.cast_from.lerp(to, k)
			end.y += r.cast_from.distance_to(to) * ARC * 4.0 * k * (1.0 - k)
			r.bait_p = to
			r.bait_v = Vector3.ZERO
			r.set_meta("splash", true)
		else:
			if r.get_meta("splash", false):
				r.set_meta("splash", false)
				_splash.burst(r.bait_p, 0.45)
			end = _tow(r, end, float(helm.get("speed")), ocean, delta)
		if r.hooked or r.bait_in or tangled_in:
			r.bait_p = Vector3.INF       # (out again, it starts from where it lands)
			r.slack = 0.0
		elif flying(r.index):
			r.slack = 0.25
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
	fight.tip = _tip_local(r)
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
	fight.tip = _tip_local(r)
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
## up toward the sky in a pump (`lift`), swung back over the shoulder winding up a cast (`wind`) and whipped down
## through it (`whip`).
func _in_hands(p: Node3D, lift: float, wind := 0.0, whip := 0.0) -> Transform3D:
	var pitch := clampf(float(p.get("_pitch")), -0.6, 0.9)
	var swing := sin(whip * PI) * 0.9
	var b := p.global_basis * Basis(Vector3.FORWARD, -wind * 0.5) \
			* Basis(Vector3.RIGHT, 0.55 + pitch * 0.6 + lift * 0.6 + wind * 0.9 - swing) * Basis(Vector3.UP, PI)
	var at := p.global_transform * Vector3(0.2 + wind * 0.25, 0.95 + wind * 0.1, -0.3 + wind * 0.2)
	return Transform3D(b.orthonormalized(), at)
