extends CanvasLayer
## The skipper's dev panel (F1, the host's only): for playtests. The weather called from here comes in over a few
## seconds on every screen (sea/weather.gd's call_weather: it turns, it doesn't jump), or goes back to coming and going
## on its own; the day moved on to morning, noon, late or the edge of dusk for every boat out; a fish put on a free rod
## of every boat out there (yours in your hands); birds brought in near. Mouse, or the key beside each row.
## Nobody else has it: a friend pressing F1 is told it's the host's.

const FishHold := preload("res://boat/fish_hold.gd")
const KEYS := "1234567890QWERTY"

var sea: Node                 # sea/sea.gd
var _box: VBoxContainer
var _panel: PanelContainer
var _rows: Array = []         # [label, Callable]
var _said: Label
## How long fights are (tuna/fight.gd's pace), stepped through by its row: [the word, the pace].
const PACES := [["USUAL LENGTH", 1.0], ["QUICK (HALF)", 0.5], ["VERY QUICK (A QUARTER)", 0.25], ["LONG (HALF AGAIN)", 1.5]]
var _pace_at := 0
var _pace_row: Button


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.03, 0.05, 0.07, 0.92)
	back.border_color = Color(0.86, 0.62, 0.28)
	back.border_width_left = 3
	back.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", back)
	_panel.position = Vector2(24, 24)
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
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
	_row("FIGHTS: USUAL LENGTH", _pace)
	_pace_row = _box.get_child(_box.get_child_count() - 1) as Button
	_said = Label.new()
	_said.add_theme_color_override("font_color", Color(0.98, 0.86, 0.22))
	_said.add_theme_font_size_override("font_size", 14)
	_box.add_child(_said)
	visible = false


func _head(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.86, 0.62, 0.28))
	_box.add_child(l)


func _row(text: String, what: Callable) -> void:
	var b := Button.new()
	b.text = "%s  %s" % [KEYS[_rows.size()], text]
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.93, 0.9, 0.8))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.3))
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
