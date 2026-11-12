extends "res://tuna/minigames/minigame.gd"
## Follow my leader: he darts left, right, left... then it's your turn: repeat it, A for left and B for right. A
## wrong one ends the go. Twist: his darts come quicker.

const SHOW := 0.3           # s a dart
const GAP := 0.5             # s between his darts and your go

## What he did (0 left, 1 right), how many you've answered, and how each went (1 right, 2 wrong).
var seq := PackedByteArray()
var got := PackedByteArray()
var idx := 0
## "show" (he's darting), "go" (your turn), "end" (a moment to see how it went).
var phase := "show"
var _pt := 0.0
var _round := 0
var _rounds := 2
var _len0 := 3
var _show := 0.36


func _init() -> void:
	id = "mimic"
	title = "FOLLOW HIS LEAD"
	moves = ["shake", "circle", "sound"]
	can_boss = true
	length = 12.0
	lead = 0.0
	_rest = 0.0


func _begin() -> void:
	_len0 = 3 if tier < 0.45 else (4 if tier < 0.8 else 5)
	_rounds = 3 if big else (1 if tier < 0.3 else 2)
	_show = SHOW / fast * (0.8 if twist else 1.0)
	_round = 0
	_deal()


func _deal() -> void:
	seq = PackedByteArray()
	got = PackedByteArray()
	var n := _len0 + (mini(_round, 1) if _len0 < 5 else 0)
	for i in n:
		# (never three the same way running: it has to be a pattern, not a count)
		var s := rng.randi_range(0, 1)
		if i >= 2 and seq[i - 1] == s and seq[i - 2] == s:
			s = 1 - s
		seq.append(s)
		got.append(0)
	idx = 0
	phase = "show"
	_pt = -0.3


## Which of his darts is showing now (-1: none), and how far through it (0..1).
func showing() -> Array:
	if phase != "show" or _pt < 0.0:
		return [-1, 0.0]
	var i := int(_pt / _show)
	return [i, fposmod(_pt, _show) / _show] if i < seq.size() else [-1, 0.0]


func _step(dt: float, _a: bool, _b: bool, a_hit: bool, b_hit: bool) -> void:
	_pt += dt
	gain = mood
	tire = maxf(mood, 0.0)
	tension = 0.4
	pose = 0.45
	match phase:
		"show":
			if _pt >= _show * seq.size() + GAP * 0.4:
				phase = "go"
				_pt = 0.0
		"go":
			var press := -1
			if a_hit and not b_hit:
				press = 0
			elif b_hit and not a_hit:
				press = 1
			if press >= 0:
				_max += 1.0
				if press == seq[idx]:
					got[idx] = 1
					_pts += 1.0
					idx += 1
					_hit(2 if idx == seq.size() else 1)
					pose = 0.7
					if idx == seq.size():
						_end()
				else:
					got[idx] = 2
					_max += seq.size() - idx - 1
					_miss()
					_end()
			elif _pt > 1.4 + 0.7 * seq.size():
				_max += seq.size() - idx
				_miss()
				_end()
		"end":
			if _pt >= 0.45:
				_round += 1
				if _round >= _rounds:
					done = true
				else:
					_deal()


func _end() -> void:
	phase = "end"
	_pt = 0.0


func cue() -> Array:
	return [Kit.TAP, Kit.TAP] if phase == "go" else [Kit.NONE, Kit.NONE]


func hint() -> Dictionary:
	var out := {"a": false, "b": false}
	if phase == "go" and idx < seq.size() and int(_pt / 0.2) >= idx and fposmod(_pt, 0.2) < 0.08:
		out["a" if seq[idx] == 0 else "b"] = true
	return out


func draw(ci: CanvasItem, rect: Rect2, kit: Kit, time: float) -> void:
	var u := unit(rect)
	var c := rect.get_center()
	var n := seq.size()
	var sh := showing()
	var si := int(sh[0])
	var sk := float(sh[1])
	# him, in the middle, darting
	var fx := 0.0
	var way := 1.0
	var col := Color(Kit.FOAM, 0.55)
	if si >= 0:
		way = -1.0 if seq[si] == 0 else 1.0
		fx = way * 46.0 * u * sin(PI * minf(sk * 1.25, 1.0))
		col = Kit.GOLD
		for i in 3:
			kit.line(ci, c + Vector2(fx - way * (26.0 + i * 9.0) * u, (i - 1) * 7.0 * u - 6.0 * u), c + Vector2(fx - way * (40.0 + i * 9.0) * u, (i - 1) * 7.0 * u - 6.0 * u),
					Color(Kit.GOLD, 0.5 * (1.0 - sk)), 2.0 * u)
	elif phase == "go" and idx > 0:
		way = -1.0 if seq[idx - 1] == 0 else 1.0
		col = Kit.GO
	kit.fish(ci, c + Vector2(fx, -6.0 * u + sin(time * 3.0) * 1.5 * u), 46.0 * u, col, way)
	# the two sides, lit as he goes to them
	for s in 2:
		var x := c.x + (s * 2.0 - 1.0) * rect.size.x * 0.42
		var on := si >= 0 and seq[si] == s
		var sc := Kit.GOLD if on else Color(Kit.FOAM, 0.3 if phase != "go" else 0.6)
		kit.chevron(ci, Vector2(x, c.y - 6.0 * u), 20.0 * u * (1.0 + 0.3 * (1.0 - sk) if on else 1.0), Vector2(s * 2.0 - 1.0, 0.0), sc, 4.0 * u)
	# the row of them: hidden once he's shown them, filled in as you answer
	var step := 20.0 * u
	for i in n:
		var p := Vector2(c.x + (i - (n - 1) * 0.5) * step, rect.end.y - 12.0 * u)
		var r := 7.0 * u
		if phase == "show":
			if i < si or (i == si):
				kit.dot(ci, p, r, Kit.GOLD if i == si else Color(Kit.GOLD, 0.45))
				kit.chevron(ci, p, 7.0 * u, Vector2(seq[i] * 2.0 - 1.0, 0.0), Kit.DEEP, 2.0)
			else:
				kit.ring(ci, p, r, Color(Kit.FOAM, 0.3), 1.5)
		else:
			match got[i]:
				1:
					kit.dot(ci, p, r, Kit.GO)
					kit.chevron(ci, p, 7.0 * u, Vector2(seq[i] * 2.0 - 1.0, 0.0), Kit.DEEP, 2.0)
				2:
					kit.dot(ci, p, r, Kit.CORAL)
				_:
					var now := phase == "go" and i == idx
					kit.ring(ci, p, r * (1.0 + (0.2 * sin(time * 8.0) if now else 0.0)), Kit.FOAM if now else Color(Kit.FOAM, 0.3), 2.0 if now else 1.5)
	kit.text(ci, Vector2(c.x, rect.position.y + 7.0 * u), "WATCH" if phase == "show" else ("YOUR TURN" if phase == "go" else ""), 12.0 * u,
			Color(Kit.GOLD if phase == "show" else Kit.GO, 0.9), 0, 700, 1.5)
