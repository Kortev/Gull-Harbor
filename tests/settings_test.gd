extends Node
## The settings (core/settings.gd) and their page (ui/settings_page.gd): change things, write the file, put them back
## to the defaults, read the file, and everything's as it was set and applied: the sensitivity and invert Y in your
## look, the field of view in your eyes, each bus's loudness, a rebound key in the InputMap. And the page: a slider
## dragged changes the loudness as it goes, a key row takes the next key pressed, a clash shows.
## Run: godot --headless --fixed-fps 30 --path . res://tests/settings_test.tscn

const Sea := preload("res://sea/sea.gd")
const Page := preload("res://ui/settings_page.gd")
const FILE := "user://settings_test.cfg"

var fails: Array[String] = []
var sea: Sea


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = true
	return k


func _db(bus: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func _ready() -> void:
	_check(Settings.path.is_empty(), "a test never touches the player's own file")
	for b: String in ["Effects", "Voice", "Music"]:
		_check(AudioServer.get_bus_index(b) >= 0, "the %s bus is there" % b)
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await _frames(10)
	var me := sea.crew.me
	Settings.path = FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	# sound off the shelf goes through Effects
	var p := AudioStreamPlayer.new()
	add_child(p)
	_check(p.bus == &"Effects", "a sound left on Master goes through Effects")
	# the look: one mouse move at 1, then at 2 and inverted
	var yaw0 := float(me.get("_yaw"))
	var pitch0 := float(me.get("_pitch"))
	me.call("look", Vector2(10, 10))
	var dyaw := float(me.get("_yaw")) - yaw0
	var dpitch := float(me.get("_pitch")) - pitch0
	# change everything
	Settings.set_sensitivity(2.0)
	Settings.set_invert_y(true)
	Settings.set_fov(90.0)
	Settings.set_volume("Master", 0.8)
	Settings.set_volume("Effects", 0.5)
	Settings.set_volume("Voice", 0.25)
	Settings.set_volume("Music", 0.0)
	Settings.set_window("borderless", Vector2i(1600, 900))
	Settings.set_vsync(false)
	Settings.set_max_fps(144)
	Settings.bind("jump", _key(KEY_K))
	_check(Settings.save_file() == OK and FileAccess.file_exists(FILE), "written to the file")
	# all back to the defaults...
	Settings.set_sensitivity(1.0)
	Settings.set_invert_y(false)
	Settings.set_fov(75.0)
	for b: String in Settings.volume:
		Settings.set_volume(b, 1.0)
	Settings.set_window("windowed", Settings.SIZES[0])
	Settings.set_vsync(true)
	Settings.set_max_fps(0)
	Settings.reset_keys()
	_check(InputMap.action_has_event("jump", _key(KEY_SPACE)) and not InputMap.action_has_event("jump", _key(KEY_K)),
			"RESET TO DEFAULTS puts jump back on Space")
	# ...and read back
	_check(Settings.load_file() == OK, "read from the file")
	_check(is_equal_approx(Settings.sensitivity, 2.0) and Settings.invert_y and is_equal_approx(Settings.fov, 90.0),
			"the look's back: sensitivity 2, inverted, 90°")
	_check(Settings.window == "borderless" and Settings.window_size == Vector2i(1600, 900) and not Settings.vsync
			and Settings.max_fps == 144, "the screen's back: borderless, 1600 x 900, no vsync, 144 fps")
	var y1 := float(me.get("_yaw"))
	var p1 := float(me.get("_pitch"))
	me.call("look", Vector2(10, 10))
	var dyaw2 := float(me.get("_yaw")) - y1
	var dpitch2 := float(me.get("_pitch")) - p1
	_check(is_equal_approx(dyaw2, dyaw * 2.0), "the sensitivity reaches the look (%.4f, was %.4f)" % [dyaw2, dyaw])
	_check(is_equal_approx(dpitch2, -dpitch * 2.0), "and invert Y flips it up for down (%.4f, was %.4f)"
			% [dpitch2, dpitch])
	await _frames(2)
	_check(is_equal_approx((me.get("cam") as Camera3D).fov, 90.0), "the field of view's in your eyes")
	_check(is_equal_approx(_db("Master"), linear_to_db(0.8)) and is_equal_approx(_db("Effects"), linear_to_db(0.5))
			and is_equal_approx(_db("Voice"), linear_to_db(0.25)), "each bus at its loudness (%.1f, %.1f, %.1f dB)"
			% [_db("Master"), _db("Effects"), _db("Voice")])
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "music at 0: muted")
	_check(InputMap.action_has_event("jump", _key(KEY_K)) and not InputMap.action_has_event("jump", _key(KEY_SPACE)),
			"the rebind's back: jump on K, not Space")
	_check(InputMap.event_is_action(_key(KEY_K), "jump"), "and K jumps")
	_check(Settings.clashes("jump").is_empty(), "no clash on K")
	Settings.reset_keys()
	var clean := true
	for a: Array in Settings.REBINDABLE:
		clean = clean and Settings.clashes(a[0]).is_empty()
	_check(clean, "the project's own keys: no clashes")
	Settings.load_file()
	# the page: drag the master slider, rebind a key there, see the clash
	var page := Page.new()
	add_child(page)
	page.open(1)
	await _frames(2)
	var bar: Rect2 = (page.get("_bars") as Array)[0]
	_check(bar.size.x > 0.0, "SOUND: the master slider's drawn")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(bar.position.x + bar.size.x * 0.25, bar.get_center().y)
	page.call("_on_input", press)
	_check(absf(float(Settings.volume["Master"]) - 0.25) < 0.051, "a click on the bar sets it (%.2f)"
			% float(Settings.volume["Master"]))
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(bar.position.x + bar.size.x * 0.75, bar.get_center().y)
	page.call("_on_input", drag)
	_check(absf(float(Settings.volume["Master"]) - 0.75) < 0.051 and is_equal_approx(_db("Master"),
			linear_to_db(float(Settings.volume["Master"]))), "dragging it, the bus follows live (%.2f)"
			% float(Settings.volume["Master"]))
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	page.call("_on_input", up)
	page.call("_turn", 3)
	await _frames(1)
	var rows: Array = page.get("_rows")
	var shove := -1
	for i in rows.size():
		if str(rows[i].get("action", "")) == "shove":
			shove = i
	page.call("_press", shove)
	_check(str(page.get("_waiting")) == "shove", "KEYS: a click on SHOVE waits for its key")
	page.call("_input", _key(KEY_K))
	_check(InputMap.event_is_action(_key(KEY_K), "shove") and str(page.get("_waiting")).is_empty(),
			"the next key pressed is it")
	_check(Settings.clashes("shove").has("JUMP / HOP THE RAIL"), "and K on jump too shows as a clash")
	page.call("_press", shove)
	var esc := _key(KEY_ESCAPE)
	page.call("_input", esc)
	_check(InputMap.event_is_action(_key(KEY_K), "shove"), "Esc while it waits keeps what it had")
	page.close()
	_check(not page.visible and FileAccess.file_exists(FILE), "BACK closes it and writes the file")
	# the menu and the title have the way in
	var menu: Node = sea.get_children().filter(func(n: Node) -> bool: return n.get_script() == load("res://ui/menu.gd"))[0]
	menu.call("open_settings")
	_check((menu.get("_settings") as Control).visible, "the pause card's SETTINGS opens it")
	(menu.get("_settings") as Control).call("close")
	var title := (load("res://ui/title.gd") as GDScript).new() as CanvasLayer
	title.set("sea", sea)
	sea.add_child(title)
	await _frames(1)
	var names := (title.get("_items") as Array).map(func(it: Array) -> String: return str(it[0]))
	_check(names.has("SETTINGS"), "the title's main page has SETTINGS")
	title.call("open_settings")
	_check((title.get("settings") as Control).visible, "and it opens the page over the title")
	title.queue_free()
	Settings.reset_keys()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	for f in fails:
		print("FAIL ", f)
	print("SETTINGS TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)
