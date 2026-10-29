extends Node3D
## One of the crew, first person. The node's name is its peer id and only that peer (the authority) reads input.
##
## You walk in the boat's DECK SPACE (boat/boat.gd): a still physics world with the hull's collider that never
## moves, so `body` there is a plain CharacterBody3D on a level deck, and its position IS your spot on the boat.
## This node, what everyone sees and your camera, is that spot carried by the boat's pose every frame. No sliding,
## no jitter, whatever the sea does; and you lean with the deck while your eyes keep the horizon half level.
##
## Children: Head/Camera3D, Head/Hand (the rod hangs here later). Press E on anything in group "interactable" that
## has interact(player) (and optionally interact_prompt() for the "E: ..." label).

const WALK := 3.0
const SPRINT := 4.6
const JUMP := 4.0
const GRAVITY := 12.0
const ACCEL := 22.0
const AIR_ACCEL := 5.0
const LOOK := 0.0024
const REACH := 2.5
## How much of the boat's pitch and roll your eyes take out (0: the camera is bolted to the deck).
const STEADY := 0.45
const REST := 0.03

signal prompt_changed(text: String)

const MODEL := preload("res://crew/crew.glb")
## Each crew member's oilskins, by spawn slot order (crew/crew.gd): yellow, orange, green, red.
const OILSKINS: Array[Color] = [Color(0.85, 0.62, 0.08), Color(0.92, 0.38, 0.06), Color(0.18, 0.45, 0.18),
		Color(0.7, 0.12, 0.08)]

var boat: Node3D
## Your body in the deck space: its transform is boat-local.
var body: CharacterBody3D
var head: Node3D
var cam: Camera3D
var hand: Node3D
var body_mesh: MeshInstance3D
## Tests drive the keys without a captured mouse.
var force_input := false
## A fish pulling on the rod in your hands, 0..1 (rods.gd): your view trembles with it and gets tugged toward it.
var shake := 0.0
## Slower looking (crew/binoculars.gd: through them, a little mouse goes a long way).
var look_scale := 1.0
## Your arms, 1 fresh .. 0 spent (tuna/fight.gd wears them in a fight; off the rod they come back at REST).
var arms := 1.0
## At the wheel (boat/helm.gd): your feet stay put and the keys steer her instead.
var steering := false
## Up the tuna tower (boat/tower.gd): you look round but don't walk; E or Q climbs down. Any place() ends it.
var aloft := false
var _yaw := 0.0
var _pitch := 0.0
var _prompt := ""
var _prev_local := Vector3.ZERO
var _local := Vector3.ZERO
## A crewmate's last reported spot and look (their own peer moves them; we ease toward it).
var _net_at := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _send_in := 0
## The crew model's pieces by name, their rest poses, and the walk's phase (_pose_body).
var _parts := {}
var _rest := {}
var _stride := 0.0
var _body_root: Node3D
## What you're doing that the others can't work out for themselves (sent with your spot, ACT_*), and a one-off
## move you're making (gesture(): its name and how far into it you are, s).
const ACT_GLASSES := 1
const ACT_JIG := 2
const ACT_HAUL := 4
const ACT_CRANK := 8
var act := 0
var _net_act := 0
var _gesture := ""
var _gesture_t := 0.0
## The one-off moves and how long each takes (s).
const GESTURES := {"throw": 0.6, "scoop": 0.7, "bleed": 1.1, "reach": 0.5, "stumble": 0.9}
var _crank_ph := 0.0
var _haul_ph := 0.0
## The deck dropping out from under you (a big sea): its heave, how fast, and when you last lost your feet.
var _deck_y := 0.0
var _deck_vy := 0.0
var _stumble_in := 0.0
## How hard a lurch has to be (m/s, the deck's heave changing that much in a tenth of a second) to throw you.
const LURCH := 2.2


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int() if str(name).is_valid_int() else 1)


func _ready() -> void:
	add_to_group("players")
	body = CharacterBody3D.new()
	body.name = "Crew_" + str(name)
	body.floor_stop_on_slope = true
	body.floor_max_angle = deg_to_rad(50.0)
	body.floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.75
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.875
	body.add_child(cs)
	(boat.get("deck_root") as Node3D).add_child(body)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = 1.62
	add_child(head)
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 6000.0
	head.add_child(cam)
	hand = Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0.28, -0.32, -0.45)
	head.add_child(hand)
	# What the others see: a deckhand in oilskins (art/crew.py), in pieces that swing at the joints
	_build_body()
	if is_multiplayer_authority():
		for part: MeshInstance3D in _parts.values():
			part.layers = 1 << 19      # layer 20: your own camera leaves it out, it still casts your shadow
		cam.cull_mask &= ~(1 << 19)
		cam.make_current()
		if not _at_dock():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The crew model's pieces (torso, head, arms, legs) under one node that turns with you; your oilskins in your colour.
func _build_body() -> void:
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	var src := MODEL.instantiate() as Node3D
	var colour := OILSKINS[_slot() % OILSKINS.size()]
	for n: String in ["torso", "head", "arm_l", "arm_r", "fore_l", "fore_r", "leg_l", "leg_r", "shin_l", "shin_r"]:
		var mi := src.find_child(n, true, false) as MeshInstance3D
		if mi == null:
			continue
		var t := mi.transform
		mi.owner = null
		mi.get_parent().remove_child(mi)
		mi.transform = t
		root.add_child(mi)
		_parts[n] = mi
		_rest[n] = t.basis
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and m.resource_name == "oilskin" and m is BaseMaterial3D:
				var own := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				own.albedo_color = colour
				mi.set_surface_override_material(i, own)
	src.free()
	# the joints: head and arms ride the torso, forearms the arms, shins the thighs
	for pair: Array in [["head", "torso"], ["arm_l", "torso"], ["arm_r", "torso"], ["fore_l", "arm_l"],
			["fore_r", "arm_r"], ["shin_l", "leg_l"], ["shin_r", "leg_r"]]:
		var c := _parts.get(pair[0]) as Node3D
		var to := _parts.get(pair[1]) as Node3D
		if c == null or to == null:
			continue
		var t := to.transform.affine_inverse() * c.transform
		root.remove_child(c)
		to.add_child(c)
		c.transform = t
		_rest[pair[0]] = t.basis
	_body_root = root
	body_mesh = _parts.get("torso") as MeshInstance3D


## Which crew member you are, for your oilskins' colour (crew/crew.gd's spawn slot; 0 alone).
func _slot() -> int:
	var crew := get_parent()
	var slots: Variant = crew.get("slots") if crew else null
	if slots is Dictionary and (slots as Dictionary).has(str(name).to_int()):
		return int((slots as Dictionary)[str(name).to_int()])
	return 0


## The body going with what you're doing, worked out the same on every peer from what everyone knows (the rods,
## the wheel, the harpoon) and what you send (`act`, gestures): walking and running (legs and arms swinging, knees
## and elbows bending, a bob), standing easy with the sea (breathing, knees soft), a rod in your hands (cranking:
## the reel arm going round; pumping: leaning back and dropping; braced against a run), the wheel (hands working it
## as she turns), the harpoon (cocked, and the throw), binoculars up, hauling (leaning back, hand over hand), the jig,
## a scoop of chum, bleeding a fish, a stumble when she slams a wave. Pieces turn about x (forward, + raises a
## limb in front / bends an elbow; a knee bends with -), y (twist) and z (out to the side).
func _pose_body(delta: float) -> void:
	if _parts.is_empty():
		return
	var t := Time.get_ticks_msec() * 0.001
	var moved := (_local - _prev_local) * float(Engine.physics_ticks_per_second)    # (a physics tick's step)
	var pace := clampf(Vector2(moved.x, moved.z).length() / SPRINT, 0.0, 1.0)
	_stride += delta * (2.0 + 9.0 * pace)
	var swing := sin(_stride) * 0.75 * pace
	var sea: Node = boat.get("sea") if boat else null
	var id := str(name).to_int()
	var rods: Node = sea.get("rods") if sea else null
	var landing: Node = sea.get("landing") if sea else null
	var helm: Node = boat.get("helm") if boat else null
	var rod: Node = rods.call("held_by", id) if rods else null
	var harpoon: bool = landing != null and int(landing.get("harpoon_holder")) == id
	var doing := act if is_multiplayer_authority() else _net_act
	if _gesture != "":
		_gesture_t += delta
		if _gesture_t > float(GESTURES.get(_gesture, 0.5)):
			_gesture = ""
	# standing easy: knees soft, a breath, the arms hanging a touch forward; walking over that
	var breath := sin(t * 1.7) * 0.02
	var p := {
		"torso": Vector3(-0.04 * pace + breath, sin(_stride) * 0.1 * pace, 0.0),
		"head": Vector3(clampf(_pitch * 0.6, -0.5, 0.6), 0.0, 0.0),
		"arm_l": Vector3(0.08 - swing * 0.7, 0.0, -0.06), "fore_l": Vector3(0.2 + 0.4 * pace, 0.0, 0.0),
		"arm_r": Vector3(0.08 + swing * 0.7, 0.0, 0.06), "fore_r": Vector3(0.2 + 0.4 * pace, 0.0, 0.0),
		"leg_l": Vector3(swing, 0.0, 0.0), "shin_l": Vector3(-0.08 - maxf(0.0, -sin(_stride)) * 1.1 * pace, 0.0, 0.0),
		"leg_r": Vector3(-swing, 0.0, 0.0), "shin_r": Vector3(-0.08 - maxf(0.0, sin(_stride)) * 1.1 * pace, 0.0, 0.0),
	}
	var drop := absf(sin(_stride)) * 0.035 * pace
	var crouch := 0.0
	if rod != null:
		# both hands on it: the left out on the foregrip, the right on the reel
		var lift := float(rod.get("lift"))
		var strain := float(rod.get("strain")) if bool(rod.get("hooked")) else 0.0
		var back := 0.12 + 0.3 * strain + 0.35 * lift          # leaning back into it
		p["torso"] = Vector3(back, 0.0, 0.0)
		p["arm_l"] = Vector3(0.95 + 0.6 * lift, 0.25, -0.1)
		p["fore_l"] = Vector3(0.7, 0.0, 0.0)
		p["arm_r"] = Vector3(0.55 + 0.4 * lift, -0.15, 0.15)
		p["fore_r"] = Vector3(1.15, 0.0, 0.0)
		if doing & ACT_CRANK:
			_crank_ph += delta * 13.0
			p["arm_r"] += Vector3(sin(_crank_ph) * 0.18, 0.0, cos(_crank_ph) * 0.1)
			p["fore_r"] += Vector3(cos(_crank_ph) * 0.35, 0.0, 0.0)
		crouch = 0.08 + 0.12 * strain + 0.1 * lift            # knees bent, braced
	elif harpoon:
		# the harpoon cocked over the shoulder, the off hand pointing; the throw: the arm whips through
		p["arm_l"] = Vector3(1.1, 0.3, -0.1)
		p["fore_l"] = Vector3(0.3, 0.0, 0.0)
		p["arm_r"] = Vector3(2.7, 0.0, 0.25)
		p["fore_r"] = Vector3(1.3, 0.0, 0.0)
		p["torso"] = Vector3(0.08, -0.25, 0.0)
	elif steering:
		# both hands on the wheel, working it as she turns
		var steer := float(helm.get("steer")) if helm else 0.0
		p["arm_l"] = Vector3(1.15 + steer * 0.3, 0.0, -0.05)
		p["fore_l"] = Vector3(0.75, 0.0, 0.0)
		p["arm_r"] = Vector3(1.15 - steer * 0.3, 0.0, 0.05)
		p["fore_r"] = Vector3(0.75, 0.0, 0.0)
		p["torso"] = Vector3(-0.04, steer * 0.12, 0.0)
	if doing & ACT_GLASSES:
		# binoculars up to the eyes, elbows out
		p["arm_l"] = Vector3(1.35, 0.0, -0.55)
		p["fore_l"] = Vector3(2.0, 0.0, 0.0)
		p["arm_r"] = Vector3(1.35, 0.0, 0.55)
		p["fore_r"] = Vector3(2.0, 0.0, 0.0)
	if doing & ACT_HAUL:
		# leaning back on it, hand over hand
		_haul_ph += delta * 4.5
		var heave := sin(_haul_ph)
		p["torso"] = Vector3(0.3 + 0.12 * heave, 0.0, 0.0)
		p["arm_l"] = Vector3(0.9 + 0.35 * heave, 0.0, -0.05)
		p["fore_l"] = Vector3(0.5 - 0.3 * heave, 0.0, 0.0)
		p["arm_r"] = Vector3(0.9 - 0.35 * heave, 0.0, 0.05)
		p["fore_r"] = Vector3(0.5 + 0.3 * heave, 0.0, 0.0)
		crouch = 0.22
	if doing & ACT_JIG:
		# working the jig rod up and down
		p["arm_r"] = Vector3(0.9, 0.0, 0.3)
		p["fore_r"] = Vector3(0.7 + sin(t * 5.0) * 0.45, 0.0, 0.0)
		p["arm_l"] = Vector3(0.6, 0.2, -0.05)
		p["fore_l"] = Vector3(0.9, 0.0, 0.0)
	# the one-off moves, over whatever else
	if _gesture != "":
		var gk := clampf(_gesture_t / float(GESTURES[_gesture]), 0.0, 1.0)
		var arc := sin(gk * PI)              # 0 -> 1 -> 0 over the move
		match _gesture:
			"throw":
				# wound back, then whipped through, leaning into it
				var whip := smoothstep(0.15, 0.45, gk)
				p["arm_r"] = Vector3(lerpf(2.9, 0.7, whip), 0.0, 0.2)
				p["fore_r"] = Vector3(lerpf(1.5, 0.1, whip), 0.0, 0.0)
				p["torso"] = Vector3(lerpf(0.15, -0.3, whip) * (1.0 - smoothstep(0.7, 1.0, gk)), -0.3 * (1.0 - whip), 0.0)
			"scoop":
				# down to the bucket, then flung out over the side
				var fling := smoothstep(0.35, 0.7, gk)
				p["arm_r"] = Vector3(lerpf(0.2, 2.0, fling), 0.0, 0.2)
				p["fore_r"] = Vector3(lerpf(0.9, 0.2, fling), 0.0, 0.0)
				p["torso"] = Vector3(-0.35 * arc, -0.35 * (fling - 0.5), 0.0)
				crouch = maxf(crouch, 0.2 * (1.0 - fling))
			"bleed":
				# down on one knee, the knife in, out
				crouch = maxf(crouch, 0.45 * arc)
				p["torso"] = Vector3(-0.5 * arc, 0.0, 0.0)
				p["arm_r"] = Vector3(0.9 + 0.3 * sin(gk * 18.0) * arc, 0.0, 0.1)
				p["fore_r"] = Vector3(0.6, 0.0, 0.0)
			"reach":
				p["arm_r"] = Vector3(1.1 * arc + 0.1, 0.0, 0.1)
				p["fore_r"] = Vector3(0.3, 0.0, 0.0)
				p["torso"] = Vector3(-0.2 * arc, 0.0, 0.0)
			"stumble":
				# thrown off balance: arms out, a lurch
				p["arm_l"] = Vector3(0.6 * arc, 0.0, -1.1 * arc)
				p["arm_r"] = Vector3(0.6 * arc, 0.0, 1.1 * arc)
				p["torso"] = Vector3(-0.25 * arc, 0.0, 0.15 * sin(gk * 9.0) * arc)
				crouch = maxf(crouch, 0.15 * arc)
	# crouching: down at the hips, thighs forward and shins back so the feet stay put
	if crouch > 0.0:
		var bend := acos(clampf(1.0 - crouch / 0.95 * 1.6, -1.0, 1.0)) * 0.6
		p["leg_l"] += Vector3(bend, 0.0, 0.0)
		p["leg_r"] += Vector3(bend, 0.0, 0.0)
		p["shin_l"] += Vector3(-bend * 2.0, 0.0, 0.0)
		p["shin_r"] += Vector3(-bend * 2.0, 0.0, 0.0)
		p["torso"] += Vector3(-bend * 0.6, 0.0, 0.0)
	var k := minf(1.0, delta * 14.0)
	for part: String in p:
		_aim(part, p[part], k)
	if _body_root:
		_body_root.position.y = lerpf(_body_root.position.y, -drop - crouch * 0.55, k)


## One piece toward its pose (x, y, z: euler, radians), `k` of the way there this frame.
func _aim(part: String, e: Vector3, k: float) -> void:
	var piece := _parts.get(part) as Node3D
	if piece:
		piece.basis = piece.basis.slerp(Basis.from_euler(e) * (_rest[part] as Basis), k)


## A one-off move (GESTURES: the harpoon's throw, a scoop of chum, bleeding a fish, a reach, a stumble): yours, and
## everyone sees it.
func gesture(g: String) -> void:
	if not is_multiplayer_authority():
		return
	if Net.in_session():
		_play_gesture.rpc(g)
	else:
		_play_gesture(g)


@rpc("authority", "call_local", "reliable")
func _play_gesture(g: String) -> void:
	if GESTURES.has(g):
		_gesture = g
		_gesture_t = 0.0


func _exit_tree() -> void:
	if is_instance_valid(body):
		body.queue_free()


## Puts you at a boat-local spot, facing `yaw` (radians round the boat's up axis; 0 faces the bow).
func place(local: Vector3, yaw: float) -> void:
	aloft = false
	body.position = local
	_prev_local = local
	_local = local
	_net_at = local
	_yaw = yaw
	_net_yaw = yaw


func local_position() -> Vector3:
	return body.position


## Mouse look comes first, before any UI could take the motion.
func _input(event: InputEvent) -> void:
	if is_multiplayer_authority() and event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		_yaw -= m.relative.x * LOOK * look_scale
		_pitch = clampf(_pitch - m.relative.y * LOOK * look_scale, -1.45, 1.45)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _at_dock():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact") and steering:
		(boat.get("helm") as Node).call("request", false)
	elif aloft and (event.is_action_pressed("interact") or event.is_action_pressed("drop")):
		var tower: Node = boat.get("tower")
		if tower:
			tower.call("down", self)
		else:
			aloft = false
	elif event.is_action_pressed("interact"):
		var target := _looked_at()
		if target:
			target.call("interact", self)


func _physics_process(delta: float) -> void:
	_prev_local = body.position
	if is_multiplayer_authority():
		_walk(delta)
		act = _doing()
		_send_in -= 1
		if Net.in_session() and _send_in <= 0:
			_send_in = 2      # 30 a second
			_state.rpc(body.position, _yaw, _pitch, act)
	else:
		body.position = body.position.lerp(_net_at, 0.4)
		_yaw = lerp_angle(_yaw, _net_yaw, 0.4)
		_pitch = lerpf(_pitch, _net_pitch, 0.4)
	_local = body.position


## What you're up to that the others can't see for themselves (ACT_*).
func _doing() -> int:
	var sea: Node = boat.get("sea") if boat else null
	if sea == null:
		return 0
	var out := 0
	var glasses: Node = sea.get("binoculars")
	if glasses != null and float(glasses.get("_up")) > 0.3:
		out |= ACT_GLASSES
	var jig: Node = sea.get("jig")
	if jig != null and bool(jig.get("_jigging")):
		out |= ACT_JIG
	var landing: Node = sea.get("landing")
	if landing != null and int(landing.get("_my_pull")) >= 0:
		out |= ACT_HAUL
	var rods: Node = sea.get("rods")
	var live := force_input or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if rods != null and rods.call("held_by", str(name).to_int()) != null and live \
			and Input.is_action_pressed("use_primary"):
		out |= ACT_CRANK
	return out


## Where a crew member is on deck and where they look: sent by their own peer to everyone else.
@rpc("authority", "call_remote", "unreliable_ordered")
func _state(at: Vector3, yaw: float, pitch: float, doing := 0) -> void:
	_net_at = at
	_net_yaw = yaw
	_net_pitch = pitch
	_net_act = doing


func _walk(delta: float) -> void:
	if aloft and boat.get("tower") == null:
		aloft = false          # (she's been swapped for a boat with no tower: down you come)
	if steering or aloft:
		body.velocity = Vector3.ZERO
		return
	var live := force_input or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if live else Vector2.ZERO
	var wish := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y)
	wish = wish.normalized() * (SPRINT if Input.is_action_pressed("sprint") else WALK) * minf(input.length(), 1.0)
	var v := body.velocity
	var flat := Vector3(v.x, 0.0, v.z).move_toward(wish, (ACCEL if body.is_on_floor() else AIR_ACCEL) * delta)
	v.x = flat.x
	v.z = flat.z
	if body.is_on_floor():
		v.y = 0.0
		if live and Input.is_action_just_pressed("jump"):
			v.y = JUMP
	else:
		v.y -= GRAVITY * delta
	body.velocity = v
	body.move_and_slide()


## Every frame: your spot on deck (smoothed between physics ticks) carried by the boat as it is right now.
func _process(delta: float) -> void:
	var f := Engine.get_physics_interpolation_fraction()
	var local := _prev_local.lerp(_local, f)
	var deck := boat.global_transform
	global_transform = deck * Transform3D(Basis(Vector3.UP, _yaw), local)
	_pose_body(delta)
	# Your eyes: level out part of the deck's tilt, keep your own look.
	var tilted := global_transform.basis.orthonormalized()
	var level := Basis(Vector3.UP, tilted.get_euler(EULER_ORDER_YXZ).y)
	var eyes := tilted.slerp(level, STEADY)
	head.global_basis = eyes * Basis(Vector3.RIGHT, _pitch)
	if is_multiplayer_authority():
		if shake <= 0.0:
			arms = minf(arms + REST * delta, 1.0)     # (no fish in your hands)
		_lurch(delta)
		if shake > 0.02:
			var t := Time.get_ticks_msec() * 0.001
			var tremble := Vector3(sin(t * 31.0) + sin(t * 13.0 + 2.0), sin(t * 23.0 + 1.0), 0.0) * 0.006 * shake
			head.global_basis = head.global_basis * Basis.from_euler(tremble + Vector3(-0.035 * shake, 0.0, 0.0))
		_update_prompt()


## A big sea throwing the deck about: lose your feet now and then (a stumble, everyone sees), not at the wheel.
func _lurch(delta: float) -> void:
	if delta <= 0.0:
		return
	var y := boat.global_position.y
	var vy := (y - _deck_y) / delta
	var jerk := absf(vy - _deck_vy)
	_deck_y = y
	_deck_vy = lerpf(_deck_vy, vy, minf(delta * 10.0, 1.0))
	_stumble_in -= delta
	if jerk > LURCH and _stumble_in <= 0.0 and not steering and body.is_on_floor():
		_stumble_in = 5.0
		gesture("stumble")


## At the dock (boat/fish_hold.gd): the dock screen's up, and a click on it mustn't put you back on deck.
func _at_dock() -> bool:
	var sea: Node = boat.get("sea") if boat else null
	var hold: Node = sea.get("fish_hold") if sea else null
	return hold != null and bool(hold.get("docked"))


## What you're looking at that you could press E on (null: nothing): tuna/landing.gd checks you're still on the
## tuna door while you haul.
func looking_at() -> Node:
	return _looked_at()


func _looked_at() -> Node:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * REACH)
	q.collide_with_areas = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return null
	var n := hit["collider"] as Node
	while n and not n.is_in_group("interactable"):
		n = n.get_parent()
	return n


func _update_prompt() -> void:
	var t := _looked_at()
	var text := ""
	if t:
		text = str(t.call("interact_prompt")) if t.has_method("interact_prompt") else "Use"
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
