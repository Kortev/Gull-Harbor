extends "res://tuna/minigames/minigame.gd"
## The BIG PULL: what a combo's cashed in for (tuna/fight_arcade.gd gives it at every fifth step of the combo; it's
## not in the registry). One button, any button, and it can't be failed: left alone it goes off by itself. The fight
## turns its ["pull"] into a great chunk of line; the HUD into the whole screen.

const AUTO := 1.6            # s before it goes by itself
const AFTER := 1.0           # s of him coming in after it

## How big (1 at x5, 2 at x10...), set by the fight.
var level := 1
var fired := false
var _ft := 0.0


func _init() -> void:
	id = "pull"
	title = "BIG PULL"
	length = AUTO + AFTER + 0.5
	lead = 0.0


func _begin() -> void:
	fired = false
	_ft = 0.0
	score = 1.0


func _step(dt: float, _a: bool, _b: bool, a_hit: bool, b_hit: bool) -> void:
	gain = 0.3
	tire = 0.5
	if not fired:
		tension = 0.5 + 0.3 * clampf(t / AUTO, 0.0, 1.0)
		pose = 0.25
		if ((a_hit or b_hit) and t > 0.25) or t >= AUTO:
			fired = true
			_ft = 0.0
			events.append(["pull"])
	else:
		_ft += dt
		gain = 1.0
		tire = 1.0
		tension = 0.7
		pose = 1.0
		if _ft >= AFTER:
			done = true


func cue() -> Array:
	return [Kit.NONE, Kit.NONE] if fired else [Kit.TAP, Kit.TAP]


func hint() -> Dictionary:
	return {"a": not fired and t > 0.35 and t < 0.45, "b": false}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, _time: float) -> void:
	var u := unit(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.8
	var x0 := c.x - w * 0.5
	var y := c.y + 22.0 * u
	if not fired:
		# its name, and the fuse: a ruler burning down (it goes by itself)
		kit.num(ci, c + Vector2(0.0, -14.0 * u), "BIG PULL", 34.0 * u, Kit.YELLOW)
		kit.scale(ci, Vector2(x0, y), Vector2(x0 + w, y), 16, 4, Kit.PAPER, 1.0, 4.0 * u, 8.0 * u)
		var fx := x0 + w * clampf(1.0 - t / AUTO, 0.0, 1.0)
		kit.rule(ci, Vector2(x0, y), Vector2(fx, y), Kit.YELLOW, true)
		kit.tri(ci, Vector2(fx, y - 2.0 * u), 11.0 * u, Vector2.DOWN, Kit.YELLOW)
	else:
		# him, coming in along the ruler to the boat
		var k := Kit.out_cubic(_ft / AFTER)
		var fx := lerpf(x0 + w, x0 + w * 0.22, k)
		kit.scale(ci, Vector2(x0, y), Vector2(x0 + w, y), 16, 4, Kit.PAPER, 1.0, 4.0 * u, 8.0 * u)
		kit.rule(ci, Vector2(x0, y), Vector2(fx, y), Kit.PAPER, true)
		kit.boat(ci, Vector2(x0 - 2.0 * u, y - 9.0 * u), 30.0 * u, Kit.PAPER, 1.0)
		kit.fish(ci, Vector2(fx, y - 16.0 * u), 40.0 * u, Kit.ORANGE, -1.0)
