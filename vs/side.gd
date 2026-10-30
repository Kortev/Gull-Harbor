extends Node
## One boat's side in VS (vs/vs.gd): what her own things (the boat, the rods, the landing, the fish hold, the chum,
## the jig) see as "the sea". Her own things are hers; everything else (the ocean, the schools, the
## weather, the land) is the one sea's, passed through. The crew are the one crew, except that to the other boat's
## things you aren't aboard: they see a crew with no `me` and a HUD nobody sees (so their notes and their fight
## readout stay on their own crew's screens).

const Hud := preload("res://ui/hud.gd")

var sea: Node              # sea/sea.gd
var vs: Node               # vs/vs.gd
## 0: boat A (the one the sea always had), 1: boat B.
var team := 0
var boat: Node3D
var rods: Node
var landing: Node
var fish_hold: Node
var chum: Node
var jig: Node
var _view: CrewView


func _ready() -> void:
	_view = CrewView.new()
	_view.name = "CrewView"
	_view.crew = sea.get("crew") as Node
	add_child(_view)


func _get(property: StringName) -> Variant:
	if property == &"crew":
		return sea.get("crew") if int(vs.get("my_team")) == team else _view
	return sea.get(property)


## The crew, as the other boat's things see them: everyone's there (on whichever boat), but not you.
class CrewView extends Node:
	var crew: Node
	var me: Node = null
	var hud: CanvasLayer

	func _ready() -> void:
		hud = Hud.new()
		hud.visible = false
		add_child(hud)

	func _get(property: StringName) -> Variant:
		return crew.get(property) if crew != null else null

	func get_player(id: int) -> Node:
		return crew.call("get_player", id) if crew != null else null

	func call_sign(id: int) -> String:
		return str(crew.call("call_sign", id)) if crew != null else ""
