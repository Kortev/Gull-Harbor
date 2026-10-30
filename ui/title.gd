extends CanvasLayer
## The title: what you see when the game starts. The harbour at the fish pier behind it, a camera drifting slowly
## round the boats at their berths; BLUEFIN in big pixel letters (ui/pixfont.gd, the game's pixel look) and the way
## in:
##   RIVALS   two boats, a crew each; most pounds aboard by dusk wins the day, best of three (vs/vs.gd)
##   CO-OP    one boat, a crew of up to four
##   SOLO     her and you
##   QUIT
## Rivals and co-op ask HOST or JOIN. Hosting opens the crew list (who's aboard which boat, the join code to send, a
## Steam invite) and the host's START; joining is your Steam friends with a boat out, or typing in their code. START
## (or SOLO) closes it for everyone aboard: the letters fade, and the camera glides down from its drift into your eyes
## on the dock, no cut.
##
## Mouse or keys (up, down, Enter, Esc back). Only in the game itself: tests and screenshots never see it.

const PixFont := preload("res://ui/pixfont.gd")

const AMBER := Color(1.0, 0.78, 0.34)
const CREAM := Color(1.0, 0.95, 0.82)
const DIM := Color(0.72, 0.76, 0.8)
const SHADOW := Color(0.02, 0.03, 0.05, 0.85)
## The letters' sizes (px per font pixel): the name, its line under it, the choices, the small print.
const LOGO := 15
const SUB := 3
const ITEM := 5
const SMALL := 2
## How long the camera takes gliding down into your eyes (s).
const GLIDE := 2.4

var sea: Node                # sea/sea.gd
## Up: the title's showing (and the dock menu, ui/menu.gd, waits under it).
var up := true
var _page := "main"
var _mode := ""              # "rivals" or "coop", once picked
var _pick := 0
var _items: Array = []       # [label, blurb, callable]
var _rects: Array[Rect2] = []
var _note := ""
var _code := ""              # being typed, on the join page
var _view: Control
var _cam: Camera3D
var _spin := 0.0
var _fade := 0.0             # 0 showing .. 1 gone
var _glide := -1.0           # the camera's glide into your eyes, s in (-1: not yet)
var _from: Transform3D
var _friends_in := 0.0


func _ready() -> void:
	layer = 15
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.focus_mode = Control.FOCUS_ALL
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	add_child(_view)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.far = 6000.0
	sea.add_child(_cam)
	_cam.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_go("main")
	Net.hosted.connect(func() -> void: _go("lobby"))
	Net.joined.connect(func() -> void:
		_note = ""
		_go("lobby"))
	Net.opened.connect(func(ok: bool, _c: String) -> void:
		_note = "" if ok else "YOUR ROUTER SAID NO: THE CODE WORKS ON YOUR WI-FI ONLY")
	# (a friend aboard after the host's started: straight off the title for them too)
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server() and not up:
			_begin.rpc_id(id))
	Net.dropped.connect(func(reason: String) -> void:
		if up:
			_note = reason.to_upper()
			_go("main"))
	_view.grab_focus()


## Turn to a page of the title: its choices.
func _go(page: String) -> void:
	_page = page
	_pick = 0
	_items.clear()
	match page:
		"main":
			_items = [["RIVALS", "TWO BOATS, A CREW EACH. MOST FISH BY DUSK WINS THE DAY.", func() -> void: _choose("rivals")],
				["CO-OP", "ONE BOAT, UP TO FOUR OF YOU. MAKE THE QUOTA OR LOSE HER.", func() -> void: _choose("coop")],
				["SOLO", "JUST YOU AND HER. HARD WORK ALONE.", _solo],
				["QUIT", "", func() -> void: get_tree().quit()]]
		"host_join":
			_items = [["HOST", "START A BOAT AND SEND YOUR FRIEND THE CODE.", _host],
				["JOIN", "GET ABOARD A FRIEND'S BOAT.", func() -> void: _go("join")],
				["BACK", "", func() -> void: _go("main")]]
		"join":
			_code = ""
			_items = []
			if bool(Net.steam.get("available")):
				for f: Dictionary in Net.steam.call("friends_out"):
					var lobby := int(f["lobby"])
					var who := str(f["name"])
					_items.append(["JOIN " + who.to_upper(), "", func() -> void:
						_note = "JOINING..."
						Net.join_steam(lobby)])
			_items.append(["JOIN BY CODE", "TYPE OR PASTE THE CODE (CTRL+V), THEN ENTER.", func() -> void:
				_note = "JOINING..." if Net.join(_code) == OK else "COULDN'T START JOINING"])
			_items.append(["BACK", "", func() -> void: _go("host_join")])
			_pick = _items.size() - 2
		"lobby":
			_items = []
			if Net.is_host():
				_items.append(["START", "EVERYONE TO THE DOCK.", _start])
				if Net.mode == "steam":
					_items.append(["INVITE A FRIEND", "", func() -> void: Net.steam.call("invite")])
				elif not Net.code.is_empty():
					_items.append(["COPY THE CODE", "", func() -> void:
						DisplayServer.clipboard_set(Net.code)
						_note = "COPIED. SEND IT TO YOUR FRIEND."])
				if _mode == "rivals":
					_items.append(["SWAP BOATS", "PUT YOURSELF ON THE OTHER BOAT.", _swap])
			else:
				if _mode == "rivals" or bool((sea.get("vs") as Node).get("on")):
					_items.append(["SWAP BOATS", "PUT YOURSELF ON THE OTHER BOAT.", _swap])
			_items.append(["LEAVE", "", func() -> void:
				Net.leave()
				(sea.get("crew") as Node).call("start_solo")
				_go("main")])
	_view.queue_redraw()


func _choose(mode: String) -> void:
	_mode = mode
	_note = ""
	if Net.in_session_or_hosting():
		_go("lobby")
	else:
		_go("host_join")


func _host() -> void:
	_note = "MAKING A BOAT..."
	if bool(Net.steam.get("available")):
		Net.host_steam()
	elif Net.host() != OK:
		_note = "COULDN'T HOST (PORT IN USE?)"


func _swap() -> void:
	var vs := sea.get("vs") as Node
	if not bool(vs.get("on")):
		return
	vs.call("ask_team", 1 - int(vs.get("my_team")))


## Host: off the title, everyone aboard with you (rivals: two boats first).
func _start() -> void:
	var vs := sea.get("vs") as Node
	if _mode == "rivals" and not bool(vs.get("on")):
		vs.call("host_set_on", true)
	elif _mode == "coop" and bool(vs.get("on")):
		vs.call("host_set_on", false)
	if Net.in_session():
		_begin.rpc()
	else:
		_begin()


func _solo() -> void:
	_mode = "solo"
	if Net.in_session_or_hosting():
		Net.leave()
		(sea.get("crew") as Node).call("start_solo")
	_begin()


## Everyone: the title goes, the camera glides down into your eyes.
@rpc("authority", "call_local", "reliable")
func _begin() -> void:
	if not up:
		return
	up = false
	_glide = 0.0
	_from = _cam.global_transform
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var boat := sea.get("boat") as Node3D
	if up:
		# the drift: out over the water off the pier's end, swinging slowly from side to side, looking back in at the
		# boats and the harbour behind them
		_spin += delta * 0.06
		var c := boat.global_position if boat else Vector3.ZERO
		var vs := sea.get("vs") as Node
		if vs != null and bool(vs.get("on")):
			c = Vector3.ZERO
			for side: Object in vs.get("sides"):
				c += (side.get("boat") as Node3D).global_position * 0.5
		var a := PI + 0.8 * sin(_spin * 0.5)
		var eye := c + Vector3(sin(a) * 32.0, 8.0 + 2.0 * sin(_spin * 0.7), cos(a) * 32.0)
		_cam.global_position = eye
		_cam.look_at(c + Vector3(0, 2.5, 0))
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if _page == "lobby" or _page == "join":
			_friends_in -= delta
			if _friends_in <= 0.0:
				_friends_in = 1.0
				if _page == "join" and bool(Net.steam.get("available")):
					var keep := _code
					_go("join")
					_code = keep
				_view.queue_redraw()
		return
	if _glide >= 0.0:
		var me: Node = (sea.get("crew") as Node).get("me")
		var to: Camera3D = me.get("cam") if me else null
		_glide += delta
		var k := clampf(_glide / GLIDE, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		_fade = clampf(_glide / 0.8, 0.0, 1.0)
		_view.modulate.a = 1.0 - _fade
		if to != null:
			_cam.global_transform = _from.interpolate_with(to.global_transform, k)
			_cam.fov = lerpf(60.0, to.fov, k)
		if k >= 1.0:
			_glide = -1.0
			if to != null:
				to.make_current()
			_view.visible = false
			var hold := sea.get("fish_hold") as Node
			var vs := sea.get("vs") as Node
			if hold == null or not bool(hold.get("docked")) or (vs != null and bool(vs.get("on"))):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_input(e: InputEvent) -> void:
	if not up:
		return
	if e is InputEventMouseMotion:
		for i in _rects.size():
			if _rects[i].has_point((e as InputEventMouseMotion).position) and i != _pick:
				_pick = i
				_view.queue_redraw()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		for i in _rects.size():
			if _rects[i].has_point((e as InputEventMouseButton).position):
				_pick = i
				_press()
	elif e is InputEventKey and (e as InputEventKey).pressed:
		var k := e as InputEventKey
		if k.keycode == KEY_UP or k.keycode == KEY_W:
			_pick = posmod(_pick - 1, maxi(_items.size(), 1))
		elif k.keycode == KEY_DOWN or k.keycode == KEY_S and _page != "join":
			_pick = posmod(_pick + 1, maxi(_items.size(), 1))
		elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			_press()
		elif k.keycode == KEY_ESCAPE:
			if _page == "join":
				_go("host_join")
			elif _page == "host_join":
				_go("main")
		elif _page == "join":
			if k.keycode == KEY_V and k.ctrl_pressed:
				_code = DisplayServer.clipboard_get().strip_edges().to_upper().left(24)
			elif k.keycode == KEY_BACKSPACE:
				_code = _code.left(-1)
			elif k.unicode > 32 and k.unicode < 127 and _code.length() < 24:
				_code += String.chr(k.unicode).to_upper()
		_view.queue_redraw()
		_view.accept_event()


func _press() -> void:
	if _pick >= 0 and _pick < _items.size():
		(_items[_pick][2] as Callable).call()
		_view.queue_redraw()


func _text(at: Vector2, text: String, col: Color, scale: int) -> void:
	PixFont.draw(_view, at + Vector2(scale, scale), text, SHADOW, scale)
	PixFont.draw(_view, at, text, col, scale)


func _draw_view() -> void:
	var size := _view.size
	# a dark wash down the left, the harbour bright beside it
	var wash := Color(0.01, 0.02, 0.035, 0.78)
	var w0 := size.x * 0.42
	var w1 := size.x * 0.72
	_view.draw_rect(Rect2(0, 0, w0, size.y), wash)
	_view.draw_polygon(PackedVector2Array([Vector2(w0, 0), Vector2(w1, 0), Vector2(w1, size.y), Vector2(w0, size.y)]),
			PackedColorArray([wash, Color(wash, 0.0), Color(wash, 0.0), wash]))
	# the name, shaded top to bottom like the dawn on the water, and its line under it
	var at := Vector2(64, 56)
	var word := "BLUEFIN"
	var rows := [CREAM, CREAM, AMBER, AMBER, Color(0.95, 0.5, 0.22)]
	PixFont.draw(_view, at + Vector2(5, 5), word, SHADOW, LOGO)
	for r in 5:
		var x := at.x
		for ch in word:
			var g: Array = PixFont.GLYPHS[ch]
			var row: String = g[r]
			for cx in 3:
				if row[cx] == "#":
					_view.draw_rect(Rect2(x + cx * LOGO, at.y + r * LOGO, LOGO, LOGO), rows[r])
			x += 4 * LOGO
	_text(at + Vector2(4, LOGO * 5 + 18), "GULL HARBOR  -  BLUEFIN TUNA OFF THE NEW ENGLAND COAST", DIM, SUB)
	# the page's own heading, and the crew list in the lobby
	var y := at.y + LOGO * 5 + 70
	var heading: String = {"host_join": _mode.to_upper().replace("COOP", "CO-OP"), "join": "JOIN A FRIEND",
			"lobby": "THE CREW"}.get(_page, "")
	if not heading.is_empty():
		_text(Vector2(at.x + 4, y), heading, AMBER, 3)
		y += 30
	if _page == "join":
		_text(Vector2(at.x + 4, y), "CODE: " + _code + ("_" if Time.get_ticks_msec() % 1000 < 500 else " "), CREAM, 4)
		y += 34
	if _page == "lobby":
		y = _draw_crew(Vector2(at.x + 4, y))
	# the choices
	_rects.clear()
	for i in _items.size():
		var label: String = _items[i][0]
		var on := i == _pick
		var r := Rect2(at.x - 4, y - 6, PixFont.width(label, ITEM) + 60, ITEM * 5 + 12)
		_rects.append(r)
		if on:
			_view.draw_rect(Rect2(at.x - 4, y - 6, 8, ITEM * 5 + 12), AMBER)
		_text(Vector2(at.x + 22, y), label, AMBER if on else CREAM, ITEM)
		y += ITEM * 5 + 16
	if _pick >= 0 and _pick < _items.size() and not str(_items[_pick][1]).is_empty():
		_text(Vector2(at.x + 22, y + 4), str(_items[_pick][1]), DIM, SMALL)
		y += 24
	if not _note.is_empty():
		_text(Vector2(at.x + 22, y + 10), _note, Color(1.0, 0.7, 0.5), SMALL)
	_text(Vector2(at.x + 4, size.y - 30), "MOUSE OR ARROW KEYS, ENTER TO PICK, ESC TO GO BACK", Color(DIM, 0.6), SMALL)


## Who's aboard (and in rivals, which boat), and the code to send: under the lobby's heading. Returns where it ends.
func _draw_crew(at: Vector2) -> float:
	var crew := sea.get("crew") as Node
	var vs := sea.get("vs") as Node
	var slots: Dictionary = crew.get("slots")
	var rivals := bool(vs.get("on")) or _mode == "rivals"
	var teams: Dictionary = vs.get("teams")
	var y := at.y
	var cols := 2 if rivals else 1
	for c in cols:
		var x := at.x + c * 260
		var yy := y
		if rivals:
			_text(Vector2(x, yy), "BOAT " + "AB"[c], [AMBER, Color(0.45, 0.8, 1.0)][c], 3)
			yy += 24
		var ids := slots.keys()
		ids.sort()
		for id: int in ids:
			if rivals and int(teams.get(id, 0)) != c:
				continue
			var who := str(crew.call("call_sign", id)).to_upper() + ("  (YOU)" if id == Net.my_id() else "")
			_text(Vector2(x + 8, yy), who, CREAM, 2)
			yy += 18
		y = maxf(y, yy) if c == cols - 1 else y
		if c < cols - 1:
			at.y = maxf(at.y, yy)
	y = maxf(y, at.y) + 14
	if Net.is_host() and Net.mode == "code" and not Net.code.is_empty():
		_text(Vector2(at.x, y), "JOIN CODE: " + Net.code, CREAM, 3)
		y += 30
	elif not Net.is_host():
		_text(Vector2(at.x, y), "WAITING FOR THE HOST TO START", DIM, 2)
		y += 22
	return y + 10
