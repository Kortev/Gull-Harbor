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
const Kit := preload("res://ui/kit.gd")
## (The fight's lessons: none any more. Kept so a save from before reads.)
const ORDER: Array[String] = []

var kit := Kit.new()
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

func _c(col: Color, a: float) -> Color:
	return Color(col, col.a * a)


## The card, straight over the world (nothing behind it): the title in heavy numerals over a heavy rule, the step
## beside the button to use.
func _draw() -> void:
	if _a <= 0.01 or _id == "":
		return
	var p := clampf(size.y / 1080.0, 0.7, 2.5)
	kit.px = p
	var a := _a
	var cx := roundf(size.x * 0.5)
	var y := roundf(size.y * 0.2)
	var head := "HE'S ALONGSIDE! LAND HIM" if _phase == "do" else "HE'S ABOARD!"
	var tag := "FIRST FISH: HE'LL HOLD ON THE HOOK TILL YOU'RE DONE"
	kit.label(self, Vector2(cx, y), Settings.say(tag), 15.0 * p, _c(Kit.PAPER, 0.6 * a))
	y += 46.0 * p
	var hw := kit.num(self, Vector2(cx, y), head, 44.0 * p, _c(Kit.YELLOW, a))
	y += 30.0 * p
	kit.rule(self, Vector2(cx - hw * 0.5, y), Vector2(cx + hw * 0.5, y), _c(Kit.PAPER, a), true)
	kit.scale(self, Vector2(cx - hw * 0.5, y + 4.0 * p), Vector2(cx - hw * 0.5 + hw * 0.3, y + 4.0 * p), 6, 3,
			_c(Kit.PAPER, a), 1.0, 6.0 * p, 11.0 * p, false)
	y += 58.0 * p
	if _phase == "do" and not _land_do.is_empty():
		# the button, and what to do beside it
		var said := Settings.say(str(_land_do[0]))
		var fs := 28.0 * p
		var tw := kit.text_w(said, fs, 600, fs * 0.06)
		var icon_w := 84.0 * p
		var left := roundf(cx - (icon_w + tw) * 0.5)
		_draw_icon(Vector2(left + icon_w * 0.4, y + 6.0 * p), str(_land_do[1]), a)
		kit.text(self, Vector2(left + icon_w, y), said, fs, _c(Kit.YELLOW if _good > 0.0 else Kit.PAPER, a), -1, 600, fs * 0.06)
		if _good > 0.0:
			kit.label(self, Vector2(cx, y + 84.0 * p), "GOOD!", 20.0 * p, _c(Kit.YELLOW, a))
	elif _phase == "why":
		kit.num(self, Vector2(cx, y), "GOOD!", 30.0 * p, _c(Kit.YELLOW, a))
		for s: String in "SPIKE HIM, BLEED HIM, ICE HIM. QUICK.\nA CLEAN, COLD FISH PAYS DOUBLE.".split("\n"):
			y += 40.0 * p
			kit.text(self, Vector2(cx, y), s, 28.0 * p, _c(Kit.PAPER, a), 0, 600, 28.0 * p * 0.06)
		y += 56.0 * p
		var ready := _phase_t >= 0.6
		var on := fmod(_t, 1.0) < 0.6
		kit.label(self, Vector2(cx, y), Settings.say("SPACE OR CLICK: GO ON"), 18.0 * p,
				_c(Kit.YELLOW, (1.0 if on else 0.5) * a if ready else 0.3 * a))


## The button to use, from the kit: the mouse with the button that matters solid (HOLD), or a key cap (its letter in
## yellow), or crossed out for hands off. With the pad in your hands, its button (the left mouse its RT, the right its LT).
func _draw_icon(at: Vector2, kind: String, a: float) -> void:
	var p := kit.px
	var pad := Settings.pad
	if kind.begins_with("key:"):
		var k := kind.substr(4)
		if pad:
			k = Pad.cap(k, true)
		var w := maxf(44.0 * p, kit.text_w(k, 26.0 * p, 700) + 18.0 * p)
		var r := Rect2(at - Vector2(w * 0.5, 22.0 * p), Vector2(w, 44.0 * p))
		kit.corners(self, r, 12.0 * p, _c(Kit.PAPER, a))
		kit.num(self, at, k, 28.0 * p, _c(Kit.YELLOW, a))
		return
	match kind:
		"left", "left_down":
			kit.button(self, at, 64.0 * p, 0, Kit.HOLD, _t, false, pad, a)
		"right":
			kit.button(self, at, 64.0 * p, 1, Kit.HOLD, _t, false, pad, a)
		"wheel_down":
			kit.button(self, at, 64.0 * p, 0, Kit.TAP, _t, false, pad, a)
		"none":
			kit.button(self, at, 64.0 * p, 0, Kit.OFF, _t, false, pad, a)
