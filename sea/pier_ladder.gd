extends Area3D
## The ladder at the fish pier's end, down its side into the harbour (sea/harbour.gd draws its rails and rungs): the
## way out of the water onto the pier. It works the way a boat's boarding ladder does (boat/ladder.gd, crew/player.gd's
## climb): swim to its foot and E, W up it rung by rung (S back down, E lets go), and over its top onto the pier's
## deck; from the deck, E at its top takes you down it.
##
## A child of the quay (sea/quay.gd), whose frame the climb is in. Its own +z points out from the pier into the water
## (so its foot is +z of it, and the deck -z, as a boat's ladder has them).

const FOOT := -1.4            # the rails' bottom, under the water
const STEP := 0.35
const SWIMMING := 1           # (crew/player.gd's SWIM)
const ON_DECK := 0            # (and its DECK)

var boat: Node3D              # the quay (sea/quay.gd): the frame you climb in
## Where it hangs, in the ladder's own frame: y the pier's deck (its top), z 0 the pier's side.
var spot := Vector3.ZERO
## Which way you face climbing it (the quay frame's yaw: toward the pier).
var face := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("ladders")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, spot.y - FOOT + 0.3, 0.6)
	cs.shape = box
	cs.position = Vector3(0.0, (spot.y + FOOT) * 0.5, 0.3)
	add_child(cs)


func interact(player: Node) -> void:
	var m := int(player.get("mode"))
	if m == SWIMMING or (m == ON_DECK and player.get("boat") == boat):
		player.call("climb", boat)


func interact_prompt() -> String:
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p.is_multiplayer_authority():
			var m := int(p.get("mode"))
			if m == SWIMMING:
				return "Climb out onto the pier"
			return "Climb down" if m == ON_DECK and p.get("boat") == boat else ""
	return ""


## The climb, in the quay's frame, from where you took hold (`from`, your feet): in to the foot of it, up it a rung at
## a time, over its top, onto the pier's deck. Each leg's [end, s].
func path(from: Vector3) -> Array:
	var cap := spot.y
	var foot := transform * Vector3(0.0, FOOT - 0.25, 0.42)
	return [
		[foot, clampf(from.distance_to(foot) / 1.1, 0.3, 1.4)],
		[transform * Vector3(0.0, cap - 0.3, 0.28), 1.3],
		[transform * Vector3(0.0, cap + 0.25, 0.16), 0.25],
		[transform * Vector3(0.0, cap + 0.15, -0.25), 0.22],
		[transform * Vector3(0.0, cap + 0.02, -0.75), 0.4],
	]


func steps() -> int:
	return maxi(2, roundi((spot.y - 0.3 - FOOT) / STEP))
