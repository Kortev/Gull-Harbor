extends Area3D
## Somewhere to sit (boat/kinds.gd's "seats", and the sportfisher's fighting chair: boat/boat.gd's `chair`). E on it
## and you sit down (or lean, on a leaning post), to watch the baits; E or Q gets you up. You look round but don't
## walk. The fighting chair is more: with a rod in your hands its butt goes in the chair's gimbal and you fight the
## fish from there, your legs and back taking the weight (tuna/fight.gd's CHAIR_ARMS), the chair swinging round with
## you. Where you are and that you're sitting are yours (crew/player.gd sends them), so nobody asks the host.

var boat: Node3D          # boat/boat.gd
## The fighting chair's model (it swivels on its pedestal), or null for a plain seat.
var chair: Node3D
## What it is ("the bench"), where your feet go when you sit (boat-local), which way you face, and whether you lean
## on it rather than sit.
var title := ""
var feet := Vector3.ZERO
var face := 0.0
var lean := false
var _base := Basis.IDENTITY


## A plain seat: `top` the middle of its seat (boat-local), facing `yaw`.
func setup(spec: Dictionary) -> void:
	title = spec["name"]
	face = spec["face"]
	lean = bool(spec.get("lean", false))
	var top: Vector3 = spec["at"]
	var fwd := Vector3(-sin(face), 0.0, -cos(face))
	feet = top - Vector3(0.0, 0.5 if lean else 0.55, 0.0) + fwd * (0.25 if lean else 0.1)
	_area(top, Vector3(0.6, 0.5, 0.6))


## The fighting chair, on its model.
func setup_chair(on: Node3D) -> void:
	chair = on
	_base = chair.basis
	title = "the fighting chair"
	face = PI
	feet = chair.position + Vector3(0.0, 0.0, 0.05)
	_area(chair.position + Vector3(0.0, 0.5, 0.0), Vector3(0.8, 0.8, 0.8))


func _area(at: Vector3, size: Vector3) -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	position = at
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)


func interact(player: Node) -> void:
	if _sitter() == null and not _harpoon(player):
		sit(player)


func interact_prompt() -> String:
	if _sitter() != null:
		return ""
	if chair != null:
		var rods: Node = boat.get("sea").get("rods")
		var rod: Node = rods.call("held_by", Net.my_id()) if rods else null
		if rod != null and bool(rod.get("hooked")):
			return "Fight it from the chair"
		return "Sit in the chair"
	return ("Lean on " if lean else "Sit on ") + title


## Down in it, facing its way (the fighting chair: the way you were facing, if that's more aft than not).
func sit(player: Node) -> void:
	var yaw := face
	if chair != null:
		var was := float(player.get("_yaw"))
		yaw = was if cos(was) < 0.0 else PI
	player.call("place", feet, yaw)
	player.set("seated", true)
	player.set("sat_in", self)
	if not player.is_multiplayer_authority():
		return
	var hud: Node = boat.get("sea").get("crew").get("hud")
	var rods: Node = boat.get("sea").get("rods")
	var rod: Node = rods.call("held_by", Net.my_id()) if rods else null
	if chair != null and rod != null:
		hud.call("notify", "The rod's in the gimbal: your legs take the weight, so your arms last longer. You can't "
				+ "walk it to a corner from here, so keep the stern on it. E or Q to get up.")
	else:
		hud.call("notify", "%s %s. E or Q to get up." % ["Leaning on" if lean else "Sitting on", title])


## Up: a step forward off a seat, beside the fighting chair.
func get_up(player: Node) -> void:
	var yaw := float(player.get("_yaw"))
	var ahead := Vector3(-sin(face), 0.0, -cos(face)) * 0.45
	var at := feet + (ahead if chair == null else Vector3(0.65, 0.0, 0.0))
	player.call("place", Vector3(at.x, float(boat.get("deck")) + 0.05, at.z), yaw)


func _process(_delta: float) -> void:
	# the fighting chair swings round with whoever's in it (it faces aft when they face aft)
	if chair == null:
		return
	var p := _sitter()
	if p != null:
		chair.basis = Basis(Vector3.UP, float(p.get("_yaw")) - PI) * _base


## Whoever's in it (as far as this machine knows: near enough is in it).
func _sitter() -> Node:
	var crew: Node = boat.get("sea").get("crew")
	if crew == null:
		return null
	for p: Node in crew.get_children():
		if p.has_method("is_seated") and bool(p.call("is_seated")) \
				and Vector2(p.local_position().x - feet.x, p.local_position().z - feet.z).length() < 0.3:
			return p
	return null


func _harpoon(player: Node) -> bool:
	var landing: Node = boat.get("sea").get("landing")
	return landing != null and int(landing.get("harpoon_holder")) == player.get_multiplayer_authority()
