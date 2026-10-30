extends Control
## The hotbar, bottom middle: your kit (crew/kit.gd) as five little pictures, no words; what's in your hands is lit.
## Over it, while you wind up a throw or a cast, a bar filling (how hard it'll go). crew/hands.gd owns it.
## It's only there while you're picking: a few seconds after you change what's in your hands it fades away (to a
## ghost while you hold something, gone with empty hands), and comes back on the next pick.

const Kit := preload("res://crew/kit.gd")
const NAMES := {"knife": "Knife", "gaff": "Gaff", "jig": "Jig rod", "scoop": "Chum scoop", "bait": "Bait"}
const CELL := 46.0
const GAP := 6.0

var hands: Node               # crew/hands.gd
var _held := "?"
var _shown := 0.0             # s left fully shown


func _init() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -64.0
	offset_bottom = -64.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if hands == null:
		return
	var held := str(hands.get("item"))
	if held != _held:
		_held = held
		_shown = 2.5
	_shown -= delta
	var want := 1.0 if _shown > 0.0 else (0.3 if held != "" else 0.0)
	modulate.a = move_toward(modulate.a, want, delta * (4.0 if want > modulate.a else 1.5))


func _draw() -> void:
	if hands == null:
		return
	var n := Kit.ITEMS.size()
	var w := n * CELL + (n - 1) * GAP
	var held := str(hands.get("item"))
	var stowed := bool(hands.call("stowed"))
	for i in n:
		var r := Rect2(Vector2(-w * 0.5 + i * (CELL + GAP), 0.0), Vector2(CELL, CELL))
		var on := Kit.ITEMS[i] == held
		var a := 0.35 if stowed else 1.0
		draw_rect(r, Color(0.05, 0.07, 0.08, (0.62 if on else 0.4) * a))
		draw_rect(r, Color(1.0, 0.86, 0.5, 0.95 * a) if on else Color(1, 1, 1, 0.18 * a), false, 2.0 if on else 1.0)
		_icon(Kit.ITEMS[i], r.get_center(), Color(1, 1, 1, (0.95 if on else 0.6) * a))
		# its key, small in the corner; how many you've got where that matters (chum scoops left, live bait in the well)
		var font := get_theme_default_font()
		draw_string(font, r.position + Vector2(4, 12), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(1, 1, 1, 0.45 * a))
		var have := _count(Kit.ITEMS[i])
		if have >= 0:
			draw_string(font, r.position + Vector2(0, CELL - 4), str(have), HORIZONTAL_ALIGNMENT_RIGHT, CELL - 4, 12,
					Color(1, 1, 1, 0.8 * a))
	# what you've just picked, named once over the bar (it fades with it)
	if held != "" and _shown > 0.0:
		draw_string(get_theme_default_font(), Vector2(-w * 0.5, -10), str(NAMES.get(held, held)),
				HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(1.0, 0.92, 0.7, clampf(_shown / 0.6, 0.0, 1.0)))
	# winding up: how hard it'll go (the scoop's throw, or a rod's cast: rods.gd's wind on your rod)
	var wind := float(hands.get("wind"))
	var spread: Node = null
	var p: Node = hands.get("player")
	var boat: Node = p.get("boat") if p else null
	var sea: Node = boat.get("sea") if boat else null
	spread = sea.get("rods") if sea else null
	var mine: Node = spread.call("held_by", str(p.name).to_int()) if spread else null
	if mine:
		wind = float(mine.get("wind"))
	if wind > 0.0:
		_shown = maxf(_shown, 0.5)
		var bar := Rect2(Vector2(-60.0, -16.0), Vector2(120.0, 6.0))
		draw_rect(bar, Color(0, 0, 0, 0.45))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * wind, bar.size.y)),
				Color(1.0, 0.86, 0.5).lerp(Color(1.0, 0.45, 0.2), wind))


## How many of `item` you've got, where it matters (-1: it doesn't): chum scoops left in the bucket, live mackerel
## in the well for the bait.
func _count(item: String) -> int:
	var p: Node = hands.get("player")
	var boat: Node = p.get("boat") if p else null
	var sea: Node = boat.get("sea") if boat else null
	var hold: Node = sea.get("fish_hold") if sea else null
	if hold == null:
		return -1
	match item:
		"scoop":
			return int(hold.get("chum"))
		"bait":
			return int(hold.get("well")) if bool(hold.call("has_gear", "bait")) else -1
	return -1


## Each item drawn in a few strokes, about 30 px across.
func _icon(item: String, c: Vector2, col: Color) -> void:
	match item:
		"knife":
			draw_line(c + Vector2(-13, 10), c + Vector2(-4, 1), col.darkened(0.5), 5.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 2), c + Vector2(13, -14), c + Vector2(-1, 5)]), col)
		"gaff":
			draw_line(c + Vector2(-14, 14), c + Vector2(8, -8), col, 3.0)
			draw_arc(c + Vector2(8, -2), 6.0, -PI * 0.5, PI * 0.7, 10, col, 2.5)
		"jig":
			draw_line(c + Vector2(-14, 14), c + Vector2(12, -14), col, 2.0)
			draw_circle(c + Vector2(-8, 8), 3.5, col)
			draw_line(c + Vector2(12, -14), c + Vector2(12, 12), Color(col, col.a * 0.6), 1.0)
			for k in 3:
				draw_line(c + Vector2(12, -2 + k * 5), c + Vector2(15, 0 + k * 5), col, 1.5)
		"scoop":
			draw_line(c + Vector2(-14, -10), c + Vector2(0, 2), col, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 0), c + Vector2(14, 0), c + Vector2(11, 9),
					c + Vector2(1, 9)]), col)
			if bool(hands.get("scoop_full")):
				draw_rect(Rect2(c + Vector2(0, -3), Vector2(12, 3)), Color(0.6, 0.22, 0.14, col.a))
		"bait":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 0), c + Vector2(-2, -6), c + Vector2(8, -2),
					c + Vector2(8, 2), c + Vector2(-2, 6)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(8, 0), c + Vector2(14, -6), c + Vector2(14, 6)]), col)
			draw_circle(c + Vector2(-8, -1), 1.3, Color(0, 0, 0, col.a))
