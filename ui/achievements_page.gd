extends Control
## The achievements page (core/achievements.gd's LIST, Net.achievements' record of them): one dark card, as the
## settings page (ui/settings_page.gd) is, over whatever's behind (the title's harbour, the board, the sea from the
## pause card). Along its top how many are earned of how many, as a row of cells; under it all of them in two columns,
## each its medal (ui/medals.gd, the 32 grid at 1x, or 2x on a tall screen), its name, what it's for and the day it was
## earned. A locked one's medal is greyed and its words dim; a counted one shows how far along it is (640 / 1000 KG);
## a secret one (ui/medals.gd's SECRET) is a "?" with its words hidden till it's earned.
##
## Mouse: hover picks one, BACK closes. Keys: the arrows go up and down a column and across, Enter on BACK or Esc
## closes. A pad works it as the keys do (core/pad.gd's as_key(): the d-pad or left stick, A, B back).

signal closed

const PixFont := preload("res://ui/pixfont.gd")
const Pad := preload("res://core/pad.gd")
const Medals := preload("res://ui/medals.gd")
const Achievements := preload("res://core/achievements.gd")

const AMBER := Color(1.0, 0.78, 0.34)
const CREAM := Color(1.0, 0.95, 0.82)
const DIM := Color(0.66, 0.71, 0.76)
const GOOD := Color(0.6, 1.0, 0.6)
const SHADOW := Color(0.02, 0.03, 0.05, 0.85)
const CELL := Color(0.12, 0.15, 0.18)
const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
## The card's width (the settings page's), and the screen height from which the medals are drawn at 2x.
const W := 880.0
const TALL := 840.0

## The career's best run of quotas (boat/fish_hold.gd's best_run), for Keeping Her's count: -1 not known.
var best_run := -1
## Which one's picked: 0 .. LIST's size - 1 down the left column then the right, LIST's size: BACK.
var pick := 0
var _rects: Array[Rect2] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gui_input.connect(_on_input)
	Settings.device_changed.connect(queue_redraw)


## Up (`run`: the career's best run of quotas, if it's known).
func open(run := -1) -> void:
	best_run = run
	pick = 0
	visible = true
	grab_focus()
	queue_redraw()


func close() -> void:
	visible = false
	closed.emit()


## The career's best run of quotas for Keeping Her's count, from the boat's books (boat/fish_hold.gd): the best
## run sold, or this one so far. -1 on a friend's boat (her books are the skipper's, not yours).
static func run_of(hold: Node) -> int:
	if hold == null or not Net.is_host():
		return -1
	return maxi(int(hold.get("best_run")), int(hold.get("quota_n")) - 1)


static func count() -> int:
	return Net.achievements.got.size()


## The count along the top: "5 / 16".
static func header() -> String:
	return "%d / %d" % [count(), Achievements.LIST.size()]


## What the page says of one: [its name, what it's for, the day it was earned ("" while it's locked)].
static func words(api: String) -> Array:
	var a := Achievements.info(api)
	var got := Net.achievements.has(api)
	if not got and Achievements.secret(api):
		return ["???", "A SECRET. KEEP FISHING.", ""]
	var when := date(int(Net.achievements.got.get(api, 0))) if got else ""
	return [str(a[1]).to_upper(), str(a[2]).to_upper(), "EARNED" if got and when.is_empty() else when]


## A day as the page says it: "31 OCT 2026" ("" if it isn't known: earned before there were dates).
static func date(unix: int) -> String:
	if unix <= 0:
		return ""
	var d := Time.get_date_dict_from_unix_time(unix)
	return "%d %s %d" % [int(d["day"]), MONTHS[int(d["month"]) - 1], int(d["year"])]


func _on_input(e: InputEvent) -> void:
	if e is InputEventJoypadButton or e is InputEventJoypadMotion:
		e = Pad.as_key(e)
		accept_event()
		if e == null:
			return
	var n := Achievements.LIST.size()
	var half := ceili(n / 2.0)
	if e is InputEventMouseMotion:
		for i in _rects.size():
			if _rects[i].has_point((e as InputEventMouseMotion).position) and i != pick:
				pick = i
				queue_redraw()
		accept_event()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _rects.size() > n and _rects[n].has_point((e as InputEventMouseButton).position):
			close()
		accept_event()
	elif e is InputEventKey and (e as InputEventKey).pressed:
		match (e as InputEventKey).keycode:
			KEY_UP, KEY_W:
				# (off the top of a column: BACK, under the left one)
				pick = n if pick == 0 or pick == half else (half - 1 if pick == n else pick - 1)
			KEY_DOWN, KEY_S:
				pick = n if pick == half - 1 or pick == n - 1 else (0 if pick == n else pick + 1)
			KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D:
				if pick < n:
					pick = (pick + half) % (half * 2) if pick + half < n or pick >= half else pick
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if pick == n:
					close()
			KEY_ESCAPE:
				close()
		queue_redraw()
		accept_event()


# --- drawing ---

func _text(at: Vector2, text: String, col: Color, scale: int) -> void:
	PixFont.draw(self, at + Vector2(scale, scale), text, Color(SHADOW, SHADOW.a * col.a), scale)
	PixFont.draw(self, at, text, col, scale)


## `text` cut into lines of at most `chars` characters, at the spaces.
static func _wrap(text: String, chars: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		if not line.is_empty() and line.length() + 1 + word.length() > chars:
			out.append(line)
			line = word
		else:
			line = word if line.is_empty() else line + " " + word
	if not line.is_empty():
		out.append(line)
	return out


func _draw() -> void:
	var list := Achievements.LIST
	var n := list.size()
	var half := ceili(n / 2.0)
	var u := 2 if size.y >= TALL else 1           # (the medals' scale)
	var icon := 32.0 * u
	var row := icon + (16.0 if u == 2 else 22.0)
	var w := minf(W, size.x - 32.0)
	var h := minf(row * half + 186.0, size.y - 32.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.035, 0.55))
	var card := Rect2(((size - Vector2(w, h)) * 0.5).floor(), Vector2(w, h))
	draw_rect(card, Color(0.025, 0.035, 0.045, 0.96))
	draw_rect(Rect2(card.position, Vector2(4, h)), Color(AMBER, 0.7))
	var x := card.position.x + 32.0
	var y := card.position.y + 26.0
	_text(Vector2(x, y), "ACHIEVEMENTS", AMBER, 4)
	# how many, in words and as a row of cells, along the top right
	var have := count()
	var tally := header()
	var right := card.end.x - 32.0
	var cw := 10.0
	var cells := Rect2(right - n * (cw + 3.0) + 3.0, y + 3.0, n * (cw + 3.0) - 3.0, 14.0)
	for i in n:
		draw_rect(Rect2(cells.position.x + i * (cw + 3.0), cells.position.y, cw, 14.0), AMBER if i < have else CELL)
	_text(Vector2(cells.position.x - PixFont.width(tally, 3) - 16.0, y + 1.0), tally, CREAM, 3)
	draw_rect(Rect2(x, y + 36.0, w - 64.0, 2.0), Color(DIM, 0.25))
	# the medals, two columns
	_rects.clear()
	var top := y + 52.0
	var col_w := floorf((w - 64.0 - 24.0) * 0.5)
	for i in n:
		var cx := x + (col_w + 24.0) * floori(float(i) / half)
		var cy := top + row * (i % half)
		_entry(list[i], Rect2(cx, cy, col_w, row - 6.0), icon, i == pick)
	# BACK, and the hint along the bottom, as the settings page has them
	var by := card.end.y - 78.0
	var r := Rect2(x - 4, by - 6, PixFont.width("BACK", 3) + 34, 27)
	_rects.append(r)
	if pick == n:
		draw_rect(Rect2(x - 4, by - 6, 6, 27), AMBER)
	_text(Vector2(x + 14, by), "BACK", AMBER if pick == n else CREAM, 3)
	var hint := "STICK OR D-PAD: LOOK THEM OVER.  [B]: BACK" if Settings.pad \
			else "MOUSE OR ARROW KEYS: LOOK THEM OVER.  ESC: BACK"
	_text(Vector2(x, card.end.y - 34), hint, Color(DIM, 0.7), 2)


## One achievement in its slot `r`: the medal, the name and the day it was earned, what it's for (or how far along).
func _entry(a: Array, r: Rect2, icon: float, on: bool) -> void:
	var api: String = a[0]
	var got := Net.achievements.has(api)
	var said := words(api)
	_rects.append(r.grow_individual(8, 4, 4, 2))
	if on:
		draw_rect(r.grow_individual(8, 4, 4, 2), Color(1, 1, 1, 0.05))
		draw_rect(Rect2(r.position.x - 8, r.position.y - 4, 4, r.size.y + 6), AMBER)
	draw_texture_rect(Medals.texture(api, not got), Rect2(r.position, Vector2(icon, icon)), false)
	var tx := r.position.x + icon + 14.0
	var tw := r.end.x - tx
	var name: String = said[0]
	var when: String = said[2]
	var ny := r.position.y + maxf(floorf((icon - 36.0) * 0.5), 0.0)
	_text(Vector2(tx, ny), name, (AMBER if on else CREAM) if got else Color(DIM, 0.75), 3)
	if not when.is_empty():
		_text(Vector2(r.end.x - PixFont.width(when, 2), ny + 3.0), when, Color(GOOD, 0.85), 2)
	var dy := ny + 22.0
	var lines := _wrap(said[1], int(tw / 8.0))
	var prog: Array = Net.achievements.progress(api, best_run)
	for i in mini(lines.size(), 1 if not prog.is_empty() else 2):
		_text(Vector2(tx, dy + i * 14.0), lines[i], Color(DIM, 0.95 if got else 0.6), 2)
	if not prog.is_empty():
		# how far along: a row of cells filling amber, and the count
		var f := clampf(float(prog[0]) / maxf(float(prog[1]), 1.0), 0.0, 1.0)
		var by := dy + 14.0
		var count_text := ("%d / %d KG" if api == "TON" else "%d / %d") % [floori(float(prog[0])), int(prog[1])]
		var bw := tw - PixFont.width(count_text, 2) - 12.0
		var cells := 12
		var cw := floorf((bw - (cells - 1) * 2.0) / cells)
		for c in cells:
			draw_rect(Rect2(tx + c * (cw + 2.0), by, cw, 8.0), Color(AMBER, 0.8) if (c + 0.5) / cells <= f else CELL)
		_text(Vector2(tx + cells * (cw + 2.0) + 10.0, by - 1.0), count_text, CREAM, 2)
