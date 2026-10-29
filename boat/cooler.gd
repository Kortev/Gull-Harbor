extends Area3D
## The cooler (the sportfisher's, by her wheelhouse: boat/kinds.gd's "cooler"). E on it and you crack a drink: a swig,
## and whatever's in there this time. Just for fun: it does nothing to the fishing.

const Sfx := preload("res://audio/sfx.gd")
const DRINKS := [
	"A can of Gull Cola. Warm. Somebody forgot the ice again.",
	"Ginger ale. Captain's rule: nothing stronger till the fish is in the box.",
	"Iced tea from the bottom of the cooler. Tastes faintly of bait.",
	"The last orange soda. Whoever packed this cooler owes you one.",
	"Bilge Brew Root Beer. You don't want to know where it's made.",
	"Half a coffee in a thermos from this morning. Cold now. Still coffee.",
	"A can of Sea Mist. It's mostly sea mist.",
	"Something sticky. You drink it anyway: you're at sea.",
]

var boat: Node3D          # boat/boat.gd
var _last := -1


func setup(at: Vector3) -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	position = at + Vector3(0.0, -0.2, 0.0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.78, 0.5, 0.55)
	cs.shape = box
	add_child(cs)


func interact(player: Node) -> void:
	if _hands_full(player):
		return
	player.call("gesture", "drink")
	Sfx.play_point(self, global_position, "kit.switch", 0.6)
	if player.is_multiplayer_authority():
		var i := randi() % DRINKS.size()
		if i == _last:
			i = (i + 1) % DRINKS.size()
		_last = i
		var hud: Node = boat.get("sea").get("crew").get("hud")
		hud.call("notify", DRINKS[i])


func interact_prompt() -> String:
	return "Grab a drink" if not _hands_full(null) else ""


## A rod or the harpoon in your hands: no hand free for a can.
func _hands_full(player: Node) -> bool:
	var who := player.get_multiplayer_authority() if player != null else Net.my_id()
	var sea: Node = boat.get("sea")
	var rods: Node = sea.get("rods")
	var landing: Node = sea.get("landing")
	return (rods != null and rods.call("held_by", who) != null) \
			or (landing != null and int(landing.get("harpoon_holder")) == who)
