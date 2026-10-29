extends Area3D
## The fighting chair (the sportfisher's, in her cockpit facing aft: boat/boat.gd's `chair`). E on it and you sit
## down; with a rod in your hands its butt goes in the chair's gimbal and you fight the fish from there, your legs
## and back taking the weight (tuna/fight.gd's CHAIR_ARMS), the chair swinging round as you follow the fish. Or just
## sit and watch the baits. E or Q gets you up. Where you are and that you're sitting are yours (crew/player.gd sends
## them), so nobody asks the host; the chair turns to whoever's in it.

var boat: Node3D          # boat/boat.gd
var chair: Node3D         # her chair (the model's piece: it swivels on its pedestal)
var _base := Basis.IDENTITY


func setup(on: Node3D) -> void:
	chair = on
	_base = chair.basis
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	position = chair.position + Vector3(0.0, 0.5, 0.0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	cs.shape = box
	add_child(cs)


func interact(player: Node) -> void:
	if _sitter() == null and not _harpoon(player):
		sit(player)


func interact_prompt() -> String:
	if _sitter() != null:
		return ""
	var crew: Node = boat.get("sea").get("crew")
	var me: Node = crew.get("me") if crew else null
	var rods: Node = boat.get("sea").get("rods")
	var rod: Node = rods.call("held_by", Net.my_id()) if rods and me else null
	if rod != null and bool(rod.get("hooked")):
		return "Fight it from the chair"
	return "Sit in the chair"


## Down in the chair, facing aft (or the way you were facing, if that's more aft).
func sit(player: Node) -> void:
	var yaw := float(player.get("_yaw"))
	player.call("place", chair.position + Vector3(0.0, 0.0, 0.05), yaw if cos(yaw) < 0.0 else PI)
	player.set("seated", true)
	if player.is_multiplayer_authority():
		var hud: Node = boat.get("sea").get("crew").get("hud")
		var rods: Node = boat.get("sea").get("rods")
		var rod: Node = rods.call("held_by", Net.my_id()) if rods else null
		hud.call("notify", ("The rod's in the gimbal: your legs take the weight, so your arms last longer. You can't "
				+ "walk it to a corner from here, so keep the stern on it. E or Q to get up.") if rod != null
				else "Sitting in the fighting chair. E or Q to get up.")


## Up, beside the chair.
func get_up(player: Node) -> void:
	var yaw := float(player.get("_yaw"))
	player.call("place", chair.position + Vector3(0.65, 0.05, 0.0), yaw)


func _process(_delta: float) -> void:
	# the chair swings round with whoever's in it (it faces aft when they face aft)
	var p := _sitter()
	if p != null:
		var yaw := float(p.get("_yaw"))
		chair.basis = Basis(Vector3.UP, yaw - PI) * _base


func _sitter() -> Node:
	var crew: Node = boat.get("sea").get("crew")
	if crew == null:
		return null
	for p: Node in crew.get_children():
		if p.has_method("is_seated") and bool(p.call("is_seated")):
			return p
	return null


func _harpoon(player: Node) -> bool:
	var landing: Node = boat.get("sea").get("landing")
	return landing != null and int(landing.get("harpoon_holder")) == player.get_multiplayer_authority()
