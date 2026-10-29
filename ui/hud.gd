extends CanvasLayer
## The whole HUD, kept minimal: a dot in the middle of the view and the "E: ..." prompt under it.

var _prompt: Label


func _ready() -> void:
	layer = 5
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.55)
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


func follow(player: Node) -> void:
	player.connect("prompt_changed", _on_prompt)


func _on_prompt(text: String) -> void:
	_prompt.text = "" if text.is_empty() else "E: " + text
