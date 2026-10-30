extends CanvasLayer
## First-time tips, on the radio: the first time each thing comes up (heading out, the first flock in the glasses,
## nearing birds too fast, the first bite, the first fight, the first fish alongside, on deck ...), Dale from the bank
## comes on the VHF (ui/radio.gd: the squelch, the hiss, his voice if it's been recorded) and says what to do in a
## line, once. Which you've seen is kept on this machine (SAVE), so each player gets them once, whoever's boat
## they're on; the field guide in the Esc menu (ui/menu.gd) has the lot, and can show them all again (reset()).
## docs/FEATURES.md is where these come from.

const Sfx := preload("res://audio/sfx.gd")
const SAVE := "user://bluefin_tips.cfg"
const Hud := preload("res://ui/hud.gd")
const Radio := preload("res://ui/radio.gd")
## Who's on the radio: Dale, the bank's loan officer. You're his investment, so he keeps an eye on you. Each tip is
## a line or two of what to do, said the way Dale would say it: the world shows the rest.
const CALLER := "VHF 16 \u00b7 Dale, the bank"
## Tip id -> what Dale says. (The alongside one depends on the boat: _alongside_text.)
const TIPS := {
	"out": "Dale, from the bank. Tuna feed under birds. Find a flock.",
	"flock": "Diving birds, white water? Bluefin. Go. Birds sitting? Wait for them.",
	"fast": "Easy! Under 10 knots near the birds, or they dive.",
	"bite": "That's a reel screaming. Grab the rod!",
	"fight": "Reel screaming? Hands off. Grinding? Pump: lift slow, wind as you drop. He jumps, drop the tip.",
	"alone": "Alone? Rod in the holder, Q. Steer, then grab it again.",
	"captain": "Captain: stern to the fish. S backs down. Under the boat? Hands off the throttle.",
	"lines": "Reel the other lines in before they tangle.",
	"deck": "Bleed it, ice it. Quick. A cold fish pays double.",
	"spiral": "Colour! Wind while he comes up, ease off while he goes under.",
	"stale": "That bait's washed out. Bait in hand, E on the rod, cast it again.",
	"cast": "Get some baits out. Pick up a rod, hold the click, let go.",
	"wait": "Slow? Chum off the transom brings them to you.",
}

var sea: Node                 # sea/sea.gd
var radio: Radio
var _talk := 0.0              # the transmit light's flicker
var _light: ColorRect
var _seen := {}
var _queue: Array[String] = []
var _card: PanelContainer
var _title: Label
var _body: Label
var _left := 0.0              # s the card has left up
var _in := 0.0
var _out_since := -1.0        # (sea clock) when she headed out this trip, for the waiting tip
var _had_fish := false
var _keep := true             # (false in tests and screenshots: nothing saved)
## How-to words under the crosshair ("Wire it, then harpoon it"): each is shown this many times (each time it comes
## up), then never again; you know it by then, and the world shows the rest. Warnings ("OUT OF GEAR!") always show.
const TEACH := 2
var _taught := {}             # text -> times it's come up
var _teaching := ""           # the one up now
var _teach_now := false       # and whether it's still being taught


func _ready() -> void:
	layer = 6
	_keep = sea.get_parent() == get_tree().root and not "--shot" in " ".join(OS.get_cmdline_user_args())
	if _keep:
		var cfg := ConfigFile.new()
		if cfg.load(SAVE) == OK:
			for k in cfg.get_section_keys("seen") if cfg.has_section("seen") else []:
				_seen[k] = true
			for k in cfg.get_section_keys("taught") if cfg.has_section("taught") else []:
				_taught[k] = int(cfg.get_value("taught", k))
	radio = Radio.new()
	radio.name = "Radio"
	add_child(radio)
	# the card: bottom left, out of the way of the sea ahead, growing up from the corner
	_card = PanelContainer.new()
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_left = 20.0
	_card.offset_right = 320.0
	_card.offset_bottom = -24.0
	_card.custom_minimum_size = Vector2(300, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.05, 0.06, 0.82)
	box.border_color = Color(1.0, 0.75, 0.3, 0.9)
	box.border_width_left = 4
	box.set_content_margin_all(14)
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_right = 4
	_card.add_theme_stylebox_override("panel", box)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	_light = ColorRect.new()
	_light.custom_minimum_size = Vector2(7, 7)
	_light.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_light)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", Hud.SMALL)
	_title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.36))
	head.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(272, 0)
	_body.add_theme_font_size_override("font_size", Hud.BODY)
	_body.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	col.add_child(_body)
	_card.modulate.a = 0.0
	add_child(_card)


## `text` (a how-to under the crosshair), or "" once it's been taught: TEACH times it's come up.
func teach(text: String) -> String:
	if text != _teaching:
		_teaching = text
		_teach_now = _count(text)
	return text if _teach_now else ""


## The same for words that come up once, as a moment (taking the wheel): `text`, or "" once taught.
func teach_once(text: String) -> String:
	return text if _count(text) else ""


## Whether `text` is still being taught, counting this time.
func _count(text: String) -> bool:
	if text.is_empty() or int(_taught.get(text, 0)) >= TEACH:
		return false
	_taught[text] = int(_taught.get(text, 0)) + 1
	if _keep:
		var cfg := ConfigFile.new()
		cfg.load(SAVE)
		cfg.set_value("taught", text, _taught[text])
		cfg.save(SAVE)
	return true


## Every tip shows again (the field guide's button).
func reset() -> void:
	_seen.clear()
	_taught.clear()
	if _keep:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


## Tip `id` now, unless it's been seen (or it's already waiting).
func show_tip(id: String) -> void:
	if _seen.has(id) or _queue.has(id) or not (TIPS.has(id) or id == "alongside"):
		return
	_seen[id] = true
	_queue.append(id)
	if _keep:
		var cfg := ConfigFile.new()
		cfg.load(SAVE)
		cfg.set_value("seen", id, true)
		cfg.save(SAVE)


func _process(delta: float) -> void:
	_in -= delta
	if _in <= 0.0:
		_in = 0.25
		_watch()
	# the card: one tip at a time, up long enough to read (a second for every three words), fading in and out
	if _left <= 0.0 and not _queue.is_empty():
		var id: String = _queue.pop_front()
		_title.text = CALLER
		_body.text = _alongside_text() if id == "alongside" else str(TIPS[id])
		_left = maxf(5.0, _body.text.split(" ").size() / 3.0)
		var line := id
		if id == "alongside" and bool(((sea.get("boat") as Node).get("spec") as Dictionary).get("wire", false)):
			line = "alongside_wire"
		_left = maxf(_left, radio.call_in("dale", line, _left))
	_left -= delta
	var want := 1.0 if _left > 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else 0.0
	_card.modulate.a = move_toward(_card.modulate.a, want, delta * 3.0)
	# the transmit light: lit while he's keyed up, flickering like a voice
	_talk -= delta
	if _talk <= 0.0:
		_talk = randf_range(0.05, 0.14)
		_light.color = Color(1.0, 0.3, 0.2, randf_range(0.55, 1.0) if _left > 0.4 else 0.15)


## What's going on, and whether it's the first time for any of it.
func _watch() -> void:
	var hold: Node = sea.get("fish_hold")
	if hold == null or bool(hold.get("docked")):
		_out_since = -1.0
		_had_fish = false
		return
	var now := float((sea.get("ocean") as Node).get("wave_time"))
	if _out_since < 0.0:
		_out_since = now
		show_tip("out")
	var me := Net.my_id()
	var boat := sea.get("boat") as Node
	var helm: Node = boat.get("helm")
	var speed := absf(float(helm.get("speed")))
	var rods := sea.get("rods") as Node
	var landing := sea.get("landing") as Node
	var schools := sea.get("schools") as Node
	var crew := sea.get("crew") as Node
	# the first flock picked out
	var spotter: Node = sea.get("spotter")
	if spotter != null and spotter.get("_looking") != null:
		show_tip("flock")
	# coming up on birds too fast
	if speed > 4.5:
		var at: Vector2 = helm.get("at")
		for s: Node in schools.get("schools"):
			if not bool(s.get("bait_only")) and (s.call("center", now) as Vector2).distance_to(at) < 350.0:
				show_tip("fast")
				break
	# a fish on
	var on := false
	var mine: Node = rods.call("held_by", me)
	for r: Node in rods.get("rods"):
		if bool(r.get("hooked")) and not bool(r.get("alongside")):
			on = true
			_had_fish = true
			if int(r.get("holder")) == 0 and mine == null:
				show_tip("bite")
	if on:
		if mine != null and bool(mine.get("hooked")):
			show_tip("fight")
			if str(mine.get("move")) == "spiral":
				show_tip("spiral")
			if (crew.get("slots") as Dictionary).size() <= 1:
				show_tip("alone")
		if int(helm.get("captain")) == me:
			show_tip("captain")
		for r: Node in rods.get("rods"):
			if not bool(r.get("hooked")) and not bool(r.get("bait_in")):
				show_tip("lines")
				break
	# alongside, on deck
	if not (landing.get("fish") as Dictionary).is_empty():
		show_tip("alongside")
	if not (hold.get("fish") as Array).is_empty():
		show_tip("deck")
	var out_n := 0
	for r: Node in rods.get("rods"):
		if not bool(r.get("hooked")) and not bool(r.get("bait_in")):
			out_n += 1
			if float(rods.call("freshness", int(r.get("index")))) < float(rods.get("STALE")):
				show_tip("stale")
	if out_n == 0 and not on and now - _out_since > 25.0:
		show_tip("cast")
	# a while out with nothing doing
	if not _had_fish and now - _out_since > 150.0:
		show_tip("wait")


func _alongside_text() -> String:
	var spec: Dictionary = (sea.get("boat") as Node).get("spec")
	if bool(spec.get("wire", false)):
		return "Wire it at the door, harpoon it off the port rack, haul. Ninety seconds."
	return "Harpoon off the port rack, then haul it in. Ninety seconds."
