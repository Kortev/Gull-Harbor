extends "res://tuna/minigames/minigame.gd"
## WORK IT CLEAR: the line's about to part on her hull, or go in her props, and this is the one chance to get it
## off her (tuna/fight_arcade.gd starts it in place of losing the fish; it's not in the registry). The two buttons
## turn about, wind and lean, wind and lean: NEED of them before the time's gone and it's off her; short of that
## the fish is lost the way it was going (`why`).

const NEED := 8
const TIME := 4.2

## How the fish goes if this is lost ("chafed", "cut"), set by the fight.
var why := "chafed"
var won := false
var taps := 0
var _next_a := true
var _flash := 0.0


func _init() -> void:
	id = "clear"
	title = "WORK IT CLEAR"
	length = TIME + 0.6
	lead = 0.6
	hitstop = false


func _begin() -> void:
	won = false
	taps = 0
	_next_a = true
	_flash = 0.0
	score = 0.0


func _step(dt: float, _a: bool, _b: bool, a_hit: bool, b_hit: bool) -> void:
	gain = 0.0
	tire = 0.0
	tension = 0.78
	pose = 0.3 + 0.6 * float(taps) / NEED
	_flash = maxf(_flash - dt * 6.0, 0.0)
	if won:
		if t >= _won_at + 0.5:
			done = true
		return
	if not live():
		return
	if (a_hit and _next_a) or (b_hit and not _next_a):
		taps += 1
		_next_a = not _next_a
		_flash = 1.0
		events.append(["hit", 1])
		if taps >= NEED:
			won = true
			score = 1.0
			_won_at = t
			events.append(["hit", 2])
	elif a_hit or b_hit:
		events.append(["near"])
	if t >= lead + TIME and not won:
		done = true


var _won_at := 0.0


func cue() -> Array:
	if won or not live():
		return [Kit.NONE, Kit.NONE]
	return [Kit.TAP, Kit.NONE] if _next_a else [Kit.NONE, Kit.TAP]


func hint() -> Dictionary:
	var on := live() and not won
	return {"a": on and _next_a, "b": on and not _next_a}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, _time: float) -> void:
	var u := unit(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.8
	var x0 := c.x - w * 0.5
	var k := float(taps) / NEED
	# what's wrong, in a word
	var word := "IN THE PROPS" if why == "cut" else "LINE ON THE HULL"
	kit.label(ci, Vector2(c.x, rect.position.y + 12.0 * u), "CLEAR" if won else word, 15.0 * u,
			Kit.YELLOW if won else Kit.ORANGE)
	# her side (a heavy corner) and the line bent over it: each turn of the buttons lifts it a step off her
	var top := rect.position.y
	var corner := Vector2(c.x - 6.0 * u, top + 42.0 * u)
	kit.path(ci, PackedVector2Array([Vector2(x0, corner.y), corner, Vector2(corner.x, top + 62.0 * u)]), Kit.PAPER, true)
	kit.hatch(ci, Rect2(x0, corner.y + 4.0 * u, corner.x - x0 - 4.0 * u, 15.0 * u), Kit.PAPER, false, 9.0 * u)
	var tip := Vector2(x0 + w * 0.12, top + 25.0 * u)
	var fish := Vector2(x0 + w * 0.93, top + 58.0 * u)
	var lift := Vector2(22.0, -12.0) * u * k
	var bend := corner + Vector2(2.0, -2.0) * u + lift
	var col := Kit.YELLOW if won else Kit.ORANGE
	kit.path(ci, PackedVector2Array([tip, bend, fish]), col, _flash > 0.5 or won)
	kit.fish(ci, fish + Vector2(8.0, 4.0) * u, 30.0 * u, Kit.ORANGE, -1.0)
	if not won:
		kit.diamond(ci, bend, 9.0 * u, Kit.ORANGE, _flash <= 0.5)
	# the turns done, and the time burning down
	var y := top + 90.0 * u
	var gap := 20.0 * u
	var sx := c.x - gap * (NEED - 1) * 0.5
	for i in NEED:
		kit.square(ci, Vector2(sx + gap * i, top + 75.0 * u), 10.0 * u, Kit.YELLOW if i < taps else Kit.PAPER, i < taps)
	kit.scale(ci, Vector2(x0, y), Vector2(x0 + w, y), 16, 4, Kit.PAPER, 1.0, 4.0 * u, 8.0 * u)
	if not won:
		var left := clampf(1.0 - (t - lead) / TIME, 0.0, 1.0)
		kit.rule(ci, Vector2(x0, y), Vector2(x0 + w * left, y), Kit.ORANGE, true)
		kit.tri(ci, Vector2(x0 + w * left, y - 2.0 * u), 11.0 * u, Vector2.DOWN, Kit.ORANGE)
