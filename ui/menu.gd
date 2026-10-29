extends CanvasLayer
## The Esc menu: back to it, host a crew, join a friend's boat, leave, quit; and (host only, for now) the
## conditions: calm, sunny, fog, rain, heavy, storm, day or night. Shown whenever the mouse is free.

const CONDITIONS: Array[String] = ["calm", "sunny", "fog", "rain", "heavy", "storm"]

var _panel: PanelContainer
var _status: Label
var _address: LineEdit
var _host: Button
var _join: Button
var _leave: Button
var _weather: Array[Button] = []
var _night: CheckButton


func _ready() -> void:
	layer = 10
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(420, 0)
	_panel.position = Vector2(-210, -170)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.05, 0.06, 0.88)
	box.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	var title := Label.new()
	title.text = "BLUEFIN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	col.add_child(title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.modulate = Color(0.75, 0.78, 0.8)
	col.add_child(_status)
	col.add_child(_button("Back to the deck", _resume))
	_host = _button("Host a crew (port %d)" % Net.PORT, func() -> void:
		var err := Net.host()
		_status.text = "Hosting. Friends join your address." if err == OK else "Couldn't host (port in use?)")
	col.add_child(_host)
	var row := HBoxContainer.new()
	_address = LineEdit.new()
	_address.placeholder_text = "friend's address (127.0.0.1)"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_address)
	_join = _button("Join", func() -> void:
		_status.text = "Joining..." if Net.join(_address.text) == OK else "Couldn't start joining")
	row.add_child(_join)
	col.add_child(row)
	_leave = _button("Leave the crew", func() -> void:
		Net.leave()
		var crew := get_parent().get("crew") as Node
		crew.call("start_solo"))
	col.add_child(_leave)
	var wrow := HBoxContainer.new()
	for c in CONDITIONS:
		var b := _button(c, func() -> void: _set_conditions(c, bool(get_parent().get("night"))))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrow.add_child(b)
		_weather.append(b)
	col.add_child(wrow)
	_night = CheckButton.new()
	_night.text = "Night"
	_night.toggled.connect(func(on: bool) -> void:
		_set_conditions(str(get_parent().get("condition")), on))
	col.add_child(_night)
	col.add_child(_button("Quit", func() -> void: get_tree().quit()))
	Net.joined.connect(func() -> void: _status.text = "Aboard.")
	Net.dropped.connect(func(reason: String) -> void: _status.text = reason)


func _button(text: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on)
	return b


func _set_conditions(c: String, is_night: bool) -> void:
	(get_parent().get("crew") as Node).call("set_conditions", c, is_night)


func _resume() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	var open := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _headless_shot()
	_panel.visible = open
	if not open:
		return
	var session := Net.in_session()
	_host.disabled = session
	_join.disabled = session
	_leave.disabled = not session
	for b in _weather:
		b.disabled = not Net.is_host()
		b.modulate = Color(1, 0.85, 0.4) if b.text == str(get_parent().get("condition")) else Color.WHITE
	_night.disabled = not Net.is_host()
	_night.set_pressed_no_signal(bool(get_parent().get("night")))
	if _status.text.is_empty():
		_status.text = "Alone on the boat." if not session else ""


## Screenshots and tests never show the menu.
func _headless_shot() -> bool:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shot") or a.begins_with("--cam") or a.begins_with("--net-report"):
			return true
	return false
