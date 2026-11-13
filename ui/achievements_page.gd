extends Control
## The achievements page (core/achievements.gd's LIST, Net.achievements' record of them): a column in the kit's hand
## (ui/kit.gd), as the settings page (ui/settings_page.gd) is, over whatever's behind (the title's harbour, the board, the sea
## from the pause card). Along its top how many are earned of how many (yellow, right of the title); under it all of them in two columns,
## each its medal (ui/medals.gd, the 32 grid at 1x, or 2x on a tall screen), its name, what it's for and the day it was
## earned. A locked one's medal and words are at alpha 0.4; a counted one shows how far along it is (640 / 1000 KG);
## a secret one (ui/medals.gd's SECRET) is a "?" with its words hidden till it's earned.
##
## Mouse: hover picks one, BACK closes. Keys: the arrows go up and down a column and across, Enter on BACK or Esc
## closes. A pad works it as the keys do (core/pad.gd's as_key(): the d-pad or left stick, A, B back).

signal closed

const Kit := preload("res://ui/kit.gd")
const Pad := preload("res://core/pad.gd")
const Medals := preload("res://ui/medals.gd")
const Achievements := preload("res://core/achievements.gd")

const DIM := Color(0.02, 0.03, 0.04, 0.6)
const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
## The screen height from which the medals are drawn at 2x.
const TALL := 840.0

var kit := Kit.new()
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

## The screen's scale (the HUD's): 1 at 1080p.
func _px() -> float:
	return clampf(get_viewport().get_visible_rect().size.y / 1080.0, 0.7, 2.5)


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


## `text` cut into lines no wider than `width` px in the kit's face at `size`.
func _wrap_px(text: String, width: float, size: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var tryit := word if line.is_empty() else line + " " + word
		if not line.is_empty() and kit.text_w(tryit, size) > width:
			out.append(line)
			line = word
		else:
			line = tryit
	if not line.is_empty():
		out.append(line)
	return out


func _draw() -> void:
	var p := _px()
	kit.px = p
	kit.defer = true
	var list := Achievements.LIST
	var n := list.size()
	var half := ceili(n / 2.0)
	var u := 2 if size.y >= TALL else 1           # (the medals' scale)
	var icon := 32.0 * u
	var row := maxf(icon + 14.0, 78.0 * p)
	var w := minf(size.x - 48.0, 1240.0 * p)
	var total := 100.0 * p + row * half + 110.0 * p
	var x := floorf((size.x - w) * 0.5)
	var y0 := floorf(maxf(14.0 * p, (size.y - total) * 0.5))
	draw_rect(Rect2(Vector2.ZERO, size), DIM)
	# the title, how many earned at the right of it, the heavy rule and the ticks under it
	kit.num(self, Vector2(x, y0 + 22.0 * p), "ACHIEVEMENTS", 44.0 * p, Kit.PAPER, -1)
	kit.num(self, Vector2(x + w, y0 + 22.0 * p), header(), 36.0 * p, Kit.YELLOW, 1)
	kit.rule(self, Vector2(x, y0 + 54.0 * p), Vector2(x + w, y0 + 54.0 * p), Kit.PAPER, true)
	kit.scale(self, Vector2(x, y0 + 54.0 * p), Vector2(x + w * 0.3, y0 + 54.0 * p), 24, 4, Kit.PAPER, 1.0, -1.0, -1.0, false)
	# the medals, two columns with a fine rule between them
	_rects.clear()
	var top := y0 + 100.0 * p
	var gap := 36.0 * p
	var col_w := floorf((w - gap) * 0.5)
	for i in n:
		var cx := x + (col_w + gap) * floori(float(i) / half)
		var cy := top + row * (i % half)
		_entry(list[i], Rect2(cx + 22.0 * p, cy, col_w - 22.0 * p, row - 8.0 * p), icon, i == pick, p)
	kit.rule(self, Vector2(x + col_w + gap * 0.5, top - 6.0 * p), Vector2(x + col_w + gap * 0.5, top + row * half - 14.0 * p),
			Color(Kit.PAPER, 0.5))
	# BACK, and the hint along the bottom
	var by := top + row * half + 26.0 * p
	var back_on := pick == n
	var bw := kit.text_w("BACK", 28.0 * p, 700 if back_on else 600)
	var r := Rect2(x, by - 22.0 * p, bw + 28.0 * p, 44.0 * p)
	_rects.append(r)
	kit.text(self, Vector2(x + 14.0 * p, by), "BACK", 28.0 * p, Kit.YELLOW if back_on else Kit.PAPER, -1, 700 if back_on else 600)
	kit.corners(self, r.grow(4.0 * p), 9.0 * p, Kit.YELLOW if back_on else Kit.PAPER, back_on)
	var hint := "STICK OR D-PAD: LOOK THEM OVER.  [B]: BACK" if Settings.pad \
			else "MOUSE OR ARROW KEYS: LOOK THEM OVER.  ESC: BACK"
	kit.label(self, Vector2(x + r.size.x + 40.0 * p, by), hint, 16.0 * p, Color(Kit.PAPER, 0.6), -1)
	kit.flush()
	kit.defer = false


## One achievement in its slot `r`: the medal, the name and the day it was earned, what it's for (or how far along).
func _entry(a: Array, r: Rect2, icon: float, on: bool, p: float) -> void:
	var api: String = a[0]
	var got := Net.achievements.has(api)
	var said := words(api)
	_rects.append(r.grow_individual(30.0 * p, 4.0 * p, 4.0 * p, 2.0 * p))
	var ink := Color(Kit.YELLOW if on else Kit.PAPER, 1.0 if got else 0.4)
	if on:
		kit.tri(self, Vector2(r.position.x - 6.0 * p, r.position.y + icon * 0.5), 15.0 * p, Vector2.RIGHT, Kit.YELLOW)
	draw_texture_rect(Medals.texture(api, not got), Rect2(r.position, Vector2(icon, icon)), false,
			Color(1, 1, 1, 1.0 if got else 0.4))
	var tx := r.position.x + icon + 16.0 * p
	var tw := r.end.x - tx
	var name: String = said[0]
	var when: String = said[2]
	var ny := r.position.y + 11.0 * p
	var when_w := 0.0
	if not when.is_empty():
		when_w = kit.label(self, Vector2(r.end.x, ny), when, 15.0 * p, Color(Kit.YELLOW, 0.85), 1) + 14.0 * p
	kit.text(self, Vector2(tx, ny), name, 26.0 * p, ink, -1, 600)
	var dy := ny + 24.0 * p
	var dim := Color(Kit.PAPER, 0.6 if got else 0.4)
	var lines := _wrap_px(said[1], tw, 17.0 * p)
	var prog: Array = Net.achievements.progress(api, best_run)
	for i in mini(lines.size(), 1 if not prog.is_empty() else 2):
		kit.text(self, Vector2(tx, dy + i * 20.0 * p), lines[i], 17.0 * p, dim, -1, 600)
	if not prog.is_empty():
		# how far along: a little ruler with a pointer on the count, and the count
		var f := clampf(float(prog[0]) / maxf(float(prog[1]), 1.0), 0.0, 1.0)
		var by := dy + 30.0 * p
		var count_text := ("%d / %d KG" if api == "TON" else "%d / %d") % [floori(float(prog[0])), int(prog[1])]
		var cw := kit.label(self, Vector2(r.end.x, by), count_text, 15.0 * p, Color(Kit.PAPER, 0.85), 1)
		var rw := maxf(tw - cw - 24.0 * p, 20.0 * p)
		kit.scale(self, Vector2(tx, by), Vector2(tx + rw, by), 10, 5, Color(Kit.PAPER, 0.6), -1.0, 5.0 * p, 9.0 * p)
		kit.tri(self, Vector2(tx + f * rw, by + 2.0 * p), 11.0 * p, Vector2.UP, Kit.YELLOW)
