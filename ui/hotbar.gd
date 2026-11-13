extends Control
## The hotbar, bottom middle: your kit (crew/kit.gd) as five little pixel pictures, no words; what's in your hands is
## lit and stands up a little out of the row. Over it, while you wind up a throw or a cast, a bar filling (how hard
## it'll go). crew/hands.gd owns it. It's only there while you're picking: a few seconds after you change what's in
## your hands it fades away (to a ghost while you hold something, gone with empty hands), and comes back on the next
## pick.

const Kit := preload("res://crew/kit.gd")
const Ink := preload("res://ui/kit.gd")
const NAMES := {"knife": "Knife", "gaff": "Gaff", "jig": "Jig rod", "scoop": "Chum scoop", "bait": "Live mackerel",
		"dead": "Dead mackerel", "whistle": "Tin whistle"}
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
	"whistle": [
		"................", "................", ".............ak.", "............asd.",
		"...........asd..", "..........akd...", ".........asd....", "........asd.....",
		".......akd......", "......asd.......", ".....asd........", "....akd.........",
		"...ggd..........", "..ggg...........", "..gg............", "................",
	],
}

var hands: Node               # crew/hands.gd
var ink := Ink.new()          # the fight's linework and type (ui/kit.gd): the hotbar is drawn in it, no slots
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
	var p := clampf(get_viewport().get_visible_rect().size.y / 1080.0, 0.7, 2.5)
	ink.px = p
	ink.defer = true
	var cell := CELL * p
	var gap := GAP * p
	var n := Kit.ITEMS.size()
	var w := n * cell + (n - 1) * gap
	var held := str(hands.get("item"))
	var stowed := bool(hands.call("stowed"))
	for i in n:
		var it := Kit.ITEMS[i]
		var up := smoothstep(0.0, 1.0, float(_lift.get(it, 0.0)))
		var r := Rect2(Vector2(roundf(-w * 0.5 + i * (cell + gap)), -roundf(6.0 * p * up)), Vector2(cell, cell))
		var a := 0.45 if stowed else 1.0
		# no slot: the picture stands on the world, what's in your hands in a frame of yellow corner ticks
		var tex := _icons["scoop_full" if it == "scoop" and bool(hands.get("scoop_full")) else it] as Texture2D
		var tint := Color(0.7, 0.74, 0.78, 0.8 * a).lerp(Color(1, 1, 1, a), up)
		if it == "bait" and str(hands.call("carrying")) == "dead":
			tint *= Color(0.6, 0.58, 0.56)        # (a dead one in your fist: dull)
		var pad := 8.0 * p
		draw_texture_rect(tex, Rect2(r.position + Vector2(pad, pad), Vector2(cell - pad * 2.0, cell - pad * 2.0)), false, tint)
		if up > 0.5:
			ink.corners(self, r, 10.0 * p, Color(Ink.YELLOW, a), false)
		# its key, small in the corner; how many you've got where that matters (chum scoops left, live bait in the well)
		ink.text(self, r.position + Vector2(8.0 * p, 7.0 * p), str(i + 1), 12.0 * p, Color(Ink.PAPER, a), -1, 600, 0.0, false)
		var have := _count(it)
		if have >= 0:
			ink.num(self, r.position + Vector2(cell - 4.0 * p, cell - 8.0 * p), str(have), 16.0 * p,
					Color(Ink.ORANGE if have == 0 else Ink.PAPER, a), 1)
	# what you've just picked, named once over the bar (it fades with it)
	if held != "" and _shown > 0.0:
		var named := str(hands.call("net_item"))
		var fade := clampf(_shown / 0.6, 0.0, 1.0)
		ink.label(self, Vector2(0.0, -22.0 * p), str(NAMES.get(named, named)), 15.0 * p, Color(Ink.PAPER, fade))
	# winding up: how hard it'll go (the scoop's throw, or a rod's cast: rods.gd's wind on your rod)
	var wind := float(hands.get("wind"))
	var spread: Node = null
	var pl: Node = hands.get("player")
	var boat: Node = pl.get("boat") if pl else null
	var sea: Node = boat.get("sea") if boat else null
	spread = sea.get("rods") if sea else null
	var mine: Node = spread.call("held_by", str(pl.name).to_int()) if spread else null
	if mine:
		wind = float(mine.get("wind"))
	var landing: Node = sea.get("landing") if sea else null
	if landing != null and int(landing.get("harpoon_holder")) == str(pl.name).to_int():
		wind = float(landing.get("draw"))       # (the harpoon wound up to throw)
	if wind > 0.0:
		_shown = maxf(_shown, 0.5)
		var x0 := -60.0 * p
		var x1 := 60.0 * p
		var y := -44.0 * p
		ink.scale(self, Vector2(x0, y), Vector2(x1, y), 12, 4, Ink.PAPER, -1.0, 4.0 * p, 8.0 * p)
		ink.rule(self, Vector2(x0, y), Vector2(lerpf(x0, x1, wind), y), Ink.ORANGE if wind > 0.85 else Ink.YELLOW, true)
	ink.flush()
	ink.defer = false


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
			return int(hold.get("well"))
	return -1
