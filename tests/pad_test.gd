extends Node
## The pad (core/pad.gd, core/settings.gd): its buttons and sticks are on the actions, the right stick turns your head
## (on its curve, with its own sensitivity and invert Y), a trigger reels part way, L3 sprints till the stick lets go;
## the menus go round with the d-pad and the left stick and A and B (the settings page, the title, the harbour
## board's buttons by Godot's own focus); the prompts name the pad's buttons while it's the pad in hand and the keys
## again once a key's pressed; and rumble's asked for on a strike, unless it's switched off.
## Run: godot --headless --fixed-fps 30 --path . res://tests/pad_test.tscn

const Sea := preload("res://sea/sea.gd")
const Page := preload("res://ui/settings_page.gd")
const Title := preload("res://ui/title.gd")
const FILE := "user://pad_test.cfg"

var fails: Array[String] = []
var sea: Sea


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _button(b: JoyButton, down := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	return e


func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e


func _send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## The right stick held at `v` for `n` frames: how far your head turned (yaw, pitch).
func _hold_look(me: Node, v: Vector2, n: int) -> Vector2:
	var y0 := float(me.get("_yaw"))
	var p0 := float(me.get("_pitch"))
	_send(_axis(JOY_AXIS_RIGHT_X, v.x))
	_send(_axis(JOY_AXIS_RIGHT_Y, v.y))
	await _frames(n)
	_send(_axis(JOY_AXIS_RIGHT_X, 0.0))
	_send(_axis(JOY_AXIS_RIGHT_Y, 0.0))
	await _frames(1)
	return Vector2(float(me.get("_yaw")) - y0, float(me.get("_pitch")) - p0)


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await _frames(10)
	var me := sea.crew.me
	me.set("force_input", true)
	# the pad's on the actions
	var on := func(e: InputEvent, action: String) -> bool: return InputMap.event_is_action(e, action)
	_check(on.call(_button(JOY_BUTTON_A), "jump") and on.call(_button(JOY_BUTTON_X), "interact")
			and on.call(_button(JOY_BUTTON_B), "drop") and on.call(_button(JOY_BUTTON_Y), "shove")
			and on.call(_button(JOY_BUTTON_START), "pause") and on.call(_button(JOY_BUTTON_RIGHT_SHOULDER), "slot_next")
			and on.call(_button(JOY_BUTTON_DPAD_UP), "talk") and on.call(_button(JOY_BUTTON_DPAD_DOWN), "radio"),
			"A jumps, X uses, B drops, Y shoves, START pauses, RB's the next in hand, the d-pad talks")
	_check(on.call(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), "use_primary")
			and on.call(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0), "use_secondary")
			and on.call(_axis(JOY_AXIS_LEFT_Y, -1.0), "move_forward") and on.call(_axis(JOY_AXIS_RIGHT_X, 1.0), "look_right"),
			"RT casts and reels, LT heaves, the left stick walks, the right stick looks")
	_check(Settings.describe("jump") == "SPACE" and Settings.clashes("jump").is_empty(),
			"the keys page still lists the keyboard's own (jump: %s), no clash from the pad" % Settings.describe("jump"))
	_check(not Settings.pad, "the keys and mouse to start with")
	# the look
	var turned: Vector2 = await _hold_look(me, Vector2(1.0, 0.0), 15)
	_check(Settings.pad, "the stick moved: it's the pad in hand now")
	_check(turned.x < -0.5, "the right stick over to the right turns you right (%.2f rad in half a second)" % turned.x)
	var soft: Vector2 = await _hold_look(me, Vector2(0.4, 0.0), 15)
	_check(soft.x < 0.0 and absf(soft.x) < absf(turned.x) * 0.3,
			"a little push turns you slowly, on the curve (%.2f against %.2f)" % [soft.x, turned.x])
	var dead: Vector2 = await _hold_look(me, Vector2(0.08, 0.08), 10)
	_check(dead.length() < 0.0001, "inside the dead middle: nothing (drift)")
	var up: Vector2 = await _hold_look(me, Vector2(0.0, -1.0), 6)
	Settings.set_pad_invert_y(true)
	var up_inv: Vector2 = await _hold_look(me, Vector2(0.0, -1.0), 6)
	Settings.set_pad_invert_y(false)
	_check(up.y > 0.1 and up_inv.y < -0.1, "stick up looks up (%.2f); inverted, down (%.2f)" % [up.y, up_inv.y])
	Settings.set_pad_sensitivity(2.0)
	var fast: Vector2 = await _hold_look(me, Vector2(1.0, 0.0), 6)
	Settings.set_pad_sensitivity(1.0)
	var norm: Vector2 = await _hold_look(me, Vector2(1.0, 0.0), 6)
	_check(absf(fast.x) > absf(norm.x) * 1.7, "the pad's sensitivity reaches it (%.2f at 2, %.2f at 1)"
			% [fast.x, norm.x])
	me.set("_pitch", 0.0)
	# the buttons fire their actions; a trigger part way is part way
	_send(_button(JOY_BUTTON_X))
	_check(Input.is_action_pressed("interact"), "X: use")
	_send(_button(JOY_BUTTON_X, false))
	_send(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.6))
	var pull := Input.get_action_strength("use_primary")
	_check(Input.is_action_pressed("use_primary") and pull > 0.3 and pull < 0.8,
			"RT part way: casting, reeling, at %.2f of full" % pull)
	_send(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	_check(not Input.is_action_pressed("use_primary"), "and let go, not")
	var y0 := (me.get("body") as Node3D).position.y
	_send(_button(JOY_BUTTON_A))
	var rose := 0.0
	for i in 12:
		await get_tree().physics_frame
		rose = maxf(rose, (me.get("body") as Node3D).position.y - y0)
	_send(_button(JOY_BUTTON_A, false))
	_check(rose > 0.05, "A: a jump (up %.2f m)" % rose)
	await _frames(20)
	_send(_axis(JOY_AXIS_LEFT_Y, -1.0))
	_send(_button(JOY_BUTTON_LEFT_STICK))
	_send(_button(JOY_BUTTON_LEFT_STICK, false))
	await _frames(2)
	_check(Input.is_action_pressed("sprint"), "L3 clicked, the stick forward: sprinting")
	_send(_axis(JOY_AXIS_LEFT_Y, 0.0))
	await _frames(2)
	_check(not Input.is_action_pressed("sprint"), "the stick let go: walking again")
	# the prompts, in the pad's buttons
	var hud: Node = sea.crew.hud
	hud.call("_on_prompt", "SPACE|Jump")
	var key := hud.get("_key") as Label
	var what := hud.get("_what") as Label
	_check(key.text == "A" and what.text == "Jump", "a prompt's key cap: A, not SPACE (%s)" % key.text)
	hud.call("_on_prompt", "HOLD LMB|BLEED HIM, QUICK")
	_check(key.text == "HOLD RT", "the mouse's left button on a cap: RT (%s)" % key.text)
	hud.call("_on_prompt", "Q: rod back first")
	_check(key.text == "X" and what.text == "[B]: rod back first", "E's X, Q's B (%s | %s)" % [key.text, what.text])
	_check(Settings.say("HOLD LEFT MOUSE: REEL") == "HOLD [RT]: REEL"
			and Settings.say("HE'S HEADING FOR THE PORT LINE! E ON IT: REEL IT IN!")
			== "HE'S HEADING FOR THE PORT LINE! [X] ON IT: REEL IT IN!"
			and Settings.say("Hold click, let go: throw. Right mouse steadies") == "Hold [RT], let go: throw. [LT] steadies"
			and Settings.say("W/S throttle   A/D steer") == "[LS] throttle   [LS] steer",
			"the words: left mouse RT, right mouse LT, E X, WASD the stick, and HE'S still HE'S")
	var k := InputEventKey.new()
	k.keycode = KEY_K
	k.physical_keycode = KEY_K
	k.pressed = true
	_send(k)
	_check(not Settings.pad and key.text == "E" and what.text == "Q: rod back first",
			"a key pressed: the keys again, and the prompt says so (%s | %s)" % [key.text, what.text])
	_check(Settings.say("HOLD LEFT MOUSE: REEL") == "HOLD LEFT MOUSE: REEL", "the words as they were")
	_send(_button(JOY_BUTTON_Y))
	_send(_button(JOY_BUTTON_Y, false))
	_check(Settings.pad and key.text == "X", "a button: the pad's again, straight away")
	# rumble: a strike, unless it's off
	Settings.last_rumble = []
	sea.rods.call("_strike", 0, 120.0, 0.0, 0.0, 7)
	_check(not Settings.last_rumble.is_empty(), "a strike: the pad buzzes (%s)" % str(Settings.last_rumble))
	Settings.last_rumble = []
	Settings.set_rumble(false)
	Settings.buzz(1.0, 1.0, 0.5)
	_check(Settings.last_rumble.is_empty(), "rumble off: nothing")
	Settings.set_rumble(true)
	sea.rods.call("_off", 0, "")
	# the PAD settings kept in the file, and a rebind and the file leave the pad's buttons be
	Settings.path = FILE
	Settings.set_pad_sensitivity(2.5)
	Settings.set_pad_invert_y(true)
	Settings.set_rumble(false)
	Settings.bind("jump", k)
	Settings.save_file()
	Settings.set_pad_sensitivity(1.0)
	Settings.set_pad_invert_y(false)
	Settings.set_rumble(true)
	Settings.reset_keys()
	Settings.load_file()
	_check(is_equal_approx(Settings.pad_sensitivity, 2.5) and Settings.pad_invert_y and not Settings.rumble,
			"the PAD page's settings come back from the file")
	_check(InputMap.event_is_action(k, "jump") and InputMap.event_is_action(_button(JOY_BUTTON_A), "jump"),
			"jump rebound to K and read back: A still jumps")
	Settings.set_pad_sensitivity(1.0)
	Settings.set_pad_invert_y(false)
	Settings.set_rumble(true)
	Settings.reset_keys()
	Settings.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	# the settings page: round it with the pad
	var page := Page.new()
	add_child(page)
	page.open(0)
	await _frames(1)
	page.call("_on_input", _button(JOY_BUTTON_DPAD_DOWN))
	_check(int(page.get("_pick")) == 1, "the settings: d-pad down, the next row")
	page.call("_on_input", _axis(JOY_AXIS_LEFT_Y, 0.9))
	page.call("_on_input", _axis(JOY_AXIS_LEFT_Y, 0.95))
	_check(int(page.get("_pick")) == 2, "the stick down: one more, held over it's still one (%d)" % int(page.get("_pick")))
	page.call("_on_input", _axis(JOY_AXIS_LEFT_Y, 0.0))
	page.call("_on_input", _axis(JOY_AXIS_LEFT_Y, -0.9))
	page.call("_on_input", _axis(JOY_AXIS_LEFT_Y, 0.0))
	_check(int(page.get("_pick")) == 1, "let go and up: back one")
	page.call("_on_input", _button(JOY_BUTTON_LEFT_SHOULDER))
	_check(int(page.get("tab")) == Page.TABS.find("PAD"), "LB: the page before, round to PAD")
	page.call("_on_input", _button(JOY_BUTTON_DPAD_DOWN))
	page.call("_on_input", _button(JOY_BUTTON_A))
	_check(Settings.pad_invert_y, "PAD's INVERT LOOK Y: A flips it")
	page.call("_on_input", _button(JOY_BUTTON_A))
	page.call("_on_input", _button(JOY_BUTTON_DPAD_UP))
	var was := Settings.pad_sensitivity
	page.call("_on_input", _button(JOY_BUTTON_DPAD_RIGHT))
	_check(Settings.pad_sensitivity > was, "LOOK SENSITIVITY: d-pad right, up a step (%.2f)" % Settings.pad_sensitivity)
	Settings.set_pad_sensitivity(1.0)
	page.call("_on_input", _button(JOY_BUTTON_B))
	_check(not page.visible, "B: back")
	page.queue_free()
	# the harbour board: Godot's focus, the first button picked up, the d-pad on to the next
	var menu: Node = sea.get_children().filter(func(n: Node) -> bool: return n.get_script() == load("res://ui/menu.gd"))[0]
	await _frames(3)
	var f0 := get_viewport().gui_get_focus_owner()
	_check(f0 is Button and (menu.get("_panel") as Control).is_ancestor_of(f0),
			"the board up with the pad in hand: a button's picked (%s)" % (f0.get("text") if f0 else "none"))
	var down := _button(JOY_BUTTON_DPAD_DOWN)
	get_viewport().push_input(down)
	get_viewport().push_input(_button(JOY_BUTTON_DPAD_DOWN, false))
	await _frames(1)
	var f1 := get_viewport().gui_get_focus_owner()
	_check(f1 is Button and f1 != f0, "d-pad down: the next one (%s)" % (f1.get("text") if f1 else "none"))
	# the title: d-pad and A
	var t := Title.new()
	t.name = "Title"
	t.sea = sea
	sea.add_child(t)
	await _frames(1)
	var view := t.get("_view") as Control
	var pick0 := int(t.get("_pick"))
	t.call("_on_input", _button(JOY_BUTTON_DPAD_DOWN))
	_check(int(t.get("_pick")) == pick0 + 1, "the title: d-pad down, the next")
	t.call("_on_input", _axis(JOY_AXIS_LEFT_Y, -0.9))
	_check(int(t.get("_pick")) == pick0, "the stick up, back")
	t.call("_on_input", _axis(JOY_AXIS_LEFT_Y, 0.0))
	view.queue_redraw()
	t.call("_choose", "rivals")
	t.call("_on_input", _button(JOY_BUTTON_B))
	_check(str(t.get("_page")) == "main", "RIVALS, then B: back to the main page")
	t.queue_free()
	Settings.set_pad_invert_y(false)
	for f in fails:
		print("FAIL ", f)
	print("PAD TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)
