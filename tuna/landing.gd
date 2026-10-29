extends Node
## Landing a fish: from boatside to the deck. A fish fought to the boat (tuna/fight.gd's boatside) lies beaten on the
## surface just astern of the transom, still on the line. Someone sticks it with the harpoon (E on the harpoon along
## the port side, aim at the fish, left mouse throws, Q puts it back), then it's hauled in through the tuna door in
## the transom (hold E on the door: one person can, slowly; two or three make short work of a giant). Then it's on
## deck (boat/fish_hold.gd). Leave it alongside too long without sticking it and the hook pulls.
##
## The host decides (who has the harpoon, a stick, how far the haul has got) and tells everyone. A throw is judged
## on the thrower's machine (it's their aim) and the host takes their word for it.

const Tuna := preload("res://tuna/tuna.gd")
const Action := preload("res://core/action.gd")

## Seconds a fish lies alongside before the hook pulls, if nobody sticks it.
const HOOK_HOLDS := 90.0
## A throw: how far it reaches (m from your eyes), and how far off the fish's middle it can pass and still stick
## (times the fish's length).
const REACH := 9.0
const AIM := 0.45
const FLY := 14.0
## The haul: seconds for one person to haul a fish aboard, HAUL_BASE + kg * HAUL_PER_KG (a giant about 20 s);
## each extra hand on it adds the same again.
const HAUL_BASE := 2.0
const HAUL_PER_KG := 0.05
## Boat-local spots: the transom (where the lines go over), the harpoon lying in its rack along the inside of the
## port bulwark (its point forward), and the tuna doors either side of the live well.
const STERN_Z := 7.05
const RACK := Vector3(-2.02, 1.2, 4.4)
const DOOR_X := 1.0
const DOOR := Vector3(0.0, 0.95, 6.82)

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
var _fly_t := 0.0
var _fly_at := Transform3D.IDENTITY
var _fly_dir := Vector3.ZERO
var _send_in := 0.0


func _ready() -> void:
	var boat := sea.get("boat") as Node3D
	_harpoon = _make_harpoon()
	_harpoon.name = "Harpoon"
	add_child(_harpoon)
	var rack := Action.new(Vector3(0.45, 0.45, 2.5))
	rack.name = "HarpoonRack"
	rack.position = RACK + Vector3(0.0, 0.0, -0.6)
	rack.use = func(_p: Node) -> void: _request_harpoon(true)
	rack.prompt = func() -> String: return _rack_prompt()
	boat.add_child(rack)
	for side: float in [1.0, -1.0]:
		var door := Action.new(Vector3(0.8, 0.7, 0.35))
		door.name = "TunaDoor" + ("Starboard" if side > 0.0 else "Port")
		door.position = DOOR + Vector3(side * DOOR_X, 0.0, 0.0)
		door.use = func(_p: Node) -> void: _start_pull(side)
		door.prompt = func() -> String: return _door_prompt(side)
		door.add_child(_make_door())
		boat.add_child(door)
		_doors.append(door)
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_sync.rpc_id(id, harpoon_holder, _states()))
	Net.peer_left.connect(func(id: int) -> void:
		_pulling.erase(id)
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
			_harpoon.global_transform = boat.global_transform * Transform3D(Basis.IDENTITY, RACK)
		else:
			_harpoon.global_transform = _in_hands(p)
	for i: int in fish:
		var f: Dictionary = fish[i]
		(f["node"] as Node3D).global_transform = _fish_transform(f, boat, ocean)
	# hauling: let go of E, or look away from the door, and you've stopped
	if _my_pull >= 0:
		var me := crew.get("me") as Node
		var f: Dictionary = fish.get(_my_pull, {})
		var door: Node = null
		if not f.is_empty():
			door = _doors[0 if float(f["side"]) > 0.0 else 1]
		if f.is_empty() or me == null or not Input.is_action_pressed("interact") or me.call("looking_at") != door:
			_stop_pull()
	if Net.is_host():
		_host_tick(delta)


## Where a fish alongside is: across the stern on its side of her, in the water; hauled, it comes up through the
## tuna door and rolls onto its side.
func _fish_transform(f: Dictionary, boat: Node3D, ocean: Node) -> Transform3D:
	var side := float(f["side"])
	var k := smoothstep(0.0, 1.0, float(f["haul"]))
	var water := boat.global_transform * Vector3(side * 1.1, 0.0, STERN_Z + 0.9)
	water.y = float(ocean.call("height_at", water)) - 0.12
	var door := boat.global_transform * (DOOR + Vector3(side * DOOR_X, -0.15, -0.6))
	var head := -boat.global_basis.x * side        # (its head toward her middle)
	var b := Basis.looking_at(head, boat.global_basis.y) * Basis(Vector3(0, 0, 1), k * PI * 0.5)
	return Transform3D(b, water.lerp(door, k))


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
	if harpoon_holder == Net.my_id():
		return "Aim at the fish, left mouse throws  (Q puts it back)" if waiting else "Q puts the harpoon back"
	if waiting and (sea.get("rods") as Node).call("held_by", Net.my_id()) != null:
		return "Boatside! Q puts the rod back, then grab the harpoon (port side)"
	if waiting:
		return "Boatside! Stick it: the harpoon's along the port side"
	if stuck:
		return "Stuck! Haul it in: hold E on the tuna door"
	return ""


func _rack_prompt() -> String:
	if harpoon_holder != 0:
		return ""
	if (sea.get("rods") as Node).call("held_by", Net.my_id()) != null:
		return "Put the rod back first (Q)"
	var helm: Node = (sea.get("boat") as Node).get("helm")
	if int(helm.get("captain")) == Net.my_id():
		return ""
	return "Grab the harpoon"


func _door_prompt(side: float) -> String:
	var i := _stuck_on(side)
	if i >= 0:
		return "Hold to haul it aboard (%d%%)" % roundi(float(fish[i]["haul"]) * 100.0)
	for j: int in fish:
		if float(fish[j]["side"]) == side:
			return "Stick it first (the harpoon)"
	return ""


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
		if bool(f["stuck"]):
			continue
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
	if fish.has(i) and not bool(fish[i]["stuck"]):
		if Net.in_session():
			_stuck.rpc(i)
		else:
			_stuck(i)
		(sea.get("rods") as Node).call("host_off", i, "Stuck! Now haul it in: hold E on the tuna door")
	elif Net.in_session():
		_missed.rpc(who)
	else:
		_missed(who)


@rpc("authority", "call_local", "reliable")
func _stuck(i: int) -> void:
	if not fish.has(i):
		return
	var f: Dictionary = fish[i]
	f["stuck"] = true
	var node := f["node"] as Tuna
	node.effort = 0.08
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
func _missed(who: int) -> void:
	if who == Net.my_id():
		_note("Missed! Grab the harpoon and try again")


# ------------------------------------------------------------------ the haul

func _start_pull(side: float) -> void:
	var i := _stuck_on(side)
	if i < 0:
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
		f["t"] = float(f["t"]) + delta
		if not bool(f["stuck"]):
			if float(f["t"]) > HOOK_HOLDS:
				_host_gone(i, "The hook pulled at the boat! Stick it quicker.")
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
	_note("Boatside! A %d kg bluefin. Stick it: the harpoon's along the port side" % roundi(kg))


## A fish up alongside, off rod i. `on_rod`: still on the line (not yet stuck), so the rod shows it.
func _add(i: int, kg: float, side: float, hook_t: float, on_rod := true) -> void:
	_drop(i)
	var node := Tuna.new(kg)
	node.name = "Alongside%d" % i
	node.posed = true
	node.effort = 0.35
	add_child(node)
	fish[i] = {"kg": kg, "side": side, "hook_t": hook_t, "t": 0.0, "stuck": false, "haul": 0.0, "node": node}
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
	_drop(i)


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
	harpoon_holder = 0
	_pulling.clear()
	_my_pull = -1


func _states() -> Array:
	var out := []
	for i: int in fish:
		var f: Dictionary = fish[i]
		out.append([i, f["kg"], f["side"], f["hook_t"], f["t"], f["stuck"], f["haul"]])
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
		if bool(s[5]):
			_stuck(i)


# ------------------------------------------------------------------ odds and ends

func _note(text: String) -> void:
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
