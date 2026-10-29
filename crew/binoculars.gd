extends CanvasLayer
## Binoculars: hold B (or the middle mouse button) and your view closes in (ZOOM), looking slower, through the two
## round lenses. Put them on a flock far off and you see what it's doing (tuna/schools.gd's spot_text: bluefin busting
## under diving birds, gulls over little bait, birds sitting on the water while the tuna are down), how far off it is
## and which way; left click calls it, and it's marked on the radar for everyone. Not with a fish on in your hands.

const ZOOM := 8.0             # the field of view through them (degrees; the naked eye's is the camera's own)
const AIM := 0.035            # how close to the middle a flock has to be to make it out (rad)
const REACH := 4500.0         # the furthest you can make one out (m)

var sea: Node                 # sea/sea.gd
## How far they're up to your eyes, 0..1, and the field of view without them.
var _up := 0.0
var _eye_fov := 75.0
var _lenses: ColorRect
var _read: Label
var _looking: Node = null     # the flock in the middle of them
## Times they've been used: the HUD's nudge to use them stops after a few.
var used := 0
var _was_down := true


func _ready() -> void:
	layer = 5
	_lenses = ColorRect.new()
	_lenses.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lenses.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float up = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float r = 0.36;
	float d = min(length(p - vec2(-0.2, 0.0)), length(p - vec2(0.2, 0.0)));
	float dark = smoothstep(r - 0.03, r + 0.005, d);
	COLOR = vec4(0.0, 0.0, 0.0, dark * up);
}
"""
	mat.shader = sh
	_lenses.material = mat
	_lenses.visible = false
	add_child(_lenses)
	_read = Label.new()
	_read.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_read.position = Vector2(-400, -150)
	_read.size = Vector2(800, 80)
	_read.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_read.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_read.add_theme_font_size_override("font_size", 20)
	_read.add_theme_constant_override("outline_size", 6)
	_read.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_read.visible = false
	add_child(_read)


func _process(delta: float) -> void:
	var crew := sea.get("crew") as Node
	var me: Node = crew.get("me") if crew else null
	var cam: Camera3D = me.get("cam") if me else null
	if cam == null:
		return
	var want := Input.is_action_pressed("binoculars") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and not _fish_in_hands()
	if want and _was_down:
		used += 1
	_was_down = not want
	if _up <= 0.0 and want:
		_eye_fov = cam.fov
	_up = move_toward(_up, 1.0 if want else 0.0, delta * 4.0)
	if _up > 0.0:
		cam.fov = lerpf(_eye_fov, ZOOM, _up * _up)
	elif not is_equal_approx(cam.fov, _eye_fov):
		cam.fov = _eye_fov
	me.set("look_scale", cam.fov / _eye_fov)
	_lenses.visible = _up > 0.0
	(_lenses.material as ShaderMaterial).set_shader_parameter("up", _up)
	# what's in the middle of them
	_looking = _aimed_at(cam) if _up > 0.9 else null
	_read.visible = _looking != null
	if _looking != null:
		var schools := sea.get("schools") as Node
		var w := str(schools.call("where", _looking.call("center", schools.call("now"))))
		var text := str(schools.call("spot_text", _looking)) + "\n" + w.substr(0, 1).to_upper() + w.substr(1)
		var marks: Dictionary = schools.get("marks")
		var id := int(_looking.get("id"))
		text += ("   (called by %s)" % str(marks[id])) if marks.has(id) else "   Left click: call it to the crew"
		_read.text = text


func _unhandled_input(event: InputEvent) -> void:
	if _looking != null and event.is_action_pressed("use_primary"):
		(sea.get("schools") as Node).call("call_out", int(_looking.get("id")))
		get_viewport().set_input_as_handled()


## The flock nearest the middle of your view, if one's close enough to it and not too far off to make out.
func _aimed_at(cam: Camera3D) -> Node:
	var schools := sea.get("schools") as Node
	var fwd := -cam.global_basis.z
	var best: Node = null
	var best_a := AIM
	var t := float(schools.call("now"))
	for s: Node in schools.get("schools"):
		var c: Vector2 = s.call("center", t)
		var to := Vector3(c.x, cam.global_position.y * 0.5 + 4.0, c.y) - cam.global_position
		if to.length() > REACH:
			continue
		var a := fwd.angle_to(to.normalized())
		if a < best_a:
			best_a = a
			best = s
	return best


## Both hands on a rod with a fish on: no binoculars.
func _fish_in_hands() -> bool:
	var rods := sea.get("rods") as Node
	var mine: Node = rods.call("held_by", Net.my_id()) if rods else null
	return mine != null and bool(mine.get("hooked"))
