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
	for n: String in ["torso", "head", "arm_l", "arm_r", "leg_l", "leg_r"]:
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
	body_mesh = _parts.get("torso") as MeshInstance3D


## Which crew member you are, for your oilskins' colour (crew/crew.gd's spawn slot; 0 alone).
func _slot() -> int:
	var crew := get_parent()
	var slots: Variant = crew.get("slots") if crew else null
	if slots is Dictionary and (slots as Dictionary).has(str(name).to_int()):
		return int((slots as Dictionary)[str(name).to_int()])
	return 0


## The body going with what you're doing: legs and arms swinging as you walk, arms out to a rod or the wheel, the
## throwing arm up with the harpoon, the head with your look.
func _pose_body(delta: float) -> void:
	if _parts.is_empty():
		return
	var moved := (_local - _prev_local) * float(Engine.physics_ticks_per_second)    # (a physics tick's step)
	var pace := clampf(Vector2(moved.x, moved.z).length() / SPRINT, 0.0, 1.0)
	_stride += delta * (2.0 + 9.0 * pace)
	var swing := sin(_stride) * 0.7 * pace
	var sea: Node = boat.get("sea") if boat else null
	var id := str(name).to_int()
	var rods: Node = sea.get("rods") if sea else null
	var landing: Node = sea.get("landing") if sea else null
	var on_rod: bool = rods != null and rods.call("held_by", id) != null
	var harpoon: bool = landing != null and int(landing.get("harpoon_holder")) == id
	var reach := on_rod or steering
	_turn("leg_l", swing)
	_turn("leg_r", -swing)
	_turn("arm_l", 1.15 if reach or harpoon else -swing * 0.6)
	_turn("arm_r", 1.15 if reach else (2.6 if harpoon else swing * 0.6))
	_turn("head", clampf(_pitch * 0.6, -0.5, 0.6))


func _turn(part: String, angle: float) -> void:
	var p := _parts.get(part) as Node3D
	if p:
		p.basis = p.basis.slerp(Basis(Vector3.RIGHT, angle) * (_rest[part] as Basis), 0.25)


func _exit_tree() -> void:
	if is_instance_valid(body):
		body.queue_free()


## Puts you at a boat-local spot, facing `yaw` (radians round the boat's up axis; 0 faces the bow).
func place(local: Vector3, yaw: float) -> void:
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
	elif event.is_action_pressed("interact"):
		var target := _looked_at()
		if target:
			target.call("interact", self)


func _physics_process(delta: float) -> void:
	_prev_local = body.position
	if is_multiplayer_authority():
		_walk(delta)
		_send_in -= 1
		if Net.in_session() and _send_in <= 0:
			_send_in = 2      # 30 a second
			_state.rpc(body.position, _yaw, _pitch)
	else:
		body.position = body.position.lerp(_net_at, 0.4)
		_yaw = lerp_angle(_yaw, _net_yaw, 0.4)
		_pitch = lerpf(_pitch, _net_pitch, 0.4)
	_local = body.position


## Where a crew member is on deck and where they look: sent by their own peer to everyone else.
@rpc("authority", "call_remote", "unreliable_ordered")
func _state(at: Vector3, yaw: float, pitch: float) -> void:
	_net_at = at
	_net_yaw = yaw
	_net_pitch = pitch


func _walk(delta: float) -> void:
	if steering:
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
		if shake > 0.02:
			var t := Time.get_ticks_msec() * 0.001
			var tremble := Vector3(sin(t * 31.0) + sin(t * 13.0 + 2.0), sin(t * 23.0 + 1.0), 0.0) * 0.006 * shake
			head.global_basis = head.global_basis * Basis.from_euler(tremble + Vector3(-0.035 * shake, 0.0, 0.0))
		_update_prompt()


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
