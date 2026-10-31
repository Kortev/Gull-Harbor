extends Control
## The first fish you ever hook, taught a step at a time, each as it first matters (rods.gd makes it beside the fight
## HUD and ticks it every frame): the fish takes (reel, keep the needle in the green), it runs (let go), it goes off
## to the side (the captain swings her stern to him; alone, the rod goes in its holder while you steer), your arms
## tire (swap on the rod; alone, rest it in the holder), and it comes up alongside (land it). For the fight's lessons
## the fish holds still (tuna/fight.gd's `paused`: he doesn't move and
## nothing can be lost, but the needle still answers your hand, so you see what reeling does) and a card in the middle
## says what's happening and the one thing to do, the button drawn, the bar glowing. It waits till you've done it,
## then says why in a line and waits again for you to read it: SPACE or a click and the fight runs on. (The side
## and the arms are things to do once he's moving again, so those cards only want reading.) Alone or with a crew,
## each says what's yours to do (`steps_solo`). The landing
## goes step by step as you do each (rod back, wire, harpoon, haul); the fish's hook clock stands still meanwhile
## (tuna/landing.gd's hold_clock), but the sea doesn't, so there's no NEXT between those steps, only after the last.
##
## Which you've been taught is kept on this machine (SAVE), like ui/tips.gd's radio tips, and the field guide's "show
## them all again" wipes it too. Off in the tests and screenshots (`enabled`) unless asked for (--tutor).
##
## Only the fish waits, not the game, and the fight runs on the machine of whoever holds the rod (rods.gd), so it works
## the same in a crew or against the other boat: it costs you the clock, gains you nothing. Anything else that can end
## it (the other boat across your line) still can.

const Fight := preload("res://tuna/fight.gd")
const Sfx := preload("res://audio/sfx.gd")
const SAVE := "user://bluefin_tutor.cfg"
const GREEN := Color(0.45, 0.95, 0.55)
const AMBER := Color(1.0, 0.75, 0.3)
const RED := Color(1.0, 0.3, 0.25)
const PALE := Color(0.95, 0.93, 0.86)
const DIM := Color(0.62, 0.66, 0.68)
const INK := Color(0.02, 0.03, 0.05, 0.86)
const U := 3.0                        # px a pixel of the drawn mouse and keys
## The fight's lessons, in the order they're looked for (any after the first only once it's been taught).
const ORDER := ["reel", "run", "wide", "arms"]
## Each: what's happening (head), the steps (what to do, and the picture: which button; alone, `steps_solo` if it
## has them), why, once it's done, what the fish puts on the needle meanwhile (-1: what he's really doing), and
## whether it only wants reading (`read`).
const LESSONS := {
	"reel": {"head": "FISH ON!", "steps": [["HOLD LEFT MOUSE TO REEL. KEEP THE NEEDLE IN THE GREEN.", "left"]],
			"why": "IN THE GREEN YOU WIN LINE AND TIRE HIM.\nTOO SLACK OR TOO TIGHT FOR LONG AND HE'S GONE.",
			"pull": 0.15},
	"run": {"head": "HE'S RUNNING!", "steps": [["LET GO.", "none"]],
			"why": "LET HIM TAKE LINE, OR IT GOES IN THE RED AND SNAPS.\nREEL AGAIN WHEN HE STOPS.", "pull": -1.0},
	"wide": {"head": "HE'S GONE OFF TO THE SIDE!",
			"steps": [["CAPTAIN: A OR D, SWING HER STERN TO HIM. YOU KEEP REELING.", "none"]],
			"steps_solo": [["Q: ROD IN THE HOLDER. E AT THE WHEEL, A OR D: STERN TO HIM.", "key:Q"]],
			"why": "OFF THE STERN YOU CAN'T WIN LINE (WATCH THE LITTLE BOAT).\nPAST HER BEAM THE LINE RUBS THE HULL AND PARTS.",
			"pull": -1.0, "read": true},
	"arms": {"head": "YOUR ARMS ARE TIRING!",
			"steps": [["SWAP: YOUR MATE PRESSES E ON YOUR ROD, YOU TAKE THE WHEEL.", "key:E"]],
			"steps_solo": [["Q: REST THE ROD IN A HOLDER. E ON IT AGAIN WHEN YOU'RE FRESH.", "key:Q"]],
			"why": "SPENT ARMS REEL SLOW AND HE GETS HIS BREATH BACK.\nHANDS OFF THE ROD, THEY COME BACK.",
			"pull": -1.0, "read": true},
}

var rods: Node                # rods/rods.gd
var sea: Node                 # sea/sea.gd
## Whether it teaches at all (real play; a test or --tutor turns it on), and whether what's taught is saved.
var enabled := false
var keep := false
var _taught := {}
var _id := ""                 # the lesson up: one of ORDER, "land", or ""
var _fight: Fight             # the fight it's holding still
var _step := 0
var _phase := ""              # "do" (waiting for you), "why" (waiting for you to read it)
var _held := 0.0              # s the asked-for thing's been done
var _phase_t := 0.0
var _good := 0.0              # a step just done: GOOD! for a moment
var _gap := 0.0               # s before another lesson may come up
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


## Whether the lesson up is about the bar (the fight HUD makes it glow).
func highlight() -> bool:
	return _id == "reel" and _phase == "do"


## Whether Dale's radio tip `tip` (ui/tips.gd) would only say again what this has shown or is showing.
func covers(tip: String) -> bool:
	if not enabled:
		return false
	var lesson := {"fight": "reel", "alongside": "land"}.get(tip, "") as String
	return not lesson.is_empty() and (busy() or taught(lesson))


## Every frame, from rods.gd: `mine` is the rod in your hands (or null).
func tick(delta: float, mine: Node) -> void:
	_t += delta
	_a = move_toward(_a, 1.0 if _id != "" else 0.0, delta * 5.0)
	_good = maxf(_good - delta, 0.0)
	queue_redraw()
	# (not on the other boat's rods in VS: you aren't aboard her, and her HUD's a hidden one)
	if not enabled or (sea.get("crew") as Node).get("me") == null:
		if _id != "":
			_drop()
		return
	var f: Fight = null
	if mine != null and bool(mine.get("hooked")) and not bool(mine.get("alongside")):
		f = mine.get("fight") as Fight
	if _id in ORDER and (f == null or f != _fight or f.done):
		_drop()       # (the rod's left your hands, or the fight's over: this one waits for another time)
	if _id == "land" or (_id == "" and not taught("land")):
		_land(delta)
	if _id == "":
		_gap -= delta
		if f != null and not f.done and _gap <= 0.0:
			for id: String in ORDER:
				if not taught(id) and (id == "reel" or taught("reel")) and _wants(id, f):
					_start(id, f)
					break
	if _id in ORDER:
		_fight.paused = true
		_run(delta)


## Whether lesson `id`'s moment has come, from what the fight's doing.
func _wants(id: String, f: Fight) -> bool:
	match id:
		"reel":
			return true
		"run":
			return f.slipping
		"wide":
			return f.angle_k() < 0.5 and not f.slipping and f.move != "jump"
		"arms":
			return f.arms < Fight.TIRED and not f.slipping and f.move != "jump"
	return false


## The lesson's steps: alone, its `steps_solo` if it has them.
func _steps(id: String) -> Array:
	var l: Dictionary = LESSONS[id]
	var landing := sea.get("landing") as Node
	var solo := landing == null or int(landing.call("_crew_aboard")) <= 1
	return l["steps_solo"] if solo and l.has("steps_solo") else l["steps"]


func _start(id: String, f: Fight) -> void:
	_id = id
	_fight = f
	f.paused = true
	_step = 0
	_phase = "do"
	_held = 0.0
	_phase_t = 0.0
	f.pause_pull = float(LESSONS[id]["pull"])
	Sfx.play("ui.page", 0.6)


## A step of the lesson up: done (held for long enough), on to the next, or to why.
func _run(delta: float) -> void:
	_phase_t += delta
	if _phase != "do":
		return
	var me := (sea.get("crew") as Node).get("me") as Node
	var live := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (me != null and bool(me.get("force_input")))
	var crank := live and Input.is_action_pressed("use_primary")
	var ok := false
	var need := 0.6
	if bool(LESSONS[_id].get("read", false)):
		ok = true
		need = 1.2
	elif _id == "reel":
		ok = crank and _fight.strain >= Fight.GREEN_LO
	elif _id == "run":
		ok = not crank
		need = 0.8
	_held = _held + delta if ok else 0.0
	if _held < need or not ok:
		return
	_held = 0.0
	_good = 0.7
	_step += 1
	Sfx.play("ui.check", 0.7)
	if _step >= _steps(_id).size():
		_phase = "why"
		_phase_t = 0.0


func _input(event: InputEvent) -> void:
	if _phase != "why" or _phase_t < 0.6 or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	var mb := event as InputEventMouseButton
	var next := (key != null and key.pressed and not key.echo
			and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) \
			or (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT)
	if next:
		get_viewport().set_input_as_handled()
		_finish()


## Read and understood: taught, saved, and the fight runs on (with a moment's grace: nothing's lost to the click).
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
	_gap = 0.0 if _id == "reel" else 2.0
	_drop()


func _drop() -> void:
	if _fight != null:
		_fight.paused = false
		_fight.pause_pull = -1.0
		_fight.grace = maxf(_fight.grace, 1.0)
	if _id == "land":
		_unhold()
	_fight = null
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
		return ["HOLD E AT THE %s: HAUL HIM ABOARD" % ("TUNA DOOR" if bool(spec.get("door", false)) else "GUNWALE"),
				"key:E"]
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
		return ["LOOK AT HIM. LEFT MOUSE: THROW", "left"]
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
	if _id == "land":
		head = "HE'S ALONGSIDE! LAND HIM" if _phase == "do" else "HE'S ABOARD!"
		tag = "FIRST FISH: HE'LL HOLD ON THE HOOK TILL YOU'RE DONE"
		doing = _land_do
		why = "BLEED HIM, ICE HIM, QUICK.\nA COLD FISH PAYS DOUBLE."
	else:
		var l: Dictionary = LESSONS[_id]
		head = l["head"]
		tag = "HE HOLDS STILL TILL YOU DO IT: TAKE YOUR TIME"
		steps = _steps(_id).size()
		if _step < steps:
			doing = _steps(_id)[_step]
		why = l["why"]
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
		var next := "SPACE OR CLICK: GO ON"
		var nw := font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_line(font, at.x + w - 24.0 - nw, y, next, 12, Color(AMBER, (blink if ready else 0.25) * a))


func _line(font: Font, x: float, y: float, text: String, px: int, col: Color) -> void:
	draw_string(font, Vector2(roundf(x), roundf(y)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


## The button to use, drawn in whole pixels: a mouse with the button that matters lit (and which way to move it), or
## a key.
func _draw_icon(at: Vector2, kind: String, a: float, pulse: float) -> void:
	var o := at.floor()
	var line := Color(PALE, 0.8 * a)
	var lit := Color(GREEN, pulse * a)
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
