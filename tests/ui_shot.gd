extends Node
## Every screen of the UI, shot (QA for the look: alignment, sizes, clipping), the game itself from its title (the
## sea at the tree's root, as it boots) put straight into each state rather than played there. Parts (-- --part=):
##   menus    the title's pages, its achievements and settings, the lobby (co-op, and Rivals all on one boat: START
##            warns), the harbour board and its manual, settings and achievements, a toast
##   sea      out there on the sportfisher: the deck, a notice, the wheel, a rod, the fight (its tells, the long
##            one too), the wheel with a fish on (the plotter), the pause card and its pages, swimming, aloft
##   rivals   the countdown, the race out, dusk's race home, the results card (A's day, B's day, a tie, the match)
## Into --out=<dir> as <part>_NN_<what>.png. The bank and the medals are a test's, never yours. Run (needs a window):
##   godot --path . --resolution 1600x900 res://tests/ui_shot.tscn -- --part=menus --out=<dir> [--port=7831]
## (--size=1920x1080: a borderless window that size at the screen's corner, for a size the screen can't fit with a
## title bar.)

const Sea := preload("res://sea/sea.gd")
const FightBot := preload("res://tests/fight_bot.gd")
const SAVE := "user://bluefin_ui_shot.cfg"

var sea: Sea
var part := "menus"
var out := "user://ui_shot/"
var port := 7831
var _n := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = a.trim_prefix("--part=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=").trim_suffix("/") + "/"
		elif a.begins_with("--port="):
			port = int(a.trim_prefix("--port="))
		elif a.begins_with("--size="):
			var wh := a.trim_prefix("--size=").split("x")
			await get_tree().process_frame
			get_window().borderless = true
			get_window().position = Vector2i.ZERO
			get_window().size = Vector2i(int(wh[0]), int(wh[1]))
			await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	get_tree().root.add_child.call_deferred(sea)
	get_tree().set_deferred("current_scene", sea)
	await get_tree().process_frame
	await get_tree().process_frame
	sea.fish_hold.save_path = SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	sea.fish_hold.call("_load")
	sea.fish_hold.call("_host_changed")
	sea.set_condition("sunny")
	# a few medals earned, a ton part sold
	var a := Net.achievements
	var now := int(Time.get_unix_time_from_system())
	a.got = {"FIRST_FISH": now - 86400 * 9, "LIVE_BAIT": now - 86400 * 9, "GIANT": now - 86400 * 2,
			"RIVALS_DAY": now - 3600, "BOARDED": now - 3600}
	a.kg_sold = 640.0
	a.queue.clear()
	await _wait(2.0)
	await call("_" + part)
	print("UI SHOT ", part, " DONE")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()


# ---- the menus ---------------------------------------------------------------------------------------------------

func _menus() -> void:
	var t := sea.title
	await _shot("title")
	t.set("_pick", 1)
	await _shot("title_rivals_picked")
	t.call("_choose", "rivals")
	await _shot("rivals_host_join")
	t.call("_go", "join")
	await _shot("join")
	t.set("_mode", "")
	t.call("_go", "credits")
	await _shot("credits")
	t.call("_go", "main")
	t.call("open_achievements")
	await _shot("achievements")
	for i in 3:
		await _key(KEY_DOWN)
	await _key(KEY_RIGHT)
	await _shot("achievements_picked")
	await _key(KEY_ESCAPE)
	t.call("open_settings")
	for p in 5:
		await _shot("settings_%d" % p)
		await _key(KEY_TAB)
	await _key(KEY_ESCAPE)
	# the lobby: co-op, then Rivals with everyone on boat A
	t.set("_mode", "coop")
	Net.host(port)
	await _wait(0.5)
	t.call("_go", "lobby")
	await _shot("lobby_coop")
	Net.leave()
	sea.crew.call("start_solo")
	await _wait(0.3)
	t.call("_go", "main")
	t.call("_choose", "rivals")
	t.call("_host")
	if not Net.in_session_or_hosting():
		Net.host(port)
	await _wait(0.6)
	t.call("_go", "lobby")
	await _shot("lobby_rivals")
	t.set("_pick", 0)
	t.call("_press")          # START, all aboard A
	await _shot("lobby_rivals_start_alone")
	sea.vs.host_set_on(false)
	Net.leave()
	sea.crew.call("start_solo")
	await _wait(0.3)
	# FISH, the intro skipped, the board
	t.call("_go", "main")
	Net.host(port)
	await _wait(0.3)
	t.call("_fish")
	await _wait(1.0)
	await _shot("intro")
	t.call("_skip")
	while t.busy():
		await get_tree().process_frame
	await _wait(1.0)
	await _shot("board")
	var menu := _menu()
	menu.set("_reading", true)
	await _shot("board_manual")
	menu.set("_reading", false)
	menu.call("open_achievements")
	await _shot("board_achievements")
	await _key(KEY_ESCAPE)
	menu.call("open_settings", 3)
	await _shot("board_settings_keys")
	await _key(KEY_ESCAPE)
	Net.achievements.unlock("SPORTFISHER")
	await _wait(0.6)
	await _shot("board_toast")
	await _wait(5.0)
	menu.set("_wipe", true)
	await _wait(0.2)
	await _shot("board_new_career_ask")


# ---- out there ---------------------------------------------------------------------------------------------------

func _sea() -> void:
	await _off_title()
	var hold := sea.fish_hold
	hold.head_out("sportfisher")
	hold.trip_t0 -= hold.DAY * 0.3
	sea.schools.set("_next", 9999.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var me := sea.crew.me
	me.force_input = true
	await _wait(1.5)
	await _shot("deck")
	sea.crew.hud.notify("Fish on! E on the rod")
	await _wait(0.3)
	await _shot("notice")
	sea.boat.helm.request(true)
	_hold("move_forward", true)
	await _wait(3.0)
	_hold("move_forward", false)
	await _shot("helm")
	sea.boat.helm.request(false)
	await _wait(0.5)
	for r in sea.rods.rods:
		sea.rods.host_cast(r.index)
	for r in sea.rods.rods:
		while sea.rods.flying(r.index):
			await get_tree().process_frame
	sea.rods.request_grab(1)
	await _wait(0.6)
	await _shot("rod")
	sea.rods.request_return(1)
	await _wait(0.4)
	# a fish on, nobody on the rod: the tells
	sea.rods.strike(0, 220.0)
	await _wait(1.5)
	await _shot("fish_on_lines_out")
	for r in sea.rods.rods:
		if r.index != 0:
			sea.rods._host_line(r.index, true)
	await _wait(2.0)
	sea.boat.helm.request(true)
	var rod = sea.rods.rods[0]
	await _wait(1.0)
	_hold_fish(rod)
	await _shot("helm_fish_on")
	sea.boat.helm.request(false)
	await _wait(0.4)
	sea.rods.request_grab(0)
	await _play(rod, 4.0)
	await _shot("fight")
	sea.rods.arms = 0.2
	await _play(rod, 1.0)
	await _shot("fight_arms")
	# the pause card (alone: it holds the world still)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _wait(0.4)
	await _shot("pause")
	var menu := _menu()
	menu.set("_reading", true)
	await _wait(0.2)
	await _shot("pause_manual")
	menu.set("_reading", false)
	menu.call("open_achievements")
	await _shot("pause_achievements")
	await _key(KEY_ESCAPE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(0.4)
	sea.rods.request_return(0)
	if rod.hooked and rod.fight != null:
		rod.fight.set("grace", 0.0)
	await _wait(0.3)
	# up the tower, then over the side
	var tower: Node = sea.boat.get("tower")
	if tower != null:
		tower.call("interact", me)
		await _wait(3.0)
		await _shot("aloft")
		me.call("climb_down_tower")
		await _wait(2.5)
	var at: Vector3 = sea.boat.global_position + sea.boat.global_transform.basis.x * 6.0
	me.call("overboard", at, sea.boat.global_position)
	await _wait(2.0)
	await _shot("swimming")
	Net.achievements.unlock("STORM")
	await _wait(0.6)
	await _shot("swim_toast")


# ---- Rivals ------------------------------------------------------------------------------------------------------

func _rivals() -> void:
	var t := sea.title
	var vs := sea.vs
	t.call("_choose", "rivals")
	Net.host(port)
	await _wait(0.6)
	t.call("_start")
	await _wait(0.3)
	t.call("_skip")
	while t.busy():
		await get_tree().process_frame
	vs.set("count_end", vs.call("_now") + 7.0)
	await _wait(0.6)
	await _shot("countdown")
	while float(vs.get("count_end")) > 0.0:
		await get_tree().process_frame
	await _wait(0.2)
	await _shot("go")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	sea.boat.helm.request(true)
	_hold("move_forward", true)
	await _wait(6.0)
	_hold("move_forward", false)
	(vs.get("sides")[0].get("fish_hold") as Node).call("host_add", 180.0, 60.0)
	await _wait(0.5)
	await _shot("race_out")
	vs.set("home_by", vs.call("_now") + 150.0)
	await _wait(0.5)
	await _shot("dusk")
	vs.set("home_by", -1.0)
	var card: Node = vs.get("card")
	var boats := [{"fish": 3, "kg": 412.0, "big": 220.0, "money": 9800, "late": 0.0, "lb": 908.0},
			{"fish": 2, "kg": 260.0, "big": 180.0, "money": 6100, "late": 40.0, "lb": 485.0}]
	var tie := [boats[0], boats[0]]
	for c: Array in [["card_day_a", {"decided": false, "winner": 0, "day": 1, "wins": [1, 0], "boats": boats,
				"day_lb": [908.0, 485.0]}],
			["card_day_b", {"decided": false, "winner": 1, "day": 2, "wins": [1, 1], "boats": [boats[1], boats[0]],
				"day_lb": [485.0, 908.0]}],
			["card_tie", {"decided": false, "winner": -1, "day": 2, "wins": [1, 0], "boats": tie,
				"day_lb": [908.0, 908.0]}],
			["card_match", {"decided": true, "winner": 0, "day": 3, "wins": [2, 1], "boats": boats,
				"day_lb": [908.0, 485.0]}]]:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		card.call("open", c[1], 0)
		card.set("states", [0, 1])
		await _wait(float(card.get("T_BUTTONS")) + 0.6)
		await _shot(c[0])
		card.call("close")
	await _wait(0.3)


# ---- hands -------------------------------------------------------------------------------------------------------

func _off_title() -> void:
	var t := sea.title
	Net.host(port)
	await _wait(0.3)
	t.call("_fish")
	t.call("_skip")
	while t.busy():
		await get_tree().process_frame
	await _wait(0.5)


func _menu() -> Node:
	for c in sea.get_children():
		if c.get_script() == load("res://ui/menu.gd"):
			return c
	return null


## The fish held where he is, astern and fresh (a shot's worth, not a fight).
func _hold_fish(rod: Node) -> void:
	if rod.get("fight") != null:
		(rod.get("fight") as RefCounted).set("grace", 999.0)


## `s` seconds of the fight, a test angler on the reel.
func _play(rod: Node, s: float) -> void:
	var mem := {}
	var t := 0.0
	while t < s and rod.get("hooked"):
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var f: RefCounted = rod.get("fight")
		if f == null:
			continue
		f.set("grace", 999.0)
		var act := FightBot.act(f.call("cues"), dt, "good", mem)
		sea.rods.bot_aim = Vector3(float(act["pitch"]), float(act["side"]), 0.0)
		_hold("use_primary", float(act["crank"]) > 0.5)
	_hold("use_primary", false)


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await get_tree().process_frame
	await _wait(0.15)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var path := "%s%s_%02d_%s.png" % [out, part, _n, what]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)
