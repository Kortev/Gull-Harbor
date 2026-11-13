extends "res://tuna/minigames/minigame.gd"
## He charges the boat: the line goes slack. Hammer A to wind it tight as fast as he comes; a belly of slack in the
## water and the hook falls out.

const FILL := 1.3            # s for the slack to fill with nobody winding

var slack_n := 0.0
var _need := 3.0


func _init() -> void:
	id = "charge"
	title = "HE'S COMING: WIND!"
	moves = ["charge"]
	only = true
	length = 3.6
	lead = 0.5


func _begin() -> void:
	length = rng.randf_range(3.0, 4.0)
	_need = lerpf(2.4, 4.0, tier)
	slack_n = 0.0


func _step(dt: float, a: bool, _b: bool, a_hit: bool, _b_hit: bool) -> void:
	var fill := 1.0 / FILL
	slack_n += fill * dt * (1.0 if live() else 0.5)
	if a_hit:
		slack_n -= fill / _need
	if a:
		slack_n -= fill * 0.3 * dt
	slack_n = clampf(slack_n, 0.0, 1.0)
	var keep := 1.0 - slack_n
	slack = slack_n
	gain = keep * 2.0 - 1.0
	tire = 0.5 * keep
	tension = 0.1 + 0.2 * keep
	pose = 0.25
	if slack_n > 0.7:
		hook = 0.7
	if live():
		_pts += keep * dt
		_max += dt


func cue() -> Array:
	return [Kit.MASH, Kit.NONE]


func hint() -> Dictionary:
	return {"a": fposmod(t, 0.14) < 0.07, "b": false}


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	# the boat and the orange fish on a ruled waterline, the line between them a path that sags (and goes orange) as
	# it slackens; a short ruler on top for how tight you've got it.
	var u := unit(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.9
	var sea_y := c.y + 30.0 * u
	var k := clampf(t / length, 0.0, 1.0)
	kit.rule(ci, Vector2(c.x - w * 0.5, sea_y), Vector2(c.x + w * 0.5, sea_y))
	var bx := c.x - w * 0.4
	kit.boat(ci, Vector2(bx, sea_y - 7.0 * u), 44.0 * u, Kit.PAPER, -1.0)
	var tip := Vector2(bx + 22.0 * u, sea_y - 44.0 * u)
	kit.rule(ci, Vector2(bx + 6.0 * u, sea_y - 14.0 * u), tip)
	var fx := lerpf(c.x + w * 0.44, c.x - w * 0.05, k)
	var fish_at := Vector2(fx, sea_y + 12.0 * u)
	var slackly := slack_n > 0.6
	var pts := PackedVector2Array()
	for i in 25:
		var s := i / 24.0
		var p := tip.lerp(fish_at + Vector2(-20.0 * u, 0.0), s)
		p.y += 4.0 * s * (1.0 - s) * (4.0 + 60.0 * slack_n) * u
		pts.append(p)
	kit.path(ci, pts, Kit.ORANGE if slackly else Kit.PAPER, slackly)
	kit.fish(ci, fish_at, 36.0 * u, Kit.ORANGE, -1.0)
	for i in 3:
		var kk := fposmod(time * 3.0 + i / 3.0, 1.0)
		if kk < 0.7:
			kit.rule(ci, fish_at + Vector2((24.0 + 26.0 * kk) * u, (i - 1) * 7.0 * u), fish_at + Vector2((34.0 + 26.0 * kk) * u, (i - 1) * 7.0 * u))
	# tightness: a ruler, drawn heavy along as the line comes tight
	var ra := Vector2(c.x - w * 0.5, rect.position.y + 8.0 * u)
	var rb := Vector2(c.x + w * 0.5, ra.y)
	kit.scale(ci, ra, rb, 20, 5, Kit.PAPER, 1.0, 5.0 * u, 10.0 * u)
	var keep := 1.0 - slack_n
	if keep > 0.01:
		kit.rule(ci, ra, ra.lerp(rb, keep), Kit.ORANGE if slackly else Kit.PAPER, true)
	kit.tri(ci, ra.lerp(rb, keep) + Vector2(0.0, 12.0 * u), 13.0 * u, Vector2.UP, Kit.ORANGE if slackly else Kit.PAPER)
