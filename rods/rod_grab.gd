extends Area3D
## The part of a rod you press E on (rod.gd puts it there): with a mackerel in your fist and its line in, you hook it
## on (rods/rig.gd); otherwise you ask the spread for the rod.


func interact(player: Node) -> void:
	var rod: Node = get_meta("rod")
	var spread: Node = rod.get("spread")
	var idle := int(rod.get("holder")) == 0 and not bool(rod.get("hooked"))
	var hands: Node = player.get("hands") if player else null
	var carrying := str(hands.call("carrying")) if hands != null else ""
	if idle and not carrying.is_empty() and bool(rod.get("bait_in")):
		(spread.get("rig") as Node).call("begin", int(rod.get("index")), carrying)
		return
	if player != null and idle:
		player.call("gesture", "reach")
	spread.call("request_grab", int(rod.get("index")))


func interact_prompt() -> String:
	var rod: Node = get_meta("rod")
	var spread: Node = rod.get("spread")
	var crew: Node = spread.get("sea").get("crew")
	return rod.call("interact_prompt", crew.get("me") if crew else null)
