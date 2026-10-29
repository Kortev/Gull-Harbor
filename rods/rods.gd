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

var sea: Node                 # sea/sea.gd
var rods: Array[Rod] = []


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


func _process(_delta: float) -> void:
	var boat := sea.get("boat") as Node3D
	var ocean := sea.get("ocean") as Node
	var crew := sea.get("crew") as Node
	for r in rods:
		var p: Node3D = crew.call("get_player", r.holder) if r.holder != 0 else null
		if p == null:
			# in its holder: the holder's tube, the butt down in it
			var t: Transform3D = boat.call("holder_transform", HOLDERS[r.index])
			r.global_transform = t.translated_local(Vector3(0, 0, -0.42))
		else:
			r.global_transform = _in_hands(p)
		var end := boat.global_transform * BAITS[r.index]
		end.y = ocean.call("height_at", end)
		r.line_end = end


## A rod in someone's hands: the butt at their belt, the rod out in front and up, following where they look.
func _in_hands(p: Node3D) -> Transform3D:
	var head := p.get("head") as Node3D
	var pitch := clampf(float(p.get("_pitch")), -0.6, 0.9)
	var b := p.global_basis * Basis(Vector3.RIGHT, 0.55 + pitch * 0.6) * Basis(Vector3.UP, PI)
	var at := p.global_transform * Vector3(0.2, 0.95, -0.3)
	return Transform3D(b.orthonormalized(), at)
