extends CanvasLayer
## The whole HUD, kept minimal: a dot in the middle of the view and the "E: ..." prompt under it.

var _prompt: Label
var _note: Label
var _note_t := 0.0


func _ready() -> void:
	layer = 5
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.55)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE    # the captured cursor sits right on it
	dot.size = Vector2(3, 3)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(1.5, 1.5)
	add_child(dot)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position += Vector2(-150, 26)
	_prompt.size = Vector2(300, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("shadow_offset_x", 1)
	_prompt.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_prompt)
	_note = Label.new()
	_note.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_note.position += Vector2(-300, 40)
	_note.size = Vector2(600, 30)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_child(_note)


## A line of text at the top for a few seconds ("The host left.").
func notify(text: String) -> void:
	_note.text = text
	_note.modulate.a = 1.0
	_note_t = 4.0


func _process(delta: float) -> void:
	_note_t -= delta
	_note.modulate.a = clampf(_note_t, 0.0, 1.0)


func follow(player: Node) -> void:
	player.connect("prompt_changed", _on_prompt)
	_on_prompt("")


func _on_prompt(text: String) -> void:
	_prompt.text = "" if text.is_empty() else "E: " + text
