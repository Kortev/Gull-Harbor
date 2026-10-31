extends CanvasLayer
## Rivals' results card (vs/vs.gd): up on every screen at the same moment once a day's been weighed (the host's word),
## the mouse freed for it. A dark card over the harbour, the two boats side by side: days won, fish, total, biggest,
## the money, the late cut and the pounds weighed, each row tallying up in turn, then the stamp lands on the winner
## (WINNER for the match, DAY WON for a day, TIE when it's dead even). Under it NEXT DAY (or REMATCH once the match is
## won) and BACK TO THE TITLE. Everyone has to press NEXT DAY / REMATCH (pressed again it's taken back); under each
## boat, whether her crew have. When they all have, the screen fades to black and the next day (or a fresh match)
## starts from the countdown. If the other crew leave, it says so and only the title's left.
##
## The pixel font (ui/pixfont.gd) at whole sizes, the colours of the title (ui/title.gd) and the menu (ui/menu.gd).

const PixFont := preload("res://ui/pixfont.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const Sfx := preload("res://audio/sfx.gd")

const AMBER := Color(1.0, 0.78, 0.34)
const CREAM := Color(1.0, 0.95, 0.82)
const DIM := Color(0.66, 0.71, 0.76)
const GOOD := Color(0.6, 1.0, 0.6)
const BAD := Color(1.0, 0.5, 0.42)
const INK := Color(1.0, 0.36, 0.28)
const SHADOW := Color(0.02, 0.03, 0.05, 0.85)
const BG := Color(0.025, 0.035, 0.045, 0.95)
const COLOURS := [Color(1.0, 0.74, 0.32), Color(0.45, 0.8, 1.0)]
## The card (px), and its rows.
const W := 780
const H := 500
const ROWS := ["DAYS WON", "FISH", "TOTAL", "BIGGEST", "MONEY", "LATE: HALF", "WEIGHED"]
## The tally: the first row starts T0 s in, each next ROW s after, counting up over UP s; then the stamp (STAMP s to
## land), then the buttons.
const T0 := 0.5
const ROW := 0.3
const UP := 0.6
const STAMP := 0.22
const T_STAMP := T0 + ROW * 7 + UP + 0.2
const T_BUTTONS := T_STAMP + STAMP + 0.3
## The fade to black and back (s).
const FADE := 0.8

var vs: Node                 # vs/vs.gd
## What's on it (empty: it's down): {decided, winner (-1 a tie), day, wins [a, b], crewed [a, b], boats: [{fish, kg,
## big, money, late, lb}, ...]}.
var data := {}
## s since it came up.
var t := 0.0
## Each boat: 0 deciding, 1 ready, 2 nobody aboard her, 3 her crew left (vs/vs.gd's word); and who's pressed.
var states := [0, 0]
var ready_ids: Array = []
## The other crew's gone (they left, or the host did).
var gone := false
## Which boat you're on, kept for after the two boats have gone (the host left).
var mine := 0
var _view: Control
var _black: ColorRect
var _rects: Array[Rect2] = []
var _pick := 0
var _fast := false
var _tick_at := 0.0
var _counted := -1.0
var _stamped := false
var _fading := false


func _ready() -> void:
	layer = 16
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.visible = false
	_view.draw.connect(_draw_card)
	_view.gui_input.connect(_on_input)
	add_child(_view)
	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.color = Color.BLACK
	_black.modulate.a = 0.0
	add_child(_black)


func up() -> bool:
	return not data.is_empty()


func open(d: Dictionary, team: int) -> void:
	data = d
	mine = team
	t = 0.0
	states = [0, 0]
	ready_ids = []
	gone = false
	_fast = false
	_stamped = false
	_fading = false
	_counted = -1.0
	_pick = 0
	_view.modulate.a = 1.0
	_view.visible = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	Sfx.play("ui.page", 0.8)


func close() -> void:
	data = {}
	_view.visible = false
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Everyone's pressed: the card and the harbour behind it fade to black.
func fade_out() -> void:
	_fading = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_black, "modulate:a", 1.0, FADE).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_view, "modulate:a", 0.0, FADE * 0.8)


## The next's ready under the black: it fades back up on the boats at their berths.
func fade_in() -> void:
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(_black, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)


func dark() -> float:
	return _black.modulate.a


## The number row `row` shows for boat `i` now (it tallies up from nothing).
func shown(row: int, i: int) -> float:
	var full := _value(row, i)
	var k := clampf((t - T0 - row * ROW) / UP, 0.0, 1.0)
	return full * (1.0 - pow(1.0 - k, 3.0))


func stamped() -> bool:
	return t >= T_STAMP + STAMP


func _value(row: int, i: int) -> float:
	var b: Dictionary = (data.get("boats", [{}, {}]) as Array)[i]
	match row:
		0: return float((data.get("wins", [0, 0]) as Array)[i])
		1: return float(b.get("fish", 0))
		2: return float(b.get("kg", 0.0))
		3: return float(b.get("big", 0.0))
		4: return float(b.get("money", 0))
		5: return float(b.get("late", 0.0))
		_: return float(b.get("lb", 0.0))


func _team() -> int:
	return int(vs.get("my_team")) if bool(vs.get("on")) else mine


func _process(delta: float) -> void:
	if not up():
		return
	t += delta * (4.0 if _fast and t < T_STAMP else 1.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# a tick as the numbers count, the stamp's thump as it lands
	var counting := t > T0 and t < T0 + ROW * ROWS.size() + UP
	if counting and t - _tick_at > 0.07:
		_tick_at = t
		var sum := 0.0
		for r in ROWS.size():
			sum += roundf(shown(r, 0)) + roundf(shown(r, 1))
		if sum != _counted:
			_counted = sum
			Sfx.play("ui.tick", 0.35, randf_range(1.1, 1.3))
	if not _stamped and t >= T_STAMP + STAMP:
		_stamped = true
		Sfx.play("ui.stamp")
		Sfx.play("ui.reveal", 0.7)
	_view.queue_redraw()


func _primary() -> String:
	if ready_ids.has(Net.my_id()):
		return "READY!"
	return "REMATCH" if bool(data.get("decided", false)) else "NEXT DAY"


func _can_press() -> bool:
	return t >= T_BUTTONS and not gone and not _fading


func _press(i: int) -> void:
	if t < T_BUTTONS or _fading:
		return
	if i == 0:
		if _can_press():
			Sfx.play("ui.unready" if ready_ids.has(Net.my_id()) else "ui.ready")
			vs.call("press_ready")
	else:
		Sfx.play("ui.back")
		vs.call("to_title")


func _input(e: InputEvent) -> void:
	if not up() or _fading:
		return
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if t < T_STAMP:
		_fast = true
	elif k.keycode in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D, KEY_TAB]:
		_pick = 1 - _pick
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_press(_pick)
	else:
		return
	get_viewport().set_input_as_handled()


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		for i in _rects.size():
			if _rects[i].has_point((e as InputEventMouseMotion).position):
				_pick = i
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if t < T_STAMP:
			_fast = true
		for i in _rects.size():
			if _rects[i].has_point((e as InputEventMouseButton).position):
				_pick = i
				_press(i)
		_view.accept_event()


func _text(at: Vector2, text: String, col: Color, sc: int) -> void:
	PixFont.draw(_view, at + Vector2(sc, sc), text, Color(SHADOW, SHADOW.a * col.a), sc)
	PixFont.draw(_view, at, text, col, sc)


func _centred(cx: float, y: float, text: String, col: Color, sc: int) -> void:
	_text(Vector2(floorf(cx - PixFont.width(text, sc) * 0.5), y), text, col, sc)


static func _money(n: int) -> String:
	return ("-$" if n < 0 else "$") + FishHold._money(absi(n))


func _draw_card() -> void:
	var size := _view.size
	var a := clampf(t / 0.35, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - a, 3.0)
	_view.draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.035, 0.55 * e))
	# the stamp's thump shakes the card a pixel or two
	var shake := Vector2.ZERO
	var since := t - T_STAMP - STAMP
	if since > 0.0 and since < 0.25:
		var m := roundf(3.0 * (1.0 - since / 0.25))
		shake = Vector2(randi_range(-1, 1), randi_range(-1, 1)) * m
	var o := ((size - Vector2(W, H)) * 0.5).floor() + Vector2(0, roundf((1.0 - e) * 48.0)) + shake
	var fade := e
	_view.draw_rect(Rect2(o, Vector2(W, H)), Color(BG, BG.a * fade))
	_view.draw_rect(Rect2(o, Vector2(4, H)), Color(AMBER, 0.7 * fade))
	var decided := bool(data.get("decided", false))
	var winner := int(data.get("winner", -1))
	var me := _team()
	_text(o + Vector2(28, 22), "THE MATCH" if decided else "DAY %d" % int(data.get("day", 1)), Color(AMBER, fade), 4)
	var sub := ("OVER %d DAYS, BEST OF THREE" % int(data.get("day", 1))) if decided else "BEST OF THREE: FIRST TO TWO DAYS"
	_text(o + Vector2(30, 50), sub, Color(DIM, fade), 2)
	_view.draw_rect(Rect2(o + Vector2(28, 70), Vector2(W - 56, 2)), Color(DIM, 0.25 * fade))
	var cx := [o.x + 380.0, o.x + 610.0]
	var top := o.y + 84.0
	var row_y := top + 64.0
	var step := 30.0
	# the winner's column, lit once the stamp's down
	if stamped() and winner >= 0:
		_view.draw_rect(Rect2(cx[winner] - 105.0, top - 8.0, 210.0, 64.0 + step * ROWS.size() + 4.0),
				Color(COLOURS[winner], 0.09 * fade))
	for i in 2:
		var col: Color = COLOURS[i]
		_centred(cx[i], top, "BOAT " + "AB"[i], Color(col, fade), 4)
		_centred(cx[i], top + 30.0, "YOU" if i == me else "THEM", Color(DIM, fade), 2)
	for r in ROWS.size():
		var y := row_y + r * step
		var on := clampf((t - T0 - r * ROW) / 0.15, 0.0, 1.0) * fade
		_text(Vector2(o.x + 30.0, y + 4.0), ROWS[r], Color(DIM, on), 2)
		for i in 2:
			_cell(r, i, cx[i], y, on)
	# the stamp: lands from big to its size in whole steps, square to the card
	if t >= T_STAMP:
		var k := clampf((t - T_STAMP) / STAMP, 0.0, 1.0)
		var sc := roundi(lerpf(16.0, 6.0, k * k))
		var word := "TIE" if winner < 0 else ("WINNER" if decided else "DAY WON")
		var ink := AMBER if winner < 0 else INK
		var sx: float = (cx[0] + cx[1]) * 0.5 if winner < 0 else cx[winner]
		var tw := PixFont.width(word, sc)
		var pad := sc * 2
		var box := Rect2(floorf(sx - tw * 0.5 - pad), floorf(o.y + 34.0 - sc * 2.5 - pad), tw + pad * 2, sc * 5 + pad * 2)
		var al := (0.35 + 0.65 * k) * fade
		_view.draw_rect(box, Color(0.04, 0.03, 0.03, 0.85 * al))
		var b := maxi(sc / 2, 2)
		for edge: Rect2 in [Rect2(box.position, Vector2(box.size.x, b)),
				Rect2(box.position + Vector2(0, box.size.y - b), Vector2(box.size.x, b)),
				Rect2(box.position, Vector2(b, box.size.y)),
				Rect2(box.position + Vector2(box.size.x - b, 0), Vector2(b, box.size.y))]:
			_view.draw_rect(edge, Color(ink, al))
		PixFont.draw(_view, box.position + Vector2(pad, pad), word, Color(ink, al), sc)
	if t < T_STAMP + STAMP:
		return
	# who won, in words
	var after := clampf((t - T_STAMP - STAMP) / 0.3, 0.0, 1.0) * fade
	var lb: Array = data.get("day_lb", [0.0, 0.0])
	var wins: Array = data.get("wins", [0, 0])
	var line := ""
	var lc := AMBER
	if decided:
		line = ("YOU TAKE THE MATCH, %d-%d" if winner == me else "THEY TAKE THE MATCH, %d-%d") \
				% [int(wins.max()), int(wins.min())]
		lc = GOOD if winner == me else BAD
	elif winner < 0:
		line = "DEAD EVEN: %d LB EACH. NO DAY TO EITHER" % roundi(float(lb[0]))
	else:
		var by := absi(roundi(float(lb[0])) - roundi(float(lb[1])))
		line = ("THE DAY'S YOURS, BY %d LB" if winner == me else "THEIR DAY, BY %d LB") % by
		lc = GOOD if winner == me else BAD
	var ly := row_y + step * ROWS.size() + 10.0
	_centred(o.x + W * 0.5, ly, line, Color(lc, after), 3)
	# each boat's crew: pressed yet?
	for i in 2:
		var s := int(states[i])
		var said: String = ["DECIDING...", "READY", "NOBODY ABOARD", "LEFT THE GAME"][s]
		var sc2: Color = [DIM, GOOD, Color(DIM, 0.5), BAD][s]
		if s == 0 and fmod(t, 1.0) < 0.5:
			said = "DECIDING.. "
		_centred(cx[i], ly + 30.0, said, Color(sc2, after * sc2.a), 2)
	# the buttons
	var bk := clampf((t - T_BUTTONS) / 0.3, 0.0, 1.0) * fade
	var by := o.y + H - 84.0
	var labels := [_primary(), "BACK TO THE TITLE"]
	_rects.clear()
	for i in 2:
		var r := Rect2(o.x + W * 0.5 - 300.0 + i * 310.0, by, 290.0, 44.0)
		_rects.append(r)
		var primary := i == 0
		var live := _can_press() if primary else t >= T_BUTTONS
		var base := Color(0.85, 0.55, 0.16) if primary else Color(0.1, 0.13, 0.16)
		if primary and ready_ids.has(Net.my_id()):
			base = Color(0.3, 0.62, 0.3)
		if not live:
			base = Color(base.darkened(0.45), 0.7)
		elif i == _pick:
			base = base.lightened(0.15)
		_view.draw_rect(r, Color(base, base.a * bk))
		if i == _pick and live:
			for edge: Rect2 in [Rect2(r.position, Vector2(r.size.x, 2)), Rect2(r.position + Vector2(0, r.size.y - 2),
					Vector2(r.size.x, 2)), Rect2(r.position, Vector2(2, r.size.y)),
					Rect2(r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y))]:
				_view.draw_rect(edge, Color(CREAM, 0.8 * bk))
		var tc := Color(0.06, 0.05, 0.03) if primary and live else (CREAM if live else Color(DIM, 0.5))
		PixFont.draw(_view, Vector2(floorf(r.get_center().x - PixFont.width(labels[i], 3) * 0.5),
				floorf(r.get_center().y - 7.0)), labels[i], Color(tc, tc.a * bk), 3)
	_centred(o.x + W * 0.5, by + 56.0, _status(), Color(_status_colour(), bk), 2)


## One number on the card, counting up (the days won as pips).
func _cell(r: int, i: int, cx: float, y: float, on: float) -> void:
	var v := shown(r, i)
	var col := Color(CREAM, on)
	var text := ""
	match r:
		0:
			var n := roundi(v)
			var x := floorf(cx - 22.0)
			for d in 2:
				var c: Color = COLOURS[i]
				_view.draw_rect(Rect2(x + d * 30.0, y, 14, 14), Color(c, 0.35 * on))
				if d >= n:
					_view.draw_rect(Rect2(x + d * 30.0 + 2.0, y + 2.0, 10, 10), Color(0.02, 0.03, 0.04, on))
				else:
					_view.draw_rect(Rect2(x + d * 30.0, y, 14, 14), Color(c, on))
			return
		1: text = "%d" % roundi(v)
		2: text = "%d KG" % roundi(v)
		3: text = "%d KG" % roundi(v) if float(_value(1, i)) > 0.0 else "-"
		4:
			text = _money(roundi(v))
			col = Color(GOOD if _value(4, i) > 0.0 else BAD, on) if t > T0 + r * ROW + UP else col
		5:
			text = "-%d LB" % roundi(v) if _value(5, i) > 0.0 else "-"
			col = Color(BAD, on) if _value(5, i) > 0.0 else Color(DIM, on)
		_:
			text = "%d LB" % roundi(v)
			col = Color(COLOURS[i], on)
	_centred(cx, y, text, col, 3)


func _status() -> String:
	if gone:
		return "THEY'VE LEFT THE GAME. BACK TO THE TITLE"
	if _fading:
		return ""
	var me := _team()
	var word := "A REMATCH" if bool(data.get("decided", false)) else "THE NEXT DAY"
	var ours := int(states[me]) in [1, 2]
	var theirs := int(states[1 - me]) in [1, 2]
	if ready_ids.has(Net.my_id()) and not ours:
		return "WAITING FOR YOUR CREW..."
	if ready_ids.has(Net.my_id()) and not theirs:
		return "WAITING FOR THEM..."
	if theirs and int(states[1 - me]) == 1:
		return "THEY'RE READY FOR %s" % word
	return "EVERYONE PRESSES %s TO GO ON" % _primary()


func _status_colour() -> Color:
	if gone:
		return BAD
	return AMBER if int(states[1 - _team()]) == 1 and not ready_ids.has(Net.my_id()) else DIM
