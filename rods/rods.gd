extends Node3D
## The spread: four rods in the stern holders (the transom corners and the two aft on each side), each with its
## bait out astern. Who holds which rod is the host's call: E on a rod asks it (request_grab), Q puts the one you
## hold back (request_return); the answer comes to every peer (_set_holder). A rod in someone's hands rides on
## them, its butt in their belt and the blank up ahead of them.

const Rod := preload("res://rods/rod.gd")
## The boat's holders the rods sit in, and where each bait is (boat-local: x across, z astern of the transom).
const HOLDERS: Array[int] = [6, 7, 0, 1]
const BAITS: Array[Vector3] = [Vector3(5.0, 0, 38.0), Vector3(-5.0, 0, 38.0), Vector3(14.0, 0, 52.0),
		Vector3(-14.0, 0, 52.0)]

## Seconds of a bluefin's first run before an unattended reel is empty.
const SPOOL_S := 24.0

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
			_holders.rpc_id(id, _holder_list()))
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
	rods[i].holder = who


## Host: a fish takes rod i's bait.
func strike(i: int, kg: float) -> void:
	var r := rods[i]
	if r.hooked:
		return
	var away := (r.line_end - r.global_position)
	var dir := Vector3(away.x, 0.0, away.z).normalized().rotated(Vector3.UP, randf_range(-0.9, 0.9))
	var t := float((sea.get("ocean") as Node).get("wave_time"))
	if Net.in_session():
		_strike.rpc(i, kg, t, dir)
	else:
		_strike(i, kg, t, dir)


@rpc("authority", "call_local", "reliable")
func _strike(i: int, kg: float, t: float, dir: Vector3) -> void:
	var r := rods[i]
	r.hooked = true
	r.fish_kg = kg
	r.hook_t = t
	r.run_dir = dir
	r.line_out = 0.0
	_hud_note("FISH ON!  The %s rod!" % ["port corner", "starboard corner", "port", "starboard"][i])


## The first run, left alone: blistering at first, tiring a little (m of line past the bait, s after the bite).
static func run_out(dt: float) -> float:
	return 150.0 * (1.0 - exp(-maxf(dt, 0.0) / 16.0))


@rpc("authority", "call_local", "reliable")
func _off(i: int, why: String) -> void:
	var r := rods[i]
	r.hooked = false
	r.line_out = 0.0
	r.strain = 0.05
	_hud_note(why)


## The holder's word on how the fight's going: line out and how hard it pulls (any peer: the holder's own).
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _fight_state(i: int, out: float, pull: float) -> void:
	if rods[i].holder == multiplayer.get_remote_sender_id():
		rods[i].line_out = out
		rods[i].strain = pull


func _hud_note(text: String) -> void:
	var crew := sea.get("crew") as Node
	(crew.get("hud") as Node).call("notify", text)


func _host_off(i: int, why: String) -> void:
	if Net.in_session():
		_off.rpc(i, why)
	else:
		_off(i, why)


@rpc("authority", "call_remote", "reliable")
func _holders(list: Array) -> void:
	for i in mini(list.size(), rods.size()):
		rods[i].holder = int(list[i])


func _holder_list() -> Array:
	var out := []
	for r in rods:
		out.append(r.holder)
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
	var t := float(ocean.get("wave_time"))
	var me := Net.my_id()
	_send_in -= delta
	for r in rods:
		if r.hooked:
			if r.holder == 0:
				# nobody on it: the fish runs, line pours off; the reel empties and it's gone
				r.line_out = run_out(t - r.hook_t)
				r.strain = 0.95
				r.reeling = 0.0
				if Net.is_host() and t - r.hook_t > SPOOL_S:
					_host_off(r.index, "Spooled! Nobody grabbed it and it took all the line.")
			elif r.holder == me:
				_reel_stub(r, delta)
			# (someone else's: their peer sends line_out and strain)
		else:
			r.strain = 0.05
			r.reeling = 0.0
		var p: Node3D = crew.call("get_player", r.holder) if r.holder != 0 else null
		if p == null:
			# in its holder: the holder's tube, the butt down in it
			var ht: Transform3D = boat.call("holder_transform", HOLDERS[r.index])
			r.global_transform = ht.translated_local(Vector3(0, 0, -0.42))
		else:
			r.global_transform = _in_hands(p)
		var end := boat.global_transform * BAITS[r.index]
		if r.hooked:
			end += r.run_dir * r.line_out
		end.y = ocean.call("height_at", end)
		r.line_end = end


## Until the fight exists: hold left mouse to crank the fish in; it still takes line now and then.
func _reel_stub(r: Rod, delta: float) -> void:
	var me := (sea.get("crew") as Node).get("me") as Node
	var live := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (me != null and bool(me.get("force_input")))
	var cranking := Input.is_action_pressed("use_primary") and live
	var t := float((sea.get("ocean") as Node).get("wave_time"))
	var surge := maxf(sin(t * 0.7 + r.fish_kg) * 6.0 - 2.0, 0.0)
	r.reeling = 2.5 if cranking else 0.0
	r.line_out = maxf(r.line_out - r.reeling * delta + surge * delta, -BAITS[r.index].z + 4.0)
	r.strain = 0.55 + 0.4 * clampf(surge / 4.0, 0.0, 1.0)
	if _send_in <= 0.0 and Net.in_session():
		_send_in = 0.1
		_fight_state.rpc(r.index, r.line_out, r.strain)
	if r.line_out <= -BAITS[r.index].z + 4.5:
		var why := "Boatside! A %d kg bluefin. (Gaff and harpoon come with the crew jobs.)" % roundi(r.fish_kg)
		if Net.is_host():
			_host_off(r.index, why)
		else:
			_landed_stub.rpc_id(1, r.index)


@rpc("any_peer", "call_remote", "reliable")
func _landed_stub(i: int) -> void:
	if rods[i].holder == multiplayer.get_remote_sender_id() and rods[i].hooked:
		_host_off(i, "Boatside! A %d kg bluefin. (Gaff and harpoon come with the crew jobs.)" % roundi(rods[i].fish_kg))


## A rod in someone's hands: the butt at their belt, the rod out in front and up, following where they look.
func _in_hands(p: Node3D) -> Transform3D:
	var head := p.get("head") as Node3D
	var pitch := clampf(float(p.get("_pitch")), -0.6, 0.9)
	var b := p.global_basis * Basis(Vector3.RIGHT, 0.55 + pitch * 0.6) * Basis(Vector3.UP, PI)
	var at := p.global_transform * Vector3(0.2, 0.95, -0.3)
	return Transform3D(b.orthonormalized(), at)
