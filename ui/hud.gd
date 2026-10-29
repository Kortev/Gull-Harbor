extends CanvasLayer
## The whole HUD, kept minimal: a dot in the middle of the view and the "E: ..." prompt under it; in a fight, what
## the fish is doing (the tell, which says what to do) and a ring round the dot that fills and reddens with the strain.

var _prompt: Label
var _tell: Label
var _ring: Control
var _strain := 0.0
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
	_tell = Label.new()
	_tell.set_anchors_preset(Control.PRESET_CENTER)
	_tell.position += Vector2(-200, 56)
	_tell.size = Vector2(400, 30)
	_tell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tell.add_theme_font_size_override("font_size", 20)
	_tell.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_tell.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_tell.add_theme_constant_override("shadow_offset_x", 1)
	_tell.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_tell)
	_ring = Control.new()
	_ring.set_anchors_preset(Control.PRESET_CENTER)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
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


## In a fight: the tell ("It's running! Let it go") and the strain 0..1 ("" and 0 when there's no fight).
func fight(tell: String, strain: float) -> void:
	_tell.text = tell
	if absf(strain - _strain) > 0.01 or (strain == 0.0) != (_strain == 0.0):
		_strain = strain
		_ring.queue_redraw()


func _draw_ring() -> void:
	if _strain <= 0.0:
		return
	var col := Color(1, 1, 1, 0.5).lerp(Color(1.0, 0.2, 0.1, 0.95), smoothstep(0.5, 0.95, _strain))
	_ring.draw_arc(Vector2.ZERO, 16.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(_strain, 0.0, 1.0), 40, col, 3.0)


func follow(player: Node) -> void:
	player.connect("prompt_changed", _on_prompt)
	_on_prompt("")


func _on_prompt(text: String) -> void:
	_prompt.text = "" if text.is_empty() else "E: " + text
