extends Node
## The achievements (core/achievements.gd) and the files the game keeps: a test starts with none and never touches
## the player's file or Steam; a fish over the rail is First Bluefin (a 320 kg one, Giant too), a mackerel jigged is
## Live Bait, a #1 sold is Number One and the kilos add up to A Ton Ashore, a Rivals day and match won; each is handed
## to Steam (a stand-in here) and stored, once; the file reads back. A broken or nonsense achievements, settings or
## career file is the defaults, no crash. And docs/steam_achievements.md lists every one for Steamworks.
## Run: godot --headless --fixed-fps 30 --path . res://tests/achievements_test.tscn

const Sea := preload("res://sea/sea.gd")
const Achievements := preload("res://core/achievements.gd")
const FishHold := preload("res://boat/fish_hold.gd")
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
