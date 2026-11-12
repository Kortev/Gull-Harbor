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


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	var u := unit(rect)
	var c := rect.get_center()
	if not fired:
		var k := Kit.beat(time, 2.4)
		var grow := Kit.out_back(t / 0.3)
		kit.glow(ci, c, 70.0 * u, Kit.GOLD, 1.0 + k)
		for i in 3:
			var kk := fposmod(time * 1.2 + i / 3.0, 1.0)
			kit.ring(ci, c, (58.0 - 34.0 * kk) * u, Color(Kit.GOLD, kk * 0.9), 2.5 * u)
		kit.text_pop(ci, c + Vector2(0.0, -8.0 * u), "BIG PULL", 30.0 * u, Kit.GOLD, grow * (1.0 + 0.06 * k))
		kit.text(ci, c + Vector2(0.0, 22.0 * u), "PRESS!", 16.0 * u, Kit.FOAM, 0, 700, 2.0)
		# the fuse: it goes by itself
		var w := rect.size.x * 0.5
		kit.meter(ci, Rect2(c.x - w * 0.5, rect.end.y - 8.0 * u, w, 4.0 * u), 1.0 - t / AUTO, Kit.GOLD)
	else:
		# him, coming in fast
		var k := Kit.out_cubic(_ft / AFTER)
		var fx := lerpf(c.x + rect.size.x * 0.42, c.x - rect.size.x * 0.2, k)
		for i in 5:
			var y := c.y + (i - 2) * 9.0 * u
			kit.line(ci, Vector2(fx + 26.0 * u, y), Vector2(fx + (40.0 + 60.0 * (1.0 - k)) * u, y), Color(Kit.GOLD, 0.6 * (1.0 - k)), 2.5 * u)
		kit.fish(ci, Vector2(fx, c.y), 50.0 * u, Kit.GOLD, -1.0)
		kit.boat(ci, Vector2(c.x - rect.size.x * 0.4, c.y + 4.0 * u), 36.0 * u, Kit.FOAM, -1.0)
