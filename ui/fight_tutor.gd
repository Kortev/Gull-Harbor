extends Control
## The first fish you ever land, taught a step at a time as you do each (rods.gd makes it beside the fight HUD and ticks
## it every frame): it comes up alongside, and a card says the one thing to do next (rod back, wire, harpoon, rope,
## haul), the button drawn; the fish's hook clock stands still meanwhile (tuna/landing.gd's hold_clock), but the sea
## doesn't, so there's no NEXT between those steps, only after the last (SPACE or a click).
##
## The fight itself is never held still behind a card: it's taught in the moment, by Dale on the VHF and the crew
## shouting (rods/fight_calls.gd, ui/tips.gd), while the fish keeps fighting.
##
## Which you've been taught is kept on this machine (SAVE), like ui/tips.gd's radio tips, and the field guide's "show
## them all again" wipes it too. Off in the tests and screenshots (`enabled`) unless asked for (--tutor).

const Fight := preload("res://tuna/fight.gd")
const Sfx := preload("res://audio/sfx.gd")
const Pad := preload("res://core/pad.gd")
const SAVE := "user://bluefin_tutor.cfg"
const GREEN := Color(0.45, 0.95, 0.55)
const AMBER := Color(1.0, 0.75, 0.3)
const RED := Color(1.0, 0.3, 0.25)
const PALE := Color(0.95, 0.93, 0.86)
const DIM := Color(0.62, 0.66, 0.68)
const INK := Color(0.02, 0.03, 0.05, 0.86)
const U := 3.0                        # px a pixel of the drawn mouse and keys
## (The fight's lessons: none any more. Kept so a save from before reads.)
const ORDER: Array[String] = []

var rods: Node                # rods/rods.gd
var sea: Node                 # sea/sea.gd
## Whether it teaches at all (real play; a test or --tutor turns it on), and whether what's taught is saved.
var enabled := false
var keep := false
var _taught := {}
var _id := ""                 # the lesson up: "land", or ""
var _step := 0
var _phase := ""              # "do" (waiting for you), "why" (waiting for you to read it)
var _held := 0.0              # s the asked-for thing's been done
var _phase_t := 0.0
var _good := 0.0              # a step just done: GOOD! for a moment
var _a := 0.0
var _t := 0.0
var _land_i := -1             # the fish alongside being landed
var _land_do: Array = []      # [what to do, the picture] now
var _deck_n := 0              # fish on deck when it came up (one more: aboard)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var args := " ".join(OS.get_cmdline_user_args())
	# (the other boat's things in VS see a side of the sea, vs/side.gd: the real one's behind it)
	var real: Node = sea.get("sea") if sea.get("sea") is Node else sea
	keep = real.get_parent() == get_tree().root and not "--shot" in args
	enabled = keep or "--tutor" in args
	_load()


func _load() -> void:
	_taught.clear()
	if not keep:
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK and cfg.has_section("taught"):
		for k in cfg.get_section_keys("taught"):
			_taught[k] = true


## Whether lesson `id` has been taught on this machine.
func taught(id: String) -> bool:
	return _taught.has(id)


## Whether a lesson's up right now.
func busy() -> bool:
	return _id != ""


## (Nothing on the fight HUD glows for a lesson any more.)
func highlight() -> bool:
	return false


## Whether Dale's radio tip `tip` (ui/tips.gd) would only say again what this has shown or is showing.
func covers(tip: String) -> bool:
	if not enabled:
		return false
	var lesson := {"alongside": "land"}.get(tip, "") as String
	return not lesson.is_empty() and (busy() or taught(lesson))


## Every frame, from rods.gd: `mine` is the rod in your hands (or null).
func tick(delta: float, _mine: Node) -> void:
	_t += delta
	_a = move_toward(_a, 1.0 if _id != "" else 0.0, delta * 5.0)
	_good = maxf(_good - delta, 0.0)
	queue_redraw()
	# (not on the other boat's rods in VS: you aren't aboard her, and her HUD's a hidden one)
	if not enabled or (sea.get("crew") as Node).get("me") == null:
		if _id != "":
			_drop()
		return
	if _id == "land" or (_id == "" and not taught("land")):
		_land(delta)


func _input(event: InputEvent) -> void:
	if _phase != "why" or _phase_t < 0.6 or not is_visible_in_tree():
		return
	var key := event as InputEventKey if event is InputEventKey else Pad.as_key(event)      # (the pad's A: Enter)
	var mb := event as InputEventMouseButton
	var next := (key != null and key.pressed and not key.echo
			and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) \
			or (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT)
	if next:
		get_viewport().set_input_as_handled()
		_finish()


## Read and understood: taught, saved, and the card goes.
func _finish() -> void:
	_taught[_id] = true
	if keep:
		var cfg := ConfigFile.new()
		cfg.load(SAVE)
		cfg.set_value("taught", _id, true)
		cfg.save(SAVE)
	Sfx.play("ui.confirm", 0.6)
	if _id == "land":
		_unhold()
	_drop()


func _drop() -> void:
	if _id == "land":
		_unhold()
	_id = ""
	_phase = ""


# ------------------------------------------------------------------ the landing

## The first fish alongside: what to do next, from where things are (who's got the rod, the harpoon, whether it's
## wired, stuck), each step shown as it comes; aboard, why it matters, and NEXT.
func _land(delta: float) -> void:
	var landing := sea.get("landing") as Node
	var hold := sea.get("fish_hold") as Node
	if landing == null or hold == null:
		return
	var fish: Dictionary = landing.get("fish")
	if _id == "":
		if fish.is_empty():
			return
		_land_i = int(fish.keys()[0])
		_id = "land"
		_phase = "do"
		_phase_t = 0.0
		_land_do = []
		_deck_n = (hold.get("fish") as Array).size()
		landing.call("hold_clock", _land_i, true)
		Sfx.play("ui.page", 0.6)
	_phase_t += delta
	if _phase == "why":
		return
	if not fish.has(_land_i):
		if (hold.get("fish") as Array).size() > _deck_n:
			_phase = "why"
			_phase_t = 0.0
			_good = 0.7
			Sfx.play("ui.check", 0.7)
		else:
			_drop()        # (gone: the lesson waits for the next one)
		return
	var now := _land_step(landing, fish[_land_i])
	if not _land_do.is_empty() and now[0] != _land_do[0]:
		_good = 0.7
		Sfx.play("ui.check", 0.5)
	_land_do = now


func _land_step(landing: Node, f: Dictionary) -> Array:
	var me := Net.my_id()
	var i := _land_i
	var mine: Node = rods.call("held_by", me)
	var crew_n := int(landing.call("_crew_aboard"))
	var helm: Node = (sea.get("boat") as Node).get("helm")
	var spec: Dictionary = landing.get("spec")
	var harpoon := int(landing.get("harpoon_holder"))
	if bool(f["stuck"]):
		if harpoon == me:
			return ["Q: PUT THE HARPOON BACK", "key:Q"]
		var at := "TUNA DOOR" if bool(spec.get("door", false)) else "GUNWALE"
		if not bool(f.get("roped", false)):
			return ["E AT THE %s AS HIS TAIL SWINGS IN: ROPE IT" % at, "key:E"]
		return ["HOLD E AT THE %s: HAUL HIM ABOARD" % at, "key:E"]
	if mine != null and int(mine.get("index")) == i and crew_n > 1:
		return ["KEEP THE ROD: HOLD HIM UP FOR YOUR MATE TO HARPOON", "none"]
	if mine != null:
		return ["Q: PUT THE ROD IN A HOLDER", "key:Q"]
	if int(helm.get("captain")) == me and crew_n <= 1:
		return ["E: LET GO OF THE WHEEL", "key:E"]
	if harpoon == me:
		if bool(landing.call("needs_wire", i)):
			return ["WIRE HIM FIRST: E AT THE TRANSOM", "key:E"]
		if bool(landing.call("down", i)):
			return ["HE'S GONE DOWN. WAIT, HE COMES BACK UP", "none"]
		return ["HOLD LEFT MOUSE: WIND UP. LET GO: THROW. LEAD HIM", "left"]
	if bool(landing.call("needs_wire", i)):
		return ["E AT THE TRANSOM: GRAB THE LEADER (WIRE HIM)", "key:E"]
	if harpoon != 0:
		return ["YOUR MATE'S GOT THE HARPOON", "none"]
	return ["GRAB THE HARPOON: E ON THE RACK, PORT SIDE", "key:E"]


func _unhold() -> void:
	var landing := sea.get("landing") as Node
	if landing != null and _land_i >= 0:
		landing.call("hold_clock", _land_i, false)
	_land_i = -1


# ------------------------------------------------------------------ drawn

func _draw() -> void:
	if _a <= 0.01 or _id == "":
		return
	var font := get_theme_default_font()
	var a := _a
	var head := ""
	var tag := ""
	var doing: Array = []
	var why := ""
	var steps := 1
	head = "HE'S ALONGSIDE! LAND HIM" if _phase == "do" else "HE'S ABOARD!"
	tag = "FIRST FISH: HE'LL HOLD ON THE HOOK TILL YOU'RE DONE"
	doing = _land_do
	why = "SPIKE HIM, BLEED HIM, ICE HIM. QUICK.\nA CLEAN, COLD FISH PAYS DOUBLE."
	# the card's lines, and how wide the widest is
	var lines := [[tag, 12, DIM], [head, 24, AMBER]]
	var w := 0.0
	var why_lines := why.split("\n") if _phase == "why" else PackedStringArray()
	for s: String in why_lines:
		w = maxf(w, font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x)
	for ln: Array in lines:
		w = maxf(w, font.get_string_size(str(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(ln[1])).x)
	var icon_w := 22.0 * U
	if _phase == "do" and not doing.is_empty():
		w = maxf(w, icon_w + font.get_string_size(str(doing[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x)
	w = roundf(w + 48.0)
	var h := 30.0 + 42.0 + (24.0 * U if _phase == "do" else 24.0 + why_lines.size() * 30.0 + 30.0) + 18.0
	var at := Vector2(roundf((size.x - w) * 0.5), roundf(size.y * 0.2))
	draw_rect(Rect2(at, Vector2(w, h)), Color(INK, INK.a * a))
	draw_rect(Rect2(at, Vector2(w, 6)), Color(AMBER, 0.9 * a))
	var y := at.y + 30.0
	_line(font, at.x + 24.0, y, tag, 12, Color(DIM, a))
	y += 36.0
	_line(font, at.x + 24.0, y, head, 24, Color(AMBER, a))
	y += 18.0
	if _phase == "do" and not doing.is_empty():
		# the picture, and what to do beside it
		var pulse := 0.7 + 0.3 * sin(_t * 7.0)
		_draw_icon(Vector2(at.x + 24.0, y + 2.0 * U), str(doing[1]), a, pulse)
		var col := GREEN if _good > 0.0 else PALE
		_line(font, at.x + 24.0 + icon_w, y + 12.0 * U, str(doing[0]), 18, Color(col, a))
		if steps > 1:
			_line(font, at.x + 24.0 + icon_w, y + 12.0 * U + 30.0, "STEP %d OF %d" % [_step + 1, steps], 12,
					Color(DIM, a))
		if _good > 0.0:
			_line(font, at.x + w - 24.0 - font.get_string_size("GOOD!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x,
					at.y + 66.0, "GOOD!", 18, Color(GREEN, a))
	elif _phase == "why":
		y += 24.0
		_line(font, at.x + 24.0, y, "GOOD!", 18, Color(GREEN, a))
		for s: String in why_lines:
			y += 30.0
			_line(font, at.x + 24.0, y, s, 18, Color(PALE, a))
		y += 36.0
		var ready := _phase_t >= 0.6
		var blink := 1.0 if fmod(_t, 1.0) < 0.6 else 0.45
		var next := Settings.say("SPACE OR CLICK: GO ON")
		var nw := font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_line(font, at.x + w - 24.0 - nw, y, next, 12, Color(AMBER, (blink if ready else 0.25) * a))


func _line(font: Font, x: float, y: float, text: String, px: int, col: Color) -> void:
	draw_string(font, Vector2(roundf(x), roundf(y)), Settings.say(text), HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


## The button to use, drawn in whole pixels: a mouse with the button that matters lit (and which way to move it), or
## a key. With the pad in your hands, its button on a key cap (the left mouse its RT, the right its LT).
func _draw_icon(at: Vector2, kind: String, a: float, pulse: float) -> void:
	var o := at.floor()
	var line := Color(PALE, 0.8 * a)
	var lit := Color(GREEN, pulse * a)
	if Settings.pad and kind != "none":
		kind = "key:" + {"left": "RT", "left_down": "RT", "right": "LT", "wheel_down": "LB"}.get(kind,
				Pad.cap(kind.substr(4), true) if kind.begins_with("key:") else kind)
	if kind.begins_with("key:"):
		_px(o, Vector2(0, 2), Vector2(11, 11), Color(INK, a))
		_box(o + Vector2(0, 2) * U, Vector2(11, 11), line)
		_px(o, Vector2(1, 12), Vector2(10, 1), Color(PALE, 0.4 * a))
		var font := get_theme_default_font()
		draw_string(font, o + Vector2(4, 10) * U, kind.substr(4), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, lit)
		return
	# the mouse: a body 10 x 14, its two buttons over the top, the wheel between
	_box(o, Vector2(10, 16), line)
	_px(o, Vector2(5, 1), Vector2(0.34, 6), line)
	_px(o, Vector2(1, 6), Vector2(8, 0.34), line)
	var left := [Vector2(1, 1), Vector2(4, 5)]
	var right := [Vector2(5.34, 1), Vector2(3.66, 5)]
	match kind:
		"left", "left_down":
			_px(o, left[0], left[1], lit)
		"right":
			_px(o, right[0], right[1], lit)
		"wheel_down":
			_px(o, Vector2(4.34, 1.5), Vector2(1.34, 3), lit)
		"none":
			# hands off: both buttons crossed out
			for k in 9:
				_px(o, Vector2(0.5 + k, 0.5 + k * 0.6), Vector2(1, 1), Color(AMBER, pulse * a))
				_px(o, Vector2(8.5 - k, 0.5 + k * 0.6), Vector2(1, 1), Color(AMBER, pulse * a))
	# which way: the rod up (lift), the mouse or the wheel down
	if kind == "right":
		_arrow(o + Vector2(13, 1) * U, -1.0, Color(AMBER, pulse * a))
	elif kind in ["left_down", "down", "wheel_down"]:
		_arrow(o + Vector2(13, 1) * U, 1.0, Color(AMBER, pulse * a))


## A rectangle in mouse pixels from `o`.
func _px(o: Vector2, p: Vector2, s: Vector2, col: Color) -> void:
	draw_rect(Rect2((o + p * U).round(), (s * U).round().max(Vector2.ONE)), col)


## A one-pixel outline, `s` mouse pixels.
func _box(o: Vector2, s: Vector2, col: Color) -> void:
	_px(o, Vector2(0, 0), Vector2(s.x, 1), col)
	_px(o, Vector2(0, s.y - 1), Vector2(s.x, 1), col)
	_px(o, Vector2(0, 0), Vector2(1, s.y), col)
	_px(o, Vector2(s.x - 1, 0), Vector2(1, s.y), col)


## An arrow 5 wide and 12 tall, pointing down (`way` 1) or up (-1).
func _arrow(o: Vector2, way: float, col: Color) -> void:
	_px(o, Vector2(2, 0 if way > 0.0 else 3), Vector2(1, 9), col)
	for k in 3:
		_px(o, Vector2(k, 9.0 + k if way > 0.0 else 2.0 - k), Vector2(5 - 2 * k, 1), col)
