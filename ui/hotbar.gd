extends Control
## The hotbar, bottom middle: your kit (crew/kit.gd) as five little pixel pictures, no words; what's in your hands is
## lit and stands up a little out of the row. Over it, while you wind up a throw or a cast, a bar filling (how hard
## it'll go). crew/hands.gd owns it. It's only there while you're picking: a few seconds after you change what's in
## your hands it fades away (to a ghost while you hold something, gone with empty hands), and comes back on the next
## pick.

const Kit := preload("res://crew/kit.gd")
const NAMES := {"knife": "Knife", "gaff": "Gaff", "jig": "Jig rod", "scoop": "Chum scoop", "bait": "Bait"}
const CELL := 48.0
const GAP := 6.0
## Each item drawn 16 px square, doubled: a character a pixel, from PALETTE ("." left clear). The scoop's chum ("m",
## "M") only shows with a scoopful in it.
const PALETTE := {
	"w": Color8(235, 238, 240), "s": Color8(160, 168, 176), "d": Color8(90, 96, 104), "k": Color8(25, 25, 28),
	"h": Color8(225, 222, 210), "a": Color8(190, 195, 200), "f": Color8(40, 40, 44), "r": Color8(200, 40, 30),
	"o": Color8(205, 215, 222), "b": Color8(40, 90, 180), "B": Color8(25, 55, 120), "c": Color8(205, 160, 105),
	"C": Color8(150, 105, 60), "l": Color8(240, 240, 220), "p": Color8(240, 90, 140), "y": Color8(250, 215, 60),
	"g": Color8(80, 200, 110), "u": Color8(60, 95, 190), "U": Color8(35, 60, 130), "m": Color8(150, 40, 30),
	"M": Color8(110, 25, 20), "e": Color8(205, 165, 110), "G": Color8(40, 120, 115), "K": Color8(12, 30, 32),
	"S": Color8(215, 222, 228), "x": Color8(240, 244, 246), "i": Color8(10, 10, 10)
}
const SPRITES := {
	"knife": [
		"................", "..............x.", ".............xs.", "............xsd.",
		"...........xsd..", "..........xsd...", ".........xsd....", "........xsd.....",
		".......ksd......", "......kkk.......", ".....hhkk.......", "....hhh.........",
		"...hhh..........", "..hhh...........", "..hh............", "................",
	],
	"gaff": [
		"................", "...........ooo..", "..........o...o.", "..........o...o.",
		"...........o..o.", "..............o.", ".............o..", "............a...",
		"...........r....", "..........a.....", ".........a......", "........a.......",
		".......f........", "......ff........", ".....ff.........", "....ff..........",
	],
	"jig": [
		"..............d.", ".............d.l", "............d..l", "...........d...p",
		"..........d....l", ".........d.....y", "........d......l", ".......d.......g",
		"......c........l", "..bb.c.........s", ".bBBb..........s", ".bBbc...........",
		"..bc............", "..c.............", ".c..............", "c...............",
	],
	"scoop": [
		"................", "................", "..uuuuuu........", ".uUUUUUUu.......",
		".uUmMmmUu.......", "..uuuuuuS.......", "...uuuuu.e......", "..........e.....",
		"...........e....", "............e...", ".............r..", "..............e.",
		"...............e", "................", "................", "................",
	],
	"bait": [
		"................", "................", "................", "................",
		".....GGGGG......", "...GGKGKGKGG..GG", "..GxGKGKGKGKGGG.", ".SGiGGKGKGKGGGG.",
		"..SSSSSSSSSSG.GG", "...SSSSSSSSS...G", ".....SSSSS......", "................",
		"................", "................", "................", "................",
	],
}

var hands: Node               # crew/hands.gd
var _held := "?"
var _shown := 0.0             # s left fully shown
var _lift := {}               # item -> how far its slot's stood up, 0..1
var _icons := {}              # sprite name -> ImageTexture


func _init() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -64.0
	offset_bottom = -64.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for item: String in SPRITES:
		_icons[item] = _sprite(SPRITES[item] as Array, false)
	_icons["scoop_full"] = _sprite(SPRITES["scoop"] as Array, true)


## A sprite's pixels as a little texture (the chum left out unless `chum`: the cup's inside shows instead).
static func _sprite(rows: Array, chum: bool) -> ImageTexture:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			var ch := row[x]
			if ch in "mM" and not chum:
				ch = "U"
			if PALETTE.has(ch):
				img.set_pixel(x, y, PALETTE[ch])
	return ImageTexture.create_from_image(img)


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
	for item: String in Kit.ITEMS:
		_lift[item] = move_toward(float(_lift.get(item, 0.0)), 1.0 if item == held else 0.0, delta * 8.0)


func _draw() -> void:
	if hands == null:
		return
	var n := Kit.ITEMS.size()
	var w := n * CELL + (n - 1) * GAP
	var held := str(hands.get("item"))
	var stowed := bool(hands.call("stowed"))
	for i in n:
		var it := Kit.ITEMS[i]
		var up := smoothstep(0.0, 1.0, float(_lift.get(it, 0.0)))
		var r := Rect2(Vector2(roundf(-w * 0.5 + i * (CELL + GAP)), -roundf(6.0 * up)), Vector2(CELL, CELL))
		var a := 0.35 if stowed else 1.0
		# a dark slot with a hard 2 px frame, lit warm for the one in your hands
		draw_rect(r, Color(0.05, 0.07, 0.08, lerpf(0.42, 0.7, up) * a))
		draw_rect(r.grow(-2.0), Color(1, 1, 1, 0.04 * a), false, 2.0)
		draw_rect(r, Color(1, 1, 1, 0.2 * a).lerp(Color(1.0, 0.86, 0.5, 0.95 * a), up), false, 2.0)
		var tex := _icons["scoop_full" if it == "scoop" and bool(hands.get("scoop_full")) else it] as Texture2D
		var tint := Color(0.62, 0.66, 0.7, 0.75 * a).lerp(Color(1, 1, 1, a), up)
		draw_texture_rect(tex, Rect2(r.position + Vector2(8, 8), Vector2(32, 32)), false, tint)
		# its key, small in the corner; how many you've got where that matters (chum scoops left, live bait in the well)
		var font := get_theme_default_font()
		draw_string(font, r.position + Vector2(4, 12), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(1, 1, 1, 0.45 * a))
		var have := _count(it)
		if have >= 0:
			var tw := font.get_string_size(str(have), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_rect(Rect2(r.position + Vector2(CELL - tw - 7, CELL - 15), Vector2(tw + 5, 13)), Color(0.05, 0.07, 0.08, 0.8 * a))
			draw_string(font, r.position + Vector2(0, CELL - 4), str(have), HORIZONTAL_ALIGNMENT_RIGHT, CELL - 4, 12,
					Color(1, 1, 1, 0.85 * a))
	# what you've just picked, named once over the bar (it fades with it)
	if held != "" and _shown > 0.0:
		draw_string(get_theme_default_font(), Vector2(-w * 0.5, -14), str(NAMES.get(held, held)),
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
		var bar := Rect2(Vector2(-60.0, -22.0), Vector2(120.0, 6.0))
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
