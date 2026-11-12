extends "res://tuna/minigames/minigame.gd"
## Ride him: he's running. A tension needle you lift by holding B and let fall by letting go; keep it in his moving
## green band. In it he tires fast and takes least; under it he pours line off; over it the line's hurt.
## Mirrored: the bar's the other way round. Twist: he darts (the band moves in sudden slides).

const ACC := 3.2
const VMAX := 1.1

var needle := 0.35
var vel := 0.0
var band_c := 0.5
var band_w := 0.16
var inside := false
var _w1 := 1.0
var _ph1 := 0.0
var _ph2 := 0.0
var _dart := 0.0
var _dart_to := 0.0
var _dart_in := 1.5


func _init() -> void:
	id = "ride"
	title = "RIDE THE RUN"
	moves = ["run", "surge"]
	length = 5.5


func _begin() -> void:
	length = rng.randf_range(4.6, 6.0) * (1.5 if big else 1.0)
	band_w = lerpf(0.19, 0.115, tier)
	_w1 = lerpf(0.9, 1.5, tier) * fast
	_ph1 = rng.randf() * TAU
	_ph2 = rng.randf() * TAU
	needle = 0.35
	vel = 0.0
	_dart_in = rng.randf_range(1.2, 2.0)
	_band()


func _band() -> void:
	band_c = clampf(0.55 + 0.19 * sin(t * _w1 + _ph1) + 0.08 * sin(t * _w1 * 2.3 + _ph2) + _dart, band_w + 0.04, 0.96 - band_w)


func _step(dt: float, _a: bool, b: bool, _a_hit: bool, _b_hit: bool) -> void:
	if twist:
		_dart_in -= dt
		if _dart_in <= 0.0:
			_dart_in = rng.randf_range(1.1, 1.9)
			_dart_to = rng.randf_range(0.12, 0.2) * (1.0 if _dart_to <= 0.0 else -1.0)
		_dart = move_toward(_dart, _dart_to, 0.6 * dt)
	_band()
	vel = clampf(vel + (ACC if b else -ACC) * dt, -VMAX, VMAX)
	needle += vel * dt
	if needle <= 0.0 or needle >= 1.0:
		needle = clampf(needle, 0.0, 1.0)
		vel = 0.0
	var off := needle - band_c
	inside = absf(off) <= band_w
	tension = 0.25 + 0.5 * needle
	pose = 0.4 + 0.5 * needle
	if inside:
		gain = 1.0
		tire = 1.0
	elif off > 0.0:
		gain = 0.8
		tire = 0.45
		fray = clampf((off - band_w) / 0.2, 0.2, 1.0)
		tension = 0.95
	else:
		gain = -clampf((-off - band_w) / 0.2, 0.25, 1.0)
		tire = 0.15
	if live():
		_max += dt
		if inside:
			_pts += dt


func cue() -> Array:
	return [Kit.NONE, Kit.HOLD if needle < band_c else Kit.RELEASE]


func hint() -> Dictionary:
	return {"a": false, "b": needle + vel * 0.16 < band_c}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	var u := unit(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.9
	var h := 16.0 * u
	var x0 := c.x - w * 0.5
	var bar := Rect2(x0, c.y - h * 0.5 + 6.0 * u, w, h)
	var at := func(v: float) -> float: return x0 + w * (1.0 - v if mirror else v)
	kit.pill(ci, bar, Kit.TRACK)
	# the ends: slack one side, parting the other
	var slack_x := at.call(0.0) as float
	var snap_x := at.call(1.0) as float
	kit.dot(ci, Vector2(slack_x + (h * 0.5 if not mirror else -h * 0.5), bar.get_center().y), h * 0.26, Color(Kit.TEAL, 0.7))
	kit.dot(ci, Vector2(snap_x + (-h * 0.5 if not mirror else h * 0.5), bar.get_center().y), h * 0.26, Color(Kit.CORAL, 0.8))
	# his band
	var bx := at.call(band_c) as float
	var bw := band_w * w
	var band := Rect2(bx - bw, bar.position.y, bw * 2.0, h)
	if inside:
		kit.glow(ci, band.get_center(), bw * 1.3, Kit.GO, 1.2)
	kit.pill(ci, band, Color(Kit.GO, 0.95 if inside else 0.5))
	kit.fish(ci, Vector2(bx, bar.position.y - 13.0 * u + sin(time * 9.0) * 1.5 * u), 30.0 * u, Kit.GO if inside else Kit.FOAM, -1.0 if mirror else 1.0)
	# your needle
	var nx := at.call(needle) as float
	var col := Kit.FOAM if inside else (Kit.CORAL if needle > band_c else Kit.TEAL)
	kit.line(ci, Vector2(nx, bar.position.y - 5.0 * u), Vector2(nx, bar.end.y + 5.0 * u), col, 4.0 * u)
	kit.dot(ci, Vector2(nx, bar.end.y + 9.0 * u), 4.5 * u, col)
	if not inside:
		# which way to take it
		var way := signf((at.call(band_c) as float) - nx)
		for i in 3:
			var k := fposmod(time * 2.5 + i / 3.0, 1.0)
			kit.chevron(ci, Vector2(nx + way * (9.0 + 16.0 * k) * u, bar.end.y + 9.0 * u), 7.0 * u, Vector2(way, 0.0), Color(col, 1.0 - k), 2.0)
