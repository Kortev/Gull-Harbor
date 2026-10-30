extends Node
## Landing a fish: from boatside to the deck. A fish fought to the boat (tuna/fight.gd's boatside) lies beaten on the
## surface, still on the line: astern of the sportfisher's transom, or along the skiff's side by her stern quarter.
## Someone sticks it with the harpoon (E on the harpoon along the port side, aim at the fish, left mouse throws, Q
## puts it back), then it's hauled aboard: through the sportfisher's tuna door in the transom, over the skiff's
## gunwale (hold E there: one person can, slowly; two or three make short work of a giant). Then it's on deck
## (boat/fish_hold.gd). Leave it alongside too long without sticking it and the hook pulls. Where all of that is comes
## from the boat's kind (boat/kinds.gd).
##
## Someone has to hold it there: the angler keeping the rod (or the wireman on the leader). Left on a rod in its
## holder it isn't held: every SHEER_EVERY s it kicks, sheers off and goes down out of reach for SHEER_FOR s, the rod
## bending over, then wallows back up. You can still stick it alone between kicks; with a mate on the rod it lies
## quiet for the harpoon. All worked out from the shared clock and who holds the rod, so every peer sees the same.
##
## The host decides (who has the harpoon, a stick, how far the haul has got) and tells everyone. A throw is judged
## on the thrower's machine (it's their aim) and the host takes their word for it.

const Tuna := preload("res://tuna/tuna.gd")
const Action := preload("res://core/action.gd")
const Sfx := preload("res://audio/sfx.gd")
const Splash := preload("res://sea/splash.gd")

## Seconds a fish lies alongside before the hook pulls, if nobody sticks it.
const HOOK_HOLDS := 90.0
## On a boat whose kind says `wire` (the sportfisher's high transom), someone has to wire the fish (E at the transom:
## grab the leader) before it can be stuck; the wire holds it this long (s), then it's thrashing free again.
const WIRE_HOLD := 15.0
## A throw: how far it reaches (m from your eyes), and how far off the fish's middle it can pass and still stick
## (times the fish's length).
const REACH := 9.0
const AIM := 0.45
const FLY := 14.0
## The haul: seconds for one person to haul a fish aboard, HAUL_BASE + kg * HAUL_PER_KG (a giant about 20 s);
## each extra hand on it adds the same again.
const HAUL_BASE := 2.0
const HAUL_PER_KG := 0.05
## How far from the door you can stand and keep hauling (m).
const HAUL_REACH := 3.5
## Not held: how often it kicks off (s), how long it's down each time (s), how far it goes out from her and down (m),
## and how fast it goes and comes back (0..1 a second). Down past half of that, the harpoon can't reach it.
const SHEER_EVERY := 9.0
const SHEER_FOR := 4.0
const SHEER_OUT := Vector2(2.2, 1.4)
const SHEER_RATE := 1.2

var sea: Node                 # sea/sea.gd
## Fish alongside, by the rod they came up on: {kg, side (1 starboard, -1 port), hook_t (sea clock), t (s alongside),
## stuck, haul (0..1), node (the Tuna)}.
var fish := {}
## Who's got the harpoon (peer id; 0: in its rack).
var harpoon_holder := 0
var _pulling := {}            # host: peer id -> the fish they're hauling
var _my_pull := -1
var _harpoon: Node3D
var _doors: Array[Action] = []      # [starboard, port]
var _rack: Action
## The boat's spots for all this (boat/kinds.gd).
var spec: Dictionary = {}
var _fly_t := 0.0
var _fly_at := Transform3D.IDENTITY
var _fly_dir := Vector3.ZERO
var _send_in := 0.0
## Host: fish whose hook clock stands still (rod index -> the peer who asked): the first fish someone ever lands,
## while ui/fight_tutor.gd walks them through it one step at a time. It never runs the other way.
var _clock_held := {}


var _splash: Splash


func _ready() -> void:
	_splash = Splash.new()
	_splash.name = "Splash"
	add_child(_splash)
	_harpoon = _make_harpoon()
	_harpoon.name = "Harpoon"
	add_child(_harpoon)
	_attach()
	(sea.get("boat") as Node).connect("rebuilt", _attach)
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_sync.rpc_id(id, harpoon_holder, _states()))
	Net.peer_left.connect(func(id: int) -> void:
		_pulling.erase(id)
		for i: int in _clock_held.keys():
			if int(_clock_held[i]) == id:
				_clock_held.erase(i)
		if Net.is_host() and harpoon_holder == id:
			_host_set_harpoon(0))
	Net.dropped.connect(func(_reason: String) -> void: _clear())
	Net.left.connect(func(was_host: bool) -> void:
		if not was_host:
			_clear()       # (those were the host's fish)
			return
		# our own boat: our fish stay; crewmates' hands come off the harpoon and the door
		if harpoon_holder != Net.my_id():
			harpoon_holder = 0
		for peer: int in _pulling.keys():
			if peer != Net.my_id():
				_pulling.erase(peer))


## The harpoon's rack and the haul spots, where her kind has them (again whenever she's rebuilt as another kind).
func _attach() -> void:
	var boat := sea.get("boat") as Node3D
	spec = boat.get("spec")
	_clear()
	for n: Node in [_rack] + _doors:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.queue_free()
	_doors.clear()
	_rack = Action.new(Vector3(0.45, 0.45, 2.5))
	_rack.name = "HarpoonRack"
	_rack.position = rack_at() + Vector3(0.0, 0.0, -0.6)
	_rack.use = func(_p: Node) -> void: _request_harpoon(true)
	_rack.prompt = func() -> String: return _rack_prompt()
	boat.add_child(_rack)
	var haul: Vector3 = spec["haul"]
	for side: float in [1.0, -1.0]:
		var door := Action.new(spec["haul_box"])
		door.name = ("TunaDoor" if bool(spec["door"]) else "Gunwale") + ("Starboard" if side > 0.0 else "Port")
		door.position = Vector3(haul.x * side, haul.y, haul.z)
		door.use = func(_p: Node) -> void: _start_pull(side)
		door.prompt = func() -> String: return _door_prompt(side)
		if bool(spec["door"]):
			door.add_child(_make_door())
		boat.add_child(door)
		_doors.append(door)


func rack_at() -> Vector3:
	return spec.get("rack", Vector3(-2.02, 1.2, 4.4))


# ------------------------------------------------------------------ what everyone sees

func _process(delta: float) -> void:
	var boat := sea.get("boat") as Node3D
	var ocean := sea.get("ocean") as Node
	var crew := sea.get("crew") as Node
	# the harpoon: flying from a throw, in someone's hands, or in its rack
	if _fly_t > 0.0:
		# (its flight in her frame: she may be under way)
		_fly_t -= delta
		_fly_at.origin += _fly_dir * FLY * delta
		_harpoon.global_transform = boat.global_transform * _fly_at
	else:
		var p: Node3D = crew.call("get_player", harpoon_holder) if harpoon_holder != 0 else null
		if p == null:
			_harpoon.global_transform = boat.global_transform * Transform3D(Basis.IDENTITY, rack_at())
		else:
			_harpoon.global_transform = _in_hands(p)
	var rods := sea.get("rods") as Node
	for i: int in fish:
		var f: Dictionary = fish[i]
		var node := f["node"] as Tuna
		# held, it lies there; not held, it kicks off and down now and then, the rod in its holder bending over
		var goal := sheer_goal(i)
		if goal > 0.5 and float(f["sheer"]) <= 0.0:
			_splash.burst(node.global_position + Vector3(0.0, 0.2, 0.0), 1.4, true)
			node.effort = 1.0
			if i < (rods.get("rods") as Array).size():
				Sfx.play_point(self, (rods.get("rods")[i] as Node3D).global_position, "dock.reel", 1.0, 1.4)
		f["sheer"] = move_toward(float(f["sheer"]), goal, delta * SHEER_RATE)
		if goal > 0.5:
			node.effort = maxf(node.effort, 0.8)
		if i < (rods.get("rods") as Array).size():
			var rod: Node = rods.get("rods")[i]
			if bool(rod.get("alongside")):
				rod.set("strain", 0.35 + 0.6 * float(f["sheer"]))
		node.global_transform = _fish_transform(f, boat, ocean)
		# not stuck yet, it's still got some kick: a tail thrashing the water now and then
		if not bool(f.get("stuck", false)) and float(f.get("haul", 0.0)) <= 0.0:
			var due := float(f.get("thrash_in", randf_range(1.0, 3.0))) - delta
			if due <= 0.0:
				due = randf_range(1.8, 4.0)
				_splash.burst(node.global_position + Vector3(0.0, 0.2, 0.0), 1.1, true)
				node.effort = 1.0
			f["thrash_in"] = due
			node.effort = move_toward(node.effort, 0.15, delta * 0.8)
	# hauling: let go of E, or walk away from the door, and you've stopped (the crosshair can drift as she rolls:
	# you're still holding the line)
	if _my_pull >= 0:
		var me := crew.get("me") as Node3D
		var f: Dictionary = fish.get(_my_pull, {})
		var door: Node3D = null
		if not f.is_empty():
			door = _doors[0 if float(f["side"]) > 0.0 else 1]
		if f.is_empty() or me == null or door == null or not Input.is_action_pressed("interact") 				or me.global_position.distance_to(door.global_position) > HAUL_REACH:
			_stop_pull()
	if Net.is_host():
		_host_tick(delta)


## Where a fish alongside is, in the water on its side of her (across the sportfisher's stern, along the skiff's side);
## hauled, it comes up aboard and rolls onto its side.
func _fish_transform(f: Dictionary, boat: Node3D, ocean: Node) -> Transform3D:
	var side := float(f["side"])
	var k := smoothstep(0.0, 1.0, float(f["haul"]))
	var w: Vector3 = spec.get("fish_water", Vector3(1.1, 0.0, 7.95))
	# (sheering off: out from her, astern of a transom or abeam of a side, and down)
	var s := smoothstep(0.0, 1.0, float(f.get("sheer", 0.0)))
	var out := Vector3(0.35 * side, 0.0, 1.0) if bool(spec.get("fish_across", true)) else Vector3(side, 0.0, 0.3)
	var water := boat.global_transform * (Vector3(w.x * side, 0.0, w.z) + out.normalized() * SHEER_OUT.x * s)
	water.y = float(ocean.call("height_at", water)) - 0.12 - SHEER_OUT.y * s
	var a: Vector3 = spec.get("fish_aboard", Vector3(1.0, 0.8, 6.22))
	var aboard := boat.global_transform * Vector3(a.x * side, a.y, a.z)
	# across her stern its head toward her middle; along her side its head forward
	var head := -boat.global_basis.x * side if bool(spec.get("fish_across", true)) else -boat.global_basis.z
	var b := Basis.looking_at(head, boat.global_basis.y) * Basis(Vector3(0, 0, 1), k * PI * 0.5)
	# (over a gunwale, not through the door: lifted up over it on the way)
	var over := float(spec.get("haul_lift", 0.0)) * sin(k * PI)
	return Transform3D(b, water.lerp(aboard, k) + boat.global_basis.y * over)


## The harpoon in someone's hands: at the shoulder, pointing where they look.
func _in_hands(p: Node3D) -> Transform3D:
	var cam := p.get("cam") as Node3D
	if cam == null:
		return p.global_transform
	return Transform3D(cam.global_basis, cam.global_transform * Vector3(0.22, -0.3, 0.1))


## Where the line from rod i goes into the fish alongside (rods.gd draws it).
func fish_point(i: int) -> Vector3:
	var f: Dictionary = fish.get(i, {})
	return (f["node"] as Node3D).global_position if not f.is_empty() else Vector3.ZERO


## What to do now, for the HUD (rods.gd shows it when you're not fighting a fish).
func hint() -> String:
	var waiting := false
	var stuck := false
	for i: int in fish:
		if bool(fish[i]["stuck"]):
			stuck = true
		else:
			waiting = true
	var unwired := false
	var wired := false
	for i: int in fish:
		if not bool(fish[i]["stuck"]) and bool(spec.get("wire", false)):
			unwired = unwired or needs_wire(i)
			wired = wired or not needs_wire(i)
	if harpoon_holder == Net.my_id():
		if waiting and unwired and not wired:
			return "Wire it first   Q put back"
		return "Click to throw   Q put back" if waiting else "Q put back"
	if waiting and (sea.get("rods") as Node).call("held_by", Net.my_id()) != null:
		# (with a mate aboard, keep it: you're holding it up for their harpoon)
		return "Hold it there" if _crew_aboard() > 1 else "Q: rod back, then the harpoon"
	if waiting and wired:
		return "Wired: harpoon it"
	if waiting and unwired:
		return "Wire it, then harpoon it"
	if waiting:
		return "Harpoon it"
	if stuck:
		return "Stuck: haul it in"
	return ""


func _rack_prompt() -> String:
	if harpoon_holder != 0:
		return ""
	if (sea.get("rods") as Node).call("held_by", Net.my_id()) != null:
		return "Q: rod back first"
	var helm: Node = (sea.get("boat") as Node).get("helm")
	if int(helm.get("captain")) == Net.my_id():
		return ""
	return "Grab the harpoon"


func _door_prompt(side: float) -> String:
	var i := _stuck_on(side)
	if i >= 0:
		return "Hold to haul  %d%%" % roundi(float(fish[i]["haul"]) * 100.0)
	var j := _waiting_on(side)
	if j >= 0:
		if needs_wire(j):
			return "Wire it"
		if bool(spec.get("wire", false)):
			return "Wired  %d s" % ceili(wire_left(j))
		return "Harpoon it first"
	return ""


## The fish alongside on that side not stuck yet (-1: none).
func _waiting_on(side: float) -> int:
	for j: int in fish:
		if not bool(fish[j]["stuck"]) and float(fish[j]["side"]) == side:
			return j
	return -1


## Whether fish i still has to be wired before it can be stuck (her kind says so, and nobody's holding the leader).
func needs_wire(i: int) -> bool:
	return bool(spec.get("wire", false)) and fish.has(i) and wire_left(i) <= 0.0


func wire_left(i: int) -> float:
	return float(fish[i].get("wired_until", -1.0)) - _now() if fish.has(i) else 0.0


## Whether fish i's held up alongside: someone on its rod, or on its leader (wired).
func held(i: int) -> bool:
	var rods: Array = (sea.get("rods") as Node).get("rods")
	return (i < rods.size() and int(rods[i].get("holder")) != 0) or wire_left(i) > 0.0


## Where fish i wants to be: 0 lying alongside, 1 sheered off and down (not held, in a kick).
func sheer_goal(i: int) -> float:
	var f: Dictionary = fish.get(i, {})
	if f.is_empty() or bool(f["stuck"]) or held(i):
		return 0.0
	var phase := fposmod(_now() - float(f["up_t"]), SHEER_EVERY)
	return 1.0 if phase >= SHEER_EVERY - SHEER_FOR else 0.0


## Whether fish i's down out of reach (of the harpoon, of a hand on the leader).
func down(i: int) -> bool:
	return fish.has(i) and float(fish[i].get("sheer", 0.0)) > 0.5


## How many of the crew are aboard this boat (with you).
func _crew_aboard() -> int:
	var crew: Node = sea.get("crew")
	var slots: Variant = crew.get("slots") if crew != null else null
	if not slots is Dictionary:
		return 1
	var n := 0
	for id: int in slots:
		if crew.call("boat_of", id) == sea.get("boat"):
			n += 1
	return maxi(n, 1)


func _now() -> float:
	return float((sea.get("ocean") as Node).get("wave_time"))


func _stuck_on(side: float) -> int:
	for i: int in fish:
		if bool(fish[i]["stuck"]) and float(fish[i]["side"]) == side:
			return i
	return -1


# ------------------------------------------------------------------ the harpoon

func _unhandled_input(event: InputEvent) -> void:
	if harpoon_holder != Net.my_id() or _fly_t > 0.0:
		return
	var me := (sea.get("crew") as Node).get("me") as Node
	if not (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (me != null and bool(me.get("force_input")))):
		return
	if event.is_action_pressed("use_primary"):
		throw()
	elif event.is_action_pressed("drop"):
		_request_harpoon(false)


## Throws the harpoon you're holding where you're looking. It sticks a fish alongside if it's on it; either way it
## comes back to its rack on its line.
func throw() -> void:
	var me := (sea.get("crew") as Node).get("me") as Node3D
	if me == null or harpoon_holder != Net.my_id():
		return
	var cam := me.get("cam") as Node3D
	var dir := -cam.global_basis.z
	var hit := aimed_at(cam.global_position, dir)
	_fly_t = 0.35
	me.call("gesture", "throw")
	Sfx.play_point(self, _harpoon.global_position, "dock.flaps", 0.8, 1.3)
	var boat := sea.get("boat") as Node3D
	_fly_at = boat.global_transform.affine_inverse() * _harpoon.global_transform
	_fly_dir = boat.global_basis.inverse() * dir
	if Net.is_host():
		_ask_throw_as(Net.my_id(), hit)
	else:
		_ask_throw.rpc_id(1, hit)


## The fish alongside a throw from `from` along `dir` would stick (-1: none): the nearest it passes close enough to.
func aimed_at(from: Vector3, dir: Vector3) -> int:
	var best := -1
	var best_along := INF
	for i: int in fish:
		var f: Dictionary = fish[i]
		if bool(f["stuck"]) or down(i):
			continue       # (stuck already, or down out of reach)
		var node := f["node"] as Tuna
		var v := node.global_position - from
		var along := v.dot(dir)
		if along < 0.3 or along > REACH:
			continue
		if (v - dir * along).length() < node.length * AIM and along < best_along:
			best = i
			best_along = along
	return best


func _request_harpoon(take: bool) -> void:
	if Net.is_host():
		_ask_harpoon_as(Net.my_id(), take)
	else:
		_ask_harpoon.rpc_id(1, take)


@rpc("any_peer", "call_remote", "reliable")
func _ask_harpoon(take: bool) -> void:
	_ask_harpoon_as(multiplayer.get_remote_sender_id(), take)


func _ask_harpoon_as(who: int, take: bool) -> void:
	if not take:
		if harpoon_holder == who:
			_host_set_harpoon(0)
		return
	if harpoon_holder != 0:
		return
	if (sea.get("rods") as Node).call("held_by", who) != null:
		return        # (your hands are full)
	var helm: Node = (sea.get("boat") as Node).get("helm")
	if int(helm.get("captain")) == who:
		return        # (and the captain's are on the wheel)
	_host_set_harpoon(who)


func _host_set_harpoon(who: int) -> void:
	if Net.in_session():
		_set_harpoon.rpc(who)
	else:
		_set_harpoon(who)


@rpc("authority", "call_local", "reliable")
func _set_harpoon(who: int) -> void:
	harpoon_holder = who


@rpc("any_peer", "call_remote", "reliable")
func _ask_throw(i: int) -> void:
	_ask_throw_as(multiplayer.get_remote_sender_id(), i)


func _ask_throw_as(who: int, i: int) -> void:
	if who != harpoon_holder:
		return
	_host_set_harpoon(0)
	if fish.has(i) and not bool(fish[i]["stuck"]) and needs_wire(i):
		if Net.in_session():
			_missed.rpc(who, "Wire it first")
		else:
			_missed(who, "Wire it first")
	elif fish.has(i) and not bool(fish[i]["stuck"]):
		if Net.in_session():
			_stuck.rpc(i)
		else:
			_stuck(i)
		(sea.get("rods") as Node).call("host_off", i, "Stuck!")
	elif Net.in_session():
		_missed.rpc(who, "Missed")
	else:
		_missed(who, "Missed")


@rpc("authority", "call_local", "reliable")
func _stuck(i: int) -> void:
	if not fish.has(i):
		return
	var f: Dictionary = fish[i]
	f["stuck"] = true
	var node := f["node"] as Tuna
	node.effort = 0.08
	Sfx.play_point(self, node.global_position, "collar.thump", 1.0, 0.8)
	# the dart in its back, and the float on its line
	var dart := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.012
	shaft.bottom_radius = 0.012
	shaft.height = 0.5
	dart.mesh = shaft
	dart.position = Vector3(0.0, node.length * 0.12, 0.0)
	dart.rotation = Vector3(0.4, 0.0, 0.0)
	dart.material_override = _flat(Color(0.35, 0.33, 0.3))
	node.add_child(dart)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 8
	sphere.rings = 4
	ball.mesh = sphere
	ball.position = Vector3(0.4, 0.1, 0.5)
	ball.material_override = _flat(Color(1.0, 0.45, 0.1))
	node.add_child(ball)


@rpc("authority", "call_local", "reliable")
func _missed(who: int, why: String) -> void:
	if who == Net.my_id():
		_note(why)


# ------------------------------------------------------------------ the haul

func _start_pull(side: float) -> void:
	var i := _stuck_on(side)
	if i < 0:
		# not stuck yet: on a boat that wants it, E here wires it (grabs the leader)
		var j := _waiting_on(side)
		if j >= 0 and needs_wire(j) and not down(j):
			if Net.is_host():
				_ask_wire_as(j)
			else:
				_ask_wire.rpc_id(1, j)
		return
	_my_pull = i
	if Net.is_host():
		_ask_pull_as(Net.my_id(), i)
	else:
		_ask_pull.rpc_id(1, i)


func _stop_pull() -> void:
	_my_pull = -1
	if Net.is_host():
		_ask_pull_as(Net.my_id(), -1)
	else:
		_ask_pull.rpc_id(1, -1)


@rpc("any_peer", "call_remote", "reliable")
func _ask_wire(i: int) -> void:
	_ask_wire_as(i)


func _ask_wire_as(i: int) -> void:
	if not fish.has(i) or bool(fish[i]["stuck"]):
		return
	var until := _now() + WIRE_HOLD
	if Net.in_session():
		_wired.rpc(i, until)
	else:
		_wired(i, until)


@rpc("authority", "call_local", "reliable")
func _wired(i: int, until: float) -> void:
	if fish.has(i):
		fish[i]["wired_until"] = until
		Sfx.play_point(self, (fish[i]["node"] as Node3D).global_position, "kit.chain")


@rpc("any_peer", "call_remote", "reliable")
func _ask_pull(i: int) -> void:
	_ask_pull_as(multiplayer.get_remote_sender_id(), i)


func _ask_pull_as(who: int, i: int) -> void:
	if i < 0 or not fish.has(i) or not bool(fish[i]["stuck"]):
		_pulling.erase(who)
	else:
		_pulling[who] = i


## How many are hauling on fish i right now (host).
func hands_on(i: int) -> int:
	var n := 0
	for peer: int in _pulling:
		if int(_pulling[peer]) == i:
			n += 1
	return n


func _host_tick(delta: float) -> void:
	_send_in -= delta
	var send := _send_in <= 0.0 and Net.in_session()
	if send:
		_send_in = 0.1
	for i: int in fish.keys():
		var f: Dictionary = fish[i]
		if not _clock_held.has(i):
			f["t"] = float(f["t"]) + delta
		if not bool(f["stuck"]):
			if float(f["t"]) > HOOK_HOLDS:
				_host_gone(i, "The hook pulled")
			continue
		var hands := hands_on(i)
		if hands == 0:
			continue
		f["haul"] = minf(float(f["haul"]) + delta * hands / (HAUL_BASE + float(f["kg"]) * HAUL_PER_KG), 1.0)
		if float(f["haul"]) >= 1.0:
			_host_aboard(i)
		elif send:
			_haul_state.rpc(i, float(f["haul"]))


@rpc("authority", "call_remote", "unreliable_ordered")
func _haul_state(i: int, haul: float) -> void:
	if fish.has(i):
		fish[i]["haul"] = haul


## The hook clock on fish i held still (`on`) or let run again: asked of the host by whoever's being shown how to land
## their first fish (ui/fight_tutor.gd).
func hold_clock(i: int, on: bool) -> void:
	if Net.is_host():
		_ask_hold_as(Net.my_id(), i, on)
	else:
		_ask_hold.rpc_id(1, i, on)


@rpc("any_peer", "call_remote", "reliable")
func _ask_hold(i: int, on: bool) -> void:
	_ask_hold_as(multiplayer.get_remote_sender_id(), i, on)


func _ask_hold_as(who: int, i: int, on: bool) -> void:
	if on and fish.has(i):
		_clock_held[i] = who
	elif not on and int(_clock_held.get(i, -1)) == who:
		_clock_held.erase(i)


# ------------------------------------------------------------------ comes alongside, comes aboard, gets away

## Host: rod i's fish is beaten and up alongside (rods.gd, when its fight comes boatside).
func host_alongside(i: int, kg: float, bearing: float, hook_t: float) -> void:
	var side := 1.0 if sin(bearing) >= 0.0 else -1.0
	if Net.in_session():
		_alongside.rpc(i, kg, side, hook_t)
	else:
		_alongside(i, kg, side, hook_t)


@rpc("authority", "call_local", "reliable")
func _alongside(i: int, kg: float, side: float, hook_t: float) -> void:
	_add(i, kg, side, hook_t)


## A fish up alongside, off rod i. `on_rod`: still on the line (not yet stuck), so the rod shows it.
func _add(i: int, kg: float, side: float, hook_t: float, on_rod := true) -> void:
	_drop(i)
	var node := Tuna.new(kg)
	node.name = "Alongside%d" % i
	node.posed = true
	node.effort = 0.35
	add_child(node)
	fish[i] = {"kg": kg, "side": side, "hook_t": hook_t, "t": 0.0, "stuck": false, "haul": 0.0, "node": node,
			"wired_until": -1.0, "up_t": _now(), "sheer": 0.0}
	if on_rod:
		(sea.get("rods") as Node).call("set_alongside", i)


func _host_aboard(i: int) -> void:
	var f: Dictionary = fish[i]
	var now := float((sea.get("ocean") as Node).get("wave_time"))
	(sea.get("fish_hold") as Node).call("host_add", float(f["kg"]), now - float(f["hook_t"]))
	for peer: int in _pulling.keys():
		if int(_pulling[peer]) == i:
			_pulling.erase(peer)
	if Net.in_session():
		_aboard.rpc(i)
	else:
		_aboard(i)


@rpc("authority", "call_local", "reliable")
func _aboard(i: int) -> void:
	if _my_pull == i:
		_my_pull = -1
	if fish.has(i):
		Sfx.play_point(self, (fish[i]["node"] as Node3D).global_position, "dock.slap", 1.0, 0.7)
	_drop(i)


## Host, heading in: whatever's alongside is cut loose.
func host_clear() -> void:
	for i: int in fish.keys():
		_host_gone(i, "")


func _host_gone(i: int, why: String) -> void:
	(sea.get("rods") as Node).call("host_off", i, why)
	if Net.in_session():
		_gone.rpc(i)
	else:
		_gone(i)


@rpc("authority", "call_local", "reliable")
func _gone(i: int) -> void:
	_drop(i)


func _drop(i: int) -> void:
	_clock_held.erase(i)
	if fish.has(i):
		var n := fish[i]["node"] as Node
		if is_instance_valid(n):
			n.queue_free()
		fish.erase(i)
	if _my_pull == i:
		_my_pull = -1


func _clear() -> void:
	for i: int in fish.keys():
		_drop(i)
	_clock_held.clear()
	harpoon_holder = 0
	_pulling.clear()
	_my_pull = -1


func _states() -> Array:
	var out := []
	for i: int in fish:
		var f: Dictionary = fish[i]
		out.append([i, f["kg"], f["side"], f["hook_t"], f["t"], f["stuck"], f["haul"], f.get("wired_until", -1.0),
				f.get("up_t", 0.0)])
	return out


## A late joiner: the harpoon, and every fish alongside.
@rpc("authority", "call_remote", "reliable")
func _sync(holder: int, states: Array) -> void:
	_clear()
	harpoon_holder = holder
	for s: Array in states:
		var i := int(s[0])
		_add(i, float(s[1]), float(s[2]), float(s[3]), not bool(s[5]))
		fish[i]["t"] = float(s[4])
		fish[i]["haul"] = float(s[6])
		fish[i]["wired_until"] = float(s[7]) if s.size() > 7 else -1.0
		if s.size() > 8:
			fish[i]["up_t"] = float(s[8])      # (kicking off when the host's does)
		if bool(s[5]):
			_stuck(i)


# ------------------------------------------------------------------ odds and ends

func _note(text: String) -> void:
	if text.is_empty():
		return
	var crew := sea.get("crew") as Node
	(crew.get("hud") as Node).call("notify", text)


## The harpoon: a long wooden pole with a steel dart, pointing along -Z, held a little behind its middle.
func _make_harpoon() -> Node3D:
	var root := Node3D.new()
	var pole := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.022
	shaft.bottom_radius = 0.026
	shaft.height = 2.4
	shaft.radial_segments = 6
	pole.mesh = shaft
	pole.rotation = Vector3(-PI * 0.5, 0.0, 0.0)      # (the cylinder's +Y to -Z)
	pole.position = Vector3(0.0, 0.0, -0.6)
	pole.material_override = _flat(Color(0.52, 0.4, 0.26))
	root.add_child(pole)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.04
	cone.height = 0.24
	cone.radial_segments = 6
	tip.mesh = cone
	tip.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	tip.position = Vector3(0.0, 0.0, -1.92)
	tip.material_override = _flat(Color(0.62, 0.64, 0.66))
	root.add_child(tip)
	return root


## The tuna door: a hinged panel in the transom's inside face (a frame round it), facing forward into the cockpit.
func _make_door() -> Node3D:
	var root := Node3D.new()
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.74, 0.64, 0.015)
	frame.mesh = fm
	frame.position = Vector3(0.0, 0.0, 0.06)
	frame.material_override = _flat(Color(0.32, 0.33, 0.32))
	root.add_child(frame)
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.66, 0.56, 0.02)
	panel.mesh = pm
	panel.position = Vector3(0.0, 0.0, 0.05)
	panel.material_override = _flat(Color(0.7, 0.71, 0.66))
	root.add_child(panel)
	return root


static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m
