extends CanvasLayer
## Spotting flocks by eye (no binoculars: the user's call). Put a flock under your crosshair and the HUD says what you
## can make of it from where you are: from far off only that there are birds, which way and how far; closer than
## read_range (further from up the tower), what they're doing (tuna/schools.gd's spot_text: diving on bluefin busting the water, gulls over little bait,
## sitting on the water while the tuna are down). Not with a fish on in your hands. (No calling them out: the user's
## call. But a flock you pick out goes on the chart plotter as a mark where it was then, for everyone aboard:
## boat/plotter.gd. The radar paints birds in the air on its own: tuna/radar.gd.)
##
## Not from the wheel with her running (faster than RUNNING): she's slamming along and the captain's eyes are on the
## water ahead. The mate picks the birds out; the captain eases off to look for himself.

const AIM := 0.06             # how close to the middle of your view a flock has to be (rad)
const REACH := 4500.0         # the furthest a flock can be picked out (m)
## Closer than this you can tell what the birds are on (m), from the deck (your eye about EYE m over the sea); the
## higher your eye the further, like the horizon (READ * sqrt(height / EYE)): up the sportfisher's tuna tower
## (boat/tower.gd), about 1.3 km.
const READ := 700.0
const EYE := 2.2
const RUNNING := 6.0          # at the wheel faster than this (m/s, about 12 knots), no spotting

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
	var live := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _fish_in_hands() and can_spot(me)
	_looking = _aimed_at(cam) if live else null
	if _looking != null and _looking != _last:
		used += 1
		var plotter: Node = sea.get("plotter")
		if plotter != null:
			plotter.call("saw", _looking)
	_last = _looking
	_read.visible = _looking != null
	if _looking == null:
		return
	_read.text = describe(cam, _looking)


## What you make of flock `s` from where your eye is (`cam`): what it's on if it's near enough to tell (further from
## higher up), else just birds (or the whale or the dolphins with them); and which way and how far.
func describe(cam: Camera3D, s: Node) -> String:
	var schools := sea.get("schools") as Node
	var at: Vector2 = s.call("center", schools.call("now"))
	var here := Vector2(cam.global_position.x, cam.global_position.z)
	var w := str(schools.call("where", at))
	var text: String
	if at.distance_to(here) < read_range(cam):
		text = str(schools.call("spot_text", s))
	else:
		# a whale's blow or a pod's splashes catch your eye before the birds do
		var lead: Node3D = s.get("lead")
		text = Leads.far_text(lead, at.distance_to(here)) if lead != null else ""
		if text == "":
			text = "Birds"
	return text + "   " + w.trim_prefix("about ")


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


## How far off you can tell what a flock's on, from where your eye is.
static func read_range(cam: Camera3D) -> float:
	return READ * sqrt(maxf(cam.global_position.y, 1.0) / EYE)


## Whether `who` can pick birds out: not at the wheel with her running.
static func can_spot(who: Node) -> bool:
	if who == null or not bool(who.get("steering")):
		return true
	var boat: Node = who.get("boat")
	var helm: Node = boat.get("helm") if boat != null else null
	return helm == null or absf(float(helm.get("speed"))) <= RUNNING


## Both hands on a rod with a fish on: no spotting.
func _fish_in_hands() -> bool:
	var rods := sea.get("rods") as Node
	var mine: Node = rods.call("held_by", Net.my_id()) if rods else null
	return mine != null and bool(mine.get("hooked"))
