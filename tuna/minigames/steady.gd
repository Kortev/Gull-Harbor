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


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	var u := unit(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.84
	var y := rect.position.y + 20.0 * u
	var x0 := c.x - w * 0.5
	var bar := Rect2(x0, y - 6.0 * u, w, 12.0 * u)
	kit.pill(ci, bar, Kit.TRACK)
	kit.dot(ci, Vector2(bar.position.x + 6.0 * u, y), 3.2 * u, Color(Kit.CORAL, 0.8))
	kit.dot(ci, Vector2(bar.end.x - 6.0 * u, y), 3.2 * u, Color(Kit.CORAL, 0.8))
	var zone := Rect2(c.x - w * 0.5 * ZONE, bar.position.y, w * ZONE, bar.size.y)
	if inside:
		kit.glow(ci, zone.get_center(), w * ZONE * 0.7, Kit.GO, 1.0)
	kit.pill(ci, zone, Color(Kit.GO, 0.95 if inside else 0.5))
	# the rod, from your hands up to its tip
	var tip := Vector2(c.x + x * w * 0.5, y)
	var butt := Vector2(c.x, rect.end.y + 2.0 * u)
	var col := Kit.FOAM if inside else (Kit.CORAL if absf(x) > 0.8 else Kit.GOLD)
	var pts := PackedVector2Array()
	for i in 13:
		var s := i / 12.0
		pts.append(butt.lerp(Vector2(c.x, y), s) + Vector2((tip.x - c.x) * s * s, 0.0))
	kit.polyline(ci, pts, Color(col, 0.9), 3.5 * u)
	kit.dot(ci, tip, 7.5 * u, col)
	kit.dot(ci, tip, 3.0 * u, Kit.DEEP)
	# which way to knock it, and the knocks you've given it
	for s in 2:
		var way := s * 2.0 - 1.0
		var need := (x > 0.05) if s == 0 else (x < -0.05)
		var px := c.x + way * (w * 0.5 - 14.0 * u)
		var k := clampf(1.0 - float(_tap_t[s]) / 0.2, 0.0, 1.0)
		var cc := Color(Kit.GOLD if need else Kit.FOAM, 1.0 if need else 0.2)
		for i in 2:
			var kk := fposmod(time * 2.5 + i * 0.5, 1.0) if need else 0.5
			kit.chevron(ci, Vector2(px + way * (kk - 0.5) * 12.0 * u - way * k * 6.0 * u, c.y + 22.0 * u), 15.0 * u, Vector2(way, 0.0),
					Color(cc, cc.a * (1.0 - absf(kk - 0.5) * 1.2)), 3.5 * u)
