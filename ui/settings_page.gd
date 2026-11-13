extends Control
## The settings page: a column over whatever's behind (the title's harbour, or the sea from the pause card), five
## pages along its top, LOOK, SOUND, SCREEN, KEYS and PAD (the right stick's look, its invert Y, rumble). Everything
## on it is core/settings.gd's, applied the moment it changes (a slider as it's dragged, the field of view and the
## loudness with it); the file's written on BACK.
##
## Drawn in the kit's hand (ui/kit.gd; the menus' brief is docs/UI_MENUS_BRIEF.md): no panel, one flat dim over the
## whole screen and type and linework on it. A slider is a ruler with a pointer on the value, a switch the word ON or
## OFF, a choice its word between two pointers, the one picked yellow. Mouse: hover picks, click or drag changes.
## Keys: up and down pick, left and right change, Enter flips or presses, Tab the next page, Esc back. On KEYS, click an
## action (or Enter) and press the key or mouse button for it (Esc keeps what it had); one that clashes with another
## shows orange, and says with what.
## A pad works it as the keys do (core/pad.gd's as_key(): the d-pad or left stick, A, B back, the bumpers the pages).

signal closed

const Kit := preload("res://ui/kit.gd")
const Sfx := preload("res://audio/sfx.gd")

const TABS := ["LOOK", "SOUND", "SCREEN", "KEYS", "PAD"]
const Pad := preload("res://core/pad.gd")
## A slider's ruler: how many divisions it has (every fifth is long).
const CELLS := 20
## The whole-screen dim (the brief's one exception to no fills).
const DIM := Color(0.02, 0.03, 0.04, 0.6)

var kit := Kit.new()
var tab := 0
var _rows: Array = []        # Dictionary each: kind (slider, toggle, choice, key, button), label, and its own
var _pick := 0
var _drag := -1              # the slider being dragged
var _waiting := ""           # the action waiting for its new key
var _rects: Array[Rect2] = []
var _bars: Array[Rect2] = []
var _tab_rects: Array[Rect2] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false
	gui_input.connect(_on_input)
	Settings.changed.connect(queue_redraw)
	Settings.device_changed.connect(queue_redraw)


## Up, on page `at` (0 LOOK .. 4 PAD).
func open(at := 0) -> void:
	visible = true
	_waiting = ""
	_drag = -1
	_turn(at)
	grab_focus()


## BACK: written to the file, and gone.
func close() -> void:
	_waiting = ""
	_drag = -1
	Settings.save_file()
	visible = false
	closed.emit()


func _turn(to: int) -> void:
	tab = posmod(to, TABS.size())
	_waiting = ""
	_build()
	_pick = 0
	queue_redraw()


func _build() -> void:
	_rows.clear()
	match TABS[tab]:
		"LOOK":
			_rows.append(_slider("MOUSE SENSITIVITY", 0.1, 3.0, 0.05, func() -> float: return Settings.sensitivity,
					Settings.set_sensitivity, func(v: float) -> String: return "%.2f" % v))
			_rows.append({"kind": "toggle", "label": "INVERT MOUSE Y", "get": func() -> bool: return Settings.invert_y,
					"set": Settings.set_invert_y})
			_rows.append(_slider("FIELD OF VIEW", 55.0, 110.0, 1.0, func() -> float: return Settings.fov,
					Settings.set_fov, func(v: float) -> String: return "%d°" % roundi(v)))
		"SOUND":
			for b: Array in [["Master", "MASTER"], ["Effects", "EFFECTS"], ["Voice", "VOICE CHAT"], ["Music", "MUSIC"]]:
				var bus: String = b[0]
				var row := _slider(b[1], 0.0, 1.0, 0.05, func() -> float: return float(Settings.volume[bus]),
						func(v: float) -> void: Settings.set_volume(bus, v),
						func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
				row["tick"] = bus == "Master" or bus == "Effects"
				_rows.append(row)
		"SCREEN":
			_rows.append({"kind": "choice", "label": "WINDOW", "options": [["WINDOWED", "windowed"],
					["BORDERLESS", "borderless"], ["FULLSCREEN", "fullscreen"]],
					"get": func() -> String: return Settings.window,
					"set": func(v: String) -> void: Settings.set_window(v)})
			var sizes := []
			for s: Vector2i in Settings.SIZES:
				sizes.append(["%d X %d" % [s.x, s.y], s])
			_rows.append({"kind": "choice", "label": "WINDOW SIZE", "options": sizes,
					"get": func() -> Vector2i: return Settings.window_size,
					"set": func(v: Vector2i) -> void: Settings.set_window(Settings.window, v)})
			_rows.append({"kind": "toggle", "label": "VSYNC", "get": func() -> bool: return Settings.vsync,
					"set": Settings.set_vsync})
			var caps := []
			for n: int in Settings.FPS:
				caps.append(["NO CAP" if n == 0 else str(n), n])
			_rows.append({"kind": "choice", "label": "MAX FPS", "options": caps,
					"get": func() -> int: return Settings.max_fps, "set": Settings.set_max_fps})
			_rows.append({"kind": "choice", "label": "MENU AND HUD", "options": [["CRISP PIXELS", "crisp"],
					["LARGE", "large"]], "get": func() -> String: return Settings.ui_size,
					"set": Settings.set_ui_size})
		"KEYS":
			for a: Array in Settings.REBINDABLE:
				_rows.append({"kind": "key", "label": a[1], "action": a[0]})
			_rows.append({"kind": "button", "label": "RESET TO DEFAULTS", "press": Settings.reset_keys})
		"PAD":
			_rows.append(_slider("LOOK SENSITIVITY", 0.1, 3.0, 0.05, func() -> float: return Settings.pad_sensitivity,
					Settings.set_pad_sensitivity, func(v: float) -> String: return "%.2f" % v))
			_rows.append({"kind": "toggle", "label": "INVERT LOOK Y", "get": func() -> bool: return Settings.pad_invert_y,
					"set": Settings.set_pad_invert_y})
			_rows.append({"kind": "toggle", "label": "RUMBLE", "get": func() -> bool: return Settings.rumble,
					"set": func(on: bool) -> void:
						Settings.set_rumble(on)
						Settings.buzz(0.3, 0.5, 0.25)})        # (switched on: a taste of it)
	_rows.append({"kind": "button", "label": "BACK", "press": close})


func _slider(label: String, lo: float, hi: float, step: float, get_v: Callable, set_v: Callable,
		shown: Callable) -> Dictionary:
	return {"kind": "slider", "label": label, "min": lo, "max": hi, "step": step, "get": get_v, "set": set_v,
			"shown": shown}


# --- changing things ---

## Left (-1) or right (+1) on a row: a slider a step, a switch flipped, a choice the next.
func _nudge(i: int, dir: int) -> void:
	var r: Dictionary = _rows[i]
	match str(r["kind"]):
		"slider":
			_slide(i, float(r["get"].call()) + dir * float(r["step"]))
		"toggle":
			(r["set"] as Callable).call(not bool(r["get"].call()))
		"choice":
			var opts: Array = r["options"]
			var at := -1
			for j in opts.size():
				if opts[j][1] == r["get"].call():
					at = j
			(r["set"] as Callable).call(opts[posmod(at + dir, opts.size()) if at >= 0 else 0][1])
	queue_redraw()


func _slide(i: int, v: float) -> void:
	var r: Dictionary = _rows[i]
	var lo := float(r["min"])
	var hi := float(r["max"])
	var was := float(r["get"].call())
	v = clampf(snappedf(v, float(r["step"])), lo, hi)
	if is_equal_approx(v, was):
		return
	(r["set"] as Callable).call(v)
	# (you hear the loudness you've picked as you pick it)
	if bool(r.get("tick", false)) and _filled(r, v) != _filled(r, was):
		Sfx.play("ui.tick")
	queue_redraw()


func _filled(r: Dictionary, v: float) -> int:
	return roundi((v - float(r["min"])) / (float(r["max"]) - float(r["min"])) * CELLS)


func _press(i: int) -> void:
	var r: Dictionary = _rows[i]
	match str(r["kind"]):
		"button":
			(r["press"] as Callable).call()
		"key":
			_waiting = str(r["action"])
		_:
			_nudge(i, 1)
	queue_redraw()


## Waiting on a key: the next key or button pressed, anywhere, is it (Esc keeps what was there).
func _input(e: InputEvent) -> void:
	if not visible or _waiting.is_empty():
		return
	if e is InputEventJoypadButton or e is InputEventJoypadMotion:
		# (a page of the keyboard's keys: the pad's own aren't bound here, and its B keeps what was there)
		get_viewport().set_input_as_handled()
		var k := Pad.as_key(e)
		if k != null and k.keycode == KEY_ESCAPE:
			_waiting = ""
			queue_redraw()
		return
	var pressed := (e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo) \
			or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if not (e is InputEventKey and (e as InputEventKey).keycode == KEY_ESCAPE):
		Settings.bind(_waiting, e)
	_waiting = ""
	queue_redraw()


func _on_input(e: InputEvent) -> void:
	if e is InputEventJoypadButton or e is InputEventJoypadMotion:
		e = Pad.as_key(e)
		accept_event()
		if e == null:
			return
	if e is InputEventMouseMotion:
		var at := (e as InputEventMouseMotion).position
		if _drag >= 0:
			_slide_to(_drag, at.x)
		else:
			for i in _rects.size():
				if _rects[i].has_point(at) and i != _pick:
					_pick = i
					queue_redraw()
		accept_event()
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_drag = -1
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_click(mb.position)
		accept_event()
	elif e is InputEventKey and (e as InputEventKey).pressed:
		var k := e as InputEventKey
		match k.keycode:
			KEY_UP:
				_pick = posmod(_pick - 1, _rows.size())
			KEY_DOWN:
				_pick = posmod(_pick + 1, _rows.size())
			KEY_LEFT:
				_nudge(_pick, -1)
			KEY_RIGHT:
				_nudge(_pick, 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_press(_pick)
			KEY_TAB:
				_turn(tab + (-1 if k.shift_pressed else 1))
			KEY_ESCAPE:
				close()
		queue_redraw()
		accept_event()


func _click(at: Vector2) -> void:
	for t in _tab_rects.size():
		if _tab_rects[t].has_point(at):
			_turn(t)
			return
	for i in _rects.size():
		if not _rects[i].has_point(at):
			continue
		_pick = i
		var r: Dictionary = _rows[i]
		match str(r["kind"]):
			"slider":
				_drag = i
				_slide_to(i, at.x)
			"choice":
				_nudge(i, -1 if at.x < _bars[i].get_center().x else 1)
			_:
				_press(i)
		return


func _slide_to(i: int, x: float) -> void:
	var r: Dictionary = _rows[i]
	var bar := _bars[i]
	var u := clampf((x - bar.position.x) / bar.size.x, 0.0, 1.0)
	_slide(i, lerpf(float(r["min"]), float(r["max"]), u))


# --- drawing ---

## The screen's scale (the HUD's): 1 at 1080p.
func _px() -> float:
	return clampf(get_viewport().get_visible_rect().size.y / 1080.0, 0.7, 2.5)


func _draw() -> void:
	var p := _px()
	kit.px = p
	kit.defer = true
	draw_rect(Rect2(Vector2.ZERO, size), DIM)
	var w := minf(size.x - 48.0, 1240.0 * p)
	var x := floorf((size.x - w) * 0.5)
	var y0 := floorf(maxf(20.0 * p, (size.y - 740.0 * p) * 0.5))
	# the title, its heavy rule, and the ticks hanging under the first of it
	kit.num(self, Vector2(x, y0 + 22.0 * p), "SETTINGS", 44.0 * p, Kit.PAPER, -1)
	kit.rule(self, Vector2(x, y0 + 54.0 * p), Vector2(x + w, y0 + 54.0 * p), Kit.PAPER, true)
	kit.scale(self, Vector2(x, y0 + 54.0 * p), Vector2(x + w * 0.3, y0 + 54.0 * p), 24, 4, Kit.PAPER, 1.0, -1.0, -1.0, false)
	# the pages: the open one yellow, a pointer under it
	var ty := y0 + 92.0 * p
	_tab_rects.clear()
	var tx := x
	for t in TABS.size():
		var label: String = TABS[t]
		var tw := kit.text_w(label, 22.0 * p, 600, 22.0 * p * 0.17)
		_tab_rects.append(Rect2(tx - 12.0 * p, ty - 18.0 * p, tw + 24.0 * p, 52.0 * p))
		kit.label(self, Vector2(tx, ty), label, 22.0 * p, Kit.YELLOW if t == tab else Kit.PAPER, -1)
		if t == tab:
			kit.tri(self, Vector2(tx + tw * 0.5, ty + 16.0 * p), 12.0 * p, Vector2.UP, Kit.YELLOW)
		tx += tw + 48.0 * p
	var y := y0 + 166.0 * p
	_rects.clear()
	_bars.clear()
	if TABS[tab] == "KEYS":
		_draw_keys(x, y0 + 146.0 * p, w, p)
	else:
		for i in _rows.size():
			if str(_rows[i]["kind"]) == "button":
				break
			_draw_row(i, x, w, y, p)
			y += 60.0 * p
	# the buttons, along the bottom
	var by := y0 + 628.0 * p
	var bx := x + 14.0 * p
	for i in _rows.size():
		if str(_rows[i]["kind"]) != "button":
			continue
		var label: String = _rows[i]["label"]
		var on := i == _pick
		var tw := kit.text_w(label, 28.0 * p, 700 if on else 600)
		var r := Rect2(bx - 14.0 * p, by - 22.0 * p, tw + 28.0 * p, 44.0 * p)
		_rects.append(r)
		_bars.append(r)
		kit.text(self, Vector2(bx, by), label, 28.0 * p, Kit.YELLOW if on else Kit.PAPER, -1, 700 if on else 600)
		kit.corners(self, r.grow(4.0 * p), 9.0 * p, Kit.YELLOW if on else Kit.PAPER, on)
		bx += r.size.x + 36.0 * p
	var hint := "CLICK ONE, THEN PRESS ITS KEY OR BUTTON. ESC KEEPS IT" if TABS[tab] == "KEYS" \
			else "DRAG, CLICK OR LEFT / RIGHT TO CHANGE.  TAB: NEXT PAGE.  ESC: BACK"
	if Settings.pad:
		hint = "THE KEYBOARD'S KEYS: [A] ON ONE, THEN PRESS ITS KEY. [B] KEEPS IT" if TABS[tab] == "KEYS" \
				else "STICK OR D-PAD: PICK AND CHANGE.  [LB] [RB]: PAGES.  [A]: PRESS.  [B]: BACK"
	kit.label(self, Vector2(x, y0 + 700.0 * p), hint, 16.0 * p, Color(Kit.PAPER, 0.6), -1)
	kit.flush()
	kit.defer = false


## A row on LOOK, SOUND or SCREEN: its name on the left, its control on the right.
func _draw_row(i: int, x: float, w: float, y: float, p: float) -> void:
	var r: Dictionary = _rows[i]
	var on := i == _pick
	var ink := Kit.YELLOW if on else Kit.PAPER
	var cx := x + w * 0.42
	_rects.append(Rect2(x - 12.0 * p, y - 28.0 * p, w + 24.0 * p, 56.0 * p))
	if on:
		kit.tri(self, Vector2(x + 22.0 * p, y), 18.0 * p, Vector2.RIGHT, Kit.YELLOW)
	kit.text(self, Vector2(x + 34.0 * p, y), str(r["label"]), 30.0 * p, ink, -1, 600)
	match str(r["kind"]):
		"slider":
			var v := float(r["get"].call())
			var rw := w * 0.34
			# (the hit area is the ruler's own length, and tall enough to grab)
			_bars.append(Rect2(cx, y - 26.0 * p, rw, 52.0 * p))
			var line := y + 6.0 * p
			kit.scale(self, Vector2(cx, line), Vector2(cx + rw, line), CELLS, 5, Kit.PAPER, -1.0)
			var u := (v - float(r["min"])) / (float(r["max"]) - float(r["min"]))
			kit.tri(self, Vector2(cx + u * rw, line + 3.0 * p), 15.0 * p, Vector2.UP, ink)
			kit.num(self, Vector2(cx + rw + 22.0 * p, y), str(r["shown"].call(v)), 30.0 * p, ink, -1)
		"toggle":
			var lit := bool(r["get"].call())
			_bars.append(Rect2(cx, y - 24.0 * p, 140.0 * p, 48.0 * p))
			kit.text(self, Vector2(cx, y), "ON" if lit else "OFF", 30.0 * p, Kit.YELLOW if lit else Color(Kit.PAPER, 0.6), -1, 700)
		"choice":
			var shown := "?"
			for o: Array in r["options"]:
				if o[1] == r["get"].call():
					shown = o[0]
			var bw := w * 0.36
			_bars.append(Rect2(cx, y - 24.0 * p, bw, 48.0 * p))
			kit.text(self, Vector2(cx + bw * 0.5, y), shown, 30.0 * p, ink, 0, 600)
			if on:
				kit.tri(self, Vector2(cx, y), 13.0 * p, Vector2.LEFT, Kit.YELLOW)
				kit.tri(self, Vector2(cx + bw, y), 13.0 * p, Vector2.RIGHT, Kit.YELLOW)


## KEYS: the actions in two columns, each with what it's on; any clash said underneath.
func _draw_keys(x: float, y: float, w: float, p: float) -> void:
	var keys := _rows.filter(func(r: Dictionary) -> bool: return str(r["kind"]) == "key").size()
	var per := ceili(keys / 2.0)
	var col_w := w * 0.5
	var rh := 34.0 * p
	var said: Array[String] = []
	var blink := Time.get_ticks_msec() % 800 < 500
	for i in keys:
		var r: Dictionary = _rows[i]
		var action := str(r["action"])
		var cx := x + floori(float(i) / per) * col_w
		var cy := y + (i % per) * rh + rh * 0.5
		var on := i == _pick
		_rects.append(Rect2(cx - 12.0 * p, cy - rh * 0.5, col_w - 16.0 * p, rh))
		_bars.append(Rect2())
		if on:
			kit.tri(self, Vector2(cx + 16.0 * p, cy), 14.0 * p, Vector2.RIGHT, Kit.YELLOW)
		kit.text(self, Vector2(cx + 26.0 * p, cy), str(r["label"]), 24.0 * p, Kit.YELLOW if on else Kit.PAPER, -1, 600)
		var clash := Settings.clashes(action)
		var waiting := _waiting == action
		var bound := "PRESS A KEY..." if waiting else Settings.describe(action)
		var col := Kit.YELLOW if waiting else (Kit.ORANGE if not clash.is_empty() else Kit.PAPER)
		var bx := cx + col_w * 0.5
		var bw := kit.text(self, Vector2(bx, cy), bound, 22.0 * p, col, -1, 700 if waiting else 600)
		if waiting:
			kit.rule(self, Vector2(bx, cy + 12.0 * p), Vector2(cx + col_w - 36.0 * p, cy + 12.0 * p), Kit.YELLOW, true)
			if blink:
				kit.bar(self, Rect2(bx + bw + 6.0 * p, cy - 10.0 * p, 4.0 * p, 20.0 * p), Kit.YELLOW)
		if not clash.is_empty():
			var who := [str(r["label"])] + clash
			who.sort()
			var line := "CLASH: %s SHARE A KEY" % " AND ".join(PackedStringArray(who))
			if not said.has(line) and said.size() < 3:
				said.append(line)
	if _waiting != "":
		queue_redraw()        # (the blink)
	var sy := y + per * rh + 20.0 * p
	for line in said:
		kit.label(self, Vector2(x, sy), line, 16.0 * p, Kit.ORANGE, -1)
		sy += 22.0 * p
