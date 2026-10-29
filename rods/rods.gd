extends Node3D
## The spread: four rods in the stern holders (the transom corners and the two aft on each side), each with its
## bait out astern. Who holds which rod is the host's call: E on a rod asks it (request_grab), Q puts the one you
## hold back (request_return); the answer comes to every peer (_set_holder). A rod in someone's hands rides on
## them, its butt in their belt and the blank up ahead of them.

const Rod := preload("res://rods/rod.gd")
const Fight := preload("res://tuna/fight.gd")
## The boat's holders the rods sit in, and where each bait is (boat-local: x across, z astern of the transom).
const HOLDERS: Array[int] = [6, 7, 0, 1]
const BAITS: Array[Vector3] = [Vector3(5.0, 0, 38.0), Vector3(-5.0, 0, 38.0), Vector3(14.0, 0, 52.0),
		Vector3(-14.0, 0, 52.0)]

## Where the lines go over the transom (boat-local): bearings and line out are measured from here.
const STERN := Vector3(0.0, 0.0, 6.3)
## How fast a fish on an unattended rod strips line (m/s, fresh): nobody to stop it, the reel's empty in half a minute.
const FREE_RUN := 16.0
const WHY := {"broke": "The line parted!", "pulled": "Pulled the hook!",
		"spooled": "Spooled! It took every metre of line."}

var sea: Node                 # sea/sea.gd
var rods: Array[Rod] = []
var _send_in := 0.0


func _ready() -> void:
	for i in HOLDERS.size():
		var r := Rod.new()
		r.name = "Rod%d" % i
		r.index = i
		r.spread = self
		add_child(r)
		rods.append(r)
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_sync.rpc_id(id, _states()))
	Net.peer_left.connect(func(id: int) -> void:
		if Net.is_host():
			for r in rods:
				if r.holder == id:
					_host_set(r.index, 0))
	Net.dropped.connect(func(_reason: String) -> void:
		for r in rods:
			r.holder = 0)


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
	if i < 0 or i >= rods.size() or rods[i].holder != 0 or held_by(who) != null:
		return
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
	var r := rods[i]
	r.holder = who
	r.fight = null
	r.lift = 0.0
	# let go with a fish on: it runs from where it is
	r.free_t = _now()
	r.free_out = r.line_out


## Host: a fish takes rod i's bait.
func strike(i: int, kg: float) -> void:
	var r := rods[i]
	if r.hooked:
		return
	var bait := BAITS[i] - STERN
	var bearing := atan2(bait.x, bait.z) + randf_range(-0.5, 0.5)
	if Net.in_session():
		_strike.rpc(i, kg, _now(), bearing, randi())
	else:
		_strike(i, kg, _now(), bearing, randi())


@rpc("authority", "call_local", "reliable")
func _strike(i: int, kg: float, t: float, bearing: float, seed_value: int) -> void:
	var r := rods[i]
	r.hooked = true
	r.fish_kg = kg
	r.hook_t = t
	r.bearing = bearing
	r.depth = 2.0
	r.energy = 1.0
	r.move = "run"
	r.line_out = (BAITS[i] - STERN).length()
	r.free_t = t
	r.free_out = r.line_out
	r.fight = null
	r.set_meta("seed", seed_value)
	_hud_note("FISH ON!  The %s rod!" % ["port corner", "starboard corner", "port", "starboard"][i])


@rpc("authority", "call_local", "reliable")
func _off(i: int, why: String) -> void:
	var r := rods[i]
	r.hooked = false
	r.fight = null
	r.line_out = 0.0
	r.strain = 0.05
	r.move = ""
	_hud_note(why)


## The holder's word on how the fight's going (any peer: the holder's own; everyone else draws it).
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _fight_state(i: int, out: float, strain: float, bearing: float, depth: float, energy: float, lift: float,
		move: String) -> void:
	var r := rods[i]
	if r.holder == multiplayer.get_remote_sender_id() and r.hooked:
		r.line_out = out
		r.strain = strain
		r.bearing = bearing
		r.depth = depth
		r.energy = energy
		r.lift = lift
		r.move = move


## The holder's fight ended (lost, or boatside): the host says so to everyone.
@rpc("any_peer", "call_remote", "reliable")
func _report_end(i: int, how: String) -> void:
	if rods[i].holder == multiplayer.get_remote_sender_id() and rods[i].hooked:
		_host_off(i, _end_text(i, how))


func _end_text(i: int, how: String) -> String:
	if how == "boatside":
		return "Boatside! A %d kg bluefin. (The harpoon and the tuna door come with the crew jobs.)" \
				% roundi(rods[i].fish_kg)
	return str(WHY.get(how, "Lost it."))


func _now() -> float:
	return float((sea.get("ocean") as Node).get("wave_time"))


func _hud_note(text: String) -> void:
	var crew := sea.get("crew") as Node
	(crew.get("hud") as Node).call("notify", text)


func _host_off(i: int, why: String) -> void:
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
		r.free_out = float(st[8])


func _states() -> Array:
	var out := []
	for r in rods:
		out.append([r.holder, r.hooked, r.fish_kg, r.line_out, r.bearing, r.depth, r.energy, r.free_t, r.free_out])
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
	var t := _now()
	var me := Net.my_id()
	var mine: Rod = null
	_send_in -= delta
	for r in rods:
		if r.hooked:
			if r.holder == 0:
				# nobody on it: the fish runs, line pours off, and when the reel's empty it's gone
				var e := 0.4 + 0.6 * r.energy
				r.line_out = r.free_out + FREE_RUN * e * maxf(t - r.free_t, 0.0)
				r.strain = 0.95
				r.reeling = 0.0
				r.bearing += delta * 0.05
				r.depth = move_toward(r.depth, 15.0, delta * 3.0)
				r.energy = minf(r.energy + delta * 0.01, 1.0)
				if Net.is_host() and r.line_out >= Fight.CAPACITY:
					_host_off(r.index, WHY["spooled"])
			elif r.holder == me:
				mine = r
				_fight_mine(r, delta)
			# (someone else's: their peer sends how it's going)
		else:
			r.strain = 0.05
			r.reeling = 0.0
		var p: Node3D = crew.call("get_player", r.holder) if r.holder != 0 else null
		if p == null:
			# in its holder: the holder's tube, the butt down in it
			var ht: Transform3D = boat.call("holder_transform", HOLDERS[r.index])
			r.global_transform = ht.translated_local(Vector3(0, 0, -0.42))
		else:
			r.global_transform = _in_hands(p, r.lift)
		var end := boat.global_transform * BAITS[r.index]
		if r.hooked:
			# where the line goes in: toward the fish, closer to the boat the deeper it is (a straight line down)
			var hd := sqrt(maxf(r.line_out * r.line_out - r.depth * r.depth, 0.0))
			var entry := hd * 2.5 / (2.5 + r.depth * 0.5)
			end = boat.global_transform * (STERN + Vector3(sin(r.bearing), 0.0, cos(r.bearing)) * entry)
		end.y = ocean.call("height_at", end)
		r.line_end = end
	var hud := crew.get("hud") as Node
	var me_node := crew.get("me") as Node
	if me_node != null:
		# the fish in your arms: harder on a run or a headshake
		var surge := 1.0 if mine != null and mine.move in ["run", "shake"] else 0.6
		me_node.set("shake", mine.strain * surge if mine != null and mine.hooked else 0.0)
	if mine != null and mine.hooked:
		# the ring is how wrong you're fighting it, not how hard it pulls (that's the rod's bend)
		var wrong := (mine.fight as Fight).strain if mine.fight != null else 0.0
		hud.call("fight", str(Fight.TELLS.get(mine.move, "")), maxf(wrong, 0.02))
	else:
		hud.call("fight", "", 0.0)


## Your rod with a fish on: you fight it here (left mouse cranks, right mouse heaves the rod up) and tell the rest.
func _fight_mine(r: Rod, delta: float) -> void:
	var me := (sea.get("crew") as Node).get("me") as Node
	var live := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (me != null and bool(me.get("force_input")))
	var crank := live and Input.is_action_pressed("use_primary")
	var heave := live and Input.is_action_pressed("use_secondary")
	r.lift = move_toward(r.lift, 1.0 if heave else 0.0, delta * 3.5)
	if r.fight == null:
		var f := Fight.new(r.fish_kg, r.line_out, r.energy, int(r.get_meta("seed", 0)) + int(r.free_t))
		f.bearing = r.bearing
		f.depth = r.depth
		f.lost.connect(func(how: String) -> void: _end_mine(r, how))
		f.boatside.connect(func() -> void: _end_mine(r, "boatside"))
		r.fight = f
	var fight := r.fight as Fight
	fight.step(delta, crank, r.lift)
	if not r.hooked:
		return       # (it ended this step)
	r.reeling = Fight.CRANK if crank and fight.answer() != "hold" else 0.0
	r.line_out = fight.line_out
	r.strain = maxf(fight.pull, fight.strain)
	r.bearing = fight.bearing
	r.depth = fight.depth
	r.energy = fight.energy
	r.move = fight.move
	if _send_in <= 0.0 and Net.in_session():
		_send_in = 0.1
		_fight_state.rpc(r.index, r.line_out, r.strain, r.bearing, r.depth, r.energy, r.lift, r.move)


func _end_mine(r: Rod, how: String) -> void:
	if Net.is_host():
		_host_off(r.index, _end_text(r.index, how))
	else:
		r.hooked = false        # (till the host's word comes back)
		_report_end.rpc_id(1, r.index, how)


## A rod in someone's hands: the butt at their belt, the rod out in front and up, following where they look; heaved
## up toward the sky in a pump (`lift`).
func _in_hands(p: Node3D, lift: float) -> Transform3D:
	var pitch := clampf(float(p.get("_pitch")), -0.6, 0.9)
	var b := p.global_basis * Basis(Vector3.RIGHT, 0.55 + pitch * 0.6 + lift * 0.6) * Basis(Vector3.UP, PI)
	var at := p.global_transform * Vector3(0.2, 0.95, -0.3)
	return Transform3D(b.orthonormalized(), at)
