extends CanvasLayer
## The menu, shown whenever the mouse is free. At the dock (boat/fish_hold.gd's `docked`: a game starts there, and
## heading in brings you back): the last trip's slip, the bank, which boat (take her, buy her, or charter her for the
## day), the gear for sale, and Head out. Out there (Esc): back to the deck, or head in and sell the catch. Always:
## host a crew, join a friend's boat, leave, quit.
## Steam first (host, invite, your Steam friends with a boat out), the join code under it as the backup.
## (No weather here: the sea decides that, sea/weather.gd.)

const FishHold := preload("res://boat/fish_hold.gd")
const Kinds := preload("res://boat/kinds.gd")
const Manual := preload("res://ui/manual.gd")

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
var _head_in: Button
var _back: Button
## The dock: the slip, the bank, the boats, the gear, Head out (built again whenever any of it changes: _dock_of).
var _dock: VBoxContainer
var _dock_of := []
## The boat's owner's manual (ui/manual.gd), open instead of the menu.
var _manual: Manual
var _reading := false


func _ready() -> void:
	layer = 10
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(540, 600)
	_panel.position = Vector2(-270, -300)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.05, 0.06, 0.9)
	box.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var title := Label.new()
	title.text = "BLUEFIN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	col.add_child(title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.modulate = Color(0.75, 0.78, 0.8)
	col.add_child(_status)
	_back = _button("Back to the deck", _resume)
	col.add_child(_back)
	col.add_child(_button("The owner's manual", func() -> void: _reading = true))
	_manual = Manual.new(get_parent().get("tips") as Node)
	_manual.set_anchors_preset(Control.PRESET_CENTER)
	_manual.custom_minimum_size = Vector2(820, 560)
	_manual.position = Vector2(-410, -280)
	_manual.visible = false
	add_child(_manual)
	var shut := Button.new()
	shut.text = "Close the manual"
	shut.pressed.connect(func() -> void: _reading = false)
	shut.set_anchors_preset(Control.PRESET_CENTER)
	shut.position = Vector2(-70, 290)
	shut.visible = false
	shut.name = "CloseManual"
	add_child(shut)
	_dock = VBoxContainer.new()
	_dock.add_theme_constant_override("separation", 6)
	col.add_child(_dock)
	_head_in = _button("Head in and sell the catch", func() -> void:
		var hold := _fish_hold()
		if hold:
			hold.call("head_in"))
	col.add_child(_head_in)
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
	_reading = _reading and open
	_panel.visible = open and not _reading
	_manual.visible = _reading
	(get_node("CloseManual") as Control).visible = _reading
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
	var hold := _fish_hold()
	var docked: bool = hold != null and bool(hold.get("docked"))
	_back.visible = not docked
	_head_in.visible = hold != null and Net.is_host() and not docked
	var now := [docked, Net.is_host(), (hold.get("sale") as Dictionary).duplicate(true), hold.get("bank"),
			hold.get("kind"), (hold.get("owned") as Array).duplicate(), (hold.get("gear") as Array).duplicate(),
			hold.get("quota"), hold.get("earned"), hold.get("day")] if hold else []
	var vs := get_parent().get("vs") as Node
	if vs != null:
		now.append_array([vs.get("on"), (vs.get("teams") as Dictionary).duplicate()])
	if now != _dock_of:
		_dock_of = now
		_fill_dock(hold, docked)


func _fish_hold() -> Node:
	return get_parent().get("fish_hold") as Node


## The dock: the last sale's slip, the bank, the boats, the gear, and Head out (the skipper's; a crewmate sees the
## skipper's choices and waits).
func _fill_dock(hold: Node, docked: bool) -> void:
	for c in _dock.get_children():
		_dock.remove_child(c)
		c.queue_free()
	if hold == null or not docked:
		return
	var skipper := Net.is_host()
	var sold: Dictionary = hold.get("sale")
	# how the quota went, if that was its last day
	var verdict := str(sold.get("verdict", ""))
	if verdict == "met":
		var q: Array = sold["quota"]
		_dock.add_child(_slip_line("QUOTA %d MADE: $%s of $%s" % [int(q[0]), _money(int(q[1])), _money(int(q[2]))],
				24, Color(0.6, 1.0, 0.6)))
		_dock.add_child(_slip_line("The bank wants $%s next, in %d days." % [_money(int(sold["next"])),
				FishHold.DAYS]))
		_dock.add_child(HSeparator.new())
	elif verdict == "lost":
		var q: Array = sold["quota"]
		var run: Dictionary = sold["run"]
		_dock.add_child(_slip_line("THE BANK TOOK THE BOAT", 26, Color(1.0, 0.45, 0.4)))
		_dock.add_child(_slip_line("$%s of the $%s owed. That run made %d quota%s: %d fish, the biggest %d kg." % [
				_money(int(q[1])), _money(int(q[2])), int(run["quotas"]), "" if int(run["quotas"]) == 1 else "s",
				int(run["fish"]), roundi(float(run["biggest"]))]))
		_dock.add_child(_slip_line("A new start: the skiff and $%s." % _money(FishHold.START_CASH)))
		_dock.add_child(HSeparator.new())
	if bool(sold.get("abandoned", false)):
		_dock.add_child(_slip_line("Last time you left her out there. That day's gone, and the fuel's still owed.",
				15, Color(1.0, 0.75, 0.6)))
	if not sold.is_empty():
		_dock.add_child(_slip_line("SOLD AT THE DOCK", 20))
		var lines: Array = sold["lines"]
		if lines.is_empty():
			_dock.add_child(_slip_line("Nothing in the hold this trip."))
		for l: Array in lines:
			_dock.add_child(_slip_line("%d kg bluefin   %s   $%s" % [roundi(float(l[0])), str(l[1]),
					_money(int(l[2]))]))
		for c: Array in sold.get("costs", []):
			_dock.add_child(_slip_line("%s   -$%s" % [str(c[0]), _money(int(c[1]))]))
		_dock.add_child(_slip_line("The trip: $%s" % _money(int(sold["total"])), 20))
		_dock.add_child(HSeparator.new())
	else:
		_dock.add_child(_slip_line("AT THE DOCK", 20))
	var quota := int(hold.get("quota"))
	var earned := int(hold.get("earned"))
	_dock.add_child(_slip_line("QUOTA %d: $%s of $%s   Day %d of %d" % [int(hold.get("quota_n")), _money(earned),
			_money(quota), int(hold.get("day")), FishHold.DAYS], 20,
			Color(0.6, 1.0, 0.6) if earned >= quota else Color(1.0, 0.92, 0.6)))
	var bar := ProgressBar.new()
	bar.max_value = maxf(quota, 1)
	bar.value = minf(earned, quota)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	_dock.add_child(bar)
	if earned < quota:
		_dock.add_child(_slip_line("Sell $%s more by the end of day %d, or the bank takes the boat." % [
				_money(quota - earned), FishHold.DAYS], 15, Color(0.85, 0.75, 0.7)))
	_dock.add_child(_slip_line("Bank $%s   (best run: %d quotas)" % [_money(int(hold.get("bank"))),
			int(hold.get("best_run"))]))
	# the boats
	var bank := int(hold.get("bank"))
	var owned: Array = hold.get("owned")
	var picked := str(hold.get("kind"))
	for k: String in Kinds.KINDS:
		var spec: Dictionary = Kinds.KINDS[k]
		var row := VBoxContainer.new()
		var head := Label.new()
		head.text = "%s%s, %s   (fuel $%s a trip)" % ["> " if k == picked else "", str(spec["name"]).capitalize(),
				str(spec["title"]), _money(int(spec["fuel"]))]
		head.add_theme_font_size_override("font_size", 17)
		head.modulate = Color(1.0, 0.92, 0.6) if k == picked else Color(1, 1, 1)
		row.add_child(head)
		var blurb := Label.new()
		blurb.text = str(spec["blurb"])
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.modulate = Color(0.75, 0.78, 0.8)
		row.add_child(blurb)
		var buttons := HBoxContainer.new()
		if owned.has(k):
			var take := _button("Taking her" if k == picked else "Take her", func() -> void: hold.call("pick", k))
			take.disabled = not skipper or k == picked
			buttons.add_child(take)
		else:
			var buy := _button("Buy her: $%s" % _money(int(spec["price"])), func() -> void: hold.call("buy", k))
			buy.disabled = not skipper or bank < int(spec["price"])
			buttons.add_child(buy)
			var hire := _button("Chartering her" if k == picked else "Charter her: $%s a day"
					% _money(FishHold.CHARTER), func() -> void: hold.call("pick", k))
			hire.disabled = not skipper or k == picked
			buttons.add_child(hire)
		row.add_child(buttons)
		_dock.add_child(row)
	_dock.add_child(HSeparator.new())
	# the gear
	_dock.add_child(_slip_line("The chandlery", 17))
	var gear: Array = hold.get("gear")
	for g: String in FishHold.GEAR:
		var item: Dictionary = FishHold.GEAR[g]
		var line := HBoxContainer.new()
		var what := Label.new()
		what.text = "%s: %s" % [str(item["name"]), str(item["blurb"])]
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(what)
		if gear.has(g):
			var have := Label.new()
			have.text = "Aboard"
			have.modulate = Color(0.6, 1.0, 0.6)
			line.add_child(have)
		else:
			var b := _button("$%s" % _money(int(item["price"])), func() -> void: hold.call("buy", g))
			b.disabled = not skipper or bank < int(item["price"])
			line.add_child(b)
		_dock.add_child(line)
	_dock.add_child(HSeparator.new())
	_vs_rows(skipper)
	if skipper:
		var go := _button("Head out", func() -> void: hold.call("head_out"))
		go.add_theme_font_size_override("font_size", 22)
		_dock.add_child(go)
	else:
		_dock.add_child(_slip_line("Waiting for the skipper to head out."))


## VS (vs/vs.gd): the skipper's switch to two boats and back, and while it's on, the two boats with how many aboard
## each (yours lit): press the other to cross to her.
func _vs_rows(skipper: bool) -> void:
	var vs := get_parent().get("vs") as Node
	if vs == null:
		return
	var on := bool(vs.get("on"))
	if skipper:
		_dock.add_child(_button("One boat" if on else "Two boats: race for the birds", func() -> void:
			vs.call("host_set_on", not on)))
	if on:
		var row := HBoxContainer.new()
		var teams: Array = (vs.get("teams") as Dictionary).values()
		for t in 2:
			var b := _button("Boat %s  (%d)" % ["AB"[t], teams.count(t)], func() -> void: vs.call("ask_team", t))
			b.disabled = int(vs.get("my_team")) == t
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
		_dock.add_child(row)
	_dock.add_child(HSeparator.new())


func _slip_line(text: String, size := 16, tint := Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = tint
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l


static func _money(n: int) -> String:
	return FishHold._money(n)


## Screenshots and tests never show the menu.
func _headless_shot() -> bool:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shot") or a.begins_with("--cam") or a.begins_with("--net-report"):
			return true
	return false
