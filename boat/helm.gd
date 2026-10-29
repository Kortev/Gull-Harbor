extends Area3D
## The wheel, and whoever's at it: the captain. E on the wheel takes it (the host says who), E or Q leaves it.
## The captain's A/D swing her round (TURN rad/s), holding S backs her down and W runs her ahead.
##
## The boat still never goes anywhere: turning swings her heading where she sits, and backing down is felt
## through the fight (tuna/fight.gd: the boat coming back over the fish wins line and takes the strain).
## The captain's own machine steers, so it answers at once, and tells everyone her heading and throttle.

## rad/s, hard over: twin screws, one ahead and one astern, spin her faster than a fish circles (tuna/fight.gd)
const TURN := 0.45
const SEND := 1.0 / 15.0

var boat: Node3D          # boat/boat.gd
## The captain's peer id (0: nobody at the wheel).
var captain := 0
## Her heading (radians round the up axis; she starts at 0), the wheel (-1 hard to starboard .. 1 hard to port)
## and the throttle (-1 backing down .. 1 ahead).
var heading := 0.0
var steer := 0.0
var throttle := 0.0
var _net_heading := 0.0
var _send_in := 0.0


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.6, 0.5)
	cs.shape = box
	add_child(cs)
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_sync.rpc_id(id, captain, heading))
	Net.peer_left.connect(func(id: int) -> void:
		if Net.is_host() and captain == id:
			_host_set(0))
	Net.dropped.connect(func(_reason: String) -> void:
		_set_captain(0, heading))


func interact(_player: Node) -> void:
	if captain == Net.my_id():
		request(false)
	elif captain == 0:
		request(true)


func interact_prompt() -> String:
	if captain == Net.my_id():
		return "Leave the wheel"
	return "Take the wheel" if captain == 0 else ""


## Asks the host for the wheel (take) or gives it up.
func request(take: bool) -> void:
	if Net.is_host():
		_ask(take)
	else:
		_ask.rpc_id(1, take)


func is_mine() -> bool:
	return captain != 0 and captain == Net.my_id()


@rpc("any_peer", "call_remote", "reliable")
func _ask(take: bool) -> void:
	var who := multiplayer.get_remote_sender_id()
	if who == 0:
		who = Net.my_id()
	var rods: Node = boat.get("sea").get("rods")
	var landing: Node = boat.get("sea").get("landing")
	var hands_free := (rods == null or rods.call("held_by", who) == null) \
			and (landing == null or int(landing.get("harpoon_holder")) != who)
	if take and captain == 0 and hands_free:
		_host_set(who)
	elif not take and captain == who:
		_host_set(0)


func _host_set(who: int) -> void:
	if Net.in_session():
		_set_captain.rpc(who, heading)
	else:
		_set_captain(who, heading)


@rpc("authority", "call_local", "reliable")
func _set_captain(who: int, at_heading: float) -> void:
	var was: Node = _crew_member(captain)
	if was:
		was.set("steering", false)
	captain = who
	heading = at_heading
	_net_heading = at_heading
	steer = 0.0
	throttle = 0.0
	var p: Node = _crew_member(who)
	if p:
		p.set("steering", true)
		var spot: Transform3D = boat.get("helm_spot")
		p.call("place", spot.origin + Vector3(0, 0.05, 0), 0.0)
		if p.is_multiplayer_authority():
			var hud: Node = boat.get("sea").get("crew").get("hud")
			hud.call("notify", "At the wheel: A/D swing her, hold S to back down, W ahead. E or Q to leave.")


@rpc("authority", "call_remote", "reliable")
func _sync(who: int, at_heading: float) -> void:
	_set_captain(who, at_heading)


## The captain's word on the wheel (sent ~15 a second; only the captain's counts).
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(at_heading: float, wheel: float, gas: float) -> void:
	if multiplayer.get_remote_sender_id() == captain:
		_net_heading = at_heading
		steer = wheel
		throttle = gas


func _unhandled_input(event: InputEvent) -> void:
	if is_mine() and event.is_action_pressed("drop"):
		request(false)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if is_mine():
		var me: Node = _crew_member(captain)
		var live := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (me != null and bool(me.get("force_input")))
		var want_steer := Input.get_axis("move_right", "move_left") if live else 0.0
		var want_gas := Input.get_axis("move_back", "move_forward") if live else 0.0
		steer = move_toward(steer, want_steer, delta * 2.5)
		throttle = move_toward(throttle, want_gas, delta * 1.5)
		heading = wrapf(heading + steer * TURN * delta, -PI, PI)
		_send_in -= delta
		if Net.in_session() and _send_in <= 0.0:
			_send_in = SEND
			_state.rpc(heading, steer, throttle)
	elif captain != 0:
		heading = heading + wrapf(_net_heading - heading, -PI, PI) * minf(delta * 10.0, 1.0)
	else:
		steer = move_toward(steer, 0.0, delta * 2.5)
		throttle = 0.0


func _crew_member(id: int) -> Node:
	if id == 0:
		return null
	var crew: Node = boat.get("sea").get("crew")
	return crew.call("get_player", id) if crew != null else null
