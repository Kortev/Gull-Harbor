extends Area3D
## The part of a rod you press E on (rod.gd puts it there): asks the spread for the rod.


func interact(player: Node) -> void:
	var rod: Node = get_meta("rod")
	if player != null and int(rod.get("holder")) == 0 and not bool(rod.get("hooked")):
		player.call("gesture", "reach")      # (reeling a line in, or a fresh bait on)
	rod.get("spread").call("request_grab", int(rod.get("index")))


func interact_prompt() -> String:
	var rod: Node = get_meta("rod")
	return rod.call("interact_prompt", null)
