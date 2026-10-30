extends CanvasLayer
## Spotting flocks by eye (no binoculars: the user's call). Put a flock under your crosshair and the HUD says what you
## can make of it from where you are: from far off only that there are birds, which way and how far; closer than READ
## m, what they're doing (tuna/schools.gd's spot_text: diving on bluefin busting the water, gulls over little bait,
## sitting on the water while the tuna are down). Not with a fish on in your hands. (No calling them out: the user's
## call. The sportfisher's radar paints birds in the air on its own; the skiff has none.)

const AIM := 0.06             # how close to the middle of your view a flock has to be (rad)
const REACH := 4500.0         # the furthest a flock can be picked out (m)
const READ := 700.0           # closer than this you can tell what the birds are on (m)

var sea: Node                 # sea/sea.gd
var _read: Label
var _looking: Node = null     # the flock under the crosshair
## Flocks you've picked out (the HUD's nudge to look for them stops after a few).
var used := 0
var _last: Node = null


func _ready() -> void:
	layer = 5
	_read = Label.new()
	_read.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_read.position = Vector2(-300, -250)
	_read.size = Vector2(600, 30)
	_read.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_read.add_theme_font_size_override("font_size", 17)
	_read.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_read.add_theme_constant_override("shadow_offset_x", 1)
	_read.add_theme_constant_override("shadow_offset_y", 1)
	_read.visible = false
	add_child(_read)


func _process(_delta: float) -> void:
	var crew := sea.get("crew") as Node
	var me: Node = crew.get("me") if crew else null
	var cam: Camera3D = me.get("cam") if me else null
	if cam == null:
		return
	var live := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _fish_in_hands()
	_looking = _aimed_at(cam) if live else null
	if _looking != null and _looking != _last:
		used += 1
	_last = _looking
	_read.visible = _looking != null
	if _looking == null:
		return
	var schools := sea.get("schools") as Node
	var at: Vector2 = _looking.call("center", schools.call("now"))
	var here := Vector2(cam.global_position.x, cam.global_position.z)
	var w := str(schools.call("where", at))
	var text: String
	if at.distance_to(here) < READ:
		text = str(schools.call("spot_text", _looking))
	else:
		text = "Birds"
	text += "   " + w.trim_prefix("about ")
	_read.text = text


## The flock nearest the middle of your view, if one's close enough to it and not too far off to pick out.
func _aimed_at(cam: Camera3D) -> Node:
	var schools := sea.get("schools") as Node
	var fwd := -cam.global_basis.z
	var best: Node = null
	var best_a := AIM
	var t := float(schools.call("now"))
	for s: Node in schools.get("schools"):
		var c: Vector2 = s.call("center", t)
		var to := Vector3(c.x, cam.global_position.y * 0.5 + 6.0, c.y) - cam.global_position
		if to.length() > REACH:
			continue
		var a := fwd.angle_to(to.normalized())
		if a < best_a:
			best_a = a
			best = s
	return best


## Both hands on a rod with a fish on: no spotting.
func _fish_in_hands() -> bool:
	var rods := sea.get("rods") as Node
	var mine: Node = rods.call("held_by", Net.my_id()) if rods else null
	return mine != null and bool(mine.get("hooked"))
