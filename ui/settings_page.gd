extends Control
## The settings page: one dark card over whatever's behind (the title's harbour, or the sea from the pause card), four
## pages along its top, LOOK, SOUND, SCREEN and KEYS. Everything on it is core/settings.gd's, applied the moment it
## changes (a slider as it's dragged, the field of view and the loudness with it); the file's written on BACK.
##
## Drawn whole in the pixel font (ui/pixfont.gd) and square blocks: a slider is a row of cells filling amber, a switch
## two blocks, a choice < ONE > arrows. Mouse: hover picks, click or drag changes. Keys: up and down pick, left and
## right change, Enter flips or presses, Tab the next page, Esc back. On KEYS, click an action (or Enter) and press the
## key or mouse button for it (Esc keeps what it had); one that clashes with another shows red, and says with what.

signal closed

const PixFont := preload("res://ui/pixfont.gd")
const Sfx := preload("res://audio/sfx.gd")

const AMBER := Color(1.0, 0.78, 0.34)
const CREAM := Color(1.0, 0.95, 0.82)
const DIM := Color(0.66, 0.71, 0.76)
const BAD := Color(1.0, 0.5, 0.42)
const SHADOW := Color(0.02, 0.03, 0.05, 0.85)
const CELL := Color(0.12, 0.15, 0.18)
const TABS := ["LOOK", "SOUND", "SCREEN", "KEYS"]
## A slider's cells, and each one's size (px).
const CELLS := 20
const CELL_W := 14
const CELL_H := 18

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


## Up, on page `at` (0 LOOK .. 3 KEYS).
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
		"KEYS":
			for a: Array in Settings.REBINDABLE:
				_rows.append({"kind": "key", "label": a[1], "action": a[0]})
			_rows.append({"kind": "button", "label": "RESET TO DEFAULTS", "press": Settings.reset_keys})
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

func _text(at: Vector2, text: String, col: Color, scale: int) -> void:
	PixFont.draw(self, at + Vector2(scale, scale), text, SHADOW, scale)
	PixFont.draw(self, at, text, col, scale)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.035, 0.55))
	var w := minf(880.0, size.x - 32.0)
	var h := minf(600.0, size.y - 32.0)
	var card := Rect2(((size - Vector2(w, h)) * 0.5).floor(), Vector2(w, h))
	draw_rect(card, Color(0.025, 0.035, 0.045, 0.96))
	draw_rect(Rect2(card.position, Vector2(4, h)), Color(AMBER, 0.7))
	var x := card.position.x + 32.0
	var y := card.position.y + 26.0
	_text(Vector2(x, y), "SETTINGS", AMBER, 4)
	# the pages along the top
	y += 46.0
	_tab_rects.clear()
	var tx := x
	for t in TABS.size():
		var label: String = TABS[t]
		var tw := PixFont.width(label, 3)
		_tab_rects.append(Rect2(tx - 8, y - 8, tw + 16, 31))
		_text(Vector2(tx, y), label, AMBER if t == tab else DIM, 3)
		if t == tab:
			draw_rect(Rect2(tx, y + 20, tw, 3), AMBER)
		tx += tw + 40
	draw_rect(Rect2(x, y + 30, w - 64, 2), Color(DIM, 0.25))
	y += 50.0
	_rects.clear()
	_bars.clear()
	if TABS[tab] == "KEYS":
		_draw_keys(x, y, w - 64)
	else:
		for i in _rows.size():
			if str(_rows[i]["kind"]) == "button":
				break
			_draw_row(i, x, y)
			y += 44.0
	# the buttons, along the bottom
	var by := card.end.y - 78.0
	var bx := x
	for i in _rows.size():
		if str(_rows[i]["kind"]) != "button":
			continue
		var label: String = _rows[i]["label"]
		var r := Rect2(bx - 4, by - 6, PixFont.width(label, 3) + 34, 27)
		_rects.append(r)
		_bars.append(r)
		if i == _pick:
			draw_rect(Rect2(bx - 4, by - 6, 6, 27), AMBER)
		_text(Vector2(bx + 14, by), label, AMBER if i == _pick else CREAM, 3)
		bx += r.size.x + 30
	var hint := "CLICK ONE, THEN PRESS ITS KEY OR BUTTON. ESC KEEPS IT" if TABS[tab] == "KEYS" \
			else "DRAG, CLICK OR LEFT / RIGHT TO CHANGE.  TAB: NEXT PAGE.  ESC: BACK"
	_text(Vector2(x, card.end.y - 34), hint, Color(DIM, 0.7), 2)


## A row on LOOK, SOUND or SCREEN: its name on the left, its control on the right.
func _draw_row(i: int, x: float, y: float) -> void:
	var r: Dictionary = _rows[i]
	var on := i == _pick
	var cx := x + 360.0
	_rects.append(Rect2(x - 8, y - 9, cx - x + 470, 36))
	if on:
		draw_rect(Rect2(x - 8, y - 9, 6, 36), AMBER)
	_text(Vector2(x + 10, y), str(r["label"]), AMBER if on else CREAM, 3)
	match str(r["kind"]):
		"slider":
			var v := float(r["get"].call())
			var full := _filled(r, v)
			var bar := Rect2(cx, y - 2, CELLS * (CELL_W + 3) - 3, CELL_H)
			_bars.append(bar)
			for c in CELLS:
				var cell := Rect2(cx + c * (CELL_W + 3), y - 2, CELL_W, CELL_H)
				draw_rect(cell, (AMBER if on else Color(AMBER, 0.75)) if c < full else CELL)
			_text(Vector2(bar.end.x + 16, y), str(r["shown"].call(v)), CREAM, 3)
		"toggle":
			var lit := bool(r["get"].call())
			var bar := Rect2(cx, y - 4, 140, 24)
			_bars.append(bar)
			for k in 2:
				var b := Rect2(cx + k * 72, y - 4, 68, 24)
				var mine := (k == 1) == lit
				draw_rect(b, (AMBER if on else Color(AMBER, 0.75)) if mine else CELL)
				var word: String = ["OFF", "ON"][k]
				PixFont.draw(self, Vector2(b.position.x + (68 - PixFont.width(word, 2)) * 0.5, y + 3), word,
						Color(0.06, 0.05, 0.03) if mine else DIM, 2)
		"choice":
			var shown := "?"
			for o: Array in r["options"]:
				if o[1] == r["get"].call():
					shown = o[0]
			var bar := Rect2(cx, y - 6, 340, 28)
			_bars.append(bar)
			var arrow := AMBER if on else DIM
			_text(Vector2(cx, y), "<", arrow, 3)
			_text(Vector2(cx + (340 - PixFont.width(shown, 3)) * 0.5, y), shown, CREAM, 3)
			_text(Vector2(cx + 340 - PixFont.width(">", 3), y), ">", arrow, 3)


## KEYS: the actions in two columns, each with what it's on; any clash said underneath.
func _draw_keys(x: float, y: float, w: float) -> void:
	var keys := _rows.filter(func(r: Dictionary) -> bool: return str(r["kind"]) == "key").size()
	var per := ceili(keys / 2.0)
	var col_w := w * 0.5
	var said: Array[String] = []
	var blink := Time.get_ticks_msec() % 800 < 500
	for i in keys:
		var r: Dictionary = _rows[i]
		var action := str(r["action"])
		var cx := x + floori(float(i) / per) * col_w
		var cy := y + (i % per) * 26.0
		var on := i == _pick
		_rects.append(Rect2(cx - 8, cy - 6, col_w - 16, 24))
		_bars.append(Rect2())
		if on:
			draw_rect(Rect2(cx - 8, cy - 6, 5, 22), AMBER)
		_text(Vector2(cx + 6, cy), str(r["label"]), AMBER if on else CREAM, 2)
		var clash := Settings.clashes(action)
		var bound := "PRESS A KEY..." if _waiting == action else Settings.describe(action)
		var col := (AMBER if blink else Color(AMBER, 0.4)) if _waiting == action else (BAD if not clash.is_empty()
				else CREAM)
		var bx := cx + 190
		draw_rect(Rect2(bx - 6, cy - 5, col_w - 200, 20), CELL if not on else CELL.lightened(0.1))
		_text(Vector2(bx, cy), bound, col, 2)
		if not clash.is_empty():
			var who := [str(r["label"])] + clash
			who.sort()
			var line := "CLASH: %s SHARE A KEY" % " AND ".join(PackedStringArray(who))
			if not said.has(line) and said.size() < 3:
				said.append(line)
	if _waiting != "":
		queue_redraw()        # (the blink)
	var sy := y + per * 26.0 + 8
	for line in said:
		_text(Vector2(x, sy), line, BAD, 2)
		sy += 18
