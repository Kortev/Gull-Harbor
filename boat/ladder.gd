extends Area3D
## The boarding ladder hooked over a boat's transom (boat/kinds.gd's `ladder`: beside the engines, clear of the tuna
## door): two stainless rails from under the water up over the cap, flat steps between, standing off the transom on
## little feet. In the sea (crew/player.gd), swim up to it and E: you take hold, and W climbs it rung by rung (S back
## down, E lets go), over the cap onto her deck. From her deck, E at the top of it takes you over the cap and down it.
## Any boat's: in VS you can come up the other crew's (and go down your own).
##
## Built in her frame by boat/boat.gd, a child of the boat so it rides her. `path()` is the climb, boat-local.

const RAIL := 0.17            # the rails either side of the middle (m)
const STEP := 0.4             # between the steps
const FOOT := -0.75           # the rails' bottom, under her waterline
const SWIMMING := 1           # (crew/player.gd's SWIM)
const ON_DECK := 0            # (and its DECK)

var boat: Node3D              # boat/boat.gd
## Where it hangs, boat-local: x across, y the transom's cap, z the transom's outside face.
var spot := Vector3.ZERO


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("ladders")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	position = Vector3(spot.x, 0.0, spot.z)
	var cap := spot.y
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, cap - FOOT + 0.3, 0.6)
	cs.shape = box
	cs.position = Vector3(0.0, (cap + FOOT) * 0.5, 0.3)
	add_child(cs)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.8, 0.82, 0.84)
	steel.metallic = 0.6
	steel.roughness = 0.35
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.1, 0.1, 0.11)
	rubber.roughness = 0.9
	for side: float in [-RAIL, RAIL]:
		# up the transom, over the cap and a hand's width down inside it
		_tube(Vector3(side, FOOT, 0.07), Vector3(side, cap + 0.06, 0.07), steel)
		_tube(Vector3(side, cap + 0.06, 0.07), Vector3(side, cap + 0.06, -0.12), steel)
		_tube(Vector3(side, cap + 0.06, -0.12), Vector3(side, cap - 0.1, -0.12), steel)
		# its feet off the transom, rubber-shod
		for y: float in [cap - 0.35, 0.05]:
			_box(Vector3(0.05, 0.05, 0.07), Vector3(side, y, 0.035), rubber)
	var y := FOOT + 0.2
	while y < cap - 0.3:
		_box(Vector3(RAIL * 2.0, 0.025, 0.1), Vector3(0.0, y, 0.1), steel)
		y += STEP


func _tube(a: Vector3, b: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.018
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 6
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = mat
	var up := (b - a).normalized()
	var side := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := up.cross(side).normalized()
	mi.transform = Transform3D(Basis(x, up, x.cross(up)), (a + b) * 0.5)
	add_child(mi)


func _box(size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	add_child(mi)


func interact(player: Node) -> void:
	var m := int(player.get("mode"))
	if m == SWIMMING or (m == ON_DECK and player.get("boat") == boat):
		player.call("climb", boat)


## To someone in the sea, or aboard her at the top of it.
func interact_prompt() -> String:
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p.is_multiplayer_authority():
			var m := int(p.get("mode"))
			if m == SWIMMING:
				return "Climb aboard"
			return "Climb down" if m == ON_DECK and p.get("boat") == boat else ""
	return ""


## The climb, boat-local, from where you took hold (`from`, your feet): in to the bottom of the ladder, up it a step
## at a time, over the cap, down onto her deck. Each leg's [end, s]; the first leg's time grows with how far you
## were.
func path(from: Vector3) -> Array:
	var cap := spot.y
	var deck := float(boat.get("deck"))
	var x := spot.x
	var z := spot.z
	var foot := Vector3(x, FOOT - 0.25, z + 0.42)
	return [
		[foot, clampf(from.distance_to(foot) / 1.1, 0.3, 1.4)],
		[Vector3(x, cap - 0.3, z + 0.28), 1.0],
		[Vector3(x, cap + 0.18, z + 0.16), 0.22],
		[Vector3(x, cap + 0.12, z - 0.25), 0.22],
		[Vector3(x, deck + 0.02, z - 0.75), 0.4],
	]


## How many steps the climb goes up (the second leg), for the arms and legs.
func steps() -> int:
	return maxi(2, roundi((spot.y - 0.3 - FOOT) / STEP))
