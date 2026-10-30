extends CanvasLayer
## The menu, shown whenever the mouse is free (the title, ui/title.gd, comes before it and hosts or joins a crew).
##
## At the dock (boat/fish_hold.gd's `docked`: a run starts there, and heading in brings you back), the harbour board:
## one screen, nothing to scroll. Along the top the harbour, the day and the bank. Left, the quota (a bar, what's
## left to make and by when) and the last trip's slip (each fish, the costs, the trip). Right, the boats side by side
## (a line each, take her, buy her or charter her) and the chandlery's gear, a row each. Along the bottom one big
## CAST OFF (the skipper's: a crewmate sees WAITING FOR THE SKIPPER). In Rivals (vs/vs.gd) there's no board: the
## countdown lets both boats go, and Esc gives the pause card.
##
## Out there (Esc), a small pause card: back to the deck, the owner's manual, the crew (the join code to send, a Steam
## invite), leave the crew, back to the title, quit the game. No heading in from a menu, in any game: you drive her home and tie her up alongside
## the fish pier (sea/sea.gd's race home at dusk).
##
## The one pixel font (ui/pixfont.gd) at whole sizes, few words, dark cards over the harbour behind.

const FishHold := preload("res://boat/fish_hold.gd")
const Kinds := preload("res://boat/kinds.gd")
const Manual := preload("res://ui/manual.gd")

## The type sizes: the pixel font's 6 px line at 2, 3 and 4 times.
const SMALL := 12
const BODY := 18
const BIG := 24
const AMBER := Color(1.0, 0.78, 0.34)
const CREAM := Color(1.0, 0.95, 0.84)
const DIM := Color(0.66, 0.71, 0.76)
const GOOD := Color(0.6, 1.0, 0.6)
const BAD := Color(1.0, 0.5, 0.42)
const CARD := Color(0.06, 0.08, 0.1, 0.94)

## The harbour board (at the dock) and the pause card (out there): `_panel` is whichever's in use.
var _panel: Control
var _board: PanelContainer
var _pause: PanelContainer
var _dock: VBoxContainer
var _dock_of := []
var _status: Label
var _crew_box: VBoxContainer
var _code: Label
## The boat's owner's manual (ui/manual.gd), open instead of the menu.
var _manual: Manual
var _reading := false


func _ready() -> void:
	layer = 10
	_board = _card_panel(Vector2(1040, 600))
	add_child(_board)
	_dock = VBoxContainer.new()
	_dock.add_theme_constant_override("separation", 12)
	_board.add_child(_dock)
	_pause = _card_panel(Vector2(420, 0))
	add_child(_pause)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_pause.add_child(col)
	col.add_child(_label("PAUSED", BIG, AMBER))
	_status = _label("", SMALL, DIM)
	col.add_child(_status)
	col.add_child(_button("BACK TO THE DECK", _resume, true))
	col.add_child(_button("THE OWNER'S MANUAL", func() -> void: _reading = true))
	_crew_box = VBoxContainer.new()
	_crew_box.add_theme_constant_override("separation", 6)
	col.add_child(_crew_box)
	_code = _label("", BODY, CREAM)
	_crew_box.add_child(_code)
	_crew_box.add_child(_button("COPY THE JOIN CODE", func() -> void:
		DisplayServer.clipboard_set(Net.code)
		_status.text = "COPIED: SEND IT TO YOUR FRIEND"))
	_crew_box.add_child(_button("INVITE A STEAM FRIEND", func() -> void: Net.steam.call("invite")))
	col.add_child(_button("LEAVE THE CREW", _leave_crew))
	col.add_child(_button("BACK TO THE TITLE", _to_title))
	col.add_child(_button("QUIT THE GAME", func() -> void: get_tree().quit()))
	_manual = Manual.new(get_parent().get("tips") as Node)
	_manual.set_anchors_preset(Control.PRESET_CENTER)
	_manual.custom_minimum_size = Vector2(820, 560)
	_manual.position = Vector2(-410, -280)
	_manual.visible = false
	add_child(_manual)
	var shut := _button("CLOSE THE MANUAL", func() -> void: _reading = false)
	shut.set_anchors_preset(Control.PRESET_CENTER)
	shut.position = Vector2(-110, 290)
	shut.visible = false
	shut.name = "CloseManual"
	add_child(shut)
	_panel = _board
	Net.dropped.connect(func(reason: String) -> void: _status.text = reason.to_upper())


## A dark card centred on the screen, at least `size` (height 0: as tall as it needs), an amber edge down its left.
func _card_panel(size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = size
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.025, 0.035, 0.045, 0.94)
	box.border_color = Color(AMBER, 0.7)
	box.border_width_left = 4
	box.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", box)
	return p


func _label(text: String, size := BODY, col := CREAM, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	return l


## A button in the board's style: square, dark, amber when it's the one to press.
func _button(text: String, on: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on)
	b.add_theme_font_size_override("font_size", BIG if primary else SMALL)
	b.custom_minimum_size = Vector2(0, 52 if primary else 30)
	var base := Color(0.1, 0.13, 0.16) if not primary else Color(0.85, 0.55, 0.16)
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = {"normal": base, "hover": base.lightened(0.18), "pressed": base.darkened(0.2),
				"disabled": Color(base.darkened(0.4), 0.6), "focus": Color(0, 0, 0, 0)}[st]
		if st == "focus":
			box.border_color = Color(AMBER, 0.8)
			box.set_border_width_all(2)
		box.set_content_margin_all(6)
		b.add_theme_stylebox_override(st, box)
	b.add_theme_color_override("font_color", Color(0.06, 0.05, 0.03) if primary else CREAM)
	b.add_theme_color_override("font_hover_color", Color(0.06, 0.05, 0.03) if primary else AMBER)
	b.add_theme_color_override("font_pressed_color", Color(0.06, 0.05, 0.03) if primary else AMBER)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.5))
	return b


## A titled card on the board: returns where its contents go.
func _section(parent: Control, title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = CARD
	box.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", box)
	parent.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)
	if not title.is_empty():
		col.add_child(_label(title, SMALL, DIM))
	return col


func _resume() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Back to the title: off the crew (or the crew off your boat), and the game starts over from its title. (A trip left
## out at sea is settled as the day gone, the fuel owed: boat/fish_hold.gd.)
func _to_title() -> void:
	Net.leave()
	get_tree().reload_current_scene()


func _leave_crew() -> void:
	Net.leave()
	(get_parent().get("crew") as Node).call("start_solo")


func _process(_delta: float) -> void:
	var title := get_parent().get("title") as Node
	var open := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _headless_shot() \
			and (title == null or not bool(title.call("busy")))
	_reading = _reading and open
	var hold := _fish_hold()
	var docked: bool = hold != null and bool(hold.get("docked"))
	var vs := get_parent().get("vs") as Node
	var vs_on := vs != null and bool(vs.get("on"))
	_panel = _board if docked and not vs_on else _pause
	_board.visible = open and not _reading and _panel == _board
	_pause.visible = open and not _reading and _panel == _pause
	_manual.visible = _reading
	(get_node("CloseManual") as Control).visible = _reading
	if not open:
		return
	_crew_box.visible = Net.in_session_or_hosting() and multiplayer.is_server()
	_code.text = "JOIN CODE: " + Net.code if Net.mode == "code" and not Net.code.is_empty() else ""
	(_crew_box.get_child(1) as Control).visible = Net.mode == "code" and not Net.code.is_empty()
	(_crew_box.get_child(2) as Control).visible = Net.mode == "steam"
	var now := [docked, Net.is_host(), (hold.get("sale") as Dictionary).duplicate(true), hold.get("bank"),
			hold.get("kind"), (hold.get("owned") as Array).duplicate(), (hold.get("gear") as Array).duplicate(),
			hold.get("quota"), hold.get("earned"), hold.get("day"), Net.in_session_or_hosting()] if hold else []
	if now != _dock_of:
		_dock_of = now
		_fill_board(hold, docked)


func _fish_hold() -> Node:
	return get_parent().get("fish_hold") as Node


## The harbour board (see the top): rebuilt whenever anything on it changes.
func _fill_board(hold: Node, docked: bool) -> void:
	for c in _dock.get_children():
		_dock.remove_child(c)
		c.queue_free()
	if hold == null or not docked:
		return
	var skipper := Net.is_host()
	# along the top: where, when, what's in the bank
	var top := HBoxContainer.new()
	_dock.add_child(top)
	var where := _label("GULL HARBOR, THE FISH PIER", BIG, AMBER)
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(where)
	top.add_child(_label("DAY %d OF %d    BANK $%s" % [int(hold.get("day")), FishHold.DAYS,
			_money(int(hold.get("bank")))], BODY, CREAM))
	var sold: Dictionary = hold.get("sale")
	var verdict := str(sold.get("verdict", ""))
	if verdict == "lost":
		_dock.add_child(_label("THE BANK TOOK THE BOAT. A NEW RUN: THE SKIFF AND $%s" % _money(FishHold.START_CASH),
				BODY, BAD))
	elif verdict == "met":
		_dock.add_child(_label("QUOTA MADE! THE NEXT ONE: $%s IN %d DAYS" % [_money(int(sold["next"])),
				FishHold.DAYS], BODY, GOOD))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	cols.add_child(right)
	# the quota: a bar, and what's left by when
	var quota := int(hold.get("quota"))
	var earned := int(hold.get("earned"))
	var q := _section(left, "QUOTA %d" % int(hold.get("quota_n")))
	q.add_child(_label("$%s OF $%s" % [_money(earned), _money(quota)], BIG, GOOD if earned >= quota else CREAM))
	var bar := ProgressBar.new()
	bar.max_value = maxf(quota, 1)
	bar.value = minf(earned, quota)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOOD if earned >= quota else AMBER
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("background", bg)
	q.add_child(bar)
	q.add_child(_label("MADE: ON TO THE NEXT" if earned >= quota else "$%s MORE BY DAY %d, OR THE BANK TAKES HER"
			% [_money(quota - earned), FishHold.DAYS], SMALL, DIM))
	# the last trip's slip
	var slip := _section(left, "" if sold.is_empty() else "THE LAST TRIP")
	if sold.is_empty():
		slip.add_child(_label("FIRST LIGHT. FUELLED, BAITED, READY.", SMALL, DIM))
	else:
		var lines: Array = sold.get("lines", [])
		if bool(sold.get("late", false)):
			slip.add_child(_label("TOWED IN LATE: THE CANNERY PAID HALF", SMALL, BAD))
		if bool(sold.get("abandoned", false)):
			slip.add_child(_label("LEFT HER OUT THERE: THE DAY'S GONE", SMALL, BAD))
		if lines.is_empty():
			slip.add_child(_label("NO FISH", BODY, DIM))
		for l: Array in lines.slice(0, 5):
			slip.add_child(_row("%d KG  %s" % [roundi(float(l[0])), str(l[1]).to_upper()], "$" + _money(int(l[2]))))
		if lines.size() > 5:
			slip.add_child(_label("AND %d MORE" % (lines.size() - 5), SMALL, DIM))
		for c: Array in sold.get("costs", []):
			slip.add_child(_row(str(c[0]).to_upper(), "-$" + _money(int(c[1])), BAD))
		var total := int(sold.get("total", 0))
		slip.add_child(_row("THE TRIP", ("$" if total >= 0 else "-$") + _money(absi(total)), GOOD if total > 0 else BAD,
				BODY))
	# the boats, side by side
	var bank := int(hold.get("bank"))
	var owned: Array = hold.get("owned")
	var picked := str(hold.get("kind"))
	var boats := HBoxContainer.new()
	boats.add_theme_constant_override("separation", 12)
	right.add_child(boats)
	for k: String in Kinds.KINDS:
		var spec: Dictionary = Kinds.KINDS[k]
		var b := _section(boats, "TAKING HER" if k == picked else "")
		(b.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_child(_label(str(spec["name"]).trim_prefix("the ").to_upper(), BODY, AMBER if k == picked else CREAM))
		var short := _label(str(spec["blurb"]).split(". ")[0].split(": ")[0].to_upper(), SMALL, DIM)
		short.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		short.custom_minimum_size = Vector2(240, 0)
		b.add_child(short)
		b.add_child(_label("%d RODS   FUEL $%s A TRIP" % [(spec["rods"] as Array).size(), _money(int(spec["fuel"]))],
				SMALL, DIM))
		if owned.has(k):
			var take := _button("TAKING HER" if k == picked else "TAKE HER", func() -> void: hold.call("pick", k))
			take.disabled = not skipper or k == picked
			b.add_child(take)
		else:
			var buy := _button("BUY HER: $%s" % _money(int(spec["price"])), func() -> void: hold.call("buy", k))
			buy.disabled = not skipper or bank < int(spec["price"])
			b.add_child(buy)
			var hire := _button("CHARTERED" if k == picked else "CHARTER: $%s A DAY" % _money(FishHold.CHARTER),
					func() -> void: hold.call("pick", k))
			hire.disabled = not skipper or k == picked
			b.add_child(hire)
	# the chandlery
	var gear: Array = hold.get("gear")
	var shop := _section(right, "THE CHANDLERY")
	for g: String in FishHold.GEAR:
		var item: Dictionary = FishHold.GEAR[g]
		var line := HBoxContainer.new()
		var what := _label(str(item["name"]).to_upper() + ": " + str(item["blurb"]).split(". ")[0].split(":")[0]
				.to_upper(), SMALL, CREAM)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(what)
		if gear.has(g):
			line.add_child(_label("ABOARD", SMALL, GOOD))
		else:
			var buy := _button("$%s" % _money(int(item["price"])), func() -> void: hold.call("buy", g))
			buy.custom_minimum_size = Vector2(110, 30)
			buy.disabled = not skipper or bank < int(item["price"])
			line.add_child(buy)
		shop.add_child(line)
	# the way out
	if skipper:
		_dock.add_child(_button("CAST OFF", func() -> void:
			hold.call("head_out")
			_resume()
			# (you're at the wheel: take her out through the harbour mouth yourself)
			var boat: Node = get_parent().get("boat")
			if boat != null and int(boat.get("helm").get("captain")) == 0:
				boat.get("helm").call("request", true), true))
	else:
		_dock.add_child(_label("WAITING FOR THE SKIPPER TO CAST OFF", BODY, DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 10)
	_dock.add_child(links)
	links.add_child(_button("THE OWNER'S MANUAL", func() -> void: _reading = true))
	links.add_child(_button("BACK TO THE TITLE", _to_title))
	links.add_child(_button("QUIT THE GAME", func() -> void: get_tree().quit()))


## A line of the slip: what on the left, the money on the right.
func _row(what: String, money: String, col := CREAM, size := SMALL) -> HBoxContainer:
	var r := HBoxContainer.new()
	var a := _label(what, size, CREAM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(a)
	r.add_child(_label(money, size, col))
	return r


static func _money(n: int) -> String:
	return FishHold._money(n)


## Screenshots and tests never show the menu, unless asked (--menu: a screenshot of it).
func _headless_shot() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.has("--menu"):
		return false
	for a in args:
		if a.begins_with("--shot") or a.begins_with("--cam") or a.begins_with("--net-report"):
			return true
	return false
