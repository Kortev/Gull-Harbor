extends Area3D
## The wheel, and whoever's at it: the captain. E on the wheel takes it (the host says who), E or Q leaves it.
## The captain's A/D swing her round (TURN rad/s), holding S backs her down and W runs her ahead.
##
## She really goes places: W runs her ahead (up to AHEAD, about 20 knots, to get to the birds), S backs her down
## (ASTERN, a few knots, onto a fish), and let go she carries her way (COAST) before she settles. A/D turn her, and with
## twin screws she spins on the spot as well as under way. `at` is where she is in the world (x, z).
##
## Whoever's at the wheel moves her on their own machine, so it answers at once, and tells everyone where she is, her
## heading, speed and throttle; with nobody at the wheel the host lets her coast to a stop and tells everyone.

const Sfx := preload("res://audio/sfx.gd")
const SEND := 1.0 / 15.0
## The 46 footer's handling (boat/kinds.gd has each boat's; configure() sets these from it):
## rad/s hard over (twin screws, one ahead and one astern, spin her faster than a fish circles: tuna/fight.gd).
const TURN := 0.45
## m/s flat out ahead (about 20 knots) and astern (backing down on a fish).
const AHEAD := 10.0
const ASTERN := 2.6
## How fast she gets going (m/s each second), ahead and astern; how long she carries her way with the throttle
## eased (s: what's left of her speed after this long is about a third).
const SPURT := 1.4
const BACK := 2.2
const COAST := 9.0

## This boat's handling (boat/kinds.gd).
var turn := TURN
var ahead := AHEAD
var astern := ASTERN
var spurt := SPURT
var back := BACK
var coast := COAST

var boat: Node3D          # boat/boat.gd
## Rivals: a line wrapped round her props (vs/contact.gd, crossing the other boat's lines) kills her engines till this
## (the sea clock): she coasts, whatever the throttle says, while it's cleared.
var fouled_until := -1.0
## The captain's peer id (0: nobody at the wheel).
var captain := 0
## Her heading (radians round the up axis; she starts at 0), the wheel (-1 hard to starboard .. 1 hard to port)
## and the throttle (-1 backing down .. 1 ahead).
var heading := 0.0
var steer := 0.0
var throttle := 0.0
## Where she is in the world (x, z) and how fast she's going (m/s: + ahead, - astern).
var at := Vector2.ZERO
var speed := 0.0
## A shove she's been given (VS: the other boat bumping her, vs/contact.gd): sideways way on her (m/s, world x, z)
## and a turn (rad/s), both dying away.
var drift := Vector2.ZERO
var spin := 0.0
var _net_heading := 0.0
var _net_at := Vector2.ZERO
var _net_speed := 0.0
var _net_age := 0.0
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
			_sync.rpc_id(id, captain, heading, at, speed))
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
	# (whoever moves her now starts from where she is here, not from an old word)
	_net_at = at
	_net_speed = speed
	_net_age = 0.0
	steer = 0.0
	throttle = 0.0
	var p: Node = _crew_member(who)
	if p:
		p.set("steering", true)
		var spot: Transform3D = boat.get("helm_spot")
		p.call("place", spot.origin + Vector3(0, 0.05, 0), 0.0)
		if p.is_multiplayer_authority():
			var hud: Node = boat.get("sea").get("crew").get("hud")
			var tips: Node = boat.get("sea").get("tips")
			var keys := "W/S throttle   A/D steer"
			hud.call("notify", str(tips.call("teach_once", keys)) if tips != null else keys)


## Whether a line's round her props now.
func fouled() -> bool:
	var ocean: Node = boat.get("ocean") if boat else null
	return ocean != null and float(ocean.get("wave_time")) < fouled_until


## Host: a line round her props for `seconds` (everyone hears it, and her engines die on whoever's machine drives her).
func host_foul(seconds: float) -> void:
	var ocean: Node = boat.get("ocean")
	var until := float(ocean.get("wave_time")) + seconds
	if Net.in_session():
		_foul.rpc(until)
	else:
		_foul(until)


@rpc("authority", "call_local", "reliable")
func _foul(until: float) -> void:
	fouled_until = maxf(fouled_until, until)
	Sfx.play_point(boat, boat.global_position + Vector3(0, 0.5, float(boat.get("length")) * 0.5), "kit.thud", 1.0, 0.5)
	# her crew told why the engines died
	var crew: Node = boat.get("sea").get("crew") if boat.get("sea") != null else null
	var me: Node = crew.get("me") if crew != null else null
	if me != null and me.get("boat") == boat:
		(crew.get("hud") as Node).call("notify", "LINE IN THE PROPS! ENGINES DEAD TILL IT'S CLEAR")


@rpc("authority", "call_remote", "reliable")
func _sync(who: int, at_heading: float, where: Vector2, going: float) -> void:
	_set_captain(who, at_heading)
	at = where
	speed = going
	_net_at = where
	_net_speed = going
	_net_age = 0.0


## The word on her from whoever moves her (the captain, or the host with nobody at the wheel), ~15 a second.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(at_heading: float, wheel: float, gas: float, where: Vector2, going: float) -> void:
	var from := multiplayer.get_remote_sender_id()
	if from == captain or (captain == 0 and from == 1):
		_net_heading = at_heading
		steer = wheel
		throttle = gas
		_net_at = where
		_net_speed = going
		_net_age = 0.0


## Her handling, from her kind (boat/kinds.gd).
func configure(spec: Dictionary) -> void:
	turn = float(spec.get("turn", TURN))
	ahead = float(spec.get("ahead", AHEAD))
	astern = float(spec.get("astern", ASTERN))
	spurt = float(spec.get("spurt", SPURT))
	back = float(spec.get("back", BACK))
	coast = float(spec.get("coast", COAST))


## Which way her bow points (world x, z) at a heading.
static func ahead_of(h: float) -> Vector2:
	return Vector2(-sin(h), -cos(h))


## Her speed toward where she's going after `delta` s at throttle `gas` (-1 .. 1).
func next_speed(v: float, gas: float, delta: float) -> float:
	var want := gas * ahead if gas > 0.0 else gas * astern
	if absf(gas) < 0.02 or (signf(v) == signf(want) and absf(v) > absf(want)):
		# easing off (or off altogether): she carries her way
		return want + (v - want) * exp(-delta / coast)
	# getting going, or the screws thrown the other way to stop her
	var rate := spurt if gas > 0.0 else back
	return move_toward(v, want, rate * delta)


func _unhandled_input(event: InputEvent) -> void:
	if is_mine() and event.is_action_pressed("drop"):
		request(false)
		get_viewport().set_input_as_handled()


## (every frame, not every physics tick: the camera rides her, so she must move as smoothly as it does)
func _process(delta: float) -> void:
	# whoever's at the wheel moves her; with nobody there, the host lets her coast to a stop
	var driving := is_mine() or (captain == 0 and Net.is_host())
	if is_mine():
		var me: Node = _crew_member(captain)
		var live := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (me != null and bool(me.get("force_input")))
		var want_steer := Input.get_axis("move_right", "move_left") if live else 0.0
		var want_gas := Input.get_axis("move_back", "move_forward") if live else 0.0
		steer = move_toward(steer, want_steer, delta * 2.5)
		throttle = move_toward(throttle, want_gas, delta * 1.5)
		if fouled():
			throttle = 0.0
		heading = wrapf(heading + steer * turn * delta, -PI, PI)
	elif captain == 0:
		steer = move_toward(steer, 0.0, delta * 2.5)
		throttle = 0.0
	if driving:
		speed = next_speed(speed, throttle, delta)
		var was := at
		at += ahead_of(heading) * speed * delta
		if drift != Vector2.ZERO or spin != 0.0:
			at += drift * delta
			heading = wrapf(heading + spin * delta, -PI, PI)
			drift *= exp(-delta / 1.6)
			spin *= exp(-delta / 1.2)
			if drift.length() < 0.02 and absf(spin) < 0.002:
				drift = Vector2.ZERO
				spin = 0.0
		# (VS: the other boat's as solid as the shore, and a bump shoves you both apart: vs/contact.gd)
		var vs: Node = boat.get("sea").get("vs") if boat.get("sea") != null else null
		if vs != null and bool(vs.get("on")):
			vs.call("fend", self)
		# (the shore and the rig stop her dead: her bow or her stern, whichever end's going that way)
		var marks: Node = boat.get("sea").get("landmarks") if boat.get("sea") != null else null
		var end := at + ahead_of(heading) * signf(speed) * float(boat.get("length")) * 0.5
		if marks != null and absf(speed) > 0.0 and bool(marks.call("blocked", end)):
			at = was
			var pier: Node = marks.get("harbour")
			if pier != null and bool(pier.call("blocked", end)):
				# (into the pier or a boat on it: a bump, felt, not read)
				if absf(speed) > 0.6:
					var bump := ahead_of(heading) * signf(speed) * 6.0
					Sfx.play_point(boat, boat.global_position + Vector3(bump.x, 0.5, bump.y), "kit.thud",
							clampf(absf(speed) / 4.0, 0.3, 1.0), 0.7)
			elif absf(speed) > 1.0 and is_mine():
				var hud: Node = boat.get("sea").get("crew").get("hud")
				hud.call("notify", "Aground! Back her off (S)" if speed > 0.0
						else "Aground! Ahead (W)")
			speed = 0.0
		_send_in -= delta
		if Net.in_session() and _send_in <= 0.0:
			_send_in = SEND if is_mine() else SEND * 3.0
			_state.rpc(heading, steer, throttle, at, speed)
	else:
		# someone else moves her: ease toward where their word says she is by now
		_net_age += delta
		heading = heading + wrapf(_net_heading - heading, -PI, PI) * minf(delta * 10.0, 1.0)
		# (carried along at her speed, and eased onto the guess: no lagging behind her)
		var guess := _net_at + ahead_of(_net_heading) * _net_speed * _net_age
		at += ahead_of(heading) * _net_speed * delta
		at = at.lerp(guess, minf(delta * 3.0, 1.0))
		speed = _net_speed
	_show_helm()


## Your own readout at the wheel (the HUD's bottom bar): knots and the throttle.
var _showing := false


func _show_helm() -> void:
	var hud: Node = boat.get("sea").get("crew").get("hud")
	if not is_mine():
		if _showing:
			hud.call("helm", -1.0)
			_showing = false
		return
	_showing = true
	hud.call("helm", absf(speed) * 1.944, throttle)


func _crew_member(id: int) -> Node:
	if id == 0:
		return null
	var crew: Node = boat.get("sea").get("crew")
	return crew.call("get_player", id) if crew != null else null
