extends CanvasLayer
## The skipper's dev panel (F1, the host's only): for playtests. The weather called from here comes in over a few
## seconds on every screen (sea/weather.gd's call_weather: it turns, it doesn't jump), or goes back to coming and going
## on its own; the day moved on to morning, noon, late or the edge of dusk for every boat out; a fish put on a free rod
## of every boat out there (yours in your hands); birds brought in near. Mouse, or the key beside each row.
## Nobody else has it: a friend pressing F1 is told it's the host's.

const Kit := preload("res://ui/kit.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const Fight := preload("res://tuna/fight.gd")
const KEYS := "1234567890QWERTY"

var sea: Node                 # sea/sea.gd
var _box: VBoxContainer
var kit := Kit.new()
var _panel: Control
var _rows: Array = []         # [label, Callable]
var _said: Label
## How long fights are (tuna/fight.gd's pace), stepped through by its row: [the word, the pace].
const PACES := [["USUAL LENGTH", 1.0], ["QUICK (HALF)", 0.5], ["VERY QUICK (A QUARTER)", 0.25], ["LONG (HALF AGAIN)", 1.5]]
var _pace_at := 0
var _pace_row: Button
## Which fight every rod gets (tuna/fight.gd's arcade: the set-pieces of tuna/fight_arcade.gd, or the classic): its row.
var _arcade_row: Button
var _arcade_at := 0


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	# (no panel and no dim: it's small, top left, over live play; the type's keylined by its outline)
	_panel = Control.new()
	_panel.position = Vector2(24.0, 118.0 * _px())        # (under the HUD's top left)
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 0)
	_box.custom_minimum_size = Vector2(390.0 * _px(), 0)
	_panel.add_child(_box)
	_head("DEV  -  THE HOST'S  -  F1 CLOSES")
	_head("WEATHER (EVERYONE'S)")
	for k: String in ["sunny", "calm", "fog", "rain", "heavy", "storm"]:
		_row(k.to_upper(), func() -> void: _weather(k))
	_row("ON ITS OWN AGAIN", func() -> void: _weather(""))
	_head("THE DAY (EVERY BOAT OUT)")
	for d: Array in [["MORNING", 0.08], ["NOON", 0.45], ["LATE", 0.75], ["DUSK IN HALF A MINUTE", 0.975]]:
		_row(str(d[0]), func() -> void: _day(float(d[1])))
	_head("FISH")
	_row("A FISH ON, EVERY BOAT OUT", _fish_on)
	_row("BIRDS IN NEAR", _birds)
	_arcade_at = _rows.size()
	_row("FIGHT: %s" % ("ARCADE" if Fight.arcade else "CLASSIC"), _arcade)
	_arcade_row = _box.get_child(_box.get_child_count() - 1) as Button
	_row("FIGHTS: USUAL LENGTH", _pace)
	_pace_row = _box.get_child(_box.get_child_count() - 1) as Button
	_said = Label.new()
	Kit.style_label(_said, roundi(17.0 * _px()), Kit.YELLOW, 0.0, 600)
	_box.add_child(_said)
	visible = false


## The screen's scale (the HUD's): 1 at 1080p.
func _px() -> float:
	return clampf(get_viewport().get_visible_rect().size.y / 1080.0, 0.7, 2.5)


## A heading: a label with a fine rule under it.
func _head(text: String) -> void:
	var c := Control.new()
	var p := _px()
	c.custom_minimum_size = Vector2(0, 40.0 * p)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		kit.px = p
		kit.label(c, Vector2(0, 24.0 * p), text, 15.0 * p, Color(Kit.PAPER, 0.6), -1)
		kit.rule(c, Vector2(0, 36.0 * p), Vector2(c.size.x, 36.0 * p), Kit.PAPER))
	_box.add_child(c)


## A row: its key and its words as type, yellow under the mouse.
func _row(text: String, what: Callable) -> void:
	var p := _px()
	var b := Button.new()
	b.text = "%s  %s" % [KEYS[_rows.size()], text]
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	var fs := roundi(18.0 * p)
	b.add_theme_font_override("font", Kit.font(600))
	b.add_theme_font_size_override("font_size", fs)
	b.custom_minimum_size = Vector2(0, 28.0 * p)
	var pad := StyleBoxEmpty.new()
	pad.content_margin_top = 0
	pad.content_margin_bottom = 0
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, pad)
	b.add_theme_color_override("font_color", Kit.PAPER)
	b.add_theme_color_override("font_hover_color", Kit.YELLOW)
	b.add_theme_color_override("font_pressed_color", Kit.YELLOW)
	b.add_theme_color_override("font_outline_color", Color(0.03, 0.035, 0.04, 0.88))
	b.add_theme_constant_override("outline_size", maxi(roundi(fs * 0.22), 3))
	b.pressed.connect(what)
	_box.add_child(b)
	_rows.append([text, what])


func _input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		if not Net.is_host():
			_note("The dev panel's the host's")
			return
		_show(not visible)
		return
	if not visible:
		return
	var at := KEYS.find(OS.get_keycode_string(k.keycode))
	if at >= 0 and at < _rows.size():
		get_viewport().set_input_as_handled()
		(_rows[at][1] as Callable).call()


func _show(on: bool) -> void:
	visible = on
	var title: Node = sea.get("title")
	var busy := title != null and bool(title.call("busy"))
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not busy and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if visible and not Net.is_host():
		_show(false)        # (no longer the host: aboard someone else's boat)


func _note(text: String) -> void:
	if _said != null:
		_said.text = text.to_upper()
	var crew: Node = sea.get("crew")
	var hud: Node = crew.get("hud") if crew != null else null
	if hud != null:
		hud.call("notify", text)


func _weather(kind: String) -> void:
	sea.call("host_call_weather", kind)
	_note("Weather: %s coming in" % kind if kind != "" else "Weather: on its own again")


## Every boat's books (Rivals: each side's; else the one), and her rods the same.
func _holds() -> Array:
	var vs: Node = sea.get("vs")
	if vs != null and bool(vs.get("on")):
		return (vs.get("sides") as Array).map(func(s: Node) -> Node: return s.get("fish_hold"))
	return [sea.get("fish_hold")]


func _rods() -> Array:
	var vs: Node = sea.get("vs")
	if vs != null and bool(vs.get("on")):
		return (vs.get("sides") as Array).map(func(s: Node) -> Node: return s.get("rods"))
	return [sea.get("rods")]


func _day(k: float) -> void:
	var moved := 0
	for h: Node in _holds():
		if h == null or bool(h.get("docked")):
			continue
		h.set("trip_t0", float(h.call("_now")) - k * FishHold.DAY)
		h.call("_host_changed")
		moved += 1
	_note("The day moved on" if moved > 0 else "Nobody's out: cast off first")


func _fish_on() -> void:
	var holds := _holds()
	var all := _rods()
	var mine: Node = sea.get("rods")
	var on := 0
	for i in all.size():
		var rods: Node = all[i]
		if rods == null or bool((holds[i] as Node).get("docked")):
			continue
		for r: Node in rods.get("rods"):
			if bool(r.get("hooked")):
				continue
			var n := int(r.get("index"))
			rods.call("host_cast", n)
			rods.call("strike", n, randf_range(120.0, 280.0))
			if rods == mine:
				rods.call("request_grab", n)
			on += 1
			break
	_note("%d fish on" % on if on > 0 else "Nobody's out with a free rod: cast off first")


## The other fight, for everyone (rods/rods.gd's host_set_arcade): a fish that's on carries on in it.
func _arcade() -> void:
	var rods: Node = sea.get("rods")
	if rods == null:
		return
	rods.call("host_set_arcade", not Fight.arcade)
	_arcade_row.text = "%s  FIGHT: %s" % [KEYS[_arcade_at], "ARCADE" if Fight.arcade else "CLASSIC"]
	_note("The fight: %s" % ("arcade (set-pieces on two buttons)" if Fight.arcade else "classic (pump and drag)"))


func _pace() -> void:
	_pace_at = (_pace_at + 1) % PACES.size()
	sea.call("host_fight_pace", float(PACES[_pace_at][1]))
	_pace_row.text = "%s  FIGHTS: %s" % [KEYS[_rows.size() - 1], PACES[_pace_at][0]]
	_note("Fights: %s" % str(PACES[_pace_at][0]).to_lower())


func _birds() -> void:
	var schools: Node = sea.get("schools")
	if schools == null:
		return
	schools.set("start_far", 300.0)
	schools.set("_next", 0.0)
	_note("Birds coming in near")
