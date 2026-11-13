extends Control
## The fight's bit of HUD (rods.gd feeds it every frame). The fight is still read off the rod, the reel and the line
## (the bend, the drag screaming, the line's hum, the line going slack, the crew shouting: rods/fight_calls.gd); this
## makes sure none of it can be missed, and that a first-timer knows what to press right now:
##
## - **The strike**, for everyone aboard: FISH ON! ROD 2! across the screen, a white flash with the hit, and a marker
##   on that rod wherever it is on her (its tip, or the edge of the screen pointing to it) saying what to press to
##   take it, or who's on it.
## - **Your reel**, bottom right, while the fish is in your hands: his state in one word (RUNNING, DEEP, TIRED,
##   SURGING ...), the reel's side plate (the spool emptying, the drag lever on its quadrant, FREE / STRIKE / FULL
##   marked), the line left as a bar and in metres, the bend as a bar with where it parts, and the keys (lift, wind,
##   drag) as little pixel key caps, the one to use now lit.
## - **What to do now** (ui/fight_coach.gd), a line over the bottom of the screen: let him run, lift, wind as you
##   drop, drop the tip; it fades as you show you've got it, and comes back in red if you flounder.
## - **He's gone**: HE'S GONE, why, and what would have saved him; the screen's edges pulse red while the line's close
##   to parting; BOATSIDE when he's up.

const Fight := preload("res://tuna/fight.gd")
const FightCoach := preload("res://ui/fight_coach.gd")
const Sfx := preload("res://audio/sfx.gd")
const Kit := preload("res://ui/kit.gd")
const GREEN := Color(0.45, 0.95, 0.55)
const AMBER := Color(1.0, 0.75, 0.3)
const RED := Color(1.0, 0.3, 0.25)
const PALE := Color(0.95, 0.93, 0.86)

## (kept for rods.gd: nothing teaches over the fight with a card)
var teaching := false
var highlight := false
var coach := FightCoach.new()
var kit := Kit.new()
var _on := false
var _a := 0.0                         # how much the reel's showing (fades in and out)
var _s := {}                          # the fight's state this frame
var _t := 0.0
var _spool := 0.0                     # (eased)
var _bend := 0.0
var _lever := Fight.STRIKE_DRAG
var _lever_t := 0.0                   # s since the lever last moved (the plate lights up)
var _banner := 0.0
var _banner_len := 1.0
var _banner_text := ""
var _banner_sub := ""
var _banner_col := PALE
var _flash := 0.0
var _lift_flash := 0.0                # (his tired moment just came: the state word flares)
var _edge: ColorRect
var _lesson := ""                     # under a loss: what would have saved it
## The rods with a fish on that aren't in your hands, to mark: [{at (world), i, name, word, tone, who, free}].
var _marks: Array = []

## What each loss means, and what would have saved it (rods.gd's WHY, said plainly): the fault's always findable.
const LESSONS := {
	"Thrown on the jump.": "THE LINE WAS TIGHT WHILE HE JUMPED. WHEN HE JUMPS, DROP THE TIP.",
	"Hook pulled.": "TOO MUCH DRAG FOR TOO LONG TORE IT OUT. BENT DOUBLE? BACK THE DRAG OFF (SCROLL).",
	"Hook fell out.": "SLACK LINE WHILE HE SHOOK HIS HEAD. KEEP IT TIGHT: WIND WHEN HE COMES AT YOU.",
	"Line parted.": "A JOLT ON A HEAVY DRAG. EASE IT OFF CLOSE IN: A SHORT LINE HAS NO GIVE.",
	"Line parted, twisted.": "YOU CRANKED WHILE HE TOOK LINE: IT TWISTS AND WEAKENS. HANDS OFF ON A RUN.",
	"Line parted on the rail.": "THE LINE WAS WORN ON THE HULL, THEN HE PULLED. KEEP THE STERN TO HIM (A/D).",
	"Chafed through on the hull.": "THE LINE RUBBED THROUGH ON HER. KEEP THE STERN TO HIM, OR TAKE THE ROD ROUND.",
	"Spooled.": "HE TOOK EVERY METRE. CHASE HIM: BACK HER DOWN (S) WHILE HE RUNS.",
	"Cut on the props.": "THE LINE WENT IN THE PROPS. HE'S UNDER HER: OUT OF GEAR, STEER ONLY.",
	"Lines tangled and parted.": "HE CROSSED A LINE LEFT OUT. FISH ON: E ON EVERY OTHER ROD, REEL THEM IN.",
}
## The same in the arcade fight (tuna/fight_arcade.gd), where the hands are two buttons.
const ARCADE_LESSONS := {
	"Thrown on the jump.": "YOU HELD ON WHILE HE WAS IN THE AIR. WHEN HE JUMPS, LET GO OF BOTH.",
	"Hook pulled.": "TOO MANY MISSES TORE IT OUT. EVERY MISS WORKS THE HOOK: WATCH THE RING ROUND IT.",
	"Hook fell out.": "MISSES AND SLACK WORKED IT LOOSE. HAMMER IT WHEN HE COMES AT YOU.",
	"Line parted.": "THE LINE FRAYED THROUGH: TOO FAR INTO THE RED, TOO OFTEN. EASE OFF WHEN THE GAME'S EDGE GOES RED.",
}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# the red at the screen's edges, the line close to parting
	_edge = ColorRect.new()
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float k = 0.0;
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float e = smoothstep(0.55, 1.05, max(d.x, d.y * 1.15));
	COLOR = vec4(0.85, 0.08, 0.05, e * k);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_edge.material = m
	get_parent().add_child.call_deferred(_edge)


## This frame's fight in your hands (or {} for none): spool (0 full .. 1 empty), drag (the lever), danger (0 .. 1:
## how near the line is to parting), spin (the spool's turn, rad), bend (the line's tension), out (m), rod (its
## number, from 1), name (where she carries it), and for the coach the fight itself (fight), the rod's elevation
## (pitch) and your hand on the crank (crank).
func show_fight(s: Dictionary) -> void:
	if s.is_empty():
		_on = false
		return
	if not _on:
		_lesson = ""
		_lever = float(s.get("drag", Fight.STRIKE_DRAG))
		coach.begin()
		if float(s.get("since", 0.0)) > 12.0:
			_set_banner("YOU'VE GOT HIM", "", AMBER, 1.6)        # (taking over a fish that's been on a while)
		elif _banner <= 0.0 or _banner_col == AMBER:
			_set_banner("FISH ON!", "LET HIM RUN. WATCH YOUR REEL", AMBER, 2.2)
	_on = true
	_s = s
	var f: Fight = s.get("fight")
	if f != null:
		coach.tick(get_process_delta_time(), f, float(s.get("pitch", 0.6)), bool(s.get("crank", false)))
		if coach.now_lift:
			# his tired moment: a soft tick and a tap in the hands, the same every time (now lift)
			Sfx.play("ui.tick", 0.45, 1.5)
			Settings.buzz(0.0, 0.35, 0.06)
			_lift_flash = 1.0


## A strike on rod `rod` (from 1, where she carries it: `where`), for everyone aboard: `free` nobody's on it, `mine`
## it's in your hands already.
func strike(rod: int, where: String, free: bool, mine: bool) -> void:
	_flash = 1.0
	var sub := where.to_upper()
	if free and not mine:
		sub += ": E ON IT, TAKE THE ROD"
	_set_banner("FISH ON! ROD %d!" % rod, sub, AMBER, 3.2)


## The fish is gone: HE'S GONE, `why` under it, and (yours: `mine`) what would have saved it.
func lost(why: String, mine := true, rod := 0) -> void:
	var said := why.trim_suffix(".").to_upper()
	_lesson = str(LESSONS.get(why, "")) if mine else ""
	if mine and Fight.arcade and ARCADE_LESSONS.has(why):
		_lesson = str(ARCADE_LESSONS[why])
	_set_banner("HE'S GONE" if mine or rod <= 0 else "HE'S GONE: ROD %d" % rod, said, RED,
			6.5 if not _lesson.is_empty() else 3.0)
	if mine:
		_on = false


## Up alongside: a moment of green.
func won() -> void:
	_set_banner("BOATSIDE!", "", GREEN, 2.4)
	_lesson = "HARPOON HIM, THEN HAUL HIM ABOARD."
	_on = false


## The lever's moved a notch (rods.gd's set_drag, on the rod in your hands).
func dragged(drag: float, tighter: bool) -> void:
	coach.dragged(drag, tighter)


## The other rods with a fish on, to mark where they are (rods.gd, every frame).
func marks(list: Array) -> void:
	_marks = list


func _set_banner(text: String, sub: String, col: Color, secs: float) -> void:
	_banner_text = text
	_banner_sub = sub
	_banner_col = col
	_banner = secs
	_banner_len = secs


func _process(delta: float) -> void:
	_t += delta
	_banner = maxf(_banner - delta, 0.0)
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_lift_flash = maxf(_lift_flash - delta * 2.0, 0.0)
	_a = move_toward(_a, 1.0 if _on else 0.0, delta * (4.0 if _on else 2.0))
	_lever_t += delta
	if _on:
		_spool = lerpf(_spool, float(_s.get("spool", 0.0)), minf(1.0, delta * 6.0))
		_bend = lerpf(_bend, float(_s.get("bend", 0.0)), minf(1.0, delta * 10.0))
		var lv := float(_s.get("drag", _lever))
		if absf(lv - _lever) > 0.001:
			_lever_t = 0.0
		_lever = move_toward(_lever, lv, delta * 3.0)
	var danger := float(_s.get("danger", 0.0)) if _on else 0.0
	if _edge and _edge.material:
		var pulse := 0.5 + 0.5 * sin(_t * 14.0)
		(_edge.material as ShaderMaterial).set_shader_parameter("k", clampf(danger, 0.0, 1.0) * 0.8 * pulse * _a)
	queue_redraw()


func _draw() -> void:
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.97, 0.9, 0.35 * _flash))
	_draw_marks()
	if _a > 0.01:
		kit.px = _kpx()
		kit.defer = true
		_draw_reel(_a)
		_draw_caps(_a * coach.caps_a)
		kit.flush()
		kit.defer = false
		_draw_coach(_a)
	if _banner > 0.0:
		_draw_banner()


## `col` faded by `a`.
static func _c(col: Color, a: float) -> Color:
	return Color(col, col.a * a)


## The ink for a state's tone: orange when it's wrong, yellow when it's the moment to act, paper otherwise.
static func _tone_ink(tone: String) -> Color:
	match tone:
		"bad":
			return Kit.ORANGE
		"do":
			return Kit.YELLOW
	return Kit.PAPER


## The reel's instruments, bottom right, straight over the world (no plate): who he is and what he's doing in a word,
## the tension on a ruler (the good band hatched yellow, where the line parts hatched orange), the line out, the drag
## setting on a ruler, and his stamina on a thin one.
func _draw_reel(a: float) -> void:
	var p := kit.px
	var x1 := size.x - 40.0 * p
	var x0 := x1 - 360.0 * p
	var rx0 := x0 + 112.0 * p
	var base := size.y - 140.0 * p                 # (the keys' row hangs under this)
	var ls := 17.0 * p
	var dim := _c(Kit.PAPER, 0.92 * a)
	var empty := _spool > 0.85
	# the top line: which rod, and him in a word
	var hy := base - 214.0 * p
	kit.label(self, Vector2(x0, hy), "ROD %d" % int(_s.get("rod", 1)), ls, dim, -1)
	var big := 24.0 * p * (1.25 if _lift_flash > 0.5 else 1.0)
	var wcol := Kit.YELLOW if _lift_flash > 0.5 else _tone_ink(coach.word_tone)
	kit.label(self, Vector2(x1, hy), coach.word, big, _c(wcol, a), 1)
	if coach.drag_t < 2.5:
		# the drag: what this notch does, a moment after it moves
		var note := Settings.say("DRAG %d/10: %s" % [roundi(_lever * 10.0), coach.drag_note])
		kit.label(self, Vector2(x1, hy - 30.0 * p), note, ls, _c(Kit.YELLOW, a * clampf((2.5 - coach.drag_t) * 2.0, 0.0, 1.0)), 1)
	# the tension: a ruler, the good band yellow and the end where it parts orange, a solid triangle on the value
	var ty := base - 168.0 * p
	var bend := clampf(_bend, 0.0, 1.0)
	var danger := float(_s.get("danger", 0.0))
	var span := x1 - rx0
	var good_a := rx0 + span * pow(0.12, 0.6)          # (a light bend still shows: the bar's scale is eased)
	var good_b := rx0 + span * pow(0.6, 0.6)
	var in_good := bend >= 0.12 and bend < 0.6
	var in_bad := bend >= 0.6
	kit.label(self, Vector2(x0, ty - 6.0 * p), "TENSION", ls, dim, -1)
	kit.scale(self, Vector2(rx0, ty), Vector2(x1, ty), 20, 5, _c(Kit.PAPER, a), 1.0, 6.0 * p, 12.0 * p)
	var band := Rect2(good_a, ty - 22.0 * p, good_b - good_a, 16.0 * p)
	kit.span(self, band, _c(Kit.YELLOW, a), in_good)
	kit.hatch(self, band, _c(Kit.YELLOW, a), in_good, 8.0 * p)
	var bad := Rect2(good_b, ty - 22.0 * p, x1 - good_b, 16.0 * p)
	kit.span(self, bad, _c(Kit.ORANGE, a), in_bad)
	kit.hatch(self, bad, _c(Kit.ORANGE, a), in_bad, 8.0 * p)
	var vx := rx0 + span * pow(bend, 0.6)
	kit.tri(self, Vector2(vx, ty + 15.0 * p), 16.0 * p, Vector2.UP,
			_c(Kit.ORANGE if in_bad else (Kit.YELLOW if in_good else Kit.PAPER), a))
	var feel := ""
	if coach.word == "SLACK":
		feel = "SLACK! WIND!"
	elif danger >= 0.3:
		feel = "ABOUT TO PART!"
	if feel != "":
		kit.label(self, Vector2(x0, ty + 14.0 * p), feel, ls, _c(Kit.ORANGE, a), -1)
	# the line out, in metres
	var ly := base - 116.0 * p
	var out_m := maxf(float(_s.get("out", Fight.CAPACITY * _spool)), 0.0)
	var lcol := Kit.ORANGE if empty and fmod(_t, 0.5) < 0.3 else Kit.PAPER
	kit.label(self, Vector2(x0, ly), "LINE OUT", ls, dim, -1)
	var lw := kit.num(self, Vector2(rx0, ly - 3.0 * p), str(roundi(out_m)), 36.0 * p, _c(lcol, a), -1)
	kit.label(self, Vector2(rx0 + lw + 8.0 * p, ly + 2.0 * p), "M", 17.0 * p, _c(lcol, a), -1)
	# the drag setting: a ruler of ten, the strike setting marked above it, a triangle on the lever
	var dy := base - 78.0 * p
	var moved := _lever_t < 1.0
	kit.label(self, Vector2(x0, dy - 6.0 * p), "DRAG", ls, dim, -1)
	kit.num(self, Vector2(x0, dy + 16.0 * p), str(roundi(_lever * 10.0)), 22.0 * p, _c(Kit.YELLOW if moved else Kit.PAPER, a), -1)
	kit.scale(self, Vector2(rx0, dy), Vector2(x1, dy), 10, 5, _c(Kit.PAPER, a), 1.0, 6.0 * p, 12.0 * p)
	kit.tri(self, Vector2(rx0 + span * Fight.STRIKE_DRAG, dy - 4.0 * p), 12.0 * p, Vector2.DOWN, _c(Kit.YELLOW, a), false)
	kit.tri(self, Vector2(rx0 + span * clampf(_lever, 0.0, 1.0), dy + 15.0 * p), 16.0 * p, Vector2.UP,
			_c(Kit.YELLOW if moved else Kit.PAPER, a))
	# his stamina: a thin ruler, an orange marker (right is fresh, left is beaten)
	var sy := base - 26.0 * p
	var f: Fight = _s.get("fight")
	var energy := clampf(f.energy if f != null else 1.0, 0.0, 1.0)
	kit.label(self, Vector2(x0, sy), "FISH", ls, dim, -1)
	kit.scale(self, Vector2(rx0, sy), Vector2(x1, sy), 20, 5, _c(Kit.PAPER, a * 0.8), 1.0, 4.0 * p, 8.0 * p)
	kit.tri(self, Vector2(rx0 + span * energy, sy + 11.0 * p), 13.0 * p, Vector2.UP, _c(Kit.ORANGE, a))


# ------------------------------------------------------------------ the keys

## The three things you do with a fish on, under the reel's instruments: lift, wind, the drag; the one the coach wants
## now YELLOW and solid, the rest hollow. The pad's buttons while it's the pad in your hands.
func _draw_caps(a: float) -> void:
	if a <= 0.01:
		return
	var p := kit.px
	var want := coach.keys
	var pad := Settings.pad
	var x1 := size.x - 40.0 * p
	var x0 := x1 - 360.0 * p
	var cy := size.y - 140.0 * p + 44.0 * p
	for ci in 3:
		var id: String = ["lift", "wind", "drag"][ci]
		var lit := want == id or (id == "drag" and want.begins_with("drag")) or (id == "lift" and want == "drop") \
				or (id == "wind" and want == "wait")
		var cx := x0 + 360.0 * p * (ci + 0.5) / 3.0
		var col := _c(Kit.YELLOW if lit else Kit.PAPER, a * (1.0 if lit else 0.9))
		var name := id.to_upper()
		if id == "lift" and want == "drop":
			name = "DROP TIP"
		elif id == "lift" and want == "wait":
			name = "WAIT..."
		kit.label(self, Vector2(cx, size.y - 140.0 * p), name, 15.0 * p, col)
		var under := ""
		match id:
			"lift":
				var down := want == "drop"
				var tip := Vector2(cx, cy + (22.0 if down else -22.0) * p)
				kit.tri(self, tip, 26.0 * p, Vector2.DOWN if down else Vector2.UP, col, lit)
				kit.rule(self, Vector2(cx, cy + (-2.0 if down else 2.0) * p), Vector2(cx, cy + (-22.0 if down else 22.0) * p), col, lit)
				under = ("RS DN" if down else "RS UP") if pad else "MOUSE"
			"wind":
				var cue := Kit.HOLD if lit else (Kit.OFF if want == "none" else Kit.NONE)
				kit.button(self, Vector2(cx, cy), 44.0 * p, 0, cue, _t, false, pad, a)
				if want == "none":
					kit.label(self, Vector2(cx, size.y - 140.0 * p), "WIND", 15.0 * p, _c(Kit.ORANGE, a))
			"drag":
				var up := want == "drag_up" or (lit and want == "drag")
				var dn := want == "drag_down" or (lit and want == "drag")
				kit.tri(self, Vector2(cx, cy - 24.0 * p), 18.0 * p, Vector2.UP, col, up)
				kit.tri(self, Vector2(cx, cy + 24.0 * p), 18.0 * p, Vector2.DOWN, col, dn)
				under = "LB / RB" if pad else "SCROLL"
		if under != "":
			kit.label(self, Vector2(cx, cy + 44.0 * p), under, 15.0 * p, _c(Kit.PAPER, 0.6 * a))


# ------------------------------------------------------------------ what to do now

## The line over the bottom of the screen: the words straight over the world, the key or button to press in yellow.
func _draw_coach(a: float) -> void:
	var k := coach.a * a
	if coach.tone == "bad":
		k = a
	if k <= 0.01 or coach.say.is_empty():
		return
	var p := kit.px
	var one := _keys_said(coach.say)
	var two := _keys_said(coach.then)
	var fs := 26.0 * p
	var gap := 34.0 * p
	var w := _said_w(one, fs) + (gap + _said_w(two, fs) if not two.is_empty() else 0.0)
	if w > size.x - 120.0 * p:
		fs = 19.0 * p
		w = _said_w(one, fs) + (gap + _said_w(two, fs) if not two.is_empty() else 0.0)
	var y := roundf(size.y * 0.6)
	var x := roundf((size.x - w) * 0.5)
	var room := size.x - 400.0 * p - 40.0 * p - 24.0 * p
	if x + w > room:
		# (clear of the reel's instruments: centred in what's left of the screen)
		x = maxf(roundf((room - w) * 0.5), 24.0 * p)
	var base := Kit.ORANGE if coach.tone == "bad" else Kit.PAPER
	if two.is_empty():
		_said(x, y, one, fs, base, k)
		return
	# the pump's two halves: the one you're on lit, the other waiting
	var wait := coach.keys == "wait"
	var w1 := _said(x, y, one, fs, base, k if coach.first else k * 0.5, coach.first and not wait)
	kit.tri(self, Vector2(x + w1 + gap * 0.75, y), 14.0 * p, Vector2.RIGHT, _c(Kit.PAPER, k * 0.6))
	_said(x + w1 + gap, y, two, fs, base, k * 0.5 if coach.first else k, not coach.first)


## A coach line is its words, then the key to press in brackets: split them.
static func _split_said(text: String) -> PackedStringArray:
	var i := text.find("(")
	if i < 0 or not text.ends_with(")"):
		return PackedStringArray([text, ""])
	return PackedStringArray([text.substr(0, i).strip_edges(), text.substr(i + 1, text.length() - i - 2)])


func _said_w(text: String, fs: float) -> float:
	var parts := _split_said(text)
	var w := kit.text_w(parts[0], fs, 600, fs * 0.06)
	if parts[1] != "":
		w += fs * 0.6 + kit.text_w(parts[1], fs * 0.7, 600, fs * 0.7 * 0.17)
	return w


## A coach line from `x` (its left end), vertically centred on `y`: the words in `col`, the key in YELLOW. Returns its width.
func _said(x: float, y: float, text: String, fs: float, col: Color, a: float, heavy := false) -> float:
	var parts := _split_said(text)
	var w := kit.text(self, Vector2(x, y), parts[0], fs, _c(col, a), -1, 700 if heavy else 600, fs * 0.06)
	if parts[1] != "":
		var kw := kit.label(self, Vector2(x + w + fs * 0.6, y), parts[1], fs * 0.7, _c(Kit.YELLOW, a), -1)
		w += fs * 0.6 + kw
	return w


## The coach's words with the pad's keys while it's the pad in your hands.
static func _keys_said(text: String) -> String:
	if not Settings.pad or text.is_empty():
		return text
	return text.replace("(MOUSE UP)", "(RIGHT STICK UP)").replace("(MOUSE DOWN)", "(RIGHT STICK DOWN)") \
			.replace("(SCROLL DOWN)", "(RB)").replace("(SCROLL UP)", "(LB)").replace("(HOLD LMB)", "(HOLD RT)") \
			.replace("SCROLL", "LB/RB")


# ------------------------------------------------------------------ the other rods

## Each rod with a fish on that isn't in your hands: a marker on its tip (or on the screen's edge, pointing to it):
## the rod's number, him in a word, and E: TAKE THE ROD, or who's on it.
func _draw_marks() -> void:
	if _marks.is_empty() or size.x < 300.0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	kit.px = _kpx()
	var p := kit.px
	var lit := fmod(_t, 0.6) < 0.4
	for m: Dictionary in _marks:
		var at: Vector3 = m["at"]
		var behind := cam.is_position_behind(at)
		var pt := cam.unproject_position(at)
		var inset := Rect2(Vector2(70, 90), size - Vector2(140, 200))
		var off := behind or not inset.has_point(pt)
		if behind:
			# (behind you: low on the screen, toward the side to turn to)
			var right := (cam.global_transform.affine_inverse() * at).x > 0.0
			pt = Vector2(size.x * (0.75 if right else 0.25), size.y)
		var free := bool(m.get("free", false))
		var head := "ROD %d: %s" % [int(m["i"]) + 1, str(m.get("word", "FISH ON"))]
		if behind:
			head = "ROD %d: BEHIND YOU" % (int(m["i"]) + 1)
		var under := ("E: TAKE THE ROD" if free else "%s'S ON IT" % str(m.get("who", "")).to_upper())
		under = Settings.say(under)
		# (a small yellow triangle where the fish is on, and who or what, in spaced capitals; paper once someone has it)
		var col := Kit.YELLOW if free else Kit.PAPER
		var w := maxf(kit.text_w(head, 17.0 * p, 600, 17.0 * p * 0.17), kit.text_w(under, 13.0 * p, 600, 13.0 * p * 0.17)) + 20.0 * p
		kit.defer = true
		if off:
			var c := size * 0.5
			var d := (pt - c)
			if d.length() < 1.0:
				d = Vector2(0, 1)
			# out to the edge of the inset rectangle along d
			var sx := (inset.size.x * 0.5) / maxf(absf(d.x), 0.001)
			var sy := (inset.size.y * 0.5) / maxf(absf(d.y), 0.001)
			var q := c + d * minf(sx, sy)
			var n := d.normalized()
			kit.tri(self, q, 22.0 * p, n, col)
			# (the words just inside the arrow, never over it)
			var mid := q - n * Vector2(w * 0.5 + 26.0 * p, 46.0 * p)
			var mc := Vector2(clampf(roundf(mid.x), w * 0.5 + 8.0, size.x - w * 0.5 - 8.0),
					clampf(roundf(mid.y), 30.0 * p, size.y - 60.0 * p))
			kit.label(self, mc - Vector2(0, 9.0 * p), head, 17.0 * p, col)
			if lit or not free:
				kit.label(self, mc + Vector2(0, 12.0 * p), under, 13.0 * p, Kit.PAPER)
		else:
			# over the tip: a bobbing triangle down onto it, the words above
			var bob := roundf(sin(_t * 6.0) * 3.0)
			var tip := pt.floor() + Vector2(0, -8.0 * p + bob)
			kit.tri(self, tip, 20.0 * p, Vector2.DOWN, col)
			kit.label(self, tip - Vector2(0, 52.0 * p), head, 17.0 * p, col)
			if lit or not free:
				kit.label(self, tip - Vector2(0, 32.0 * p), under, 13.0 * p, Kit.PAPER)
		kit.flush()
		kit.defer = false


# ------------------------------------------------------------------ the moments

func _draw_banner() -> void:
	var p := _kpx()
	kit.px = p
	var k := clampf(_banner, 0.0, 1.0)
	var age := _banner_len - _banner
	# FISH ON! is a market stamp in yellow, slammed in and gone in about a second and a half; the other moments
	# (HE'S GONE in orange, BOATSIDE in yellow) stay their time
	var fish_on := _banner_col == AMBER
	var col := Kit.YELLOW if _banner_col != RED else Kit.ORANGE
	var life := 1.5 if fish_on else _banner_len
	var at := Vector2(size.x * 0.5, size.y * 0.3)
	var big := 64.0 * p if _banner_col != GREEN else 50.0 * p
	# ("FISH ON! ROD 2!": the stamp says FISH ON!, and the rod's a small triangle and ROD 2 under it)
	var word := _banner_text
	var rod := ""
	if word.begins_with("FISH ON! ROD"):
		rod = word.trim_prefix("FISH ON! ").trim_suffix("!")
		word = "FISH ON!"
	if age < life:
		var fade := clampf((life - age) / 0.25, 0.0, 1.0)
		kit.stamp(self, at, word, big, col, Kit.slam(age), fade, -0.07 if fish_on else 0.05)
	var y2 := at.y + big * 0.62 + 34.0 * p
	if rod != "":
		var rw := kit.text_w(rod, 22.0 * p, 600, 22.0 * p * 0.17)
		kit.tri(self, Vector2(size.x * 0.5 - rw * 0.5 - 2.0 * p, y2), 16.0 * p, Vector2.RIGHT, Kit.YELLOW)
		kit.label(self, Vector2(size.x * 0.5 + 6.0 * p, y2), rod, 22.0 * p, Color(Kit.YELLOW, k))
		y2 += 34.0 * p
	if not _banner_sub.is_empty():
		kit.label(self, Vector2(size.x * 0.5, y2), Settings.say(_banner_sub), 20.0 * p, Color(Kit.PAPER, k))
		y2 += 34.0 * p
	if not _lesson.is_empty() and not fish_on:
		var lesson := Settings.say(_lesson)
		var fs := 24.0 * p
		while kit.text_w(lesson, fs, 600, fs * 0.06) > size.x * 0.9 and fs > 14.0 * p:
			fs -= 1.0
		kit.text(self, Vector2(size.x * 0.5, y2), lesson, fs, Color(Kit.PAPER, k), 0, 600, fs * 0.06)


## The screen's scale for the kit: 1 at 1080p.
func _kpx() -> float:
	return clampf(size.y / 1080.0, 0.7, 2.5)
