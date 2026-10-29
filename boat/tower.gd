extends Area3D
## The tuna tower's ladder (the sportfisher's; boat/kinds.gd's "tower" and "ladder"). E on it and you're up top, your
## eye five metres higher: through the binoculars you can read the water under a flock much further off than from the
## deck (crew/binoculars.gd). Up there you look round but don't walk; E or Q climbs back down to the foot of the
## ladder. Where you are is yours (crew/player.gd sends it like any step), so nobody asks the host.

var boat: Node3D          # boat/boat.gd
## Where you stand up top (your feet) and the foot of the ladder on deck (boat-local).
var top := Vector3.ZERO
var foot := Vector3.ZERO


## Builds the ladder from the deck up to her hardtop's aft edge, where the tower's legs stand.
func setup(spec: Dictionary) -> void:
	top = spec["tower"]
	foot = spec["ladder"]
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	var high := 2.2
	position = foot + Vector3(0.0, high * 0.5, 0.0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, high, 0.25)
	cs.shape = box
	add_child(cs)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.78, 0.8, 0.8)
	steel.metallic = 0.6
	steel.roughness = 0.35
	for sx: float in [-0.22, 0.22]:
		_bar(Vector3(0.04, high, 0.04), Vector3(sx, 0.0, 0.0), steel)
	var rungs := 7
	for i in rungs:
		_bar(Vector3(0.44, 0.03, 0.03), Vector3(0.0, -high * 0.5 + (i + 0.6) * high / rungs, 0.0), steel)


func _bar(size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = at
	mi.material_override = mat
	add_child(mi)


func interact(player: Node) -> void:
	if not bool(player.get("aloft")) and _hands_free(player):
		up(player)


func interact_prompt() -> String:
	return "Climb the tower" if _hands_free(null) else "Climb the tower (put down what you're holding)"


## Nothing in your hands (a rod, the harpoon): it takes both to climb.
func _hands_free(player: Node) -> bool:
	var who := player.get_multiplayer_authority() if player != null else Net.my_id()
	var sea: Node = boat.get("sea")
	var rods: Node = sea.get("rods")
	var landing: Node = sea.get("landing")
	return (rods == null or rods.call("held_by", who) == null) \
			and (landing == null or int(landing.get("harpoon_holder")) != who)


## Up top, facing forward.
func up(player: Node) -> void:
	player.call("place", top + Vector3(0, 0.05, 0), 0.0)
	player.set("aloft", true)
	if player.is_multiplayer_authority():
		var hud: Node = boat.get("sea").get("crew").get("hud")
		hud.call("notify", "Up the tower: hold B for the binoculars, you can read the water much further off from up "
				+ "here. E or Q to climb down.")


## Back down at the foot of the ladder, facing aft into the cockpit.
func down(player: Node) -> void:
	player.call("place", foot + Vector3(0, 0.05, 0.45), PI)
