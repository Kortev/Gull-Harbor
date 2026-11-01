extends Node
## Achievements (`Net.achievements`: a child of the Net autoload, so project.godot keeps the autoloads it has). LIST's
## few, each earned once, on the earning player's own machine (whoever's aboard when the fish comes over the rail,
## whoever threw, whoever won): unlock() records it in user://achievements.cfg and, with Steam running (core/
## steam_link.gd's `available`), sets it there too and stores the stats. What was earned with Steam off is handed to
## Steam the next time it's on (Steam ignores the ones it has). docs/steam_achievements.md is the list for Steamworks.
##
## A pixel toast comes in at the top right as one's earned (ui/pixfont.gd, its medal from ui/medals.gd), eases in,
## waits, eases out; several queue up one after another. The page of them all is ui/achievements_page.gd.
##
## Tests and screenshots (headless, or a scene under tests/) start with none and never read or write the player's
## file, and never touch Steam (`path` is "" and `steam` null there, unless a test sets them).

const PixFont := preload("res://ui/pixfont.gd")
const Medals := preload("res://ui/medals.gd")

const PATH := "user://achievements.cfg"
## [Steam API name, the name shown, what it's for]. The API names are what Steamworks is given; never rename one.
const LIST := [
	["FIRST_FISH", "First Bluefin", "Land your first bluefin tuna."],
	["GIANT", "Giant", "Land a bluefin of 300 kg or more."],
	["ONE_THROW", "One Throw", "Stick a bluefin with the harpoon on the first throw."],
	["GRADE_ONE", "Number One", "Sell a bluefin graded #1."],
	["TON", "A Ton Ashore", "Sell 1,000 kg of bluefin, all told."],
	["QUOTA", "Paid Up", "Make a quota for the bank."],
	["THREE_QUOTAS", "Keeping Her", "Make three quotas in one run."],
	["SPORTFISHER", "Bigger Boat", "Buy the sportfisher."],
	["LIVE_BAIT", "Live Bait", "Jig a mackerel into the live well."],
	["CREW", "Many Hands", "Land a bluefin with a friend aboard."],
	["NIGHT", "After Dark", "Land a bluefin after dusk."],
	["STORM", "Heavy Weather", "Land a bluefin in a storm."],
	["RIVALS_DAY", "Weighed In", "Win a day in Rivals."],
	["RIVALS_MATCH", "Best of Three", "Win a Rivals match."],
	["BOARDED", "Boarding Party", "Leap aboard the rival boat out at sea."],
	["OVERBOARD", "Man Overboard", "Shove a rival over the side."],
]
## A Ton Ashore: kilos sold in all (kept here, not a Steam stat).
const TON_KG := 1000.0
## Keeping Her: quotas made in one run.
const QUOTAS := 3
## GIANT: kilos.
const GIANT_KG := 300.0
## The toast: s easing in, s up, s easing out.
const IN := 0.35
const UP := 4.0
const OUT := 0.35
const CREAM := Color(1.0, 0.95, 0.82)
const AMBER := Color(1.0, 0.78, 0.34)
const DIM := Color(0.72, 0.76, 0.8)
const PANEL := Color(0.02, 0.04, 0.07, 0.92)

signal unlocked(api: String)

## Where they're kept ("": nowhere, in tests and screenshots, unless a test points it somewhere).
var path := PATH
## The Steam singleton while Steam's running (or a test's stand-in); null: kept here only.
var steam: Object
## API name -> when it was earned (unix s).
var got := {}
var kg_sold := 0.0
## API names waiting for their toast, and how far the one up is through it (s; -1: none up).
var queue: Array[String] = []
var _t := -1.0
var _layer: CanvasLayer
var _view: Control


func _ready() -> void:
	if _testing():
		path = ""
	else:
		load_file()
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.draw.connect(_draw_toast)
	_layer.add_child(_view)
	_link.call_deferred()


func _exit_tree() -> void:
	Medals.forget()


func _testing() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for a in OS.get_cmdline_args():
		if a.contains("tests/"):
			return true
	return false


## Steam's on (core/steam_link.gd started it): use it, and hand it whatever was earned with it off.
func _link() -> void:
	var link: Node = Net.steam
	if path.is_empty() or link == null or not bool(link.get("available")):
		return
	use_steam(link.get("steam"))


## Points achievements at Steam (or a stand-in) and hands it everything earned so far.
func use_steam(s: Object) -> void:
	steam = s
	if steam == null or got.is_empty():
		return
	for api: String in got:
		_steam_set(api)
	_steam_store()


static func known(api: String) -> bool:
	return LIST.any(func(a: Array) -> bool: return a[0] == api)


static func info(api: String) -> Array:
	for a: Array in LIST:
		if a[0] == api:
			return a
	return [api, api, ""]


func has(api: String) -> bool:
	return got.has(api)


## Kept a surprise till it's earned (its words and picture hidden on the page).
static func secret(api: String) -> bool:
	return Medals.SECRET.has(api)


## How far along a counted one is, [have, need]: A Ton Ashore's kilos; Keeping Her's quotas, the best run in
## `best_run` (the career's, boat/fish_hold.gd's; -1: not known). [] for the rest, and once it's earned.
func progress(api: String, best_run := -1) -> Array:
	if got.has(api):
		return []
	match api:
		"TON":
			return [minf(kg_sold, TON_KG), TON_KG]
		"THREE_QUOTAS":
			return [clampi(best_run, 0, QUOTAS), QUOTAS] if best_run >= 0 else []
	return []


## Earns `api` (once: false if it's had already, or isn't one of LIST's).
func unlock(api: String) -> bool:
	if got.has(api) or not known(api):
		return false
	got[api] = int(Time.get_unix_time_from_system())
	save_file()
	if steam != null:
		_steam_set(api)
		_steam_store()
	queue.append(api)
	unlocked.emit(api)
	return true


## Kilos sold (boat/fish_hold.gd, after a sale): A Ton Ashore once they come to TON_KG.
func add_sold(kg: float) -> void:
	if kg <= 0.0:
		return
	kg_sold += kg
	save_file()
	if kg_sold >= TON_KG:
		unlock("TON")


func _steam_set(api: String) -> void:
	if steam.has_method("setAchievement"):
		steam.call("setAchievement", api)


func _steam_store() -> void:
	if steam.has_method("storeStats"):
		steam.call("storeStats")


# --- the file ---

func save_file() -> Error:
	if path.is_empty():
		return ERR_UNAVAILABLE
	var c := ConfigFile.new()
	for api: String in got:
		c.set_value("unlocked", api, got[api])
	c.set_value("stats", "kg_sold", kg_sold)
	return c.save(path)


## Reads the file; missing or unreadable: none earned (an unreadable one is left as it is till the next save).
func load_file() -> Error:
	got = {}
	kg_sold = 0.0
	if path.is_empty():
		return ERR_UNAVAILABLE
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var c := ConfigFile.new()
	var err := c.load(path)
	if err != OK:
		push_warning("Achievements: %s won't read; starting from none" % path)
		return err
	if c.has_section("unlocked"):
		for api: String in c.get_section_keys("unlocked"):
			var when: Variant = c.get_value("unlocked", api, 0)
			if known(api):
				got[api] = int(when) if (when is int or when is float) else 0
	var kg: Variant = c.get_value("stats", "kg_sold", 0.0)
	kg_sold = maxf(float(kg), 0.0) if (kg is int or kg is float) else 0.0
	return OK


# --- the toast ---

func _process(delta: float) -> void:
	if _t < 0.0:
		if queue.is_empty():
			return
		_t = 0.0
	_t += delta
	if _t >= IN + UP + OUT:
		queue.pop_front()
		_t = -1.0
	_view.queue_redraw()


func _draw_toast() -> void:
	if _t < 0.0 or queue.is_empty():
		return
	var a := info(queue[0])
	var head := "ACHIEVEMENT"
	var title := str(a[1]).to_upper()
	var line := str(a[2]).to_upper()
	var s := 2 if _view.size.x < 1400.0 else 3          # (a font pixel's size: bigger on a big screen)
	var icon := 32 * (s - 1)                             # (the medal: its 32 grid at 1x, or 2x on a big screen)
	var w := maxi(PixFont.width(title, s * 2), maxi(PixFont.width(line, s), PixFont.width(head, s))) + icon + s * 14
	var h := maxi(s * 30, icon + s * 8)
	# eased in from off the right edge, and back out (continuous, a whole pixel at a time)
	var k := 1.0
	if _t < IN:
		k = _t / IN
	elif _t > IN + UP:
		k = 1.0 - (_t - IN - UP) / OUT
	k = clampf(k, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var x := floorf(_view.size.x - (w + s * 8) * k)
	var y := float(s * 8)
	var r := Rect2(x, y, w, h)
	_view.draw_rect(r, PANEL)
	_view.draw_rect(Rect2(x, y, w, s), AMBER)
	_view.draw_rect(Rect2(x, y + h - s, w, s), AMBER)
	_view.draw_rect(Rect2(x, y, s, h), AMBER)
	_view.draw_rect(Rect2(x + w - s, y, s, h), AMBER)
	# the medal
	var mx := x + s * 4
	var my := floorf(y + (h - icon) * 0.5)
	_view.draw_texture_rect(Medals.texture(queue[0]), Rect2(mx, my, icon, icon), false)
	var tx := mx + icon + s * 5
	var ty := floorf(y + (h - s * 26) * 0.5)
	PixFont.draw(_view, Vector2(tx, ty + s), head, DIM, s)
	PixFont.draw(_view, Vector2(tx, ty + s * 8), title, CREAM, s * 2)
	PixFont.draw(_view, Vector2(tx, ty + s * 20), line, DIM, s)
