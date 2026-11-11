extends CanvasLayer
## Rivals' results card (vs/vs.gd): up on every screen at the same moment once a day's been weighed (the host's word),
## the mouse freed for it. A dark card over the harbour, the boats side by side (two, three or four of them, as many
## as `data` has: yours first and marked, the others after in their order): days won, fish, total, biggest, the late
## cut and the pounds weighed (what decides it: the money's the career's, not Rivals'), each row tallying up in turn,
## then the stamp lands on the winner (WINNER for the match, DAY WON for a day, TIE when the most is shared). Fishing
## `together` there's no winner, no days won and no stamp: under the rows it's the fleet's day (every boat's pounds
## and fish as one) and each boat's share of it.
## Under it NEXT DAY (or REMATCH once the match is won) and BACK TO THE TITLE. Everyone has to press NEXT DAY /
## REMATCH (pressed again it's taken back); under each boat, whether her crew have. When they all have, the screen
## fades to black and the next day (or a fresh match) starts from the countdown. If another crew's line drops (or
## they quit), it says so: wait for them to come back, or press on without them. If the host's gone, it says so and
## only the title's left.
##
## What it says is all in lines() (and cell()), what _draw_card() puts up: the words can be read without a screen.
##
## The pixel font (ui/pixfont.gd) at whole sizes, the colours of the title (ui/title.gd) and the menu (ui/menu.gd).

const PixFont := preload("res://ui/pixfont.gd")
const Sfx := preload("res://audio/sfx.gd")
const Pad := preload("res://core/pad.gd")

const AMBER := Color(1.0, 0.78, 0.34)
const CREAM := Color(1.0, 0.95, 0.82)
const DIM := Color(0.66, 0.71, 0.76)
const GOOD := Color(0.6, 1.0, 0.6)
const BAD := Color(1.0, 0.5, 0.42)
const INK := Color(1.0, 0.36, 0.28)
const SHADOW := Color(0.02, 0.03, 0.05, 0.85)
const BG := Color(0.025, 0.035, 0.045, 0.95)
## The boats' colours and names, when vs/vs.gd hasn't its own to give (boat_colour, boat_name).
const COLOURS := [Color(1.0, 0.74, 0.32), Color(0.45, 0.8, 1.0), Color(0.95, 0.52, 0.86), Color(0.6, 0.9, 0.45)]
const NAMES := "ABCD"
## The card (px), and its rows.
const W := 780
const H := 470
const ROWS := ["DAYS WON", "FISH", "TOTAL", "BIGGEST", "LATE: HALF", "WEIGHED"]
## The boats' columns: two sit where they always have, more share the card's width right of the rows' names (px
## from the card's left edge to its right margin).
const COLS_TWO := [380.0, 610.0]
const COLS_FROM := 200.0
const COLS_TO := W - 28.0
## The tally: the first row starts T0 s in, each next ROW s after, counting up over UP s; then the stamp (STAMP s to
## land), then the buttons.
const T0 := 0.5
const ROW := 0.3
const UP := 0.6
const STAMP := 0.22
const T_STAMP := T0 + ROW * 6 + UP + 0.2
const T_BUTTONS := T_STAMP + STAMP + 0.3
## The fade to black and back (s).
const FADE := 0.8

var vs: Node                 # vs/vs.gd
## What's on it (empty: it's down): {decided, winner (-1 a tie, or fishing together), day, together, and one entry a
## boat in each of wins, crewed, day_lb and boats: [{fish, kg, big, money, late, lb}, ...]}.
var data := {}
## s since it came up.
var t := 0.0
## Each boat: 0 deciding, 1 ready, 2 nobody aboard her, 3 her crew's line dropped (waiting on them), 4 they've left
## (vs/vs.gd's word); and who's pressed.
var states: Array = [0, 0]
var ready_ids: Array = []
## The host's gone (and the other boats with them): only the title's left.
var gone := false
## Which boat you're on, kept for after the boats have gone (the host left).
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
	states = []
	states.resize(boats())
	states.fill(0)
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


## Down at once, the black too (joining a boat again after a drop: the host says what's up now).
func drop() -> void:
	close()
	_fading = false
	_black.modulate.a = 0.0


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


## How many boats are on it.
func boats() -> int:
	return maxi((data.get("boats", [{}, {}]) as Array).size(), 1)


func together() -> bool:
	return bool(data.get("together", false))


## The boats in the order they stand on the card: yours first, the others after as they come.
func order() -> Array[int]:
	var out: Array[int] = []
	var me := _team()
	if me >= 0 and me < boats():
		out.append(me)
	for i in boats():
		if i != me:
			out.append(i)
	return out


## Every boat but yours.
func others() -> Array[int]:
	var out: Array[int] = []
	for i in boats():
		if i != _team():
			out.append(i)
	return out


func boat_name(i: int) -> String:
	if vs != null and vs.has_method("boat_name"):
		return str(vs.call("boat_name", i))
	return NAMES[clampi(i, 0, NAMES.length() - 1)]


func boat_colour(i: int) -> Color:
	if vs != null and vs.has_method("boat_colour"):
		return vs.call("boat_colour", i) as Color
	return COLOURS[clampi(i, 0, COLOURS.size() - 1)]


## Boat i's crew (see `states`; a boat the host's said nothing of yet is deciding).
func state(i: int) -> int:
	return clampi(int(states[i]), 0, 4) if i >= 0 and i < states.size() else 0


## Entry i of one of data's a-boat arrays (wins, day_lb), 0 where there's none.
func _of(key: String, i: int) -> float:
	var a: Array = data.get(key, [])
	return float(a[i]) if i >= 0 and i < a.size() else 0.0


## The fleet's day, fishing together: every boat's pounds, and fish.
func fleet_lb() -> int:
	var sum := 0
	for i in boats():
		sum += roundi(_value(5, i))
	return sum


func fleet_fish() -> int:
	var sum := 0
	for i in boats():
		sum += roundi(_value(1, i))
	return sum


## Boat i's share of the fleet's pounds (0..100).
func share(i: int) -> int:
	var all := fleet_lb()
	return roundi(100.0 * roundi(_value(5, i)) / all) if all > 0 else 0


func _value(row: int, i: int) -> float:
	var list: Array = data.get("boats", [{}, {}])
	var b: Dictionary = list[i] if i >= 0 and i < list.size() else {}
	match row:
		0: return _of("wins", i)
		1: return float(b.get("fish", 0))
		2: return float(b.get("kg", 0.0))
		3: return float(b.get("big", 0.0))
		4: return float(b.get("late", 0.0))
		_: return float(b.get("lb", 0.0))


func _team() -> int:
	return int(vs.get("my_team")) if vs != null and bool(vs.get("on")) else mine


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
			for i in boats():
				sum += roundf(shown(r, i))
		if sum != _counted:
			_counted = sum
			Sfx.play("ui.tick", 0.35, randf_range(1.1, 1.3))
	if not _stamped and t >= T_STAMP + STAMP:
		_stamped = true
		if not together():
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
	var k := e as InputEventKey if e is InputEventKey else Pad.as_key(e)       # (the pad: the d-pad or stick, A)
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


## "BOAT C", "BOATS B AND C", "BOATS B, C AND D".
func _boats_said(list: Array) -> String:
	var names := PackedStringArray()
	for i: int in list:
		names.append(boat_name(i))
	if names.size() == 1:
		return "BOAT " + names[0]
	return "BOATS " + ", ".join(names.slice(0, -1)) + " AND " + names[-1]


## Whether the card talks of YOU and THEM (two boats, you on one of them), not of the boats by name.
func _you_and_them() -> bool:
	var me := _team()
	return boats() == 2 and me >= 0 and me < 2


## Who took it, in words, and its colour: [line, colour].
func _verdict() -> Array:
	var n := boats()
	var me := _team()
	var winner := int(data.get("winner", -1))
	if together():
		return ["THE FLEET'S DAY: %d LB, %d FISH" % [fleet_lb(), fleet_fish()], AMBER]
	var pounds: Array[int] = []
	var wins: Array[int] = []
	for i in n:
		pounds.append(roundi(_of("day_lb", i)))
		wins.append(int(_of("wins", i)))
	var lc := AMBER
	if winner >= 0 and me >= 0 and me < n:
		lc = GOOD if winner == me else BAD
	var who := "YOU WIN" if winner == me else "BOAT %s WINS" % boat_name(winner)
	if bool(data.get("decided", false)) and winner >= 0:
		if _you_and_them():
			return [("YOU TAKE THE MATCH, %d-%d" if winner == me else "THEY TAKE THE MATCH, %d-%d")
					% [int(wins.max()), int(wins.min())], lc]
		wins.sort()
		wins.reverse()
		var score := PackedStringArray()
		for w in wins:
			score.append(str(w))
		return ["%s THE MATCH, %s" % [who, "-".join(score)], lc]
	if winner < 0:
		if n == 2:
			return ["DEAD EVEN: %d LB EACH. NO DAY TO EITHER" % pounds[0], lc]
		return ["A TIE AT %d LB: NOBODY TAKES THE DAY" % int(pounds.max()), lc]
	# by how much: over the next best
	var best := pounds[winner] if winner < n else 0
	var next := 0
	for i in n:
		if i != winner:
			next = maxi(next, pounds[i])
	var by := absi(best - next)
	if _you_and_them():
		return [("THE DAY'S YOURS, BY %d LB" if winner == me else "THEIR DAY, BY %d LB") % by, lc]
	return ["%s THE DAY, BY %d LB" % [who, by], lc]


## Everything the card says right now, as _draw_card() puts it up: {title, sub, order (the boats, left to right),
## heads, tags and crews (one a column, in that order), rows (the rows' names), stamp ("" when there's none), verdict,
## shares (one a column, fishing together; else empty), buttons, status}.
func lines() -> Dictionary:
	var n := boats()
	var me := _team()
	var decided := bool(data.get("decided", false))
	var winner := int(data.get("winner", -1))
	var day := int(data.get("day", 1))
	var out := {"title": "THE MATCH" if decided else "DAY %d" % day, "order": order()}
	if together():
		out["sub"] = "ONE FLEET: %d BOATS FISHING TOGETHER" % n
	elif decided:
		out["sub"] = ("OVER %d DAYS, BEST OF THREE" if n == 2 else "OVER %d DAYS, FIRST TO TWO") % day
	else:
		out["sub"] = "FIRST TO TWO DAYS WINS"
	var heads: Array[String] = []
	var tags: Array[String] = []
	var crews: Array[String] = []
	var shares: Array[String] = []
	for i: int in order():
		heads.append("BOAT " + boat_name(i))
		tags.append("YOU" if i == me else ("WITH YOU" if together() else ("THEM" if n == 2 else "RIVAL")))
		var said: String = ["DECIDING...", "READY", "NOBODY ABOARD", "LOST CONNECTION", "LEFT THE GAME"][state(i)]
		if state(i) == 0 and fmod(t, 1.0) < 0.5:
			said = "DECIDING.. "
		if gone and state(i) < 2:
			said = ""        # (the host's gone: there's nothing left for your own crew to decide)
		crews.append(said)
		if together():
			shares.append("%d%%" % share(i) if fleet_lb() > 0 else "-")
	out["heads"] = heads
	out["tags"] = tags
	out["crews"] = crews
	out["shares"] = shares
	out["rows"] = ROWS.slice(1) if together() else ROWS
	out["stamp"] = "" if together() else ("TIE" if winner < 0 else ("WINNER" if decided else "DAY WON"))
	out["verdict"] = str(_verdict()[0])
	out["buttons"] = [_primary(), "BACK TO THE TITLE"]
	out["status"] = _status()
	return out


## Where the boats' columns stand (px from the card's left edge), left to right.
func columns() -> Array[float]:
	var n := boats()
	var out: Array[float] = []
	if n == 2:
		out.assign(COLS_TWO)
		return out
	for k in n:
		out.append(roundf(COLS_FROM + (COLS_TO - COLS_FROM) * (k + 0.5) / n))
	return out


## How wide a column is (px).
func span() -> float:
	return float(COLS_TWO[1]) - float(COLS_TWO[0]) if boats() == 2 else (COLS_TO - COLS_FROM) / boats()


func _draw_card() -> void:
	var size := _view.size
	var a := clampf(t / 0.35, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - a, 3.0)
	_view.draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.035, 0.55 * e))
	var said := lines()
	var fleet := together()
	# the stamp's thump shakes the card a pixel or two
	var shake := Vector2.ZERO
	var since := t - T_STAMP - STAMP
	if since > 0.0 and since < 0.25 and not fleet:
		var m := roundf(3.0 * (1.0 - since / 0.25))
		shake = Vector2(randi_range(-1, 1), randi_range(-1, 1)) * m
	var o := ((size - Vector2(W, H)) * 0.5).floor() + Vector2(0, roundf((1.0 - e) * 48.0)) + shake
	var fade := e
	_view.draw_rect(Rect2(o, Vector2(W, H)), Color(BG, BG.a * fade))
	_view.draw_rect(Rect2(o, Vector2(4, H)), Color(AMBER, 0.7 * fade))
	var winner := int(data.get("winner", -1))
	var me := _team()
	var n := boats()
	var seats := order()
	var wide := span()
	_text(o + Vector2(28, 22), str(said["title"]), Color(AMBER, fade), 4)
	_text(o + Vector2(30, 50), str(said["sub"]), Color(DIM, fade), 2)
	_view.draw_rect(Rect2(o + Vector2(28, 70), Vector2(W - 56, 2)), Color(DIM, 0.25 * fade))
	# each boat's column: by the boat's own number, wherever she stands
	var cx: Array[float] = []
	cx.resize(n)
	var at := columns()
	for k in seats.size():
		cx[seats[k]] = o.x + at[k]
	var top := o.y + 84.0
	var row_y := top + 64.0
	var step := 30.0
	# the winner's column, lit once the stamp's down
	if stamped() and winner >= 0 and winner < n and not fleet:
		_view.draw_rect(Rect2(cx[winner] - wide * 0.5 + 10.0, top - 8.0, wide - 20.0, 64.0 + step * ROWS.size() + 4.0),
				Color(boat_colour(winner), 0.09 * fade))
	for k in seats.size():
		var i := seats[k]
		_centred(cx[i], top, str(said["heads"][k]), Color(boat_colour(i), fade), 4)
		# (with more than two up, yours is the bright one, ruled under in her colour)
		var yours := i == me and n > 2
		_centred(cx[i], top + 30.0, str(said["tags"][k]), Color(CREAM if yours else DIM, fade), 2)
		if yours:
			_view.draw_rect(Rect2(floorf(cx[i] - 46.0), top + 46.0, 92.0, 2.0), Color(boat_colour(i), 0.7 * fade))
	# (fishing together there are no days to win: the rows move up one, the fleet's day under them)
	var first := 1 if fleet else 0
	for r in range(first, ROWS.size()):
		var y := row_y + (r - first) * step
		var on := clampf((t - T0 - r * ROW) / 0.15, 0.0, 1.0) * fade
		_text(Vector2(o.x + 30.0, y + 4.0), ROWS[r], Color(DIM, on), 2)
		for i in n:
			_cell(r, i, cx[i], y, on)
	# the stamp: lands from big to its size in whole steps, square to the card (with more than two boats up it's a
	# column's width, and kept on the card all the way down)
	if t >= T_STAMP and not fleet:
		var k := clampf((t - T_STAMP) / STAMP, 0.0, 1.0)
		var to := 6.0 if n == 2 else 4.0
		var sc := roundi(lerpf(to + 10.0, to, k * k))
		var word := str(said["stamp"])
		var ink := AMBER if winner < 0 else INK
		var sx: float = (float(cx.min()) + float(cx.max())) * 0.5 if winner < 0 or winner >= n else cx[winner]
		var tw := PixFont.width(word, sc)
		var pad := sc * 2
		var mid := 34.0 if n == 2 else 30.0
		var box := Rect2(floorf(sx - tw * 0.5 - pad), floorf(o.y + mid - sc * 2.5 - pad), tw + pad * 2, sc * 5 + pad * 2)
		if n > 2:
			box.position.x = clampf(box.position.x, o.x + 8.0, o.x + W - 8.0 - box.size.x)
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
	# who won, in words (together: the fleet's day, and each boat's share of it under it, in her column)
	var after := clampf((t - T_STAMP - STAMP) / 0.3, 0.0, 1.0) * fade
	var lc: Color = _verdict()[1]
	var ly := row_y + step * ROWS.size() + 10.0
	if fleet:
		_centred(o.x + W * 0.5, ly - step, str(said["verdict"]), Color(lc, after), 3)
		_text(Vector2(o.x + 30.0, ly + 2.0), "SHARE", Color(DIM, after), 2)
		for k in seats.size():
			_centred(cx[seats[k]], ly - 2.0, str(said["shares"][k]), Color(boat_colour(seats[k]), after), 3)
	else:
		_centred(o.x + W * 0.5, ly, str(said["verdict"]), Color(lc, after), 3)
	# each boat's crew: pressed yet?
	for k in seats.size():
		var sc2: Color = [DIM, GOOD, Color(DIM, 0.5), BAD, BAD][state(seats[k])]
		_centred(cx[seats[k]], ly + 30.0, str(said["crews"][k]), Color(sc2, after * sc2.a), 2)
	# the buttons
	var bk := clampf((t - T_BUTTONS) / 0.3, 0.0, 1.0) * fade
	var by := o.y + H - 84.0
	var labels: Array = said["buttons"]
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
		PixFont.draw(_view, Vector2(floorf(r.get_center().x - PixFont.width(str(labels[i]), 3) * 0.5),
				floorf(r.get_center().y - 7.0)), str(labels[i]), Color(tc, tc.a * bk), 3)
	_centred(o.x + W * 0.5, by + 56.0, str(said["status"]), Color(_status_colour(), bk), 2)


## What row `r` says for boat `i` when its number stands at `v` ("" for the days won: they're pips).
func cell(r: int, i: int, v: float) -> String:
	match r:
		0: return ""
		1: return "%d" % roundi(v)
		2: return "%d KG" % roundi(v)
		3: return "%d KG" % roundi(v) if _value(1, i) > 0.0 else "-"
		4: return "-%d LB" % roundi(v) if _value(4, i) > 0.0 else "-"
		_: return "%d LB" % roundi(v)


## One number on the card, counting up (the days won as pips).
func _cell(r: int, i: int, cx: float, y: float, on: float) -> void:
	var v := shown(r, i)
	var col := Color(CREAM, on)
	match r:
		0:
			var n := roundi(v)
			var x := floorf(cx - 22.0)
			for d in 2:
				var c := boat_colour(i)
				_view.draw_rect(Rect2(x + d * 30.0, y, 14, 14), Color(c, 0.35 * on))
				if d >= n:
					_view.draw_rect(Rect2(x + d * 30.0 + 2.0, y + 2.0, 10, 10), Color(0.02, 0.03, 0.04, on))
				else:
					_view.draw_rect(Rect2(x + d * 30.0, y, 14, 14), Color(c, on))
			return
		4: col = Color(BAD, on) if _value(4, i) > 0.0 else Color(DIM, on)
		5: col = Color(boat_colour(i), on)
	_centred(cx, y, cell(r, i, v), col, 3)


func _status() -> String:
	if gone:
		return "THEY'VE LEFT THE GAME. BACK TO THE TITLE" if boats() == 2 else "THE HOST'S LEFT THE GAME. BACK TO THE TITLE"
	if _fading:
		return ""
	var me := _team()
	var pressed := ready_ids.has(Net.my_id())
	var word := "A REMATCH" if bool(data.get("decided", false)) else "THE NEXT DAY"
	var two := _you_and_them()
	# (the others, by what their crews are at)
	var lost: Array[int] = []
	var left: Array[int] = []
	var deciding: Array[int] = []
	var ready: Array[int] = []
	for i: int in others():
		match state(i):
			0: deciding.append(i)
			1: ready.append(i)
			3: lost.append(i)
			4: left.append(i)
	if not pressed and not lost.is_empty():
		return "%s LOST CONNECTION. WAIT, OR %s TO GO ON WITHOUT THEM" % ["THEY" if two else _boats_said(lost), _primary()]
	if not pressed and not left.is_empty():
		if two:
			return "THEY'VE LEFT. %s TO GO ON WITHOUT THEM" % _primary()
		return "%s LEFT. %s TO GO ON WITHOUT THEM" % [_boats_said(left) + ("'S" if left.size() == 1 else " HAVE"), _primary()]
	var ours := me < 0 or me >= boats() or state(me) >= 1
	if pressed and not ours:
		return "WAITING FOR YOUR CREW..."
	if pressed and not deciding.is_empty():
		return "WAITING FOR %s..." % ("THEM" if two else _boats_said(deciding))
	if not ready.is_empty() and (two or not pressed):
		if two:
			return "THEY'RE READY FOR %s" % word
		return "%s READY FOR %s" % [_boats_said(ready) + ("'S" if ready.size() == 1 else " ARE"), word]
	return "EVERYONE PRESSES %s TO GO ON" % _primary()


func _status_colour() -> Color:
	if gone:
		return BAD
	var ready := others().any(func(i: int) -> bool: return state(i) == 1)
	return AMBER if ready and not ready_ids.has(Net.my_id()) else DIM
