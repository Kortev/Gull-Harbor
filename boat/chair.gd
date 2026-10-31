extends Area3D
## Somewhere to sit: the fighting chair (the sportfisher's), and her other seats (boat/kinds.gd's "seats": the
## benches, the skipper's seat, the skiff's cooler seat and the leaning post you lean on), all usable (the user's
## Chekhov's gun rule: a seat you can't sit in looks broken). E sits you down; E again, or a jump, gets you up. One
## at a time, the host says who (as boat/helm.gd does for the wheel). You go to it and down into it, and back up
## and off it, a step at a time (crew/player.gd: nothing jumps), and you look round but don't walk.
##
## The fighting chair swivels to wherever you look: with a fish on that's the fish, the rod's butt down in its gimbal
## (rods.gd's _in_hands). It's for sitting in (the user's call: no advantage in a fight, and no reason not to
## stand): fight from it if you like, or just sit and watch the sea. Both Rivals boats are the same kind, so both
## crews have the same chair and seats.

var boat: Node3D                # boat/boat.gd
var chair: Node3D               # the fighting chair's swivelling model ("chair"), or null for a plain seat
## What it is ("the bench"), where your feet go sitting in it (boat-local), which way you face, whether you lean on
## it rather than sit, and how far your hips and eyes drop (m).
var title := "the fighting chair"
var feet := Vector3.ZERO
var face := PI
var lean := false
var drop := 0.37
## Who's sitting in it (peer id, 0: nobody).
var sitter := 0
var _rest_yaw := 0.0


## The fighting chair, on its model (it swivels about its pedestal).
func setup(b: Node3D, model: Node3D) -> void:
	boat = b
	chair = model
	_rest_yaw = chair.rotation.y
	feet = chair.position + Vector3(0.0, 0.0, 0.14)     # (in front of the pedestal, facing aft)
	_area(chair.position + Vector3(0.0, 0.7, 0.0), Vector3(0.8, 0.9, 0.8))


## A plain seat (boat/kinds.gd's "seats": the middle of its top, which way you face, its name, a leaning post).
func setup_seat(b: Node3D, spec: Dictionary) -> void:
	boat = b
	title = str(spec["name"])
	face = float(spec["face"])
	lean = bool(spec.get("lean", false))
	drop = 0.1 if lean else 0.37
	var top: Vector3 = spec["at"]
	feet = top - Vector3(0.0, 0.5 if lean else 0.55, 0.0) + _ahead() * (0.25 if lean else 0.1)
	_area(top, Vector3(0.6, 0.5, 0.6))


func _area(at: Vector3, size: Vector3) -> void:
	position = at
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)
	Net.peer_joined.connect(_on_joined)
	Net.peer_left.connect(_on_left)
	Net.dropped.connect(_on_dropped)


func _on_joined(id: int) -> void:
	if multiplayer.is_server() and is_inside_tree():
		_set_sitter.rpc_id(id, sitter)


func _on_left(id: int) -> void:
	if Net.is_host() and sitter == id and is_inside_tree():
		_host_set(0)


func _on_dropped(_reason: String) -> void:
	if is_inside_tree():
		_set_sitter(0)


## The way you face sitting in it (boat-local, flat).
func _ahead() -> Vector3:
	return Vector3(-sin(face), 0.0, -cos(face))


func interact(_player: Node) -> void:
	if sitter == Net.my_id():
		request(false)
	elif sitter == 0:
		request(true)


func interact_prompt() -> String:
	if sitter == Net.my_id():
		return "Get up"
	if sitter != 0:
		return ""
	if chair != null:
		var rods: Node = boat.get("sea").get("rods") if boat.get("sea") else null
		var rod: Node = rods.call("held_by", Net.my_id()) if rods else null
		return "Fight it from the chair" if rod != null and bool(rod.get("hooked")) else "Sit"
	return "Lean" if lean else "Sit"


## Where you sit, in the boat's frame (your feet's spot).
func seat() -> Vector3:
	return feet


## Where you stand up to, off it (boat-local, on her deck): a step out in front of a seat, aft of the chair.
func stand() -> Vector3:
	var out := feet + (_ahead() * 0.45 if chair == null else Vector3(0.0, 0.0, 0.45))
	return Vector3(out.x, float(boat.get("deck")) + 0.02, out.z)


## Asks the host for the seat (take) or gives it up.
func request(take: bool) -> void:
	if Net.is_host():
		_ask(take)
	else:
		_ask.rpc_id(1, take)


@rpc("any_peer", "call_remote", "reliable")
func _ask(take: bool) -> void:
	var who := multiplayer.get_remote_sender_id()
	if who == 0:
		who = Net.my_id()
	var helm: Node = boat.get("helm")
	if take and sitter == 0 and (helm == null or int(helm.get("captain")) != who) and not _sitting_elsewhere(who):
		_host_set(who)
	elif not take and sitter == who:
		_host_set(0)


## `who` is already in another of her seats.
func _sitting_elsewhere(who: int) -> bool:
	for s: Node in boat.get("seats"):
		if s != self and int(s.get("sitter")) == who:
			return true
	return false


func _host_set(who: int) -> void:
	if Net.in_session():
		_set_sitter.rpc(who)
	else:
		_set_sitter(who)


@rpc("authority", "call_local", "reliable")
func _set_sitter(who: int) -> void:
	var was := _crew_member(sitter)
	if was and was.get("sat_in") == self:
		was.call("stand_up", stand())
	sitter = who
	var p := _crew_member(who)
	if p:
		p.call("sit_in", self)       # (you go to it and down into it: crew/player.gd)


func _process(delta: float) -> void:
	if chair == null:
		return
	var want := _rest_yaw
	var p := _crew_member(sitter)
	if p:
		want = _rest_yaw + float(p.get("_yaw")) - PI      # (it turns with you)
	chair.rotation.y = lerp_angle(chair.rotation.y, want, minf(1.0, delta * 6.0))


func _crew_member(id: int) -> Node:
	if id == 0 or boat == null:
		return null
	var crew: Node = boat.get("sea").get("crew")
	return crew.call("get_player", id) if crew != null else null
