extends Area3D
## The fighting chair (the sportfisher's), usable (the user's Chekhov's gun rule: a chair you can't sit in looks
## broken). E sits you in it; E again, or a jump, gets you up. One at a time, the host says who (as boat/helm.gd does
## for the wheel). Sitting, you're held in the seat and the chair swivels to wherever you look: with a fish on that's
## the fish. It's for sitting in (the user's call: no advantage in a fight, and no reason not to stand): fight from
## it if you like, or just sit and watch the sea.

var boat: Node3D                # boat/boat.gd
var chair: Node3D               # the model's swivelling "chair"
## Who's sitting in it (peer id, 0: nobody).
var sitter := 0
var _rest_yaw := 0.0


func setup(b: Node3D, model: Node3D) -> void:
	boat = b
	chair = model
	_rest_yaw = chair.rotation.y
	position = chair.position + Vector3(0.0, 0.7, 0.0)
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.9, 0.8)
	cs.shape = box
	add_child(cs)
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server() and is_inside_tree():
			_set_sitter.rpc_id(id, sitter))
	Net.peer_left.connect(func(id: int) -> void:
		if Net.is_host() and sitter == id:
			_host_set(0))
	Net.dropped.connect(func(_reason: String) -> void:
		_set_sitter(0))


func interact(_player: Node) -> void:
	if sitter == Net.my_id():
		request(false)
	elif sitter == 0:
		request(true)


func interact_prompt() -> String:
	if sitter == Net.my_id():
		return "Get up"
	return "Sit in the fighting chair" if sitter == 0 else ""


## Where you sit, in the boat's frame (your feet's spot: the seat's in front of the pedestal, facing aft).
func seat() -> Vector3:
	return chair.position + Vector3(0.0, 0.0, 0.14)


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
	if take and sitter == 0 and (helm == null or int(helm.get("captain")) != who):
		_host_set(who)
	elif not take and sitter == who:
		_host_set(0)


func _host_set(who: int) -> void:
	if Net.in_session():
		_set_sitter.rpc(who)
	else:
		_set_sitter(who)


@rpc("authority", "call_local", "reliable")
func _set_sitter(who: int) -> void:
	var was := _crew_member(sitter)
	if was:
		was.set("seated", false)
	sitter = who
	var p := _crew_member(who)
	if p:
		p.set("seated", true)
		if p.is_multiplayer_authority():
			p.call("place", seat(), PI)        # (facing aft, out over the stern)


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
