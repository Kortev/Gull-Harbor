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

signal prompt_changed(text: String)

var boat: Node3D
## Your body in the deck space: its transform is boat-local.
var body: CharacterBody3D
var head: Node3D
var cam: Camera3D
var hand: Node3D
var body_mesh: MeshInstance3D
## Tests drive the keys without a captured mouse.
var force_input := false
var _yaw := 0.0
var _pitch := 0.0
var _prompt := ""
var _prev_local := Vector3.ZERO
var _local := Vector3.ZERO


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
	# What the others see: an oilskin-yellow figure (a proper crew model comes later).
	body_mesh = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.75
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.6, 0.12)
	mat.roughness = 1.0
	cap.material = mat
	body_mesh.mesh = cap
	body_mesh.position.y = 0.875
	add_child(body_mesh)
	if is_multiplayer_authority():
		body_mesh.layers = 1 << 19      # layer 20: your own camera leaves it out, it still casts your shadow
		cam.cull_mask &= ~(1 << 19)
		cam.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	if is_instance_valid(body):
		body.queue_free()


## Puts you at a boat-local spot, facing `yaw` (radians round the boat's up axis; 0 faces the bow).
func place(local: Vector3, yaw: float) -> void:
	body.position = local
	_prev_local = local
	_local = local
	_yaw = yaw


func local_position() -> Vector3:
	return body.position


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		_yaw -= m.relative.x * LOOK
		_pitch = clampf(_pitch - m.relative.y * LOOK, -1.45, 1.45)
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact"):
		var target := _looked_at()
		if target:
			target.call("interact", self)


func _physics_process(delta: float) -> void:
	_prev_local = body.position
	if is_multiplayer_authority():
		_walk(delta)
	_local = body.position


func _walk(delta: float) -> void:
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
func _process(_delta: float) -> void:
	var f := Engine.get_physics_interpolation_fraction()
	var local := _prev_local.lerp(_local, f)
	var deck := boat.global_transform
	global_transform = deck * Transform3D(Basis(Vector3.UP, _yaw), local)
	# Your eyes: level out part of the deck's tilt, keep your own look.
	var tilted := global_transform.basis.orthonormalized()
	var level := Basis(Vector3.UP, tilted.get_euler(EULER_ORDER_YXZ).y)
	var eyes := tilted.slerp(level, STEADY)
	head.global_basis = eyes * Basis(Vector3.RIGHT, _pitch)
	if is_multiplayer_authority():
		_update_prompt()


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
