extends Node
## The achievements (core/achievements.gd) and the files the game keeps: a test starts with none and never touches
## the player's file or Steam; a fish over the rail is First Bluefin (a 320 kg one, Giant too), a mackerel jigged is
## Live Bait, a #1 sold is Number One and the kilos add up to A Ton Ashore, a Rivals day and match won; each is handed
## to Steam (a stand-in here) and stored, once; the file reads back. A broken or nonsense achievements, settings or
## career file is the defaults, no crash. And docs/steam_achievements.md lists every one for Steamworks. The page
## (ui/achievements_page.gd), from the title and from the harbour board: it opens, counts what's earned, greys what
## isn't (a secret one a "?"), shows how far along a counted one is, and the keys, the pad and the mouse close it.
## Run: godot --headless --fixed-fps 30 --path . res://tests/achievements_test.tscn

const Sea := preload("res://sea/sea.gd")
const Achievements := preload("res://core/achievements.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const Page := preload("res://ui/achievements_page.gd")
const Medals := preload("res://ui/medals.gd")
const Title := preload("res://ui/title.gd")
const FILE := "user://achievements_test.cfg"
const SETTINGS := "user://settings_broken_test.cfg"
const CAREER := "user://career_broken_test.cfg"

var fails: Array[String] = []
var sea: Sea


## A stand-in for Steam's achievements: what it was asked.
class FakeSteam extends Object:
	var asked: Array[String] = []
	var stored := 0

	func setAchievement(api: String) -> bool:
		asked.append(api)
		return true

	func storeStats() -> bool:
		stored += 1
		return true


func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	var a := Net.achievements
	_check(a.path.is_empty() and a.steam == null and a.got.is_empty(),
			"a test starts with none, never reads the player's file, never touches Steam")
	for f: String in [FILE, SETTINGS, CAREER]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	a.path = FILE
	var fake := FakeSteam.new()
	a.use_steam(fake)
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await _frames(10)
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	_check(a.got.is_empty(), "nothing earned just for starting")
	# a fish over the rail
	hold.head_out("skiff")
	await _frames(2)
	hold.host_add(320.0, 100.0)
	await _frames(2)
	_check(a.has("FIRST_FISH") and a.has("GIANT"), "a 320 kg fish aboard: First Bluefin and Giant")
	_check(not a.has("CREW") and not a.has("NIGHT"), "alone, in the day: not Many Hands, not After Dark")
	_check(fake.asked.has("FIRST_FISH") and fake.asked.has("GIANT") and fake.stored >= 2,
			"handed to Steam and stored (%s, stored %d times)" % [fake.asked, fake.stored])
	_check(a.queue.size() >= 1 and a.queue[0] == "FIRST_FISH", "its toast is up")
	_check(not a.unlock("FIRST_FISH") and not a.unlock("NOT_ONE"), "each once; nothing that isn't one")
	var n := fake.asked.size()
	hold.host_add(80.0, 30.0)
	await _frames(2)
	_check(fake.asked.size() == n, "a second fish earns nothing again")
	# a mackerel jigged
	(sea.jig as Node).call("_caught", Net.my_id(), true)
	_check(a.has("LIVE_BAIT"), "a mackerel into the well: Live Bait")
	# bled and iced quick, sold: a #1, and the kilos toward a ton
	for f: Dictionary in hold.fish:
		hold._work(int(f["id"]))
		hold._work(int(f["id"]))
	a.kg_sold = 700.0
	hold.head_in()
	await _frames(2)
	var grades: Array = (hold.sale["lines"] as Array).map(func(l: Array) -> String: return str(l[1]))
	_check(grades.has("#1") and a.has("GRADE_ONE"), "a #1 sold (%s): Number One" % [grades])
	_check(is_equal_approx(a.kg_sold, 1100.0) and a.has("TON"), "1,100 kg sold in all: A Ton Ashore")
	_check(not a.has("QUOTA"), "no quota made on the first day")
	# Rivals: a day and the match
	sea.vs.host_set_on(true)
	await _frames(3)
	sea.vs._result([300.0, 120.0], [[], []], [2, 0])
	await _frames(2)
	_check(a.has("RIVALS_DAY") and a.has("RIVALS_MATCH"), "boat A's day and match: Weighed In and Best of Three")
	sea.vs.host_set_on(false)
	await _frames(3)
	await _page()
	# the file
	var had := a.got.duplicate()
	a.got = {}
	_check(a.load_file() == OK and a.got.keys().size() == had.keys().size() and is_equal_approx(a.kg_sold, 1100.0),
			"the file reads back: %d earned, %d kg sold" % [a.got.size(), roundi(a.kg_sold)])
	# broken files: the defaults, no crash
	_write(FILE, "this isn't [a config file\n" + String.chr(1) + String.chr(2))
	a.load_file()
	_check(a.got.is_empty() and a.kg_sold == 0.0, "a broken achievements file: none, no crash")
	_write(FILE, "[unlocked]\nFIRST_FISH=[1, 2]\nNOT_ONE=5\n[stats]\nkg_sold=\"lots\"\n")
	_check(a.load_file() == OK and a.got.has("FIRST_FISH") and not a.got.has("NOT_ONE") and a.kg_sold == 0.0,
			"nonsense in it: what makes sense is kept")
	var sens := Settings.sensitivity
	Settings.path = SETTINGS
	_write(SETTINGS, String.chr(7) + "[[ not = = settings")
	_check(Settings.load_file() != OK and Settings.sensitivity == sens, "a broken settings file: the defaults")
	_write(SETTINGS, "[look]\nsensitivity=[1, 2]\nfov=\"wide\"\n[display]\nwindow_size=Vector2i(3, 3)\nmax_fps=-5\n"
			+ "window=\"huge\"\n[keys]\njump=5\nshove=[\"key:70\", 3]\n")
	_check(Settings.load_file() == OK and Settings.sensitivity == sens and Settings.window == "windowed"
			and Settings.window_size.x >= 640 and Settings.max_fps == 0
			and not InputMap.action_get_events("jump").is_empty(), "nonsense in it: sane values, the keys still there")
	Settings.path = ""
	hold.save_path = CAREER
	_write(CAREER, String.chr(7) + "[[ garbage = = =")
	hold._load()
	_check(hold.bank == FishHold.START_CASH and hold.owned == ["skiff"], "a broken career file: a fresh start")
	_write(CAREER, "[career]\nversion=1\n[trips]\nbank=[5]\nkind=\"skiff\"\nowned=[\"skiff\", 7]\n[run]\nday=\"x\"\n"
			+ "at_sea=[1]\n")
	hold._load()
	_check(hold.bank == FishHold.START_CASH and hold.day == 1 and hold.owned == ["skiff"],
			"nonsense in it: the defaults where it doesn't make sense")
	hold.save_path = ""
	# the list for Steamworks
	var doc := FileAccess.get_file_as_string("res://docs/steam_achievements.md")
	var missing: Array = Achievements.LIST.filter(func(e: Array) -> bool:
		return not (doc.contains("`%s`" % e[0]) and doc.contains(str(e[1])) and doc.contains(str(e[2]))))
	_check(missing.is_empty(), "docs/steam_achievements.md lists all %d (missing: %s)" % [Achievements.LIST.size(),
			missing.map(func(e: Array) -> String: return e[0])])
	fake.free()
	a.steam = null
	a.path = ""
	for f: String in [FILE, SETTINGS, CAREER]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	_done()


## The page: from the title and the board, what it says, and every way it shuts.
func _page() -> void:
	var a := Net.achievements
	var n := Achievements.LIST.size()
	var title := Title.new()
	title.sea = sea
	sea.add_child(title)
	await _frames(2)
	var item := -1
	var items: Array = title.get("_items")
	for i in items.size():
		if str(items[i][0]) == "ACHIEVEMENTS":
			item = i
	_check(item >= 0 and str(items[item][1]) == "%d OF %d EARNED." % [a.got.size(), n],
			"the title has ACHIEVEMENTS, saying how many are earned")
	title.set("_pick", item)
	title.call("_press")
	var page: Page = title.achievements
	await _frames(2)
	_check(page.visible and not (title.get("_view") as Control).visible and page.has_focus(),
			"pressed: the page is up over the title, the keys its")
	_check(Page.header() == "%d / %d" % [a.got.size(), n] and a.got.size() == 7, "it counts: %s" % Page.header())
	var rects: Array = page.get("_rects")
	_check(rects.size() == n + 1, "all %d drawn, and BACK (%d)" % [n, rects.size()])
	# earned and locked: the words, the date, the medal
	var w := Page.words("FIRST_FISH")
	var year := str(Time.get_date_dict_from_system()["year"])
	_check(w[0] == "FIRST BLUEFIN" and not str(w[2]).is_empty() and str(w[2]).ends_with(year),
			"earned: its name and the day (%s)" % [w])
	w = Page.words("ONE_THROW")
	_check(w[0] == "ONE THROW" and str(w[1]).begins_with("STICK") and str(w[2]).is_empty(),
			"locked: its name and what it's for, no day")
	w = Page.words("NIGHT")
	_check(w[0] == "???" and not str(w[1]).contains("DUSK"), "a secret one locked: ??? (%s)" % [w])
	_check(_grey(Medals.image("ONE_THROW", true)) and not _grey(Medals.image("FIRST_FISH")),
			"a locked medal's grey, an earned one's in colour")
	_check(Medals.image("NIGHT", true).get_data() != Medals.image("NIGHT").get_data()
			and Medals.image("NIGHT", true).get_data() == Medals.image("STORM", true).get_data(),
			"a secret one's locked medal gives nothing away")
	_check(Medals.texture("GIANT").get_size() == Vector2(32, 32), "a medal's 32 x 32")
	_check(Medals.KIND.keys() == Achievements.LIST.map(func(e: Array) -> String: return e[0]),
			"a medal for every one, in the list's order (tools/make_medals.gd writes them out by it)")
	# counted ones: how far along
	var kept := a.got.duplicate()
	var kg := a.kg_sold
	a.got.erase("TON")
	a.kg_sold = 640.0
	_check(a.progress("TON") == [640.0, Achievements.TON_KG], "A Ton Ashore not yet: 640 of 1000 kg")
	sea.fish_hold.best_run = 1
	_check(a.progress("THREE_QUOTAS", Page.run_of(sea.fish_hold)) == [1, 3], "Keeping Her: 1 of 3 quotas in a run")
	_check(a.progress("FIRST_FISH").is_empty(), "nothing counted for the rest")
	page.queue_redraw()
	await _frames(2)
	a.got = kept
	a.kg_sold = kg
	sea.fish_hold.best_run = 0
	_check(a.progress("TON").is_empty(), "earned: no count")
	# the keys: down the left column onto BACK, Enter shuts it
	for i in n / 2:
		page.call("_on_input", _key(KEY_DOWN))
	_check(page.pick == n, "down the column: BACK")
	page.call("_on_input", _key(KEY_UP))
	page.call("_on_input", _key(KEY_RIGHT))
	_check(page.pick == n - 1, "up and across: the right column's last (%d)" % page.pick)
	page.call("_on_input", _key(KEY_DOWN))
	page.call("_on_input", _key(KEY_ENTER))
	await _frames(1)
	_check(not page.visible and (title.get("_view") as Control).visible, "BACK: shut, the title back")
	# the pad's B, and a click on BACK
	title.call("open_achievements")
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	page.call("_on_input", b)
	_check(not page.visible, "the pad's B shuts it")
	title.call("open_achievements")
	await _frames(2)
	rects = page.get("_rects")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (rects[n] as Rect2).get_center()
	page.call("_on_input", click)
	_check(not page.visible, "a click on BACK shuts it")
	title.call("open_achievements")
	page.call("_on_input", _key(KEY_ESCAPE))
	_check(not page.visible, "Esc shuts it")
	title.queue_free()
	await _frames(1)
	# from the harbour board
	var menu: Node = sea.get_children().filter(func(c: Node) -> bool:
		return c.get_script() == load("res://ui/menu.gd"))[0]
	sea.fish_hold.docked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(3)
	var board := menu.get("_board") as Control
	_check(board.visible and _find(board, "ACHIEVEMENTS") != null, "the board has ACHIEVEMENTS")
	(_find(board, "ACHIEVEMENTS") as Button).pressed.emit()
	await _frames(2)
	var mp: Page = menu.get("_medals")
	_check(mp.visible and not board.visible, "pressed: the page in the board's place")
	mp.call("_on_input", _key(KEY_ESCAPE))
	await _frames(2)
	_check(not mp.visible and board.visible, "shut: the board back")
	_check(_find(menu.get("_pause") as Node, "ACHIEVEMENTS") != null, "the pause card has it too")


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	return k


func _find(n: Node, text: String) -> Button:
	for c in n.get_children():
		if c is Button and (c as Button).text == text:
			return c
		var b := _find(c, text)
		if b != null:
			return b
	return null


## Every pixel of it grey (or see-through).
func _grey(img: Image) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and maxf(absf(c.r - c.g), absf(c.b - c.g)) > 0.15:
				return false
	return true


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("ACHIEVEMENTS TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
