extends "res://tuna/minigames/minigame.gd"
## Keep the rod tip steady: he's yanking it about and it wants to fall away to one side. Tap A to knock it left, B
## to knock it right; keep it in the green in the middle. Out at the ends the line's hurt. Twist: bigger yanks.

const KNOCK := 0.62          # what a tap puts into it
const FALL := 2.4            # how hard it falls away from the middle
const ZONE := 0.3

var x := 0.0
var v := 0.0
var inside := true
var _yank_in := 1.0
var _push := 0.0
var _tap_t := [9.0, 9.0]


func _init() -> void:
	id = "steady"
	title = "STEADY THE TIP"
	moves = ["sound", "dog", "circle", "spiral"]
	from = 0.1
	length = 5.5
	lead = 0.6


func _begin() -> void:
	length = rng.randf_range(4.8, 6.0) * (1.4 if big else 1.0)
	x = 0.0
	v = (0.25 if rng.randf() < 0.5 else -0.25) * (-1.0 if mirror else 1.0)
	_yank_in = rng.randf_range(0.9, 1.5)
	_push = 0.0


func _step(dt: float, _a: bool, _b: bool, a_hit: bool, b_hit: bool) -> void:
	_tap_t[0] = float(_tap_t[0]) + dt
	_tap_t[1] = float(_tap_t[1]) + dt
	_yank_in -= dt
	if _yank_in <= 0.0:
		_yank_in = rng.randf_range(0.8, 1.5) / fast * lerpf(1.2, 0.8, tier)
		_push = (1.0 if rng.randf() < 0.5 else -1.0) * lerpf(0.5, 0.9, tier) * (1.4 if twist else 1.0)
	v += _push * 6.0 * dt
	_push = move_toward(_push, 0.0, 4.0 * dt)
	if a_hit:
		v -= KNOCK
		_tap_t[0] = 0.0
	if b_hit:
		v += KNOCK
		_tap_t[1] = 0.0
	# (it falls away from the middle, the further the faster; never back by itself)
	v += (x + 0.06 * signf(x if x != 0.0 else v)) * FALL * dt
	v *= exp(-1.6 * dt)
	x += v * dt
	if absf(x) >= 1.0:
		x = signf(x)
		v = 0.0
	inside = absf(x) <= ZONE
	var out := smoothstep(ZONE, 1.0, absf(x))
	gain = 1.0 if inside else lerpf(0.2, -1.0, out)
	tire = 1.0 if inside else 0.3
	tension = 0.4 + 0.3 * absf(x)
	pose = 0.6
	if absf(x) > 0.8:
		fray = 0.7
		tension = 0.95
	if live():
		_max += dt
		if inside:
			_pts += dt


func cue() -> Array:
	return [Kit.TAP if x > 0.05 else Kit.NONE, Kit.TAP if x < -0.05 else Kit.NONE]


func hint() -> Dictionary:
	var ahead := x + v * 0.3
	var on := fposmod(t, 0.1) < 0.05
	return {"a": on and ahead > 0.1, "b": on and ahead < -0.1}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, _time: float) -> void:
	# a ruler with its centre marked: the good a bracketed, hatched span round the middle (heavy while you are in it);
	# the tip a pointer under the ruler; orange hatching growing in from whichever end he is pulling it to.
	var u := unit(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.9
	var x0 := c.x - w * 0.5
	var x1 := c.x + w * 0.5
	var y := c.y + 14.0 * u
	kit.scale(ci, Vector2(x0, y), Vector2(x1, y), 40, 5, Kit.PAPER, 1.0, 5.0 * u, 11.0 * u)
	# the ends: where the line is hurt
	for s: float in [-1.0, 1.0]:
		kit.rule(ci, Vector2(c.x + s * w * 0.5, y - 24.0 * u), Vector2(c.x + s * w * 0.5, y + 11.0 * u), Kit.ORANGE, true)
	var hurt := smoothstep(ZONE, 1.0, absf(x))
	if hurt > 0.0:
		var span_len := w * 0.5 * (1.0 - ZONE) * hurt
		var ex := c.x + signf(x) * w * 0.5
		var r := Rect2(minf(ex, ex - signf(x) * span_len), y - 24.0 * u, span_len, 20.0 * u)
		kit.hatch(ci, r, Kit.ORANGE, absf(x) > 0.8)
	# the good
	var zone := Rect2(c.x - w * 0.5 * ZONE, y - 24.0 * u, w * ZONE, 20.0 * u)
	kit.span(ci, zone, Kit.YELLOW, inside)
	kit.hatch(ci, zone.grow_individual(-4.0 * u, -3.0 * u, -4.0 * u, -3.0 * u), Kit.YELLOW, inside)
	kit.rule(ci, Vector2(c.x, y - 30.0 * u), Vector2(c.x, y), Kit.PAPER)
	# the tip
	var tx := c.x + x * w * 0.5
	var col := Kit.ORANGE if (not inside and absf(x) > 0.8) else Kit.PAPER
	kit.rule(ci, Vector2(tx, y - 28.0 * u), Vector2(tx, y), col, true)
	kit.tri(ci, Vector2(tx, y + 2.0 * u), 15.0 * u, Vector2.UP, col)
