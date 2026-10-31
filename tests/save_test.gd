extends Node
## The career kept between games (boat/fish_hold.gd): money earned and gear bought are saved and back in a fresh sea;
## Rivals plays from an even start and never touches it; NEW CAREER wipes it; a damaged or newer file starts fresh.
## A test file only: the sea's own save_path is "" in tests (never the player's user://career.cfg).
## Run: godot --headless --fixed-fps 30 --path . res://tests/save_test.tscn

const Sea := preload("res://sea/sea.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const FILE := "user://career_test.cfg"

var fails: Array[String] = []


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	var real_before := _stamp(FishHold.SAVE)
	# a career: earn, buy, save
	var sea := await _sea()
	var hold := sea.fish_hold
	_check(hold.save_path == "", "a test's sea never points at the player's career")
	hold.save_path = FILE
	hold.head_out("skiff")
	hold.host_add(220.0, 40.0)
	hold.host_add(180.0, 40.0)
	hold.head_in()
	var bank := hold.bank
	_check(bank > FishHold.START_CASH + 3000, "a good day sold (bank $%d)" % bank)
	_check(hold.buy("reel"), "bought the two-speed reel")
	bank = hold.bank
	var earned := hold.earned
	var best := hold.best
	_check(FileAccess.file_exists(FILE), "saved after the sale and the purchase")
	var cfg := ConfigFile.new()
	_check(cfg.load(FILE) == OK and int(cfg.get_value("career", "version", 0)) == FishHold.VERSION,
			"the file has its version")
	sea.queue_free()
	await get_tree().process_frame
	# a fresh sea: it's all back
	sea = await _sea()
	hold = sea.fish_hold
	_check(hold.bank == FishHold.START_CASH and hold.gear.is_empty(), "a fresh sea starts fresh before it's loaded")
	hold.save_path = FILE
	hold._load()
	_check(hold.bank == bank and hold.gear.has("reel") and hold.earned == earned and hold.day == 2
			and hold.best == best, "loaded: bank $%d, the reel, $%d toward the quota, day %d" % [hold.bank,
			hold.earned, hold.day])
	# Rivals: an even start, and the career untouched
	var text := FileAccess.get_file_as_string(FILE)
	var vs := sea.vs
	vs.host_set_on(true)
	await get_tree().process_frame
	var b_hold: Node = vs.sides[1].get("fish_hold")
	_check(hold.bank == FishHold.START_CASH and hold.gear.is_empty() and not hold.has_gear("reel"),
			"Rivals: boat A starts even (no bank, no reel)")
	_check(int(b_hold.get("bank")) == FishHold.START_CASH and (b_hold.get("gear") as Array).is_empty(),
			"Rivals: boat B the same")
	hold.head_out("skiff")
	await get_tree().process_frame
	hold.host_add(150.0, 40.0)
	(b_hold as FishHold).host_add(120.0, 40.0)
	vs.host_bring_home()
	await get_tree().create_timer(0.5).timeout
	_check(FileAccess.get_file_as_string(FILE) == text, "a Rivals day sold doesn't touch the career file")
	vs.host_set_on(false)
	await get_tree().process_frame
	_check(not vs.on and hold.bank == bank and hold.gear.has("reel") and hold.earned == earned,
			"back from Rivals: the career's back (bank $%d)" % hold.bank)
	_check(FileAccess.get_file_as_string(FILE) == text, "and still untouched")
	# NEW CAREER
	hold.new_career()
	_check(hold.bank == FishHold.START_CASH and hold.gear.is_empty() and hold.best == 0 and hold.day == 1,
			"NEW CAREER: the skiff and $%d" % FishHold.START_CASH)
	hold.bank = 1
	hold._load()
	_check(hold.bank == FishHold.START_CASH and hold.gear.is_empty(), "and the wiped career is what's saved")
	# a damaged file, a newer one: fresh
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string("[trips]\nbank = 9999999\nowned = ][ not a list \"unclosed")
	f.close()
	hold.bank = 1
	hold._load()
	_check(hold.bank == FishHold.START_CASH and hold.quota_n == 1 and hold.owned == ["skiff"],
			"a damaged file starts fresh")
	cfg = ConfigFile.new()
	cfg.set_value("career", "version", FishHold.VERSION + 1)
	cfg.set_value("trips", "bank", 9999999)
	cfg.save(FILE)
	hold._load()
	_check(hold.bank == FishHold.START_CASH, "a file from a newer game starts fresh")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	hold._load()
	_check(hold.bank == FishHold.START_CASH and hold.day == 1, "no file starts fresh")
	hold.save_path = ""
	_check(_stamp(FishHold.SAVE) == real_before, "the player's own career file never touched")
	_done()


func _sea() -> Sea:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	return sea


## A file's modified time and size (0 none): to see it wasn't written.
func _stamp(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return [0, 0]
	return [FileAccess.get_modified_time(path), FileAccess.get_file_as_bytes(path).size()]


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("SAVE TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
