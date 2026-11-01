extends RefCounted
## The gamepad, an Xbox-style layout (Steam Input hands every pad over as one): put onto the project's actions as the
## game starts (bind(), from core/settings.gd; project.godot's own keys stay as they are), a pad press as the key a
## menu wants (as_key()), and the prompts' key names as the pad's (say(): "E ON THE ROD" is "[X] ON THE ROD") while
## the pad's what you last touched (Settings.pad).
##
##   left stick   walk, swim, climb; at the wheel throttle and steer     right stick   look (the rod, with a fish on)
##   A            jump, up on the rail                                    B             drop it, put back
##   X            use, grab (hold to haul)                                Y             shove
##   RT           cast, reel (as hard as it's pulled), swing; throttle    LT            heave, aim, steady; astern
##   LB / RB      last / next in hand (with a fish on: the drag)          d-pad < >     the same
##   d-pad up     talk out loud                                           d-pad down    talk on the VHF
##   L3           sprint (clicked: on till the stick lets go)             R3            dive
##   START        the pause card

## An action's buttons.
const BUTTONS := {
	"jump": [JOY_BUTTON_A], "drop": [JOY_BUTTON_B], "interact": [JOY_BUTTON_X], "shove": [JOY_BUTTON_Y],
	"slot_prev": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT],
	"slot_next": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT],
	"swim_down": [JOY_BUTTON_RIGHT_STICK], "pause": [JOY_BUTTON_START],
	"talk": [JOY_BUTTON_DPAD_UP], "radio": [JOY_BUTTON_DPAD_DOWN],
}
## An action's stick or trigger: [axis, which way].
const AXES := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1], "move_back": [JOY_AXIS_LEFT_Y, 1],
	"move_left": [JOY_AXIS_LEFT_X, -1], "move_right": [JOY_AXIS_LEFT_X, 1],
	"rod_left": [JOY_AXIS_LEFT_X, -1], "rod_right": [JOY_AXIS_LEFT_X, 1],
	"use_primary": [JOY_AXIS_TRIGGER_RIGHT, 1], "rod_reel": [JOY_AXIS_TRIGGER_RIGHT, 1],
	"use_secondary": [JOY_AXIS_TRIGGER_LEFT, 1], "rod_brace": [JOY_AXIS_TRIGGER_LEFT, 1],
	"look_left": [JOY_AXIS_RIGHT_X, -1], "look_right": [JOY_AXIS_RIGHT_X, 1],
	"look_up": [JOY_AXIS_RIGHT_Y, -1], "look_down": [JOY_AXIS_RIGHT_Y, 1],
}
## The right stick: its dead middle, and the curve past it (an exponent: small pushes turn you slowly, for aiming).
const LOOK_DEAD := 0.14
const LOOK_CURVE := 1.8
## A whole push of the right stick, in mouse px a second (crew/player.gd's look(): about 220°/s at 1).
const LOOK_PX := 1600.0
## How far a stick goes over before a menu takes it as an arrow.
const MENU_TILT := 0.55

## Each button's and axis's name, as the prompts say it.
const BUTTON_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3",
		JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_START: "START", JOY_BUTTON_BACK: "VIEW",
		JOY_BUTTON_DPAD_UP: "D-UP", JOY_BUTTON_DPAD_DOWN: "D-DOWN", JOY_BUTTON_DPAD_LEFT: "D-LEFT",
		JOY_BUTTON_DPAD_RIGHT: "D-RIGHT"}
const AXIS_NAMES := {JOY_AXIS_LEFT_X: "LS", JOY_AXIS_LEFT_Y: "LS", JOY_AXIS_RIGHT_X: "RS", JOY_AXIS_RIGHT_Y: "RS",
		JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}

## The words the game's prompts name keys with, and the pad's for them, in order (the longer first: "HOLD LEFT MOUSE"
## before "LEFT MOUSE"; a lone capital only standing alone, never in a word or after an apostrophe: HE'S stays).
const SAY := [
	["(?i)\\bspace or click\\b", "[A]"],
	["(?i)\\b(left mouse|left click|lmb)\\b", "[RT]"],
	["(?i)\\b(right mouse|right click|rmb)\\b", "[LT]"],
	["(?i)\\bmouse wheel\\b", "[LB]/[RB]"],
	["(?i)\\bclick\\b", "[RT]"],
	["(?i)\\b(wasd|w/s|a/d|w and s|a and d|a or d)\\b", "[LS]"],
	["(?i)\\bspace\\b", "[A]"],
	["(?i)\\bshift\\b", "[L3]"],
	["(?i)\\bctrl\\b", "[R3]"],
	["(?i)\\besc\\b", "[B]"],
	["(?<![A-Za-z0-9'\\[])E(?![A-Za-z0-9'\\]])", "[X]"],
	["(?<![A-Za-z0-9'\\[])Q(?![A-Za-z0-9'\\]])", "[B]"],
	["(?<![A-Za-z0-9'\\[])F(?![A-Za-z0-9'\\]])", "[Y]"],
	["(?<![A-Za-z0-9'\\[])V(?![A-Za-z0-9'\\]])", "[D-UP]"],
	["(?<![A-Za-z0-9'\\[])R(?![A-Za-z0-9'\\]])", "[D-DOWN]"],
	["(?<![A-Za-z0-9'\\[])[WS](?![A-Za-z0-9'\\]])", "[LS]"],
]

static var _say: Array = []                # [RegEx, replacement], made the first time
static var _stick := {}                    # "device:axis" -> which way a menu last had it (-1, 0, 1)
static var _seen := ""                     # the last motion as_key() was asked about, and what it said
static var _seen_key: InputEventKey


## The pad onto the InputMap: each action its buttons and axes (the look's four made here, project.godot has none).
static func bind() -> void:
	for a: String in ["look_left", "look_right", "look_up", "look_down"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a, LOOK_DEAD)
	for a: String in BUTTONS:
		if InputMap.has_action(a):
			for b: int in BUTTONS[a]:
				var e := InputEventJoypadButton.new()
				e.button_index = b as JoyButton
				e.device = -1
				if not InputMap.action_has_event(a, e):
					InputMap.action_add_event(a, e)
	for a: String in AXES:
		if InputMap.has_action(a):
			var m := InputEventJoypadMotion.new()
			m.axis = AXES[a][0] as JoyAxis
			m.axis_value = float(AXES[a][1])
			m.device = -1
			if not InputMap.action_has_event(a, m):
				InputMap.action_add_event(a, m)


## Whether `e` is the pad's (a button, or a stick pushed past drifting).
static func is_pad(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or (e is InputEventJoypadMotion
			and absf((e as InputEventJoypadMotion).axis_value) > 0.4)


## The right stick as the look wants it: past its dead middle, on its curve (length 0..1).
static func look_stick() -> Vector2:
	var v := Input.get_vector("look_left", "look_right", "look_up", "look_down", LOOK_DEAD)
	return v * pow(v.length(), LOOK_CURVE - 1.0) if v != Vector2.ZERO else Vector2.ZERO


## A trigger, 0..1, whichever pad's pulling it hardest.
static func trigger(axis: JoyAxis) -> float:
	var most := 0.0
	for d in Input.get_connected_joypads():
		most = maxf(most, Input.get_joy_axis(d, axis))
	return clampf(most, 0.0, 1.0)


## A pad press as the menus' keys: the d-pad or the left stick their arrows, A Enter, B and START Esc, RB Tab and LB
## shift-Tab. Anything else (or a key, or the mouse): null. A stick only counts as it goes over, once each way.
static func as_key(e: InputEvent) -> InputEventKey:
	var code := KEY_NONE
	var shift := false
	if e is InputEventJoypadButton:
		var b := e as InputEventJoypadButton
		if not b.pressed:
			return null
		match b.button_index:
			JOY_BUTTON_DPAD_UP: code = KEY_UP
			JOY_BUTTON_DPAD_DOWN: code = KEY_DOWN
			JOY_BUTTON_DPAD_LEFT: code = KEY_LEFT
			JOY_BUTTON_DPAD_RIGHT: code = KEY_RIGHT
			JOY_BUTTON_A: code = KEY_ENTER
			JOY_BUTTON_B, JOY_BUTTON_START: code = KEY_ESCAPE
			JOY_BUTTON_RIGHT_SHOULDER: code = KEY_TAB
			JOY_BUTTON_LEFT_SHOULDER:
				code = KEY_TAB
				shift = true
	elif e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		if m.axis != JOY_AXIS_LEFT_X and m.axis != JOY_AXIS_LEFT_Y:
			return null
		# (one motion's asked about by more than one menu: each hears the same)
		var sig := "%d:%d:%f:%d" % [m.device, m.axis, m.axis_value, Engine.get_process_frames()]
		if sig == _seen:
			return _seen_key
		var at := "%d:%d" % [m.device, m.axis]
		var way := 0
		if absf(m.axis_value) >= MENU_TILT:
			way = 1 if m.axis_value > 0.0 else -1
		elif absf(m.axis_value) > MENU_TILT * 0.6:
			way = int(_stick.get(at, 0))         # (a little give, so a stick held over doesn't chatter)
		var was := int(_stick.get(at, 0))
		_stick[at] = way
		if way != 0 and way != was:
			if m.axis == JOY_AXIS_LEFT_X:
				code = KEY_RIGHT if way > 0 else KEY_LEFT
			else:
				code = KEY_DOWN if way > 0 else KEY_UP
		_seen = sig
		_seen_key = _key(code, false) if code != KEY_NONE else null
		return _seen_key
	return _key(code, shift) if code != KEY_NONE else null


static func _key(code: Key, shift: bool) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.shift_pressed = shift
	k.pressed = true
	return k


## `text` with its keys named as the pad's (when `pad`; otherwise as it is).
static func say(text: String, pad: bool) -> String:
	if not pad or text.is_empty():
		return text
	if _say.is_empty():
		for r: Array in SAY:
			var re := RegEx.new()
			re.compile(r[0])
			_say.append([re, r[1]])
	for r: Array in _say:
		text = (r[0] as RegEx).sub(text, r[1], true)
	return text


## A prompt's key on its own, for the little key cap ("E": "X"; a hand slot's number: the bumpers that get you there).
static func cap(key: String, pad: bool) -> String:
	if not pad:
		return key
	if key.length() == 1 and key >= "1" and key <= "9":
		return "LB/RB"
	return say(key, true).replace("[", "").replace("]", "")       # ("HOLD LMB": "HOLD RT")


## An input's name ("A", "RT", "LS"), for one of the pad's.
static func input_name(e: InputEvent) -> String:
	if e is InputEventJoypadButton:
		return BUTTON_NAMES.get((e as InputEventJoypadButton).button_index, "PAD %d"
				% (e as InputEventJoypadButton).button_index)
	if e is InputEventJoypadMotion:
		return AXIS_NAMES.get((e as InputEventJoypadMotion).axis, "AXIS %d" % (e as InputEventJoypadMotion).axis)
	return "?"
