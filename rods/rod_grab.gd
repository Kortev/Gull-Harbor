extends Area3D
## The part of a rod you press E on (rod.gd puts it there): asks the spread for the rod.


func interact(player: Node) -> void:
	var rod: Node = get_meta("rod")
	var spread: Node = rod.get("spread")
	var idle := int(rod.get("holder")) == 0 and not bool(rod.get("hooked"))
	if player != null and idle:
		player.call("gesture", "reach")      # (reeling a line in, or a fresh bait on)
	var hands: Node = player.get("hands") if player else null
	if idle and hands != null and str(hands.get("item")) == "bait" and not bool(spread.call("fighting")):
		spread.call("request_bait", int(rod.get("index")))
	else:
		spread.call("request_grab", int(rod.get("index")))


func interact_prompt() -> String:
	var rod: Node = get_meta("rod")
	var spread: Node = rod.get("spread")
	var crew: Node = spread.get("sea").get("crew")
	return rod.call("interact_prompt", crew.get("me") if crew else null)
