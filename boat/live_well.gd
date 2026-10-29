extends Area3D
## The live well's lid, to press E on (boat/lids.gd): up it comes for a look at the mackerel in there.

var lids: Node            # boat/lids.gd


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false


func interact(_player: Node) -> void:
	lids.call("look_in")


func interact_prompt() -> String:
	var n := int(lids.call("mackerel"))
	if not bool(lids.get("boat").get("sea").get("fish_hold").call("has_gear", "bait")):
		return "The live well (empty: buy the live-bait well at the dock)"
	return "Look in the live well (%d mackerel)" % n
