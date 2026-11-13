extends CanvasLayer
## The whole HUD, kept minimal, and shown rather than said. A dot in the middle of the view, and under it the key
## and a word or two for what's under it. In a fight: the ring round the dot fills and reddens with the strain (a thin
## inner one for your arms once they start to go, a thin red outer one for the line wearing on the hull), a word or
## two on what to do, and under that the metres to boatside (green winning, red losing) and the fish's fight left.
## Top left the trip: the boat payment as a bar (what's aboard ghosted on), when it's due, the fish box as pips. At the wheel her
## knots and a throttle bar, bottom left (the dash's screens have the middle); with a fish on, the plotter. Notices, a
## few words, top middle, and fade. The fight's word and a notice sit on a dark band just their width, so they read
## over a bright sky or a dark sea alike, a size down if they'd run off a narrow screen. Every key named
## is the pad's while it's the pad in your hands (core/settings.gd's say(): E is [X]), changing over as you swap.

## The one type scale: small (numbers, the tally), body (prompts, notices, readouts), big (the fight's word).
const Pad := preload("res://core/pad.gd")
const Kit := preload("res://ui/kit.gd")

const SMALL := 14
const BODY := 17
const BIG := 21
## How wide the fight's word under the crosshair and a notice can run (px), at most: the screen less MARGIN a side.
const TELL_W := 1100.0
const MARGIN := 48.0
## Line out when a fish is alongside (tuna/fight.gd's BOATSIDE).
const BOATSIDE := 7.0
const CREAM := Color(0.95, 0.93, 0.88)
const GREEN := Color(0.55, 1.0, 0.55)
const AMBER := Color(1.0, 0.75, 0.35)
const RED := Color(1.0, 0.4, 0.3)
## Behind the HUD's words and tallies: dark enough to read over a bright sky, light enough to see the sea through.
const BACKING := Color(0.0, 0.02, 0.04, 0.42)

## The HUD's type and linework, in the fight's hand (ui/kit.gd). The Labels below hold the words (tests and the
## layout read them) but are drawn clear: `_type` draws them, and the helm, tally and plotter draw themselves.
var kit := Kit.new()
var _type: Control
var _tell_col := Kit.PAPER
var _tell_warn := false
var _prompt: HBoxContainer
var _key: Label
var _what: Label
var _tell: Label
var _meter: Control
var _ring: Control
var _strain := 0.0
var _arms := 1.0
var _line := -1.0
var _gain := 0.0
var _fresh := 1.0
var _wear := 0.0
var _note: Label
var _note_t := 0.0
## The prompt and the notice as they were given (said again in the pad's keys, or not, as you swap).
var _prompt_raw := ""
var _note_raw := ""
## The trip, top left (boat/fish_hold.gd): {} hides it.
var _tally: Control
var _trip := {}
## At the wheel, bottom middle (boat/helm.gd): knots (< 0 hides it) and the throttle -1..1.
var _helm: Control
var _knots := -1.0
var _throttle := 0.0
## The captain's plotter (bottom middle, only at the wheel with a fish on): her outline, bow up, and each fish
## round her as a dot on its line from the stern, red where the line's on the hull.
var _plot: Control
var _fish: Array = []


func _ready() -> void:
	layer = 5
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.55)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE    # the captured cursor sits right on it
	dot.size = Vector2(3, 3)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(1.5, 1.5)
	add_child(dot)
	# the prompt: a key cap and a word or two
	_prompt = HBoxContainer.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position += Vector2(-200, 24)
	_prompt.size = Vector2(400, 28)
	_prompt.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt.add_theme_constant_override("separation", 8)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	_key = _label(SMALL, CREAM)
	_key.text = "E"
	_prompt.add_child(_key)
	_what = _label(BODY, CREAM)
	_prompt.add_child(_what)
	_prompt.visible = false
	_tell = _label(BIG, CREAM)
	_tell.set_anchors_preset(Control.PRESET_CENTER)
	_tell.position += Vector2(0, 52)
	_tell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tell.visible = false
	add_child(_tell)
	_meter = Control.new()
	_meter.set_anchors_preset(Control.PRESET_CENTER)
	_meter.position += Vector2(0, 96)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.draw.connect(_draw_meter)
	add_child(_meter)
	_ring = Control.new()
	_ring.set_anchors_preset(Control.PRESET_CENTER)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_note = _label(BODY, CREAM)
	_note.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_note.position += Vector2(0, 40)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.visible = false
	add_child(_note)
	_tally = Control.new()
	_tally.position = Vector2(18, 16)
	_tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tally.draw.connect(_draw_tally)
	add_child(_tally)
	_helm = Control.new()
	_helm.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_helm.position += Vector2(18, -30)
	_helm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_helm.draw.connect(_draw_helm)
	add_child(_helm)
	_plot = Control.new()
	_plot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_plot.position += Vector2(-122, -122)      # (in the corner: the dash's own screens are low in the middle)
	_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plot.draw.connect(_draw_plot)
	add_child(_plot)
	# the words, drawn in the kit's type over everything else here
	_type = Control.new()
	_type.set_anchors_preset(Control.PRESET_FULL_RECT)
	_type.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type.draw.connect(_draw_type)
	add_child(_type)


## A label that holds a line of words and is drawn clear: _draw_type() prints it in the kit's type.
static func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(col, 0.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	return l


## `l` says `text` at the biggest of `sizes` that fits in `share` of the screen's width, centred on its anchor, its
## band its width.
func _fit(l: Label, text: String, sizes: Array, share := 0.9) -> void:
	l.text = text
	l.visible = not text.is_empty()
	if text.is_empty():
		return
	var screen := get_viewport().get_visible_rect().size.x
	var room := minf(TELL_W, minf(screen * share, screen - MARGIN * 2.0))
	var size: int = sizes[-1]
	for s: int in sizes:
		if _words_w(text, s) <= room:
			size = s
			break
	l.set_meta("size", size)


## How wide `text` runs (px) in the HUD's spaced capitals at type size `s` (the old size scale: SMALL, BODY, BIG).
func _words_w(text: String, s: int) -> float:
	var fs := float(s) * 1.2 * _px()
	return kit.text_w(text.to_upper(), fs, 600, fs * 0.12)


func _px() -> float:
	return clampf(get_viewport().get_visible_rect().size.y / 1080.0, 0.7, 2.5)


func _text(on: Control, at: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT,
		width := -1.0) -> void:
	var p := _px()
	var fs := float(size) * 1.2 * p
	var x := at.x
	var a := -1
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x += width * 0.5
		a = 0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x += width
		a = 1
	kit.px = p
	kit.text(on, Vector2(x, at.y - fs * 0.3), text.to_upper(), fs, col, a, 600, fs * 0.12)


## At the wheel: the fish on, each [bearing (rad, 0 dead astern, + to starboard), metres off, how hard it's rubbing
## the hull 0..1]; an empty list hides it. (The throttle's on the helm bar under it.)
func plot(fish: Array, _throttle_now := 0.0) -> void:
	if fish.is_empty() and _fish.is_empty():
		return
	_fish = fish
	_plot.queue_redraw()


func _draw_plot() -> void:
	if _fish.is_empty():
		return
	var p := _px()
	kit.px = p
	kit.defer = true
	var r := 90.0 * p
	var ci := _plot
	# the dial: a ticked circle, the hull-danger arc forward of her beam hatched in orange
	kit.dial(ci, Vector2.ZERO, r, 24, 6, Kit.PAPER, 5.0 * p, 10.0 * p)
	kit.sweep(ci, Vector2.ZERO, r * 0.35, PI * 1.5 - 1.4, PI * 1.5 + 1.4, Kit.ORANGE, true)
	# her, bow up
	var hull := PackedVector2Array([Vector2(0, -22), Vector2(8, -8), Vector2(8, 14), Vector2(-8, 14), Vector2(-8, -8)])
	for i in hull.size():
		hull[i] *= p
	kit.path(ci, hull, Kit.PAPER, false, true)
	var stern := Vector2(0, 14) * p
	for f: Array in _fish:
		var b := float(f[0])
		var d := clampf(log(1.0 + float(f[1]) / 6.0) / log(1.0 + 300.0 / 6.0), 0.12, 1.0) * r
		var at := stern + Vector2(sin(b), cos(b)) * d
		var hot := float(f[2]) > 0.5
		var col := Kit.ORANGE
		kit.rule(ci, stern, at, Kit.ORANGE if hot else Kit.PAPER, hot)
		kit.diamond(ci, at, 11.0 * p, col, true)
	kit.flush()
	kit.defer = false


## At the wheel: her speed in knots and the throttle -1..1 (knots < 0 hides it).
func helm(knots: float, throttle := 0.0) -> void:
	if knots < 0.0 and _knots < 0.0:
		return
	_knots = knots
	_throttle = throttle
	_helm.queue_redraw()


func _draw_helm() -> void:
	if _knots < 0.0:
		return
	# her knots over a throttle ruler: ahead to the right of the middle tick, astern to the left
	var p := _px()
	kit.px = p
	kit.defer = true
	var ci := _helm
	var w := 80.0 * p
	var dw := kit.num(ci, Vector2(0, -22.0 * p), "%d" % roundi(_knots), 30.0 * p, Kit.PAPER, -1)
	kit.label(ci, Vector2(dw + 7.0 * p, -17.0 * p), "KN", 14.0 * p, Kit.PAPER, -1)
	kit.scale(ci, Vector2(0, 0), Vector2(w * 2.0, 0), 20, 5, Kit.PAPER, 1.0, 5.0 * p, 9.0 * p)
	var t := clampf(_throttle, -1.0, 1.0)
	if absf(t) > 0.01:
		kit.rule(ci, Vector2(w, 0), Vector2(w + w * t, 0), Kit.YELLOW if t > 0.0 else Kit.PAPER, true)
	kit.tri(ci, Vector2(w, -3.0 * p), 11.0 * p, Vector2.DOWN, Kit.PAPER)
	kit.flush()
	kit.defer = false


## The trip, top left (boat/fish_hold.gd): day, days, box, cap, deck (counts), earned, quota, aboard (dollars), and
## earned_text/quota_text to print. {} hides it.
func tally(trip: Dictionary) -> void:
	if trip == _trip:
		return
	_trip = trip
	_tally.queue_redraw()


func _draw_tally() -> void:
	if _trip.is_empty():
		return
	var p := _px()
	kit.px = p
	kit.defer = true
	var ci := _tally
	var w := 220.0 * p
	if _trip.has("rivals"):
		# (Rivals: the match's day, no quota; her box as ever. As one fleet there's no match to win: just the day)
		var dw := kit.num(ci, Vector2(0, 14.0 * p), "DAY %d" % int(_trip["day"]), 24.0 * p, Kit.PAPER, -1)
		kit.label(ci, Vector2(dw + 10.0 * p, 17.0 * p), "ONE FLEET" if bool(_trip.get("together", false))
				else "BEST OF THREE", 13.0 * p, Kit.PAPER, -1)
		_draw_box(46.0 * p)
		kit.flush()
		kit.defer = false
		return
	var quota := maxf(float(_trip["quota"]), 1.0)
	var earned := float(_trip["earned"])
	var made := earned >= quota
	var left := int(_trip["days"]) - int(_trip["day"]) + 1
	# line one: what's earned over the payment; line two: when it's due, over the ruler of how far along it is
	var ew := kit.num(ci, Vector2(0, 14.0 * p), str(_trip["earned_text"]), 26.0 * p, Kit.YELLOW if made else Kit.PAPER, -1)
	kit.text(ci, Vector2(ew + 8.0 * p, 16.0 * p), "/ %s" % _trip["quota_text"], 18.0 * p, Kit.PAPER, -1, 600, 1.5 * p)
	var due_col := Kit.ORANGE if (left <= 1 and not made) else (Kit.YELLOW if made else Kit.PAPER)
	kit.label(ci, Vector2(0, 42.0 * p), "PAID" if made else ("DUE TODAY" if left <= 1 else "DUE IN %d DAYS" % left),
			13.0 * p, due_col, -1)
	var ry := 58.0 * p
	kit.scale(ci, Vector2(0, ry), Vector2(w, ry), 20, 5, Kit.PAPER, 1.0, 4.0 * p, 8.0 * p)
	var aboard := clampf((earned + float(_trip["aboard"])) / quota, 0.0, 1.0)
	var got := clampf(earned / quota, 0.0, 1.0)
	if aboard > got:
		kit.rule(ci, Vector2(w * got, ry), Vector2(w * aboard, ry), Kit.YELLOW, true)
	if got > 0.0:
		kit.rule(ci, Vector2(0, ry), Vector2(w * got, ry), Kit.YELLOW if made else Kit.PAPER, true)
	_draw_box(84.0 * p)
	kit.flush()
	kit.defer = false


func _draw_box(y: float) -> void:
	# the fish box, a square a place (solid once iced), and any still on deck after it in orange
	var p := _px()
	var x := 6.0 * p
	for i in int(_trip["cap"]):
		kit.square(_tally, Vector2(x, y), 11.0 * p, Kit.PAPER, i < int(_trip["box"]))
		x += 17.0 * p
	for i in int(_trip["deck"]):
		kit.square(_tally, Vector2(x + 6.0 * p, y), 11.0 * p, Kit.ORANGE, true)
		x += 17.0 * p


## A few words at the top for a few seconds ("Fish on!").
func notify(text: String) -> void:
	_note_raw = text
	_fit(_note, Settings.say(text), [BODY, SMALL])
	_note.modulate.a = 1.0
	_note_t = 4.0


## The notes' top edge (px): moved down under a banner that has the top (Rivals' countdown and race home, vs/vs.gd).
func note_at(y: float) -> void:
	if _note.position.y != y:      # (only when it moves: set every frame, it's laid out again every frame)
		_note.position.y = y


func _process(delta: float) -> void:
	_note_t -= delta
	_note.modulate.a = clampf(_note_t, 0.0, 1.0)
	_type.queue_redraw()


## The words under the crosshair, the fight's word and the notice, in the fight's type: fine spaced capitals with a
## thin dark outline, no panel. During an arcade fight nothing goes in the minigame's frame (centre, low) or under
## its ruler (top middle): the hint sits just under the crosshair, above the frame, and a notice drops under the
## ruler.
func _draw_type() -> void:
	var ci := _type
	var sz := ci.size
	var p := _px()
	kit.px = p
	kit.defer = true
	var y := sz.y * 0.5 + 36.0 * p
	if _prompt.visible and not _what.text.is_empty():
		var fs := float(BODY) * 1.2 * p
		var words := _what.text.to_upper()
		var kw := kit.text_w(_key.text, fs, 700, 0.0) + 16.0 * p
		var ww := kit.text_w(words, fs, 600, fs * 0.12)
		var x := (sz.x - (kw + 12.0 * p + ww)) * 0.5
		kit.span(ci, Rect2(x, y - 12.0 * p, kw, 24.0 * p), Kit.PAPER)
		kit.text(ci, Vector2(x + kw * 0.5, y), _key.text, fs, Kit.PAPER, 0, 700)
		kit.text(ci, Vector2(x + kw + 12.0 * p, y), words, fs, Kit.PAPER, -1, 600, fs * 0.12)
		y += 30.0 * p
	if _tell.visible and not _tell.text.is_empty():
		var size := int(_tell.get_meta("size", BIG))
		var fs := float(size) * 1.2 * p
		var words := _tell.text.to_upper()
		var ww := kit.text_w(words, fs, 600, fs * 0.12)
		var x := (sz.x - ww) * 0.5
		if _tell_warn:
			kit.tri(ci, Vector2(x - 12.0 * p, y), 15.0 * p, Vector2.RIGHT, Kit.ORANGE)
		kit.text(ci, Vector2(x, y), words, fs, Kit.ORANGE if _tell_warn else Kit.PAPER, -1, 600, fs * 0.12)
	if _note.visible and _note.modulate.a > 0.01 and not _note.text.is_empty():
		var size := int(_note.get_meta("size", BODY))
		var fs := float(size) * 1.2 * p
		var top := _note.position.y * p + 12.0 * p
		var arcade := get_node_or_null("FightArcadeHud")
		if arcade != null and float(arcade.get("_a")) > 0.01:
			top = maxf(top, 156.0 * p)
		var words := _note.text.to_upper()
		var ww := kit.text_w(words, fs, 600, fs * 0.12)
		var a := _note.modulate.a
		kit.text(ci, Vector2((sz.x - ww) * 0.5, top), words, fs, Color(Kit.PAPER, a), -1, 600, fs * 0.12)
	kit.flush()
	kit.defer = false


## In a fight: what to do ("Crank") and the strain 0..1 ("" and 0 when there's no fight: then `tell` is what wants
## doing, if anything). `arms`: yours, 0..1. `line`: metres out (< 0 hides the meter), `gain`: how fast you're winning
## it back (m/s, - while it takes line), `fresh`: the fish, 1 fresh .. 0 beat. `wear`: the line's wear on the hull,
## 0..1.
func fight(tell: String, strain: float, arms := 1.0, line := -1.0, gain := 0.0, fresh := 1.0, wear := 0.0) -> void:
	var said := Settings.say(tell)
	if said != _tell.text:
		_fit(_tell, said, [BIG, BODY, SMALL], 0.72)       # (a long one down a size, so it's all on the screen, centred)
	_tell_warn = _tell_colour(tell) == RED
	if line != _line or absf(gain - _gain) > 0.05 or absf(fresh - _fresh) > 0.01:
		_line = line
		_gain = gain
		_fresh = fresh
		_meter.queue_redraw()
	if absf(strain - _strain) > 0.01 or (strain == 0.0) != (_strain == 0.0) or absf(arms - _arms) > 0.01 \
			or absf(wear - _wear) > 0.01:
		_strain = strain
		_arms = arms
		_wear = wear
		_ring.queue_redraw()


## The word's colour says it before you read it: red trouble, amber hold off, green crank.
static func _tell_colour(tell: String) -> Color:
	var t := tell.to_lower()
	if t.begins_with("out of gear") or t.contains("under") or t.contains("tangled") or t.contains("hull"):
		return RED
	if t.contains("ease") or t.contains("let it"):
		return AMBER
	if t.contains("crank"):
		return GREEN
	return Color(1.0, 0.92, 0.7)


func _draw_meter() -> void:
	if _line < 0.0:
		return
	# metres to boatside, coloured by which way it's going, with an arrow
	var col := Color(0.85, 0.85, 0.82)
	if _gain > 0.25:
		col = GREEN
	elif _gain < -0.25:
		col = RED
	_text(_meter, Vector2(-60, 0), "%d m" % maxi(roundi(_line - BOATSIDE), 0), SMALL + 2, col,
			HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	if absf(_gain) > 0.25:
		var x := 34.0
		var up := _gain > 0.25      # (winning it in: toward you, up)
		var tri := PackedVector2Array([Vector2(x - 5, -4 if up else -10), Vector2(x + 5, -4 if up else -10),
				Vector2(x, -11 if up else -3)])
		_meter.draw_colored_polygon(tri, col)
	# the fish: a little fish, and a bar of the fight it's got left
	var y := 10.0
	_meter.draw_circle(Vector2(-46, y + 3), 4.0, Color(0.75, 0.82, 0.9, 0.9))
	_meter.draw_colored_polygon(PackedVector2Array([Vector2(-42, y + 3), Vector2(-37, y - 1), Vector2(-37, y + 7)]),
			Color(0.75, 0.82, 0.9, 0.9))
	_meter.draw_rect(Rect2(-32, y + 1, 72, 4), Color(0, 0, 0, 0.4))
	_meter.draw_rect(Rect2(-32, y + 1, 72 * clampf(_fresh, 0.0, 1.0), 4),
			Color(0.75, 0.82, 0.9, 0.5).lerp(AMBER, clampf(_fresh, 0.0, 1.0)))


func _draw_ring() -> void:
	if _strain <= 0.0:
		return
	var col := Color(1, 1, 1, 0.5).lerp(Color(1.0, 0.2, 0.1, 0.95), smoothstep(0.5, 0.95, _strain))
	_ring.draw_arc(Vector2.ZERO, 16.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(_strain, 0.0, 1.0), 40, col, 3.0)
	if _arms < 0.7:
		var ac := Color(0.55, 0.8, 1.0, 0.7).lerp(Color(1.0, 0.55, 0.1, 0.9), smoothstep(0.4, 0.1, _arms))
		_ring.draw_arc(Vector2.ZERO, 10.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(_arms, 0.0, 1.0), 32, ac, 2.0)
	if _wear > 0.02:
		_ring.draw_arc(Vector2.ZERO, 21.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(_wear, 0.0, 1.0), 40,
				Color(1.0, 0.3, 0.2, 0.9), 2.0)


func follow(player: Node) -> void:
	player.connect("prompt_changed", _on_prompt)
	_on_prompt("")
	if not Settings.device_changed.is_connected(_on_device):
		Settings.device_changed.connect(_on_device)


## The pad picked up or put down: the prompt and the notice said again in its keys.
func _on_device() -> void:
	_on_prompt(_prompt_raw)
	_fit(_note, Settings.say(_note_raw), [BODY, SMALL])


## The prompt: "words" (the key's E), or "KEY|words" for another key or the mouse.
func _on_prompt(text: String) -> void:
	_prompt_raw = text
	var parts := text.split("|", true, 1)
	_key.text = Pad.cap(parts[0] if parts.size() == 2 else "E", Settings.pad)
	_what.text = Settings.say(parts[1] if parts.size() == 2 else text)
	_prompt.visible = not text.is_empty()
