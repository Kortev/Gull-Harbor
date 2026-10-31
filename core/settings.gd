extends Node
## The player's own settings (an autoload, `Settings`): how the mouse looks, how loud things are, the window, the keys.
## Kept in user://settings.cfg (a ConfigFile) and put back as the game starts; ui/settings_page.gd is where they're
## changed, every change applied as it's made (set_*()), the file written when the page closes (save_file()).
##
## The sound goes through four buses under Master, made here if the project has none: Effects (everything in the
## game: any player left on Master as it enters the tree is moved onto it), Voice (the crew talking, voice chat to
## come), Music (for later). Radio (ui/radio.gd) sends into Effects.
##
## The keys: REBINDABLE's actions, each a list of InputEvents in the InputMap; a rebind changes the first one (a second,
## like swim_down's C, stays). The project's own bindings are remembered at startup for RESET TO DEFAULTS, and two
## actions on one input are a clash only if they weren't already sharing it there (jump and rod_reel both on Space:
## the deck and the rod never want it at once).
##
## Tests and screenshots (headless, or a scene under tests/) start from the defaults and never read or write the
## player's file (`path` is "" there, unless a test sets it).

signal changed

const PATH := "user://settings.cfg"
## Where they're kept ("": nowhere, in tests and screenshots, unless a test points it somewhere).
var path := PATH
const BUSES := ["Effects", "Voice", "Music"]
## The actions the keys page lists, in its order, and what it calls them.
const REBINDABLE := [["move_forward", "FORWARD"], ["move_back", "BACK"], ["move_left", "LEFT"],
		["move_right", "RIGHT"], ["jump", "JUMP / HOP THE RAIL"], ["sprint", "SPRINT"], ["swim_down", "DIVE"],
		["interact", "USE / GRAB"], ["use_primary", "CAST, REEL, SWING"], ["use_secondary", "HEAVE, AIM"],
		["drop", "DROP IT"], ["shove", "SHOVE"], ["slot_1", "HANDS 1"], ["slot_2", "HANDS 2"], ["slot_3", "HANDS 3"],
		["slot_4", "HANDS 4"], ["slot_5", "HANDS 5"], ["slot_next", "NEXT IN HAND"], ["slot_prev", "LAST IN HAND"]]
const WINDOWS := ["windowed", "borderless", "fullscreen"]
const SIZES: Array[Vector2i] = [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
		Vector2i(2560, 1440)]
const FPS := [30, 60, 90, 120, 144, 165, 240, 0]

## Mouse look: how far a px of mouse turns you (1: crew/player.gd's LOOK as it was), up/down flipped, the field of view.
var sensitivity := 1.0
var invert_y := false
var fov := 75.0
## Each bus's loudness, 0..1 (0 mutes it).
var volume := {"Master": 1.0, "Effects": 1.0, "Voice": 1.0, "Music": 1.0}
## The window: windowed, borderless (a borderless window the size of the screen) or fullscreen (exclusive); its size
## when windowed; vsync; the frame cap (0: none).
var window := "windowed"
var window_size := Vector2i(1152, 648)
var vsync := true
var max_fps := 0
var _defaults := {}          # action -> [InputEvent], as the project has them


func _ready() -> void:
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for a: Array in REBINDABLE:
		_defaults[a[0]] = InputMap.action_get_events(a[0]).duplicate()
	get_tree().node_added.connect(_on_node_added)
	if _testing():
		path = ""
	else:
		load_file()
	apply()


func _testing() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for a in OS.get_cmdline_args():
		if a.contains("tests/"):
			return true
	return false


## Anything that makes sound and was left on Master: onto Effects (so the effects slider has it).
func _on_node_added(n: Node) -> void:
	if (n is AudioStreamPlayer or n is AudioStreamPlayer3D or n is AudioStreamPlayer2D) and n.get("bus") == &"Master":
		n.set("bus", &"Effects")


## Everything as it stands now: the buses, the window, the frame cap (the look is read live by the crew).
func apply() -> void:
	for b: String in volume:
		_apply_volume(b)
	_apply_display()
	changed.emit()


func set_sensitivity(v: float) -> void:
	sensitivity = clampf(v, 0.1, 4.0)
	changed.emit()


func set_invert_y(on: bool) -> void:
	invert_y = on
	changed.emit()


func set_fov(v: float) -> void:
	fov = clampf(v, 55.0, 110.0)
	changed.emit()


func set_volume(bus: String, v: float) -> void:
	volume[bus] = clampf(v, 0.0, 1.0)
	_apply_volume(bus)
	changed.emit()


func set_window(mode: String, size := Vector2i.ZERO) -> void:
	window = mode if WINDOWS.has(mode) else "windowed"
	if size != Vector2i.ZERO:
		window_size = size
	_apply_display()
	changed.emit()


func set_vsync(on: bool) -> void:
	vsync = on
	_apply_display()
	changed.emit()


func set_max_fps(n: int) -> void:
	max_fps = maxi(n, 0)
	_apply_display()
	changed.emit()


func _apply_volume(bus: String) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	var v := float(volume[bus])
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Engine.max_fps = max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var want: DisplayServer.WindowMode = {"windowed": DisplayServer.WINDOW_MODE_WINDOWED,
			"borderless": DisplayServer.WINDOW_MODE_FULLSCREEN,
			"fullscreen": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN}[window]
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	if want == DisplayServer.WINDOW_MODE_WINDOWED:
		var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var s := Vector2i(mini(window_size.x, screen.size.x), mini(window_size.y, screen.size.y))
		if DisplayServer.window_get_size() != s:
			DisplayServer.window_set_size(s)
			DisplayServer.window_set_position(screen.position + (screen.size - s) / 2)


# --- the keys ---

## Puts `e` (a key or a mouse button, as pressed) first on `action`, in place of what was there.
func bind(action: String, e: InputEvent) -> void:
	var events := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, _clean(e))
	for old in events.slice(1):
		if not _same(old, e):
			InputMap.action_add_event(action, old)
	changed.emit()


func reset_keys() -> void:
	for a: String in _defaults:
		InputMap.action_erase_events(a)
		for e: InputEvent in _defaults[a]:
			InputMap.action_add_event(a, e)
	changed.emit()


## The other actions on `action`'s inputs that weren't sharing them in the project's own bindings (their names).
func clashes(action: String) -> Array[String]:
	var out: Array[String] = []
	for e in InputMap.action_get_events(action):
		for a: Array in REBINDABLE:
			if a[0] == action or out.has(a[1]):
				continue
			if _has(InputMap.action_get_events(a[0]), e) and not (_has(_defaults.get(action, []), e)
					and _has(_defaults[a[0]], e)):
				out.append(a[1])
	return out


## What an action's on, as the keys page says it ("W", "LEFT CLICK / C").
func describe(action: String) -> String:
	var names := PackedStringArray()
	for e in InputMap.action_get_events(action):
		names.append(input_name(e))
	return " / ".join(names) if not names.is_empty() else "-"


static func input_name(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		var shown := code
		if k.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			shown = DisplayServer.keyboard_get_keycode_from_physical(code)      # (the key's name on your layout)
		return OS.get_keycode_string(shown if shown != KEY_NONE else code).to_upper()
	if e is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "LEFT CLICK", MOUSE_BUTTON_RIGHT: "RIGHT CLICK", MOUSE_BUTTON_MIDDLE: "MIDDLE CLICK",
				MOUSE_BUTTON_WHEEL_UP: "WHEEL UP", MOUSE_BUTTON_WHEEL_DOWN: "WHEEL DOWN",
				MOUSE_BUTTON_XBUTTON1: "MOUSE 4", MOUSE_BUTTON_XBUTTON2: "MOUSE 5"}.get(
				(e as InputEventMouseButton).button_index, "MOUSE %d" % (e as InputEventMouseButton).button_index)
	return "?"


## A key or button as an action wants it: just which one (physical, no modifiers, not pressed).
static func _clean(e: InputEvent) -> InputEvent:
	if e is InputEventKey:
		var k := InputEventKey.new()
		var src := e as InputEventKey
		k.physical_keycode = src.physical_keycode if src.physical_keycode != KEY_NONE else src.keycode
		return k
	if e is InputEventMouseButton:
		var m := InputEventMouseButton.new()
		m.button_index = (e as InputEventMouseButton).button_index
		return m
	return e


static func _same(a: InputEvent, b: InputEvent) -> bool:
	return _code(a) == _code(b)


static func _has(events: Array, e: InputEvent) -> bool:
	for x: InputEvent in events:
		if _same(x, e):
			return true
	return false


## An input as the file keeps it: "key:87", "mouse:1".
static func _code(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		return "key:%d" % (k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if e is InputEventMouseButton:
		return "mouse:%d" % (e as InputEventMouseButton).button_index
	return ""


static func _decode(s: String) -> InputEvent:
	var kv := s.split(":")
	if kv.size() != 2 or not kv[1].is_valid_int():
		return null
	if kv[0] == "key":
		var k := InputEventKey.new()
		k.physical_keycode = int(kv[1]) as Key
		return k
	if kv[0] == "mouse":
		var m := InputEventMouseButton.new()
		m.button_index = int(kv[1]) as MouseButton
		return m
	return null


# --- the file ---

func save_file() -> Error:
	if path.is_empty():
		return ERR_UNAVAILABLE
	var c := ConfigFile.new()
	c.set_value("look", "sensitivity", sensitivity)
	c.set_value("look", "invert_y", invert_y)
	c.set_value("look", "fov", fov)
	for b: String in volume:
		c.set_value("sound", b.to_lower(), volume[b])
	c.set_value("display", "window", window)
	c.set_value("display", "window_size", window_size)
	c.set_value("display", "vsync", vsync)
	c.set_value("display", "max_fps", max_fps)
	for a: Array in REBINDABLE:
		var codes := PackedStringArray()
		for e in InputMap.action_get_events(a[0]):
			codes.append(_code(e))
		c.set_value("keys", a[0], codes)
	return c.save(path)


## Reads the file (missing: everything stays as it is) and applies it.
func load_file() -> Error:
	if path.is_empty():
		return ERR_UNAVAILABLE
	var c := ConfigFile.new()
	var err := c.load(path)
	if err != OK:
		return err
	sensitivity = clampf(float(c.get_value("look", "sensitivity", sensitivity)), 0.1, 4.0)
	invert_y = bool(c.get_value("look", "invert_y", invert_y))
	fov = clampf(float(c.get_value("look", "fov", fov)), 55.0, 110.0)
	for b: String in volume:
		volume[b] = clampf(float(c.get_value("sound", b.to_lower(), volume[b])), 0.0, 1.0)
	window = str(c.get_value("display", "window", window))
	if not WINDOWS.has(window):
		window = "windowed"
	var s: Variant = c.get_value("display", "window_size", window_size)
	window_size = s if s is Vector2i else window_size
	vsync = bool(c.get_value("display", "vsync", vsync))
	max_fps = maxi(int(c.get_value("display", "max_fps", max_fps)), 0)
	for a: Array in REBINDABLE:
		if not c.has_section_key("keys", a[0]):
			continue
		var events: Array[InputEvent] = []
		for code: String in c.get_value("keys", a[0], PackedStringArray()):
			var e := _decode(code)
			if e != null:
				events.append(e)
		if not events.is_empty():
			InputMap.action_erase_events(a[0])
			for e in events:
				InputMap.action_add_event(a[0], e)
	apply()
	return OK
