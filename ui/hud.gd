extends CanvasLayer
## The whole HUD, kept minimal, and shown rather than said. A dot in the middle of the view, and under it the key
## and a word or two for what's under it. In a fight: the ring round the dot fills and reddens with the strain (a thin
## inner one for your arms once they start to go, a thin red outer one for the line wearing on the hull), a word or
## two on what to do, and under that the metres to boatside (green winning, red losing) and the fish's fight left.
## Top left the trip: the quota as a bar (what's aboard ghosted on), the day, the fish box as pips. At the wheel her
## knots and a throttle bar; with a fish on, the plotter. Notices, a few words, top middle, and fade.

## The one type scale: small (numbers, the tally), body (prompts, notices, readouts), big (the fight's word).
const SMALL := 14
const BODY := 17
const BIG := 21
## Line out when a fish is alongside (tuna/fight.gd's BOATSIDE).
const BOATSIDE := 7.0
const CREAM := Color(0.95, 0.93, 0.88)
const GREEN := Color(0.55, 1.0, 0.55)
const AMBER := Color(1.0, 0.75, 0.35)
const RED := Color(1.0, 0.4, 0.3)

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
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.35)
	box.border_color = Color(CREAM, 0.8)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 6
	box.content_margin_right = 6
	cap.add_theme_stylebox_override("panel", box)
	_prompt.add_child(cap)
	_key = _label(SMALL, CREAM)
	_key.text = "E"
	cap.add_child(_key)
	_what = _label(BODY, CREAM)
	_prompt.add_child(_what)
	_prompt.visible = false
	_tell = _label(BIG, CREAM)
	_tell.set_anchors_preset(Control.PRESET_CENTER)
	_tell.position += Vector2(-360, 56)
	_tell.size = Vector2(720, 30)
	_tell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_note.position += Vector2(-300, 40)
	_note.size = Vector2(600, 30)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_note)
	_tally = Control.new()
	_tally.position = Vector2(18, 16)
	_tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tally.draw.connect(_draw_tally)
	add_child(_tally)
	_helm = Control.new()
	_helm.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_helm.position += Vector2(0, -34)
	_helm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_helm.draw.connect(_draw_helm)
	add_child(_helm)
	_plot = Control.new()
	_plot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_plot.position += Vector2(0, -160)
	_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plot.draw.connect(_draw_plot)
	add_child(_plot)


## A label in the HUD's one style: cream with a soft shadow.
static func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func _text(on: Control, at: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT,
		width := -1.0) -> void:
	var f := ThemeDB.fallback_font
	on.draw_string(f, at + Vector2(1, 1), text, align, width, size, Color(0, 0, 0, 0.8 * col.a))
	on.draw_string(f, at, text, align, width, size, col)


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
	var r := 90.0
	_plot.draw_circle(Vector2.ZERO, r + 6.0, Color(0.02, 0.05, 0.06, 0.45))
	_plot.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.6, 0.9, 0.8, 0.25), 1.0)
	# the danger: forward of her beam the line's on the hull
	_plot.draw_arc(Vector2.ZERO, r * 0.35, PI * 1.5 - 1.4, PI * 1.5 + 1.4, 24, Color(1.0, 0.3, 0.2, 0.35), 3.0)
	# her, bow up
	var hull := PackedVector2Array([Vector2(0, -22), Vector2(8, -8), Vector2(8, 14), Vector2(-8, 14), Vector2(-8, -8),
			Vector2(0, -22)])
	_plot.draw_polyline(hull, Color(0.9, 0.95, 0.9, 0.85), 2.0)
	var stern := Vector2(0, 14)
	for f: Array in _fish:
		var b := float(f[0])
		var d := clampf(log(1.0 + float(f[1]) / 6.0) / log(1.0 + 300.0 / 6.0), 0.12, 1.0) * r
		var at := stern + Vector2(sin(b), cos(b)) * d
		var hot := float(f[2])
		var col := Color(0.95, 0.9, 0.6).lerp(Color(1.0, 0.25, 0.15), hot)
		_plot.draw_line(stern, at, Color(col, 0.6), 1.0)
		_plot.draw_circle(at, 5.0, col)


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
	var w := 80.0
	_text(_helm, Vector2(-60, -12), "%d kn" % roundi(_knots), BODY, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	_helm.draw_rect(Rect2(-w, 0, w * 2.0, 6), Color(0, 0, 0, 0.4))
	var t := clampf(_throttle, -1.0, 1.0)
	if t > 0.0:
		_helm.draw_rect(Rect2(0, 0, w * t, 6), Color(GREEN, 0.85))
	elif t < 0.0:
		_helm.draw_rect(Rect2(w * t, 0, -w * t, 6), Color(AMBER, 0.9))
	_helm.draw_line(Vector2(0, -3), Vector2(0, 9), Color(CREAM, 0.9), 2.0)


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
	var w := 200.0
	var quota := maxf(float(_trip["quota"]), 1.0)
	var earned := float(_trip["earned"])
	var made := earned >= quota
	_text(_tally, Vector2(0, 12), "%s / %s" % [_trip["earned_text"], _trip["quota_text"]], SMALL,
			Color(GREEN if made else CREAM, 0.9))
	_text(_tally, Vector2(0, 12), "Day %d/%d" % [int(_trip["day"]), int(_trip["days"])], SMALL, Color(CREAM, 0.75),
			HORIZONTAL_ALIGNMENT_RIGHT, w)
	_tally.draw_rect(Rect2(0, 20, w, 6), Color(0, 0, 0, 0.5))
	var aboard := clampf((earned + float(_trip["aboard"])) / quota, 0.0, 1.0)
	_tally.draw_rect(Rect2(0, 20, w * aboard, 6), Color(1, 1, 1, 0.5))
	_tally.draw_rect(Rect2(0, 20, w * clampf(earned / quota, 0.0, 1.0), 6), Color(GREEN if made else AMBER, 0.85))
	# the fish box, a pip a place (filled once iced), and any still on deck after it
	var x := 0.0
	for i in int(_trip["cap"]):
		var r := Rect2(x, 34, 10, 10)
		if i < int(_trip["box"]):
			_tally.draw_rect(r, Color(0.7, 0.9, 1.0, 0.9))
		else:
			_tally.draw_rect(r, Color(0.7, 0.9, 1.0, 0.5), false, 1.0)
		x += 14.0
	for i in int(_trip["deck"]):
		_tally.draw_rect(Rect2(x + 6.0, 34, 10, 10), Color(AMBER, 0.9))
		x += 14.0


## A few words at the top for a few seconds ("Fish on!").
func notify(text: String) -> void:
	_note.text = text
	_note.modulate.a = 1.0
	_note_t = 4.0


func _process(delta: float) -> void:
	_note_t -= delta
	_note.modulate.a = clampf(_note_t, 0.0, 1.0)


## In a fight: what to do ("Crank") and the strain 0..1 ("" and 0 when there's no fight: then `tell` is what wants
## doing, if anything). `arms`: yours, 0..1. `line`: metres out (< 0 hides the meter), `gain`: how fast you're winning
## it back (m/s, - while it takes line), `fresh`: the fish, 1 fresh .. 0 beat. `wear`: the line's wear on the hull,
## 0..1.
func fight(tell: String, strain: float, arms := 1.0, line := -1.0, gain := 0.0, fresh := 1.0, wear := 0.0) -> void:
	_tell.text = tell
	_tell.add_theme_color_override("font_color", _tell_colour(tell))
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


## The prompt: "words" (the key's E), or "KEY|words" for another key or the mouse.
func _on_prompt(text: String) -> void:
	var parts := text.split("|", true, 1)
	_key.text = parts[0] if parts.size() == 2 else "E"
	_what.text = parts[1] if parts.size() == 2 else text
	_prompt.visible = not text.is_empty()
