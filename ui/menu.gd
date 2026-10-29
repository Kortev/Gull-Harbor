extends CanvasLayer
## The Esc menu: back to it, host a crew, join a friend's boat, leave, quit. Shown whenever the mouse is free.
## Steam first (host, invite, your Steam friends with a boat out), the join code under it as the backup.
## (No weather here: the sea decides that, sea/weather.gd.)

var _panel: PanelContainer
var _status: Label
var _address: LineEdit
var _host: Button
var _join: Button
var _leave: Button
var _code_row: HBoxContainer
var _code: Label
var _steam_box: VBoxContainer
var _steam_host: Button
var _steam_invite: Button
var _friends: VBoxContainer
var _friends_in := 0.0


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
	# Steam: the main way (no ports, no codes)
	_steam_box = VBoxContainer.new()
	_steam_host = _button("Host on Steam", func() -> void:
		_status.text = "Making a Steam lobby..."
		Net.host_steam())
	_steam_box.add_child(_steam_host)
	_steam_invite = _button("Invite a Steam friend", func() -> void: Net.steam.call("invite"))
	_steam_box.add_child(_steam_invite)
	_friends = VBoxContainer.new()
	_steam_box.add_child(_friends)
	col.add_child(_steam_box)
	var without := Label.new()
	without.text = "Without Steam: a join code"
	without.modulate = Color(0.6, 0.63, 0.66)
	without.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(without)
	_host = _button("Host with a join code", func() -> void:
		var err := Net.host()
		_status.text = "Hosting. Opening the door on your router..." if err == OK else "Couldn't host (port in use?)")
	col.add_child(_host)
	# the join code, once hosting has it, to copy and send to your friend
	_code_row = HBoxContainer.new()
	_code = Label.new()
	_code.add_theme_font_size_override("font_size", 24)
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_row.add_child(_code)
	_code_row.add_child(_button("Copy", func() -> void:
		DisplayServer.clipboard_set(Net.code)
		_status.text = "Copied. Send it to your friend: they paste it in and press Join."))
	_code_row.visible = false
	col.add_child(_code_row)
	var row := HBoxContainer.new()
	_address = LineEdit.new()
	_address.placeholder_text = "join code from the host (or an address)"
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
	col.add_child(_button("Quit", func() -> void: get_tree().quit()))
	Net.joined.connect(func() -> void: _status.text = "Aboard.")
	Net.hosted.connect(func() -> void:
		if Net.mode == "steam":
			_status.text = "Hosting on Steam. Invite a friend, or they'll see your boat in their menu.")
	Net.opened.connect(func(ok: bool, code: String) -> void:
		_code.text = code
		_status.text = "Your join code: send it to your friend." if ok else \
				"Your router wouldn't open the door (UPnP is off there),\nso this code works on your own Wi-Fi only.\nOver the internet: both install Tailscale and join its address.")
	Net.dropped.connect(func(reason: String) -> void: _status.text = reason)


func _button(text: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on)
	return b


## Your Steam friends with a boat out: a button each.
func _list_friends() -> void:
	for c in _friends.get_children():
		c.queue_free()
	if Net.in_session_or_hosting():
		return
	for f: Dictionary in Net.steam.call("friends_out"):
		var lobby := int(f["lobby"])
		_friends.add_child(_button("Join %s's boat" % f["name"], func() -> void:
			_status.text = "Joining %s..." % f["name"]
			Net.join_steam(lobby)))


func _resume() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	var open := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _headless_shot()
	_panel.visible = open
	if not open:
		return
	var session := Net.in_session()
	_host.disabled = Net.in_session_or_hosting()
	_join.disabled = Net.in_session_or_hosting()
	_leave.disabled = not Net.in_session_or_hosting()
	_code_row.visible = Net.in_session_or_hosting() and multiplayer.is_server() and not Net.code.is_empty()
	var steam_on := bool(Net.steam.get("available"))
	_steam_box.visible = steam_on
	if steam_on:
		_steam_host.disabled = Net.in_session_or_hosting()
		_steam_invite.visible = Net.mode == "steam" and multiplayer.is_server()
		_friends_in -= get_process_delta_time()
		if _friends_in <= 0.0:
			_friends_in = 2.0
			_list_friends()
	if _status.text.is_empty():
		_status.text = "Alone on the boat." if not session else ""


## Screenshots and tests never show the menu.
func _headless_shot() -> bool:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shot") or a.begins_with("--cam") or a.begins_with("--net-report"):
			return true
	return false
