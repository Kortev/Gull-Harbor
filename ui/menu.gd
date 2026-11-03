extends CanvasLayer
## The menu, shown whenever the mouse is free (the title, ui/title.gd, comes before it and hosts or joins a crew), but
## not while you're being served at a counter on the quay (sea/places.gd: its own card).
##
## At the dock the harbour is the menu: you walk to the chandlery, the bait shop, the broker's board, the buyer's and
## the harbor master's (sea/places.gd). The pause card there has THE HARBOUR BOARD as well, the old board, in case:
## one screen, nothing to scroll. Along the top the harbour, the day and the bank. Left, the boat payment (a bar, what's
## left to make and by when) and the last trip's slip (each fish, the costs, the trip). Right, the boats side by side
## (a line each, take her, buy her or charter her) and the chandlery's gear, a row each. Along the bottom one big
## CAST OFF (the skipper's: a crewmate sees WAITING FOR THE SKIPPER), and the skipper's NEW CAREER under it (pressed
## twice: the first asks) to wipe the saved career and start over in the skiff. In Rivals (vs/vs.gd) there's no board: the
## countdown lets both boats go, and Esc gives the pause card.
##
## Out there (Esc), a small pause card: back to the deck, the owner's manual, the settings (ui/settings_page.gd: the
## board has them too), the crew (the join code to send, a Steam
## invite), leave the crew, back to the title, quit the game. No heading in from a menu, in any game: you drive her home and tie her up alongside
## the fish pier (sea/sea.gd's race home at dusk).
##
## The one pixel font (ui/pixfont.gd) at whole sizes, few words, dark cards over the harbour behind.
##
## A pad: the d-pad or left stick goes from button to button (Godot's own focus, each button's amber frame showing
## which: the first one's picked up as the pad is), A presses; out there B or START is back to the deck, and B shuts
## the manual.

const FishHold := preload("res://boat/fish_hold.gd")
const Kinds := preload("res://boat/kinds.gd")
const Manual := preload("res://ui/manual.gd")
const SettingsPage := preload("res://ui/settings_page.gd")
const AchievementsPage := preload("res://ui/achievements_page.gd")

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
var _copy: Button
var _invite: Button
var _leave: Button
## The boat's owner's manual (ui/manual.gd), open instead of the menu.
var _manual: Manual
var _dim: ColorRect
var _reading := false
## The settings page, open instead of the menu.
var _settings: SettingsPage
var _tuning := false
## The achievements page (ui/achievements_page.gd), open instead of the menu.
var _medals: AchievementsPage
var _proud := false
## The pause card's heading (PAUSED alone; with others aboard nothing stops: THE MENU) and the line under it.
var _heading: Label
var _still: Label
## Alone out there with the pause card up, the world's held still (the tree paused): since when (ms, -1: it isn't).
var _held_at := -1
## NEW CAREER pressed once: the board asks again before the career's wiped.
var _wipe := false
## Up last frame (the board, the pause card, the manual or the settings).
var _open := false
## The harbour board open from the pause card at the dock.
var _boarding := false
var _board_button: Button


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS      # (it's what's left running while it holds the world still)
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
	_heading = _label("PAUSED", BIG, AMBER)
	col.add_child(_heading)
	_still = _label("", SMALL, DIM)
	col.add_child(_still)
	_status = _label("", SMALL, DIM)
	col.add_child(_status)
	col.add_child(_button("BACK TO THE DECK", _resume, true))
	_board_button = _button("THE HARBOUR BOARD", func() -> void: _boarding = true)
	col.add_child(_board_button)
	col.add_child(_button("THE OWNER'S MANUAL", func() -> void: _reading = true))
	col.add_child(_button("SETTINGS", open_settings))
	col.add_child(_button("ACHIEVEMENTS", open_achievements))
	# (the card in three: the way back and the pages; bringing a friend aboard; leaving)
	_crew_box = VBoxContainer.new()
	_crew_box.add_theme_constant_override("separation", 6)
	col.add_child(_gap())
	col.add_child(_crew_box)
	_crew_box.add_child(_label("A FRIEND JOINS YOUR BOAT WITH", SMALL, DIM))
	_code = _label("", BODY, CREAM)
	_crew_box.add_child(_code)
	_copy = _button("COPY THE JOIN CODE", func() -> void:
		DisplayServer.clipboard_set(Net.code)
		_status.text = "COPIED: SEND IT TO YOUR FRIEND")
	_crew_box.add_child(_copy)
	_invite = _button("INVITE A STEAM FRIEND", func() -> void: Net.steam.call("invite"))
	_crew_box.add_child(_invite)
	col.add_child(_gap())
	_leave = _button("LEAVE THE CREW", _leave_crew)
	col.add_child(_leave)
	col.add_child(_button("BACK TO THE TITLE", _to_title))
	col.add_child(_button("QUIT THE GAME", func() -> void: get_tree().quit()))
	# (the manual over a dimmed screen, as the settings and achievements pages are: the HUD under it out of the way)
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.01, 0.02, 0.035, 0.6)
	_dim.visible = false
	add_child(_dim)
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
	_settings = SettingsPage.new()
	_settings.closed.connect(func() -> void: _tuning = false)
	add_child(_settings)
	_medals = AchievementsPage.new()
	_medals.closed.connect(func() -> void: _proud = false)
	add_child(_medals)
	_panel = _board
	Net.dropped.connect(func(reason: String) -> void: _status.text = reason.to_upper())
	if _shot_page() >= 0:
		open_settings.call_deferred(_shot_page())


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


## A little space between groups of buttons.
static func _gap() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 4)
	return c


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
	if primary:
		b.set_meta("primary", true)
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


## The settings page, in place of the board or the pause card till its BACK.
func open_settings(page := 0) -> void:
	_tuning = true
	_settings.open(page)


## The achievements page, the same way.
func open_achievements() -> void:
	_proud = true
	_medals.open(AchievementsPage.run_of(_fish_hold()))


func _resume() -> void:
	while Input.is_action_pressed("jump"):          # (A on the pad is a jump too: let go of it before the deck's live)
		await get_tree().process_frame
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
	var vs := get_parent().get("vs") as Node
	# (Rivals' results card, vs/card.gd, has the mouse while it's up: the menu waits)
	var places := get_parent().get("places") as Node
	var open := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _headless_shot() \
			and (title == null or not bool(title.call("busy"))) \
			and (vs == null or not bool((vs.get("card") as Node).call("up"))) \
			and (places == null or not bool(places.call("serving")))
	_reading = _reading and open
	_wipe = _wipe and open
	if _tuning and not open:
		_tuning = false
		_settings.close()
	if _proud and not open:
		_proud = false
		_medals.close()
	var hold := _fish_hold()
	var docked: bool = hold != null and bool(hold.get("docked"))
	var vs_on := vs != null and bool(vs.get("on"))
	_boarding = _boarding and open and docked and not vs_on
	_board_button.visible = docked and not vs_on
	_panel = _board if _boarding else _pause
	var away := _reading or _tuning or _proud         # (a page up in the card's place)
	_board.visible = open and not away and _panel == _board
	_pause.visible = open and not away and _panel == _pause
	_manual.visible = _reading
	_dim.visible = _reading
	(get_node("CloseManual") as Control).visible = _reading
	_open = open
	_hold_world(open and not vs_on)
	if not open:
		return
	if Settings.pad and not _tuning and not _proud:
		_pad_focus()
	_crew_box.visible = Net.in_session_or_hosting() and multiplayer.is_server()
	_code.text = Net.code if Net.mode == "code" and not Net.code.is_empty() else ""
	_code.visible = not _code.text.is_empty()
	(_crew_box.get_child(0) as Control).visible = _code.visible
	_copy.visible = _code.visible
	_invite.visible = Net.mode == "steam"
	# (leaving's only a thing with a crew: a friend's boat, or friends aboard yours; alone it's just the title)
	_leave.visible = Net.in_session() and (not multiplayer.is_server() or not multiplayer.get_peers().is_empty())
	_status.visible = not _status.text.is_empty()
	var now := [docked, Net.is_host(), (hold.get("sale") as Dictionary).duplicate(true), hold.get("bank"),
			hold.get("kind"), (hold.get("owned") as Array).duplicate(), (hold.get("gear") as Array).duplicate(),
			hold.get("quota"), hold.get("earned"), hold.get("day"), Net.in_session_or_hosting(), _wipe, hold.get("prep"),
			roundi(float(hold.get("fuel")) * 20.0), hold.get("ice"), hold.get("well")] if hold else []
	if now != _dock_of:
		_dock_of = now
		_fill_board(hold, docked)


## The pause card out there, alone (a quiet host with nobody aboard yet counts): the world stops under it, the
## sea's clock with it (on again it carries on from where it was: no waves jumping on, no day gone by). With anyone
## else aboard it can't stop for one of you, and the card says so. A friend coming aboard lets it go at once.
func _hold_world(want: bool) -> void:
	var alone := multiplayer.multiplayer_peer == null or multiplayer.get_peers().is_empty()
	# (only the game itself: a test builds the sea under its own node, and headless nobody's looking at a card)
	var game := get_parent().get_parent() == get_tree().root and DisplayServer.get_name() != "headless"
	var hold := want and alone and game
	_heading.text = "PAUSED" if alone or not want else "THE MENU"
	_still.text = "" if alone else "THE CREW'S STILL OUT THERE: THE SEA DOESN'T STOP."
	_still.visible = not alone
	if hold == (_held_at >= 0):
		return
	var tree := get_tree()
	if hold:
		_held_at = Time.get_ticks_msec()
		tree.paused = true
		return
	var ocean := get_parent().get("ocean") as Node
	if ocean != null:
		ocean.set("clock_offset", float(ocean.get("clock_offset")) - (Time.get_ticks_msec() - _held_at) / 1000.0)
	_held_at = -1
	tree.paused = false


func _exit_tree() -> void:
	if _held_at >= 0:
		get_tree().paused = false        # (back to the title, or quit, from the pause card)


## With the pad in hand, a button to be on: the first in the card up, if none of its own has the focus.
func _pad_focus() -> void:
	var card: Control = _manual if _reading else _panel
	var has: Control = get_viewport().gui_get_focus_owner()
	var shut := get_node("CloseManual") as Control
	if has != null and has.is_visible_in_tree() and (card.is_ancestor_of(has) or (_reading and has == shut)):
		return
	var first: Control = shut if _reading else _first_button(card, true)
	if first == null:
		first = _first_button(card)
	if first != null:
		first.grab_focus()


## The first button that can be pressed under `n` (`primary`: only the big amber one, CAST OFF or BACK TO THE DECK).
func _first_button(n: Node, primary := false) -> Button:
	for c in n.get_children():
		var ok := c is Button and (c as Button).is_visible_in_tree() and not (c as Button).disabled
		if ok and (not primary or c.has_meta("primary")):
			return c
		var b := _first_button(c, primary)
		if b != null:
			return b
	return null


## The pad's B (or START) out there: the pause card's gone, back to the deck; on the manual, it's shut.
func _unhandled_input(e: InputEvent) -> void:
	if not _open or _tuning or _proud or not (e is InputEventJoypadButton and (e as InputEventJoypadButton).pressed):
		return
	var b := (e as InputEventJoypadButton).button_index
	if b != JOY_BUTTON_B and b != JOY_BUTTON_START:
		return
	if _reading:
		_reading = false
	elif _boarding:
		_boarding = false
	elif _panel == _pause:
		_resume()
	else:
		return
	get_viewport().set_input_as_handled()


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
		_dock.add_child(_label("BOAT PAYMENT MADE! THE NEXT: $%s IN %d DAYS" % [_money(int(sold["next"])),
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
	var q := _section(left, str(hold.call("due_text")))
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
	bg.bg_color = Color(0.16, 0.19, 0.22)          # (empty, it's still a bar: what's to fill)
	bar.add_theme_stylebox_override("background", bg)
	q.add_child(bar)
	q.add_child(_label("PAID: SHE'S YOURS TILL THE NEXT ONE" if earned >= quota else "$%s MORE, OR THE BANK TAKES HER"
			% _money(quota - earned), SMALL, DIM))
	# the last trip's slip
	var slip := _section(left, "" if sold.is_empty() else "THE LAST TRIP")
	if sold.is_empty():
		var prep := str(hold.get("prep"))
		slip.add_child(_label("FIRST LIGHT. %s" % ("SHE GOES OUT FUELLED, ICED AND BAITED." if prep == "off"
				else "FUEL %d%%  ICE %d  BAIT %d: TOP HER UP AT THE FLOAT." % [roundi(float(hold.get("fuel")) * 100.0),
				int(hold.get("ice")), int(hold.get("well"))]), SMALL, DIM))
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
			if l.size() > 3:
				slip.add_child(_why(l[3]))
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
		b.add_child(_label("%d RODS   FUEL $%s A TRIP   PAYMENT $%s" % [(spec["rods"] as Array).size(),
				_money(int(spec["fuel"])), _money(int(spec.get("payment", 0)))],
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
	# the bait: not for sale. Every boat's well goes out with a few live mackerel; tuna take nothing else
	var well := HBoxContainer.new()
	var says := _label("LIVE BAIT ONLY, NO LURES: A MACKEREL ON EVERY HOOK, %d IN THE WELL. JIG MORE: THE JIG ROD (3)"
			% FishHold.WELL_START, SMALL, CREAM)
	says.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	says.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	well.add_child(says)
	well.add_child(_label("ABOARD", SMALL, GOOD))
	shop.add_child(well)
	# the way out
	# the way out: by hand, her lines let go (no button for it); and the dock prep, the skipper's to change
	var prep := str(hold.get("prep"))
	var way := HBoxContainer.new()
	way.add_theme_constant_override("separation", 12)
	way.alignment = BoxContainer.ALIGNMENT_CENTER
	_dock.add_child(way)
	way.add_child(_label("TO CAST OFF, LET GO HER BOW AND STERN LINES (E AT HER CLEATS) AND TAKE HER OUT", BODY, CREAM,
			HORIZONTAL_ALIGNMENT_CENTER))
	var prep_b := _button("DOCK PREP: %s" % prep.to_upper(), func() -> void: Settings.next_prep("career"))
	prep_b.disabled = not skipper
	way.add_child(prep_b)
	_dock.add_child(_button("BACK", func() -> void: _boarding = false, true))
	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 10)
	_dock.add_child(links)
	links.add_child(_button("THE OWNER'S MANUAL", func() -> void: _reading = true))
	links.add_child(_button("SETTINGS", open_settings))
	links.add_child(_button("ACHIEVEMENTS", open_achievements))
	if skipper:
		# (twice to wipe it: the first press asks)
		var wipe := _button("SURE? WIPE IT ALL" if _wipe else "NEW CAREER", func() -> void:
			if _wipe:
				hold.call("new_career")
			_wipe = not _wipe)
		if _wipe:
			wipe.add_theme_color_override("font_color", BAD)
			wipe.add_theme_color_override("font_hover_color", BAD)
		links.add_child(wipe)
	links.add_child(_button("BACK TO THE TITLE", _to_title))
	links.add_child(_button("QUIT THE GAME", func() -> void: get_tree().quit()))


## A line of the slip: what on the left, the money on the right.
## Why a fish graded what it did (tuna/handling.gd's reasons): the three that mattered most, a word or two each, the
## bad in red and the good in green, under its line on the slip.
func _why(reasons: Array) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.set_meta("why", true)
	r.add_theme_constant_override("separation", 10)
	r.add_child(_label(" ", SMALL, DIM))
	for w: Array in reasons.slice(0, 3):
		r.add_child(_label(str(w[0]), SMALL, GOOD if bool(w[1]) else BAD))
	return r


func _row(what: String, money: String, col := CREAM, size := SMALL) -> HBoxContainer:
	var r := HBoxContainer.new()
	var a := _label(what, size, CREAM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(a)
	r.add_child(_label(money, size, col))
	return r


static func _money(n: int) -> String:
	return FishHold._money(n)


## Screenshots and tests never show the menu, unless asked (--menu: a screenshot of it; --settings[=look|sound|
## screen|keys]: of the settings page).
func _headless_shot() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.has("--menu") or _shot_page() >= 0:
		return false
	for a in args:
		if a.begins_with("--shot") or a.begins_with("--cam") or a.begins_with("--net-report"):
			return true
	return false


## --settings[=page] (screenshots): which page, 0 LOOK .. 4 PAD; -1 not asked.
static func _shot_page() -> int:
	for a in OS.get_cmdline_user_args():
		if a == "--settings" or a.begins_with("--settings="):
			return maxi(SettingsPage.TABS.find(a.trim_prefix("--settings").trim_prefix("=").to_upper()), 0)
	return -1
