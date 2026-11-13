extends CanvasLayer
## The title: what you see when the game starts. The harbour at the fish pier behind it, a camera drifting slowly
## round the boats at their berths; BLUEFIN in big type over a ruled scale (ui/kit.gd) and the way
## in:
##   FISH     your boat: out after the boat payment alone, and open for friends to come aboard any time (it hosts quietly:
##            a Steam friend sees your boat, or the Esc menu has the join code to send)
##   RIVALS   a boat each crew, two, three or four of them, any number aboard each: against each other (most pounds
##            aboard by dusk wins the day, best of three) or together, one fleet (vs/vs.gd)
##   REJOIN   (only after a friend's boat dropped you mid-game) straight back aboard her, your same spot
##   JOIN A FRIEND   aboard a friend's boat, whichever game they're playing
##   ACHIEVEMENTS   the medals earned and still to earn (ui/achievements_page.gd, over the title)
##   SETTINGS the look, the sound, the screen and the keys (ui/settings_page.gd, over the title)
##   CREDITS  who made it, and what with (CREDITS; the licenses in full are in THIRD_PARTY_NOTICES.txt by the exe)
##   QUIT
## The version (core/version.gd) sits small in the bottom right corner.
## Rivals asks HOST or JOIN. Hosting opens the crew list (a column a boat: who's aboard her; the join code to send, a
## Steam invite), the host's BOATS (how many) and AGAINST / TOGETHER, everyone's own CHANGE BOAT, and the host's
## START (Rivals: only with someone aboard every boat; it says why not, vs/vs.gd's team_problem); joining is your
## Steam friends with a boat out, or typing in their code. START
## (or SOLO) closes it for everyone aboard: the letters fade and a short intro plays, the camera pulling up and out
## over the harbour mouth and sweeping back in low past the boats at the pier, a line or two in big type (what
## the day is), then gliding down into your eyes on the dock, no cut. Any key or click skips on to the glide.
##
## Mouse, keys (up, down, Enter, Esc back) or a pad (the d-pad or left stick, A, B: the hints say so while it's in
## hand). Only in the game itself: tests and screenshots never see it.

const Kit := preload("res://ui/kit.gd")
const Kinds := preload("res://boat/kinds.gd")
const SettingsPage := preload("res://ui/settings_page.gd")
const AchievementsPage := preload("res://ui/achievements_page.gd")
const Pad := preload("res://core/pad.gd")
const Version := preload("res://core/version.gd")

const AMBER := Color(1.0, 0.78, 0.34)
## The letters' sizes at 1080p (times kit.px): the name, and the choices (the biggest, shrinking when the page is long).
const LOGO := 150.0
const ITEM := 30.0
## How long the camera takes gliding down into your eyes (s); the intro's two legs before it (s).
const GLIDE := 2.4
const LEG := 3.4
## Each boat's colour in the crew list, if vs/vs.gd hasn't its own to give (boat_colour).
const BOAT_COLOURS := [AMBER, Color(0.45, 0.8, 1.0), Color(0.55, 0.9, 0.5), Color(1.0, 0.55, 0.7)]
## The host's two ways to play Rivals: [the row's word, what it is].
const WAYS := [["AGAINST", "MOST POUNDS BY DUSK WINS THE DAY."], ["TOGETHER", "ONE FLEET. EVERY BOAT'S FISH COUNT."]]
## The credits page: [heading, its lines]. Everything third-party is listed in full, license and all, in
## THIRD_PARTY_NOTICES.txt (tools/third_party.gd writes it; tools/release.sh puts it beside the exe).
const CREDITS := [
	["MADE BY", ["%s, %s" % [Version.STUDIO, Version.YEAR]]],
	["BUILT WITH", ["GODOT ENGINE 4.7 - MIT LICENSE - GODOTENGINE.ORG",
			"JOLT PHYSICS, FREETYPE, ENET AND GODOT'S OTHER PARTS - THEIR OWN LICENSES",
			"GODOTSTEAM 4.23 - MIT LICENSE - GODOTSTEAM.COM", "STEAMWORKS SDK - VALVE CORPORATION"]],
	["SOUND", ["KENNEY - KENNEY.NL - CC0", "BIGSOUNDBANK, JOSEPH SARDIN - BIGSOUNDBANK.COM - CC0",
			"THE MUSIC: MADE FOR THE GAME, PLAYED ON INSTRUMENTS FROM VERSILIAN STUDIOS",
			"VCSL AND VSCO 2 COMMUNITY EDITION - VERSILIANSTUDIOS.NET - CC0"]],
	["PICTURES", ["TEXTURES CRUNCHED FROM POLY HAVEN PHOTOS - POLYHAVEN.COM - CC0",
			"THE BOATS, THE CREW, THE FISH AND THE PIXEL FONT: MADE FOR THE GAME"]],
	["THANKS", ["EVERYONE WHO CAME OUT ON THE BOAT TO PLAYTEST"]],
]

var sea: Node                # sea/sea.gd
var kit := Kit.new()
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
var _intro := -1.0           # the intro, s in (-1: not playing)
var _keys: Array[Transform3D] = []
var _caption: Control
var _from: Transform3D
var _friends_in := 0.0
var _lobby_was := ""         # what the lobby's rows were made from (the host's choices: made again when they change)
## The settings page, over the title while it's open.
var settings: SettingsPage
## The achievements page, the same.
var achievements: AchievementsPage


func _ready() -> void:
	layer = 15
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.focus_mode = Control.FOCUS_ALL
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_input)
	add_child(_view)
	_caption = Control.new()
	_caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.draw.connect(_draw_caption)
	add_child(_caption)
	Settings.device_changed.connect(_on_device)
	settings = SettingsPage.new()
	settings.closed.connect(func() -> void:
		_view.visible = true
		_view.grab_focus())
	add_child(settings)
	achievements = AchievementsPage.new()
	achievements.closed.connect(func() -> void:
		_view.visible = true
		_view.grab_focus())
	add_child(achievements)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.far = 6000.0
	sea.add_child(_cam)
	_cam.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_note = Net.farewell          # (dropped from a friend's boat: the game came back here, saying so)
	Net.farewell = ""
	_go("main")
	Net.hosted.connect(func() -> void:
		if _mode == "rivals":
			(sea.get("vs") as Node).call("host_set_on", true)     # (the boats from the lobby on: who's on which is real, crossing works)
		if _mode != "fish":
			_go("lobby"))
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
			_items = []
			if not Net.last_join.is_empty() and not Net.in_session_or_hosting():
				_items.append(["REJOIN", "BACK ABOARD THE BOAT YOU WERE DROPPED FROM, IN YOUR SPOT.", func() -> void:
					_mode = ""
					_note = "JOINING..." if Net.rejoin() == OK else "COULDN'T START JOINING"])
			_items += [["FISH", "YOUR BOAT. MAKE THE PAYMENTS. FRIENDS CAN JOIN ANY TIME.", _fish],
				["RIVALS", "A BOAT EACH CREW. AGAINST EACH OTHER, OR ONE FLEET.", func() -> void: _choose("rivals")],
				["JOIN A FRIEND", "GET ABOARD A FRIEND'S BOAT.", func() -> void:
					_mode = ""
					_go("join")],
				["ACHIEVEMENTS", "%d OF %d EARNED." % [AchievementsPage.count(), Net.achievements.LIST.size()],
						open_achievements],
				["SETTINGS", "THE MOUSE, THE SOUND, THE SCREEN AND THE KEYS.", open_settings],
				["CREDITS", "WHO MADE IT, AND WHAT WITH.", func() -> void: _go("credits")],
				["QUIT", "", func() -> void: get_tree().quit()]]
		"credits":
			_items = [["BACK", "", func() -> void: _go("main")]]
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
			_items.append(["BACK", "", func() -> void: _go("host_join" if _mode == "rivals" else "main")])
			_pick = _items.size() - 2
		"lobby":
			_items = []
			var vs := sea.get("vs") as Node
			var rivals := _rivals()
			var n := boats()
			_lobby_was = _lobby_now()
			# (your own way across: with two boats it's a swap, with more it's the next one along)
			var cross := ["SWAP BOATS", "PUT YOURSELF ON THE OTHER BOAT.", _swap] if n <= 2 \
					else ["CHANGE BOAT", "PUT YOURSELF ON THE NEXT BOAT ALONG.", _swap]
			if Net.is_host():
				_items.append(["START", "EVERYONE TO THE DOCK." if rivals_problem().is_empty()
						else "SOMEONE ABOARD EVERY BOAT FIRST.", _start_pressed])
				if Net.mode == "steam":
					_items.append(["INVITE A FRIEND", "", func() -> void: Net.steam.call("invite")])
				elif not Net.code.is_empty():
					_items.append(["COPY THE CODE", "", func() -> void:
						DisplayServer.clipboard_set(Net.code)
						_note = "COPIED. SEND IT TO YOUR FRIEND."])
				if rivals:
					_items.append(cross)
					# the host's: how many boats, and against each other or one fleet (vs/vs.gd, once it can)
					if vs.has_method("host_set_boats"):
						_items.append(["BOATS: %d" % n, "A CREW EACH, ANY NUMBER ABOARD. ENTER TO CHANGE.", _next_boats])
					if vs.has_method("host_set_together"):
						var way: Array = WAYS[int(together())]
						_items.append([str(way[0]), str(way[1]) + " ENTER TO CHANGE.", _next_way])
				var hold := sea.get("fish_hold") as Node
				var kind := str(hold.get("kind"))
				_items.append(["BOAT: " + str(Kinds.KINDS[kind]["name"]).trim_prefix("the ").to_upper(),
						"EVERY CREW GETS THE SAME KIND. ENTER TO CHANGE." if rivals else "ENTER TO CHANGE.",
						_next_boat])
				# the match settings (core/settings.gd), each with its default for the mode
				var m := "rivals" if _mode == "rivals" else "career"
				_items.append(["DOCK PREP: " + Settings.prep_for(m).to_upper(), {"full": "FUEL, ICE AND BAIT BY HAND AT THE "
						+ "DOCK BEFORE CASTING OFF.", "quick": "THE SAME, QUICKER.", "off": ("EVERY BOAT GOES" if rivals
						else "SHE GOES") + " OUT FUELLED, ICED AND BAITED."}[Settings.prep_for(m)] + " ENTER TO CHANGE.",
						func() -> void:
					Settings.next_prep(m)
					_again()])
			elif rivals:
				_items.append(cross)
			_items.append(["LEAVE", "", func() -> void:
				Net.leave()
				(sea.get("crew") as Node).call("start_solo")
				_go("main")])
	_view.queue_redraw()


## The settings page over the title (the title waits under it, and has the keys back when it closes).
func open_settings() -> void:
	_view.visible = false
	settings.open()


## The achievements page over the title, the same way.
func open_achievements() -> void:
	_view.visible = false
	achievements.open(AchievementsPage.run_of(sea.get("fish_hold") as Node))


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


## The lobby's rows made again (a row's word changed), the same one still picked.
func _again() -> void:
	var keep := _pick
	_go("lobby")
	_pick = mini(keep, _items.size() - 1)


## The lobby is Rivals' (picked here, or the host's word that it's on).
func _rivals() -> bool:
	return _mode == "rivals" or bool((sea.get("vs") as Node).get("on"))


## How many boats Rivals has (vs/vs.gd's word; two, until it says).
func boats() -> int:
	var vs := sea.get("vs") as Node
	return maxi(int(vs.get("boats")), 2) if "boats" in vs else 2


## Whether the boats fish together, one fleet (vs/vs.gd's word).
func together() -> bool:
	var vs := sea.get("vs") as Node
	return bool(vs.get("together")) if "together" in vs else false


## What the lobby's rows hang on: the host's choices, and whether it can start.
func _lobby_now() -> String:
	return "%d %s %s %s" % [boats(), together(), _rivals(), rivals_problem().is_empty()]


## Host, in the Rivals lobby: one more boat, and round again from four to two.
func _next_boats() -> void:
	var vs := sea.get("vs") as Node
	var most: int = (vs.get_script() as Script).get_script_constant_map().get("MAX_BOATS", 4)
	vs.call("host_set_boats", 2 if boats() >= most else boats() + 1)
	_note = ""
	_again()


## Host, in the Rivals lobby: against each other, or together.
func _next_way() -> void:
	(sea.get("vs") as Node).call("host_set_together", not together())
	_note = ""
	_again()


## Host, in the lobby: the next kind of boat (Rivals: every crew gets her; she's chartered if she isn't owned).
func _next_boat() -> void:
	var hold := sea.get("fish_hold") as Node
	var kinds := Kinds.KINDS.keys()
	var k: String = kinds[(kinds.find(str(hold.get("kind"))) + 1) % kinds.size()]
	hold.call("pick", k)
	var vs := sea.get("vs") as Node
	if bool(vs.get("on")):
		# (side 0's boat is the sea's own, the hold's just changed her: every other side's the same kind)
		var sides: Array = vs.get("sides")
		for i in range(1, sides.size()):
			((sides[i] as Node).get("boat") as Node).call("use_kind", k)
		vs.call("_moor")
	_again()


## Across to the next boat along (with two: the other one), and round to A again.
func _swap() -> void:
	var vs := sea.get("vs") as Node
	if not bool(vs.get("on")):
		return
	vs.call("ask_team", (int(vs.get("my_team")) + 1) % boats())


## Host's START: Rivals only starts with someone aboard every boat (vs/vs.gd's team_problem says why not).
func _start_pressed() -> void:
	var why := rivals_problem()
	if not why.is_empty():
		_note = "CAN'T START: " + why
		_go("lobby")
		return
	_start()


## In the Rivals lobby, why it can't start yet ("" if it can, or it isn't Rivals).
func rivals_problem() -> String:
	var vs := sea.get("vs") as Node
	if _mode != "rivals" and not bool(vs.get("on")):
		return ""
	return str(vs.call("team_problem", Net.my_id()))


## Host: off the title, everyone aboard with you (rivals: the boats first).
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


## FISH: your own boat, hosted quietly so a friend can come aboard whenever (no lobby: straight out to the dock).
func _fish() -> void:
	_mode = "fish"
	_note = ""
	if not Net.in_session_or_hosting():
		if bool(Net.steam.get("available")):
			Net.host_steam()
		else:
			Net.host()
	var vs := sea.get("vs") as Node
	if bool(vs.get("on")):
		vs.call("host_set_on", false)
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
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the intro's path: from the drift, up and out over the harbour mouth, then back in low past the boats
	var c := _middle()
	var hi := Transform3D(Basis.IDENTITY, c + Vector3(-45.0, 34.0, -115.0))
	hi = hi.looking_at(c + Vector3(0, 2, 0), Vector3.UP)
	var lo := Transform3D(Basis.IDENTITY, c + Vector3(16.0, 4.5, -24.0))
	lo = lo.looking_at(c + Vector3(-2, 1.8, 6), Vector3.UP)
	_keys = [_cam.global_transform, hi, lo]
	_intro = 0.0


## Whether the title's still between you and the game (up, or its intro and glide playing).
func busy() -> bool:
	return up or _intro >= 0.0 or _glide >= 0.0


## Where the camera looks: the boat, or in Rivals the middle of them all.
func _middle() -> Vector3:
	var boat := sea.get("boat") as Node3D
	var c := boat.global_position if boat else Vector3.ZERO
	var vs := sea.get("vs") as Node
	if vs != null and bool(vs.get("on")):
		var sides: Array = vs.get("sides")
		if not sides.is_empty():
			c = Vector3.ZERO
			for side: Object in sides:
				c += (side.get("boat") as Node3D).global_position / sides.size()
	return c


## The pad picked up or put down: the hints along the bottom in its words.
func _on_device() -> void:
	_view.queue_redraw()
	_caption.queue_redraw()


## The intro's skipped (a key, a click): on to the glide from wherever the camera's got to, no jump.
func _skip() -> void:
	if _intro >= 0.0:
		_intro = -1.0
		_glide = 0.0
		_from = _cam.global_transform
		_caption.queue_redraw()


func _input(e: InputEvent) -> void:
	if _intro >= 0.0 and ((e is InputEventKey and (e as InputEventKey).pressed)
			or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed)
			or (e is InputEventJoypadButton and (e as InputEventJoypadButton).pressed)):
		_skip()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var boat := sea.get("boat") as Node3D
	if busy() and not _cam.current:
		_cam.make_current()        # (a crew's player made aboard under the title takes its own eyes: not yet)
	if up:
		# the drift: out over the water off the pier's end, swinging slowly from side to side, looking back in at the
		# boats and the harbour behind them
		_spin += delta * 0.06
		var c := _middle()
		var a := PI + 0.8 * sin(_spin * 0.5)
		var eye := c + Vector3(sin(a) * 32.0, 8.0 + 2.0 * sin(_spin * 0.7), cos(a) * 32.0)
		_cam.global_position = eye
		_cam.look_at(c + Vector3(0, 2.5, 0))
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if _page == "lobby" or _page == "join":
			_friends_in -= delta
			if _friends_in <= 0.0:
				_friends_in = 1.0
				if _page == "lobby" and _lobby_now() != _lobby_was:
					_again()       # (the host's changed the boats or the way: the rows say so)
				if _page == "join" and bool(Net.steam.get("available")):
					var keep := _code
					_go("join")
					_code = keep
				_view.queue_redraw()
		return
	if _intro >= 0.0:
		_intro += delta
		_view.modulate.a = 1.0 - clampf(_intro / 0.8, 0.0, 1.0)
		var leg := mini(int(_intro / LEG), 1)
		var k := clampf((_intro - leg * LEG) / LEG, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		_cam.global_transform = _keys[leg].interpolate_with(_keys[leg + 1], k)
		_caption.queue_redraw()
		if _intro >= LEG * 2.0:
			_skip()
		return
	if _glide >= 0.0:
		var me: Node = (sea.get("crew") as Node).get("me")
		var to: Camera3D = me.get("cam") if me else null
		_glide += delta
		var k := clampf(_glide / GLIDE, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		_fade = 1.0
		_view.modulate.a = 0.0
		if to != null:
			_cam.global_transform = _from.interpolate_with(to.global_transform, k)
			_cam.fov = lerpf(60.0, to.fov, k)
		if k >= 1.0:
			_glide = -1.0
			if to != null:
				to.make_current()
			_view.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED      # (on your feet at the dock: walk to what you want)


## The intro's lines, big, low in the middle, fading in and out with each leg.
func _draw_caption() -> void:
	if _intro < 0.0:
		return
	var vs := sea.get("vs") as Node
	var rivals := vs != null and bool(vs.get("on"))
	var fleet := rivals and together()
	var count: String = ["TWO", "THREE", "FOUR"][clampi(boats() - 2, 0, 2)]
	var lines := ["GULL HARBOR, FIRST LIGHT",
			("ONE FLEET. THE SAME BIRDS." if fleet else count + " BOATS. THE SAME BIRDS.") if rivals
			else ("ONE BOAT, A CREW." if _mode == "coop" else "ONE BOAT. JUST YOU."),
			("EVERY BOAT'S FISH COUNT." if fleet else "MOST POUNDS BY DUSK. BEST OF THREE.") if rivals
			else "FIND THE BIRDS, FIND THE TUNA."]
	var span := LEG * 2.0 / lines.size()
	var i := mini(int(_intro / span), lines.size() - 1)
	var u := (_intro - i * span) / span
	var a := clampf(minf(u / 0.2, (1.0 - u) / 0.2), 0.0, 1.0)
	var text: String = lines[i]
	kit.px = _caption.size.y / 1080.0
	kit.defer = true
	var tx := Vector2(_caption.size.x * 0.5, _caption.size.y * 0.72)
	kit.text(_caption, tx, text, 84.0 * kit.px, Color(Kit.PAPER, a), 0, 700, 2.0 * kit.px)
	var skip := "ANY BUTTON SKIPS" if Settings.pad else "ANY KEY SKIPS"
	kit.label(_caption, Vector2(_caption.size.x - 28.0 * kit.px, _caption.size.y - 34.0 * kit.px), skip,
			_s(18.0), Color(Kit.PAPER, 0.6), 1)
	kit.flush()


func _on_input(e: InputEvent) -> void:
	if not up:
		return
	if Pad.as_key(e) != null:
		e = Pad.as_key(e)        # (the pad: the d-pad or the left stick up and down, A picks, B goes back)
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
		# (W and S are letters of a join code: typed, on the join page)
		if k.keycode == KEY_UP or (k.keycode == KEY_W and _page != "join"):
			_pick = posmod(_pick - 1, maxi(_items.size(), 1))
		elif k.keycode == KEY_DOWN or (k.keycode == KEY_S and _page != "join"):
			_pick = posmod(_pick + 1, maxi(_items.size(), 1))
		elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			_press()
		elif k.keycode == KEY_ESCAPE:
			if _page == "join":
				_go("host_join" if _mode == "rivals" else "main")      # (as its BACK: from the first page, back there)
			elif _page == "host_join" or _page == "credits":
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


## A size at 1080p made for this screen, never under 15 px.
func _s(v: float) -> float:
	return maxf(v * kit.px, 15.0)


func _draw_view() -> void:
	var size := _view.size
	kit.px = size.y / 1080.0
	kit.defer = true
	var px := kit.px
	# one flat dim over the whole screen, the harbour still showing through
	_view.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.04, 0.35))
	# the name, a heavy rule the width of the word with a scale of ticks under it, and its line
	var left := 72.0 * px
	var word := "BLUEFIN"
	var ww := kit.text_w(word, LOGO * px, 700)
	kit.num(_view, Vector2(left, 56.0 * px + LOGO * px * 0.5), word, LOGO * px, Kit.PAPER, -1)
	var ry := 56.0 * px + LOGO * px * 1.04
	kit.rule(_view, Vector2(left, ry), Vector2(left + ww, ry), Kit.PAPER, true)
	kit.scale(_view, Vector2(left, ry + 3.0 * px), Vector2(left + ww, ry + 3.0 * px), 28, 4, Kit.PAPER, 1.0, 7.0 * px, 14.0 * px, false)
	kit.label(_view, Vector2(left, ry + 42.0 * px), "GULL HARBOR  /  BLUEFIN TUNA OFF THE NEW ENGLAND COAST", _s(20.0), Kit.PAPER, -1)
	# the page's own heading, and the crew list in the lobby
	var colw := maxf(ww, 700.0 * px)
	var y := ry + 96.0 * px
	var heading: String = {"host_join": _mode.to_upper().replace("COOP", "CO-OP"), "join": "JOIN A FRIEND",
			"lobby": "THE CREW", "credits": "CREDITS"}.get(_page, "")
	if not heading.is_empty():
		kit.num(_view, Vector2(left, y + 22.0 * px), heading, 44.0 * px, Kit.PAPER, -1)
		var hy := y + 56.0 * px
		kit.rule(_view, Vector2(left, hy), Vector2(left + colw, hy), Kit.PAPER, true)
		kit.scale(_view, Vector2(left, hy + 3.0 * px), Vector2(left + colw * 0.3, hy + 3.0 * px), 12, 4, Kit.PAPER, 1.0, 6.0 * px, 12.0 * px, false)
		y = hy + 44.0 * px
	if _page == "join":
		# the code's field: its type on a heavy rule, a bar blinking after it
		kit.label(_view, Vector2(left, y + 8.0 * px), "CODE", _s(20.0), Kit.PAPER, -1)
		var fx := left + kit.text_w("CODE", _s(20.0), 600, _s(20.0) * 0.17) + 28.0 * px
		var cw := kit.text_w(_code, 40.0 * px, 700)
		var fend := fx + maxf(cw + 36.0 * px, 340.0 * px)
		kit.num(_view, Vector2(fx, y), _code, 40.0 * px, Kit.PAPER, -1)
		kit.rule(_view, Vector2(fx, y + 26.0 * px), Vector2(fend, y + 26.0 * px), Kit.PAPER, true)
		if Time.get_ticks_msec() % 1000 < 500:
			kit.bar(_view, Rect2(fx + cw + 4.0 * px, y - 16.0 * px, 4.0 * px, 36.0 * px), Kit.YELLOW)
		y += 62.0 * px
		if bool(Net.steam.get("available")) and _items.size() <= 2:
			kit.label(_view, Vector2(left, y), "NO STEAM FRIENDS HAVE A BOAT OUT RIGHT NOW", _s(17.0), Color(Kit.PAPER, 0.6), -1)
			y += 34.0 * px
	if _page == "lobby":
		y = _draw_crew(Vector2(left, y))
	if _page == "credits":
		y = _draw_credits(Vector2(left, y))
	# the choices: as big as the page has room for under what's above them (the Rivals lobby is the long one)
	_rects.clear()
	var sz := ITEM * px
	while sz > 18.0 * px and y + _items.size() * _row(sz) > size.y - 70.0 * px:
		sz -= 2.0 * px
	var row := _row(sz)
	for i in _items.size():
		var label: String = _items[i][0]
		var on := i == _pick
		var cy := y + row * 0.5
		var tw := kit.text_w(label, sz, 700 if on else 600)
		_rects.append(Rect2(left - 8.0 * px, y, tw + 70.0 * px, row))
		if on:
			kit.tri(_view, Vector2(left + 14.0 * px, cy), sz * 0.55, Vector2.RIGHT, Kit.YELLOW)
		kit.text(_view, Vector2(left + 26.0 * px, cy), label, sz, Kit.YELLOW if on else Kit.PAPER, -1, 700 if on else 600)
		# what the picked one does, beside it
		var blurb: String = _items[i][1]
		if on and not blurb.is_empty():
			kit.label(_view, Vector2(left + 26.0 * px + tw + 28.0 * px, cy), blurb, _s(17.0), Color(Kit.PAPER, 0.75), -1)
		y += row
	if not _note.is_empty():
		kit.label(_view, Vector2(left + 26.0 * px, y + 20.0 * px), _note, _s(18.0), Kit.ORANGE, -1)
	kit.label(_view, Vector2(left, size.y - 34.0 * px), "STICK OR D-PAD, [A] TO PICK, [B] TO GO BACK" if Settings.pad
			else "MOUSE OR ARROW KEYS, ENTER TO PICK, ESC TO GO BACK", _s(16.0), Color(Kit.PAPER, 0.6), -1)
	kit.label(_view, Vector2(size.x - 28.0 * px, size.y - 34.0 * px), version_text(), _s(16.0), Color(Kit.PAPER, 0.6), 1)
	kit.flush()


## A choice's row, top to top (px), its letters `sz` tall.
func _row(sz: float) -> float:
	return sz * 1.5


## What the corner says: "V1.0.0".
static func version_text() -> String:
	return "V" + Version.VERSION


## The credits, under the page's heading. Returns where they end.
func _draw_credits(at: Vector2) -> float:
	var px := kit.px
	var y := at.y
	for c: Array in CREDITS:
		kit.label(_view, Vector2(at.x, y), str(c[0]), _s(17.0), Kit.PAPER, -1)
		y += 26.0 * px
		for line: String in c[1]:
			kit.text(_view, Vector2(at.x + 14.0 * px, y), line.to_upper(), _s(19.0), Color(Kit.PAPER, 0.85), -1)
			y += 24.0 * px
		y += 8.0 * px
	return y + 6.0 * px


## Boat i's colour (vs/vs.gd's, once it has one to give).
func boat_colour(i: int) -> Color:
	var vs := sea.get("vs") as Node
	if vs.has_method("boat_colour"):
		return vs.call("boat_colour", i)
	return BOAT_COLOURS[i % BOAT_COLOURS.size()]


## Boat i's name: "A".. (vs/vs.gd's, once it has one to give).
func boat_name(i: int) -> String:
	var vs := sea.get("vs") as Node
	if vs.has_method("boat_name"):
		return str(vs.call("boat_name", i))
	return "ABCD"[i % 4]


## The crew list's columns, one a boat in Rivals (else the one, with no heading): each {"head", "colour", "crew"},
## crew the lines of who's aboard her, in the order they came.
func crew_columns() -> Array:
	var crew := sea.get("crew") as Node
	var vs := sea.get("vs") as Node
	var slots: Dictionary = crew.get("slots")
	var rivals := _rivals()
	var teams: Dictionary = vs.get("teams")
	var ids := slots.keys()
	ids.sort()
	var cols: Array = []
	for c in (boats() if rivals else 1):
		var aboard: Array[String] = []
		for id: int in ids:
			if rivals and int(teams.get(id, 0)) != c:
				continue
			aboard.append(str(crew.call("call_sign", id)).to_upper() + ("  (YOU)" if id == Net.my_id() else ""))
		cols.append({"head": "BOAT " + boat_name(c) if rivals else "", "colour": boat_colour(c), "crew": aboard})
	return cols


## Who's aboard (a column a boat in rivals), the host's choices for whoever isn't the host, and the code to send: under
## the lobby's heading. Returns where it ends.
func _draw_crew(at: Vector2) -> float:
	var px := kit.px
	var rivals := _rivals()
	var cols := crew_columns()
	var mine := int(((sea.get("vs") as Node).get("teams") as Dictionary).get(Net.my_id(), 0))
	var step := minf(300.0 * px, 700.0 * px / cols.size())
	var y := at.y
	for c in cols.size():
		var col: Dictionary = cols[c]
		var x := at.x + c * step
		var yy := at.y
		var ind := 8.0 * px if rivals else 0.0
		if rivals:
			kit.square(_view, Vector2(x + 7.0 * px, yy), 14.0 * px, col["colour"])
			kit.text(_view, Vector2(x + 26.0 * px, yy), str(col["head"]), 26.0 * px, Kit.YELLOW if c == mine else Kit.PAPER, -1, 700)
			var ly := yy + 20.0 * px
			kit.rule(_view, Vector2(x, ly), Vector2(x + step - 24.0 * px, ly))
			yy += 46.0 * px
		for who: String in col["crew"]:
			kit.text(_view, Vector2(x + ind, yy), who, _s(21.0), Kit.PAPER, -1)
			yy += 28.0 * px
		if (col["crew"] as Array).is_empty():
			kit.text(_view, Vector2(x + ind, yy), "NOBODY ABOARD", _s(21.0), Color(Kit.PAPER, 0.6), -1)
			yy += 28.0 * px
		y = maxf(y, yy)
	y += 16.0 * px
	if rivals and not Net.is_host():
		# (the host's choices, for everyone who can't change them)
		var way: Array = WAYS[int(together())]
		kit.label(_view, Vector2(at.x, y), "%d BOATS, %s. %s" % [cols.size(), way[0], way[1]], _s(17.0), Kit.PAPER, -1)
		y += 30.0 * px
	if Net.is_host() and Net.mode == "code" and not Net.code.is_empty():
		kit.label(_view, Vector2(at.x, y + 4.0 * px), "JOIN CODE", _s(17.0), Kit.PAPER, -1)
		kit.num(_view, Vector2(at.x + 150.0 * px, y), Net.code, 30.0 * px, Kit.PAPER, -1)
		y += 42.0 * px
	elif Net.is_host() and Net.mode == "code":
		kit.label(_view, Vector2(at.x, y), "JOIN CODE: ASKING YOUR ROUTER" + ".".repeat(1 + Time.get_ticks_msec() / 400 % 3), _s(17.0), Color(Kit.PAPER, 0.6), -1)
		y += 36.0 * px
	elif not Net.is_host():
		kit.label(_view, Vector2(at.x, y), "WAITING FOR THE HOST TO START", _s(17.0), Color(Kit.PAPER, 0.6), -1)
		y += 30.0 * px
	# (Rivals: why it can't start yet, on everyone's screen)
	var why := rivals_problem() if rivals else ""
	if not why.is_empty():
		kit.label(_view, Vector2(at.x, y), why, _s(17.0), Kit.ORANGE, -1)
		y += 30.0 * px
	return y + 10.0 * px
