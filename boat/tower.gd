extends Area3D
## The tuna tower's ladder (the sportfisher's; boat/kinds.gd's "tower" and "tower_foot"): a steel ladder from the
## cockpit up to her hardtop's aft edge, where the tower's legs stand. E on it (hands empty: it takes both to climb)
## and you climb, all the way, rung by rung up the ladder, onto the hardtop and up the tower's leg to the platform
## (crew/player.gd's climb_tower: it carries you, nothing jumps). Up there your eye's five metres higher, so you can
## make out what a flock's on much further off (crew/spotter.gd). You look round but don't walk; E or Q climbs you
## back down the same way. Where you are is yours (crew/player.gd sends it like any step), so nobody asks the host.

const RUNGS := 7
const HIGH := 2.2             # the ladder, deck to hardtop (m)

var boat: Node3D              # boat/boat.gd
## Where you stand up top (your feet) and the foot of the ladder on deck (boat-local).
var top := Vector3.ZERO
var foot := Vector3.ZERO


## Builds the ladder from the deck up to her hardtop's aft edge.
func setup(spec: Dictionary) -> void:
	top = spec["tower"]
	foot = spec["tower_foot"]
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	position = foot + Vector3(0.0, HIGH * 0.5, 0.0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, HIGH, 0.25)
	cs.shape = box
	add_child(cs)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.78, 0.8, 0.8)
	steel.metallic = 0.6
	steel.roughness = 0.35
	for sx: float in [-0.22, 0.22]:
		_bar(Vector3(0.04, HIGH, 0.04), Vector3(sx, 0.0, 0.0), steel)
	for i in RUNGS:
		_bar(Vector3(0.44, 0.03, 0.03), Vector3(0.0, -HIGH * 0.5 + (i + 0.6) * HIGH / RUNGS, 0.0), steel)


func _bar(size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = at
	mi.material_override = mat
	add_child(mi)


func interact(player: Node) -> void:
	if not bool(player.get("aloft")) and hands_free(player):
		player.call("climb_tower", self)


func interact_prompt() -> String:
	return "Climb the tower" if hands_free(null) else "Climb the tower (hands full)"


## Nothing in your hands (a rod, the harpoon): it takes both to climb.
func hands_free(player: Node) -> bool:
	var who := player.get_multiplayer_authority() if player != null else Net.my_id()
	var sea: Node = boat.get("sea")
	var rods: Node = sea.get("rods") if sea else null
	var landing: Node = sea.get("landing") if sea else null
	return (rods == null or rods.call("held_by", who) == null) \
			and (landing == null or int(landing.get("harpoon_holder")) != who)


## The climb, boat-local, from where you stand on deck (`from`, your feet) to the platform: to the foot of the ladder,
## up it to the hardtop, up the tower's aft leg, onto the platform. Each leg's [end, s] (the first leg's time grows
## with how far off you were).
func path(from: Vector3) -> Array:
	var deck := float(boat.get("deck"))
	var at_foot := Vector3(foot.x, deck + 0.02, foot.z + 0.35)
	var roof := foot.y + HIGH
	return [
		[at_foot, clampf(from.distance_to(at_foot) / 1.2, 0.2, 1.4)],
		[Vector3(foot.x, roof - 0.1, foot.z + 0.2), 1.8],
		[Vector3(foot.x * 0.8, roof + 0.15, foot.z - 0.2), 0.45],
		[Vector3(top.x - 0.55, lerpf(roof, top.y, 0.55), lerpf(foot.z, top.z, 0.5)), 1.2],
		[Vector3(top.x - 0.35, top.y + 0.02, top.z + 0.25), 1.0],
		[top + Vector3(0.0, 0.02, 0.0), 0.5],
	]
