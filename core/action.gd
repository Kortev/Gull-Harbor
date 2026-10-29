extends Area3D
## Something aboard you press E on (crew/player.gd looks for group "interactable" with interact()): a box you look
## at, what pressing E does, and what the "E: ..." prompt says (an empty prompt hides it). Whoever makes one fills
## in `use` and `prompt`; the harpoon's rack, the tuna door and a fish on deck are each one of these.

var use: Callable           # (player: Node) -> void
var prompt: Callable        # () -> String


func _init(size := Vector3.ONE) -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)


func interact(player: Node) -> void:
	if use.is_valid():
		use.call(player)


func interact_prompt() -> String:
	return str(prompt.call()) if prompt.is_valid() else ""
