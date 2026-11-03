extends Node
## The player's own settings (an autoload, `Settings`): how the mouse looks, how loud things are, the window, the keys.
## Kept in user://settings.cfg (a ConfigFile) and put back as the game starts; ui/settings_page.gd is where they're
## changed, every change applied as it's made (set_*()), the file written when the page closes (save_file()).
##
## The sound goes through four buses under Master, made here if the project has none: Effects (everything in the
## game: any player left on Master as it enters the tree is moved onto it), Voice (the crew talking, voice chat to
## come), Music (audio/music.gd). Radio (ui/radio.gd) sends into Effects.
##
## The keys: REBINDABLE's actions, each a list of InputEvents in the InputMap; a rebind changes the first one (a second,
## like swim_down's C, stays). The project's own bindings are remembered at startup for RESET TO DEFAULTS, and two
## actions on one input are a clash only if they weren't already sharing it there (jump and rod_reel both on Space:
## the deck and the rod never want it at once).
##
## The pad (core/pad.gd: its buttons and sticks put onto the same actions at startup, so a rebind and RESET TO DEFAULTS
## leave them be): the right stick's own sensitivity and invert Y, rumble on or off, and `pad`, whether the pad's what
## was last touched (the prompts name its buttons then: say()). L3 sprints till the left stick lets go.
##
## Tests and screenshots (headless, or a scene under tests/) start from the defaults and never read or write the
## player's file (`path` is "" there, unless a test sets it). A file that won't read, or holds nonsense, is the
## defaults (whatever in it makes sense is kept) and is written over by the next save.
##
## The window starts borderless on the whole screen the first time (no file yet); windowed it's centred, never bigger
## than the screen. The menus and the HUD are laid out for 1152 x 648 at least and only ever scaled up by a whole
## number (2560 x 1440 is twice, 1920 x 1080 once with the room to spare), so the pixel font's pixels stay square and
## even. The game going to the background (alt-tab, a click on another window) lets the mouse go, which
## puts the pause card up (ui/menu.gd), as Esc would.

signal changed
## The pad picked up, or put down for the keys and mouse (`pad`).
signal device_changed

const Pad := preload("res://core/pad.gd")

const PATH := "user://settings.cfg"
## Where they're kept ("": nowhere, in tests and screenshots, unless a test points it somewhere).
var path := PATH
const BUSES := ["Effects", "Voice", "Music"]
## The mix's own gain staging under the sliders (dB), from whole trips measured (tools/loudness.py with the game's bus
## meters): with the sound bank loudness-matched (beds -20 LUFS, one-shots -18), the game sits round -16.5 LUFS with
## the music about 4.5 dB under the effects. And a limiter last on the master (MASTER_CEILING dB), so nothing that
## stacks up ever clips.
const TRIM := {"Effects": -3.0, "Music": -4.5}
const MASTER_CEILING := -1.0
## The actions the keys page lists, in its order, and what it calls them.
const REBINDABLE := [["move_forward", "FORWARD"], ["move_back", "BACK"], ["move_left", "LEFT"],
		["move_right", "RIGHT"], ["jump", "JUMP"], ["sprint", "SPRINT"], ["swim_down", "DIVE"],
		["interact", "USE / GRAB"], ["use_primary", "CAST, REEL, SWING"], ["use_secondary", "HEAVE, AIM"],
		["drop", "DROP IT"], ["shove", "SHOVE"], ["slot_1", "HANDS 1"], ["slot_2", "HANDS 2"], ["slot_3", "HANDS 3"],
		["slot_4", "HANDS 4"], ["slot_5", "HANDS 5"], ["slot_6", "HANDS 6"], ["slot_next", "NEXT IN HAND"],
		["slot_prev", "LAST IN HAND"],
		["talk", "TALK OUT LOUD"], ["radio", "TALK ON THE VHF"]]
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
var window := "borderless"
var window_size := Vector2i(1280, 720)
var vsync := true
var max_fps := 0
## The menus and the HUD: "crisp" (scaled by whole numbers only: the pixel font's pixels square and even; on a
## 1920 x 1080 screen that's once) or "large" (scaled to fill the window, a pixel or two uneven).
var ui_size := "crisp"
const UI_SIZES := ["crisp", "large"]
## The pad: the right stick's look (1: Pad.LOOK_PX), up/down flipped, rumble.
var pad_sensitivity := 1.0
var pad_invert_y := false
var rumble := true
## The pad's what was last touched (not the keys or the mouse).
var pad := false
## The match settings, each a default per mode (the host's are the ones that count, shown in the lobby and on the
## board): the dock prep before casting off ("full": fuel, ice and bait by hand; "quick": the same, quicker; "off":
## she goes out fuelled, iced and baited), "career" (FISH, solo and co-op) and "rivals".
var prep := {"career": "full", "rivals": "off"}
const PREPS := ["full", "quick", "off"]
## The last rumble asked for: [weak, strong, seconds] (tests read it: there's no pad to feel it).
var last_rumble: Array = []
var _sprint_latch := false
var _defaults := {}          # action -> [InputEvent], as the project has them


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS       # (the pad picked up under the pause card: its hints)
	_cmd_size = _resolution_arg()
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	var master := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for k in AudioServer.get_bus_effect_count(master):
		has_limiter = has_limiter or AudioServer.get_bus_effect(master, k) is AudioEffectHardLimiter
	if not has_limiter:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = MASTER_CEILING
		AudioServer.add_bus_effect(master, lim)
	Pad.bind()
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.size_changed.connect(_ui_scale)
	_ui_scale()
	if not InputMap.has_action("slot_6"):          # (the tin whistle's: the project's own keys stop at 5)
		InputMap.add_action("slot_6")
		var six := InputEventKey.new()
		six.physical_keycode = KEY_6
		InputMap.action_add_event("slot_6", six)
	for a: Array in REBINDABLE:
		_defaults[a[0]] = InputMap.action_get_events(a[0]).duplicate()
	get_tree().node_added.connect(_on_node_added)
	if _testing():
		path = ""
		window = "windowed"           # (screenshots keep the project's own window)
		window_size = Vector2i(1152, 648)
		prep = {"career": "off", "rivals": "off"}     # (tests stock her as she casts off, unless one's testing the prep)
	else:
		load_file()
	if _cmd_size != Vector2i.ZERO:
		window = "windowed"
	apply()


## --resolution WxH on the command line (Godot's own, for screenshots and tests): that window this run, whatever's
## saved (and not saved over it).
var _cmd_size := Vector2i.ZERO
## The smallest screen the menus and the HUD are laid out for (px).
const UI_MIN := Vector2(1152, 648)


## (Godot keeps its own options out of get_cmdline_args(): the window it opened says. It opens at the project's
## size unless told otherwise.)
static func _resolution_arg() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	var opened := DisplayServer.window_get_size()
	var project := Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
			int(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))
	return opened if opened != project and opened.x > 0 else Vector2i.ZERO


## The menus and the HUD scaled to the window, laid out on at least UI_MIN: crisp, by the biggest whole number it has
## room for (the pixel font's pixels square and even), the room left over theirs to use; large, by as much as fills it.
func _ui_scale() -> void:
	var root := get_tree().root
	var k := minf(root.size.x / UI_MIN.x, root.size.y / UI_MIN.y)
	root.content_scale_factor = maxf(floorf(k) if ui_size == "crisp" else k, 1.0)


func set_ui_size(v: String) -> void:
	ui_size = v if UI_SIZES.has(v) else "crisp"
	_ui_scale()
	changed.emit()


## The game to the background: the mouse let go (the pause card comes up, ui/menu.gd), not left captured behind it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _testing() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for a in OS.get_cmdline_args():
		if a.contains("tests/"):
			return true
	return false


## Which was touched last, the pad or the keys and mouse (a nudge of the mouse doesn't count); and L3's sprint.
func _input(e: InputEvent) -> void:
	var now := pad
	if Pad.is_pad(e):
		now = true
	elif e is InputEventKey or e is InputEventMouseButton or (e is InputEventMouseMotion
			and (e as InputEventMouseMotion).relative.length() > 4.0):
		now = false
	if now != pad:
		pad = now
		device_changed.emit()
	var b := e as InputEventJoypadButton
	if b != null and b.button_index == JOY_BUTTON_LEFT_STICK and b.pressed:
		_sprint_latch = not _sprint_latch
		if _sprint_latch:
			Input.action_press("sprint")
		else:
			Input.action_release("sprint")


func _process(_delta: float) -> void:
	# (the sprint L3 clicked on goes off once the left stick's let go)
	if _sprint_latch and Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() < 0.2:
		_sprint_latch = false
		Input.action_release("sprint")


## A buzz in the hands (a strike, a hook-up, the harpoon going in), if rumble's on: `weak` and `strong` 0..1, for
## `secs`. Every pad plugged in feels it (Steam Input passes it on).
func buzz(weak: float, strong: float, secs: float) -> void:
	if not rumble:
		return
	last_rumble = [weak, strong, secs]
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), secs)


## Prompt words with their keys as the pad's when it's the pad in your hands (Pad.say()).
func say(text: String) -> String:
	return Pad.say(text, pad)


## Anything that makes sound and was left on Master: onto Effects (so the effects slider has it).
func _on_node_added(n: Node) -> void:
	if (n is AudioStreamPlayer or n is AudioStreamPlayer3D or n is AudioStreamPlayer2D) and n.get("bus") == &"Master":
		n.set("bus", &"Effects")


## Everything as it stands now: the buses, the window, the frame cap (the look is read live by the crew).
func apply() -> void:
	for b: String in volume:
		_apply_volume(b)
	_apply_display()
	_ui_scale()
	changed.emit()


func set_sensitivity(v: float) -> void:
	sensitivity = clampf(v, 0.1, 4.0)
	changed.emit()


func set_invert_y(on: bool) -> void:
	invert_y = on
	changed.emit()


func set_pad_sensitivity(v: float) -> void:
	pad_sensitivity = clampf(v, 0.1, 4.0)
	changed.emit()


func set_pad_invert_y(on: bool) -> void:
	pad_invert_y = on
	changed.emit()


## The dock prep for a mode ("career" or "rivals").
func prep_for(mode: String) -> String:
	return str(prep.get(mode, "full"))


func set_prep(mode: String, v: String) -> void:
	if PREPS.has(v) and prep.has(mode):
		prep[mode] = v
		changed.emit()


## The next one along (the lobby's and the board's ENTER TO CHANGE).
func next_prep(mode: String) -> void:
	set_prep(mode, PREPS[(PREPS.find(prep_for(mode)) + 1) % PREPS.size()])
	save_file()


func set_rumble(on: bool) -> void:
	rumble = on
	if not on:
		for d in Input.get_connected_joypads():
			Input.stop_joy_vibration(d)
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
		_cmd_size = Vector2i.ZERO        # (picked on the page: that, now)
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
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)) + float(TRIM.get(bus, 0.0)))


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
		var size := _cmd_size if _cmd_size != Vector2i.ZERO else window_size
		var s := Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
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


## What an action's on, as the keys page says it ("W", "LEFT CLICK / C"); the pad's own aren't listed there.
func describe(action: String) -> String:
	var names := PackedStringArray()
	for e in InputMap.action_get_events(action):
		if not (e is InputEventJoypadButton or e is InputEventJoypadMotion):
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
	return Pad.input_name(e)


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


## An input as the file keeps it: "key:87", "mouse:1"; the pad's ("pad:0", "axis:5:1") aren't written, they're
## always the defaults, put back as the file's read.
static func _code(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		return "key:%d" % (k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if e is InputEventMouseButton:
		return "mouse:%d" % (e as InputEventMouseButton).button_index
	if e is InputEventJoypadButton:
		return "pad:%d" % (e as InputEventJoypadButton).button_index
	if e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		return "axis:%d:%d" % [m.axis, signf(m.axis_value)]
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
	c.set_value("pad", "sensitivity", pad_sensitivity)
	c.set_value("pad", "invert_y", pad_invert_y)
	c.set_value("pad", "rumble", rumble)
	for b: String in volume:
		c.set_value("sound", b.to_lower(), volume[b])
	c.set_value("display", "window", window)
	c.set_value("display", "window_size", window_size)
	c.set_value("display", "vsync", vsync)
	c.set_value("display", "max_fps", max_fps)
	c.set_value("display", "ui_size", ui_size)
	for m: String in prep:
		c.set_value("match", "prep_" + m, prep[m])
	for a: Array in REBINDABLE:
		var codes := PackedStringArray()
		for e in InputMap.action_get_events(a[0]):
			if e is InputEventKey or e is InputEventMouseButton:
				codes.append(_code(e))
		c.set_value("keys", a[0], codes)
	return c.save(path)


## Reads the file (missing: everything stays as it is) and applies it.
func load_file() -> Error:
	if path.is_empty():
		return ERR_UNAVAILABLE
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var c := ConfigFile.new()
	var err := c.load(path)
	if err != OK:
		push_warning("Settings: %s won't read; the defaults till they're saved again" % path)
		return err
	sensitivity = clampf(_num(c, "look", "sensitivity", sensitivity), 0.1, 4.0)
	invert_y = _flag(c, "look", "invert_y", invert_y)
	fov = clampf(_num(c, "look", "fov", fov), 55.0, 110.0)
	pad_sensitivity = clampf(_num(c, "pad", "sensitivity", pad_sensitivity), 0.1, 4.0)
	pad_invert_y = _flag(c, "pad", "invert_y", pad_invert_y)
	rumble = _flag(c, "pad", "rumble", rumble)
	for b: String in volume:
		volume[b] = clampf(_num(c, "sound", b.to_lower(), volume[b]), 0.0, 1.0)
	window = str(c.get_value("display", "window", window))
	if not WINDOWS.has(window):
		window = "windowed"
	var s: Variant = c.get_value("display", "window_size", window_size)
	if s is Vector2i and (s as Vector2i).x >= 640 and (s as Vector2i).y >= 360:
		window_size = s
	vsync = _flag(c, "display", "vsync", vsync)
	max_fps = clampi(int(_num(c, "display", "max_fps", max_fps)), 0, 1000)
	ui_size = str(c.get_value("display", "ui_size", ui_size))
	if not UI_SIZES.has(ui_size):
		ui_size = "crisp"
	for m: String in prep.keys():
		var v := str(c.get_value("match", "prep_" + m, prep[m]))
		if PREPS.has(v):
			prep[m] = v
	for a: Array in REBINDABLE:
		var codes: Variant = c.get_value("keys", a[0], PackedStringArray())
		if not (codes is PackedStringArray or codes is Array):
			continue
		var events: Array[InputEvent] = []
		for code: Variant in codes:
			var e := _decode(str(code))
			if e != null:
				events.append(e)
		if not events.is_empty():
			InputMap.action_erase_events(a[0])
			for e in events:
				InputMap.action_add_event(a[0], e)
	Pad.bind()
	apply()
	return OK


## A number from the file (anything else there: `default`).
static func _num(c: ConfigFile, section: String, key: String, default: float) -> float:
	var v: Variant = c.get_value(section, key, default)
	return float(v) if (v is float or v is int) and is_finite(float(v)) else default


static func _flag(c: ConfigFile, section: String, key: String, default: bool) -> bool:
	var v: Variant = c.get_value(section, key, default)
	return bool(v) if (v is bool or v is int) else default
