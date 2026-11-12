extends "res://tuna/fight.gd"
## The arcade fight: a game in a game (docs/FIGHT_ARCADE.md). The same fish on the same rod as tuna/fight.gd (its
## line, its energy, its hook's hold, its bearing and depth, its signals, its cues: the rod, the fish, the sounds and
## the music read it just the same), but your hands play a run of set-pieces, one for each thing he does, each with its
## own verb on two buttons: A (use_primary: left mouse, RT) winds, B (use_secondary: right mouse, LT) leans back on him.
##
## - **run, surge**: ride him. A tension needle you lift by holding B and let fall by letting go; keep it in his moving
##   green band. In it he tires fast and takes little; under it he pours line off; over it the line frays.
## - **shake**: his head shakes come down a lane on a beat; tap B on each (a counter-pull). A miss works the hook.
## - **jump**: he comes up (the line lifts), goes over: hands off both while he's in the air (bow to him), and tap A as
##   he lands to take up the slack.
## - **sound**: pump him. Hold B to lift the rod to the gold at the top, then hold A to wind down; each stroke is line.
## - **dog**: the same pump, but he kicks (the meter flares): let go of B while he does or he rips the rod down.
## - **charge**: he comes at the boat: hammer A to keep the line tight.
## - **circle, spiral**: his laps round a ring. On the green half (coming up toward you) hold A and wind him in; on the
##   red half (going away) hold B and brace; winding into the red frays the line.
##
## Each piece is graded when it ends (perfect, good, ok, miss); good ones build a streak that multiplies every metre
## you win and how fast he tires (mult()); a miss breaks it and works the hook. Mistakes cost line, the hook's hold or
## the line's wear; none ends it at once. His energy is cut into stages(): each one cleared is a step up.
## The boat still matters: off the stern everything you do counts for less (angle_k), backing down wins line, the hull
## rubs the line and the props cut it.
##
## rods.gd makes one of these in place of a Fight while Fight.arcade is set, sets `pull_btn` (B) before each step,
## and step()'s crank is A. ui/fight_arcade_hud.gd draws view(); tests/fight_arcade_bot.gd plays it from view().

const PIECES := ["run", "surge", "shake", "jump", "sound", "dog", "charge", "circle", "spiral"]

## How long a fish takes: ARC_BASE + ARC_PER_KG x kg seconds of perfect work at no streak (x Fight.pace).
const ARC_BASE := 20.0
const ARC_PER_KG := 5.2
## The streak: each step of it MULT_STEP more of everything, up to MULT_CAP steps.
const MULT_STEP := 0.1
const MULT_CAP := 10
## Grades: the share of a piece done right.
const Q_PERFECT := 0.88
const Q_GOOD := 0.62
const Q_OK := 0.34
## Over this the line's suffering: it frays (wear a second per unit over) and the hook tears.
const OVER := 0.58
const FRAY := 0.16
const TEAR := 0.13
## The run: the needle's push (per s per s) and its fastest; how much line he takes of his pace in the band, and
## clamped down over it; how tiring each is.
const NEEDLE_ACC := 3.2
const NEEDLE_MAX := 1.1
const RUN_IN := 0.62
const RUN_OVER := 0.12
## The shake: s between beats (the fish's own head shakes: fight.gd's 1.6 a second), and how near a tap must be.
const BEAT := 0.625
const HIT_PERFECT := 0.075
const HIT_GOOD := 0.16
const MISS_HOLD := 0.028
## The jump, from when he leaves the water: in the air AIR s; hands off for the first HANDS_OFF of it; the tap as he
## lands, this near.
const AIR := 0.7
const HANDS_OFF := 0.45
const LAND_EARLY := 0.15
const LAND_LATE := 0.28
## The pump: m of line a full perfect stroke wins; where the gold starts; the kick's warning and its length (s).
const PUMP_M := 3.4
const GOLD := 0.86
const KICK_WARN := 0.5
const KICK_LEN := 0.6
## The charge: s for the slack to fill with nobody winding.
const SLACK_FILL := 1.3
## The laps: the share of each that's green; m/s wound on it, and what he takes back on the red unbraced.
const GREEN := 0.42
const LAP_WIN := 3.2
const LAP_TAKE := 1.5
## What he's owed to you comes in at this (m/s): never a jump of the line.
const HAUL_RATE := 5.0

## A set-piece forced for every one (dev: -- --piece=shake, for screenshots).
static var force_piece := _forced()

## B, 0..1 (rods.gd, before each step).
var pull_btn := 0.0
## The set-piece on now, how far into it (s), how long it is, and s left of its telegraph (nothing judged yet).
var piece := ""
var piece_t := 0.0
var piece_len := 1.0
var intro := 0.0
var streak := 0
var best := 0
## The last piece's grade, and s since.
var grade := ""
var grade_t := 99.0
## Line he owes you (m): paid in at HAUL_RATE.
var haul := 0.0
var stage := 0
var pieces_done := 0
## What just happened, for the HUD and the sounds: [what, ...]; whoever reads them takes them (take_events).
var events: Array = []
var seen := {}
## Where the rod wants to be (its elevation, rad): rods.gd eases it there.
var pose := 0.7

# the run
var needle := 0.4
var needle_v := 0.0
var band_c := 0.5
var band_w := 0.16
var _w1 := 1.0
var _w2 := 2.3
var _ph1 := 0.0
var _ph2 := 0.0
# the shake: each beat's time into the piece, and how it went (0 to come, 1 perfect, 2 good, 3 missed)
var beats := PackedFloat32Array()
var beat_hit := PackedByteArray()
var _lock := 0.0
# the jump: s before he leaves the water, s with a button down in the air, the landing tap (0 none, 1 good, 2 perfect)
var j_up := 1.2
var j_bad := 0.0
var j_land := 0
var _rise := 0.0
# the pump
var rod_p := 0.0
var pump_dir := 0
var top_t := 0.0
var kick_in := 0.0
var kick_t := 0.0
var stroke_q := 0.0
var pumps := 0
var _kick_pen := false
var _kicked := false
# the charge
var slack_n := 0.0
# the laps
var lap_len := 5.0
var red_t := 0.0
var arc_perfect := false
var _was_green := false

var _score := 0.0
var _score_max := 0.0
var _a_was := false
var _b_was := false
var _bag: Array = []
var _bag_phase := -1
var _d := 0.0
var _why := "pulled"
var _slack_m := 0.0
var _ready_done := false


static func _forced() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--piece="):
			return a.trim_prefix("--piece=")
	return ""


func _init(weight_kg: float, out: float, fresh := 1.0, seed_value := -1) -> void:
	super(weight_kg, out, fresh, seed_value)
	_goal_s = ARC_BASE + ARC_PER_KG * kg
	_ready_done = true
	slipping = false
	paying = 0.0
	speed = 0.0
	strain = 0.2
	stretch = strain * give()
	stage = _stage_now()
	if fresh > 0.8:
		_burst = BURST
		_start("run")
	else:
		_start(_next())


## How hard this fish's pieces are, 0..1: bigger, and later in the fight.
func difficulty() -> float:
	return clampf(0.1 + 0.5 * minf(kg, 300.0) / 300.0 + 0.4 * (1.0 - energy), 0.0, 1.0)


## What the streak's worth: x this on every metre won and on how fast he tires.
func mult() -> float:
	return 1.0 + MULT_STEP * mini(streak, MULT_CAP)


## And on line: half as much (the streak's mostly for wearing him down; the line's still to be won).
func line_mult() -> float:
	return 1.0 + 0.5 * MULT_STEP * mini(streak, MULT_CAP)


## How many steps his energy's cut into (a schoolie 2, a giant 7), and the one he's on.
func stages() -> int:
	return clampi(roundi(kg / 45.0), 2, 7)


func _stage_now() -> int:
	return clampi(int((1.0 - energy) / 0.8 * stages()), 0, stages())


func take_events() -> Array:
	var e := events
	events = []
	return e


## The streak and where the hands were, to carry across the rod changing hands (rods.gd sends it with the fight).
func arc_save() -> PackedFloat32Array:
	return PackedFloat32Array([streak, best, pieces_done, stage])


func arc_load(a: PackedFloat32Array) -> void:
	if a.size() >= 4:
		streak = int(a[0])
		best = int(a[1])
		pieces_done = int(a[2])
		stage = maxi(int(a[3]), _stage_now())


# (the classic fight's own picking of moves: not here)
func _set_move(m: String) -> void:
	if not _ready_done:
		move = m
		move_t = 0.0
		return
	_start(m)


func _next_move() -> void:
	pass


func _show(m: String) -> void:
	if move != m:
		move = m
		move_t = 0.0
		move_started.emit(m)


func carry_on(m: String, stretch_was := 0.0, turn := 0.0, hold_was := 1.0, burst := 0.0) -> void:
	if m == "rest" or not PIECES.has(m):
		m = "sound"
	hold = hold_was
	if turn != 0.0:
		_turn_sign = signf(turn)
	_turn_v = float(MOVES[m]["turn"]) * _turn_sign
	leader = leader or line_out < LEADER
	_burst = burst
	stretch = stretch_was
	strain = clampf(maxf(stretch, 0.0) / give(), 0.0, 0.5)
	t_fish = strain
	stage = maxi(stage, _stage_now())
	grace = 1.0
	if m == "jump":
		m = "shake"          # (picked up as he lands)
	_start(m, true)


## A set-piece begins: `long`, with time to get your hands on it.
func _start(p: String, long := false) -> void:
	if not PIECES.has(p):
		p = "sound"
	piece = p
	piece_t = 0.0
	_score = 0.0
	_score_max = 0.0
	var first := not seen.has(p)
	seen[p] = int(seen.get(p, 0)) + 1
	intro = 1.5 if first or long else 0.7
	_d = difficulty()
	var e := 0.6 + 0.4 * energy
	match p:
		"run", "surge":
			var run := p == "run"
			piece_len = intro + (rng.randf_range(5.0, 8.0) * e if run else rng.randf_range(3.0, 4.2))
			if run and nature == "runner":
				piece_len += 1.5
			if run and _burst > 0.0 and kg >= 100.0:
				piece_len += 3.0       # (a giant's first run: a good part of the spool)
			band_w = lerpf(0.2, 0.125, _d) * (1.0 if run else 0.9) * (0.88 if _last_run else 1.0)
			_w1 = lerpf(0.9, 1.6, _d) * (1.0 if run else 1.35)
			_w2 = _w1 * 2.3
			_ph1 = rng.randf() * TAU
			_ph2 = rng.randf() * TAU
			needle = clampf(needle, 0.25, 0.55)
			needle_v = 0.0
			if run and rng.randf() < 0.5:
				_turn_sign = -_turn_sign
		"shake":
			var pats: Array = [[0, 2, 4, 6]]
			if _d > 0.7:
				pats = [[0, 2, 3, 4, 6, 8, 9, 10], [0, 2, 4, 5, 6, 8, 10, 11, 12]]
			elif _d > 0.4:
				pats = [[0, 2, 3, 4, 6, 8], [0, 2, 4, 6, 7, 8], [0, 2, 4, 5, 6, 8]]
			var pat: Array = pats[rng.randi_range(0, pats.size() - 1)]
			beats = PackedFloat32Array()
			beat_hit = PackedByteArray()
			for s: int in pat:
				beats.append(intro + 0.7 + 0.5 * BEAT * s)
				beat_hit.append(0)
			piece_len = beats[beats.size() - 1] + 0.55
			_lock = 0.0
		"jump":
			intro = 0.0
			j_up = 1.2 + depth / 22.0
			_rise = depth / maxf(j_up - 0.3, 0.2)
			piece_len = j_up + AIR + 0.8
			j_bad = 0.0
			j_land = 0
		"sound", "dog":
			piece_len = intro + rng.randf_range(7.0, 10.0) * e
			if p == "sound" and nature == "sounder":
				piece_len += 2.0
			rod_p = 0.0
			pump_dir = 0
			top_t = 0.0
			pumps = 0
			kick_t = 0.0
			kick_in = intro + rng.randf_range(1.6, 2.6)
		"charge":
			piece_len = intro + rng.randf_range(2.8, 4.0)
			slack_n = 0.0
		"circle", "spiral":
			lap_len = lerpf(6.4, 5.0, _d) if p == "circle" else lerpf(5.0, 3.9, _d)
			piece_len = intro + lap_len * 2.0
			red_t = 0.0
			arc_perfect = false
			_was_green = false
			if p == "circle" and rng.randf() < 0.5:
				_turn_sign = -_turn_sign
	_show("dog" if p == "jump" else p)
	events.append(["piece", p])


## Where a lap is (0..1): under GREEN he's coming up toward you.
func lap() -> float:
	return fposmod((piece_t - intro) / lap_len, 1.0)


func _hurt(x: float, why: String) -> void:
	if in_holder or grace > 0.0 or x <= 0.0:
		return
	hold -= x
	_why = why


func _tire(secs: float) -> void:
	energy -= secs / (_goal_s * pace) * mult() * lerpf(0.45, 1.0, angle_k())


## One tick: `crank` is A (0..1), pull_btn is B.
func step(dt: float, crank: float, _rod_pitch: float, _side: float, drag_set: float) -> void:
	if done or dt <= 0.0:
		return
	drag = clampf(drag_set, 0.0, 1.0)
	var a := 0.0 if in_holder else clampf(crank, 0.0, 1.0)
	var b := 0.0 if in_holder else clampf(pull_btn, 0.0, 1.0)
	var a_on := a > 0.4
	var b_on := b > 0.4
	var a_tap := a_on and not _a_was
	var b_tap := b_on and not _b_was
	_a_was = a_on
	_b_was = b_on
	reeling = a_on
	grinding = false
	if events.size() > 24:
		events = events.slice(-8)       # (nobody's reading them: a rod in its holder)
	grace = maxf(grace - dt, 0.0)
	grade_t += dt
	piece_t += dt
	move_t += dt
	intro = maxf(intro - dt, 0.0)
	var judged := intro <= 0.0 and not in_holder
	_jit += (rng.randf_range(-1.0, 1.0) - _jit) * minf(1.0, 1.5 * dt)
	airborne = false
	var k := line_mult() * lerpf(0.45, 1.0, angle_k()) / pace       # (what a metre of your winding's worth)
	var tgt := 0.15       # the tension it's heading for
	var work := 0.0       # how hard he's being worked (s of tiring a second)
	var pay := 0.0        # line he takes (m/s)
	var win := 0.0        # line you take (m/s)
	_slack_m = move_toward(_slack_m, 0.0, 4.0 * dt)
	var fresh := 0.45 + 0.55 * energy

	match piece:
		"run", "surge":
			band_c = 0.55 + 0.19 * sin(piece_t * _w1 + _ph1) + 0.08 * sin(piece_t * _w2 + _ph2)
			if in_holder:
				needle = move_toward(needle, 0.12, dt)       # (on its drag: light)
			else:
				needle_v = clampf(needle_v + lerpf(-NEEDLE_ACC, NEEDLE_ACC, b) * dt, -NEEDLE_MAX, NEEDLE_MAX)
				needle += needle_v * dt
				if needle <= 0.0 or needle >= 1.0:
					needle = clampf(needle, 0.0, 1.0)
					needle_v = 0.0
			var off := needle - band_c
			var vf := v_free() * fresh * (1.0 if piece == "run" else 0.85) * (1.0 + 0.4 * clampf(_burst / BURST, 0.0, 1.0))
			_burst = maxf(_burst - dt, 0.0)
			var rate := 1.0
			tgt = 0.16 + 0.3 * needle
			if absf(off) <= band_w:
				rate = RUN_IN
				work = 1.6
				if judged:
					_score += dt
			elif off > 0.0:
				rate = RUN_OVER
				work = 0.7
				tgt += (off - band_w) * 1.8 + 0.12
				_why = "pulled"
			else:
				rate = RUN_IN + (1.0 - RUN_IN) * clampf((-off - band_w) / 0.2, 0.0, 1.0)
				work = 0.25
			if in_holder:
				rate = 0.6
				work = 0.4
			elif not judged:
				rate = minf(rate, 0.5)       # (the telegraph: he's off, but not at his worst yet)
			else:
				_score_max += dt
			pay = vf * rate
			pose = 0.75 + 0.45 * needle
		"shake":
			_lock = maxf(_lock - dt, 0.0)
			var beat_k := 0.0
			for i in beats.size():
				var bt := beats[i]
				beat_k = maxf(beat_k, 1.0 - absf(piece_t - bt) / 0.2)
				if beat_hit[i] == 0 and piece_t > bt + HIT_GOOD:
					beat_hit[i] = 3
					_score_max += 1.0
					if not in_holder:
						_hurt(MISS_HOLD, "shaken")
						events.append(["miss"])
			if b_tap and _lock <= 0.0 and not in_holder:
				var at := -1
				for i in beats.size():
					if beat_hit[i] == 0 and absf(piece_t - beats[i]) <= HIT_GOOD:
						at = i
						break
				if at >= 0:
					var perfect := absf(piece_t - beats[at]) <= HIT_PERFECT
					beat_hit[at] = 1 if perfect else 2
					_score += 1.0 if perfect else 0.75
					_score_max += 1.0
					_tire(1.3 if perfect else 0.9)
					events.append(["hit", perfect])
					pose = 1.15
				else:
					_lock = 0.25
					_score = maxf(_score - 0.34, 0.0)
					events.append(["whiff"])
			pose = move_toward(pose, 0.7, 1.6 * dt)
			tgt = 0.2 + 0.16 * maxf(beat_k, 0.0)
			pay = 0.3 * fresh
		"jump":
			var t_air := piece_t - j_up
			if t_air < 0.0:
				depth = move_toward(depth, 0.2, _rise * dt)
				tgt = 0.26
				pose = 0.95
				if t_air >= -0.5:
					_show("jump")
			else:
				depth = move_toward(depth, 0.0, 4.0 * dt)
				airborne = t_air < AIR
				if airborne:
					_thrown_t = 1.0
				if t_air < HANDS_OFF:
					if (a_on or b_on) and not in_holder:
						j_bad += dt
						_hurt(0.4 * dt, "thrown")
						tgt = 0.55
					else:
						tgt = 0.04
					pose = 0.3
				elif t_air < AIR + LAND_LATE:
					tgt = 0.06
					pose = 0.3
					if a_tap and j_land == 0 and t_air >= AIR - LAND_EARLY and not in_holder:
						j_land = 2 if absf(t_air - AIR) <= 0.09 else 1
						haul += (7.0 if j_land == 2 else 4.5) * line_mult() / pace
						events.append(["hit", j_land == 2])
				else:
					if j_land == 0 and not in_holder:
						_slack_m = maxf(_slack_m, 2.5)      # (nobody took it up: a belly of slack)
					pose = 0.7
					tgt = 0.2
		"sound", "dog":
			var heft := clampf(size_of(kg) / 1.9, 0.2, 1.0)
			var lift := lerpf(1.6, 0.95, heft)
			var kicking := false
			if piece == "dog":
				if kick_t > 0.0:
					kick_t -= dt
					kicking = kick_t <= KICK_LEN
					if kick_t <= 0.0:
						if judged or _kicked:
							_score_max += 1.0
							if not _kicked:
								_score += 1.0
								events.append(["hit", false])
						kick_in = rng.randf_range(2.0, 3.4) * lerpf(1.2, 0.8, _d)
				else:
					kick_in -= dt
					if kick_in <= 0.0 and piece_len - piece_t > KICK_WARN + KICK_LEN + 0.3:
						kick_t = KICK_WARN + KICK_LEN
						_kicked = false
			if b_on and not a_on:
				if kicking:
					rod_p = move_toward(rod_p, 0.0, 3.0 * dt)       # (he rips it down)
					tgt = 0.74
					pump_dir = 0
					if not _kicked:
						_kicked = true
						_hurt(0.02, "pulled")
						events.append(["miss"])
				else:
					rod_p = minf(rod_p + lift * dt, 1.0)
					pump_dir = 1
					top_t = top_t + dt if rod_p >= 1.0 else 0.0
					tgt = 0.14 + 0.3 * rod_p + clampf(top_t - 0.4, 0.0, 1.0) * 0.9
					_why = "pulled"
			elif a_on and not b_on:
				if pump_dir != -1:
					stroke_q = 1.0 if rod_p >= GOLD else (0.7 if rod_p >= 0.62 else rod_p * 0.7)
					if rod_p > 0.15 and not in_holder:
						events.append(["stroke", stroke_q])
					top_t = 0.0
				pump_dir = -1
				var d := minf(2.4 * dt, rod_p)
				rod_p -= d
				win += PUMP_M * d / dt * stroke_q * k * (1.4 if energy < BEATEN else 1.0)
				_tire(d * stroke_q * 1.6)
				tgt = 0.1
				if rod_p <= 0.0 and d > 0.0:
					_score += stroke_q
					pumps += 1
					pump_dir = 0
				elif d <= 0.0:
					grinding = true       # (winding with nothing lifted: the handle won't turn)
					tgt = 0.3
			elif a_on and b_on:
				grinding = true
				tgt = 0.36
			else:
				rod_p = move_toward(rod_p, 0.0, 0.5 * dt)
				if rod_p <= 0.0:
					pump_dir = 0
			if kicking:
				tgt = maxf(tgt, 0.42)
			if win <= 0.0:
				pay = (0.9 if piece == "sound" else 0.5) * fresh * (0.35 if b_on else 1.0)
			pose = lerpf(0.35, 1.3, rod_p)
		"charge":
			var closing := v_free() * 0.55 * (0.5 + 0.5 * energy)
			var need := lerpf(2.4, 4.0, _d)
			var fill := 1.0 / SLACK_FILL
			slack_n += fill * dt * (1.0 if judged or in_holder else 0.5)
			if a_tap:
				slack_n -= fill / need
			if a_on:
				slack_n -= fill * 0.3 * dt
			slack_n = clampf(slack_n, 0.0, 1.0)
			var keep := 1.0 - slack_n
			win += closing * keep / pace
			work = 0.5 * keep
			if slack_n > 0.7:
				_hurt(0.07 * dt, "shaken")
			if judged:
				_score += keep * dt
				_score_max += dt
			_slack_m = maxf(_slack_m, slack_n * 5.0)
			tgt = 0.03 + 0.1 * keep
			pose = 0.5
			if line_out < 22.0:
				piece_t = maxf(piece_t, piece_len)       # (he's here: he turns away)
		"circle", "spiral":
			var green := lap() < GREEN and intro <= 0.0
			_going_under = not green
			if _was_green and not green:
				arc_perfect = false
			if a_tap and not in_holder:
				# (on to the handle just as he turns toward you)
				var to_green := minf(lap(), 1.0 - lap()) * lap_len
				if to_green <= 0.14 and (green or lap() > 0.5):
					arc_perfect = true
					events.append(["hit", true])
			_was_green = green
			var reel := LAP_WIN * (1.0 if piece == "circle" else 0.82)
			if green:
				red_t = 0.0
				if a_on and not b_on:
					win += reel * k * (1.45 if arc_perfect else 1.0)
					work = 1.3
					tgt = 0.24
					pose = 0.55
					if judged:
						_score += dt
				else:
					work = 0.2
					tgt = 0.14
					pose = 0.8
				if judged:
					_score_max += dt
			else:
				if a_on:
					red_t += dt
					grinding = true
					if red_t > 0.22:
						tgt = 0.8
						_why = "pulled"
						if judged:
							_score = maxf(_score - 0.5 * dt, 0.0)
					pose = 0.9
				elif b_on:
					red_t = 0.0
					tgt = 0.32
					work = 0.6
					pose = 1.05
					if judged:
						_score += 0.5 * dt
				else:
					red_t = 0.0
					pay = LAP_TAKE * fresh
					tgt = 0.16
					pose = 0.8
				if judged:
					_score_max += 0.5 * dt

	# what he owes you, coming in
	if haul > 0.0:
		var h := minf(haul, HAUL_RATE * dt)
		haul -= h
		win += h / dt

	# the boat: closing on him backing down (line for the winding), pulling away from him under way
	var boat_close := 0.0
	if moving and boat_vel != Vector2.ZERO:
		var hd_was := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
		var rel := Vector2(sin(bearing), cos(bearing)) * hd_was - boat_vel * dt
		bearing = atan2(rel.x, rel.y)
		boat_close = -(sqrt(rel.length_squared() + depth * depth) - sqrt(hd_was * hd_was + depth * depth)) / dt
	else:
		var b0 := absf(wrapf(bearing, -PI, PI))
		boat_close = back_speed * maxf(-throttle, 0.0) * clampf(cos(b0) * 1.5, 0.0, 1.0) - 1.5 * maxf(throttle, 0.0)

	line_out += (pay - win - boat_close) * dt
	if line_out < BOATSIDE - 0.2:
		line_out = BOATSIDE - 0.2
	paying = maxf(pay - minf(boat_close, 0.0), 0.0)
	slipping = paying > 0.6
	wind = win
	speed = pay - win
	# the tension: eased to where the piece puts it; slack when there's a belly in it
	if shock > _shock_was:
		strain += shock - _shock_was
	shock = move_toward(shock, 0.0, dt * 0.5)
	_shock_was = shock
	strain = move_toward(strain, tgt + 0.02 * _jit, (3.0 if tgt > strain else 2.2) * dt)
	if _slack_m > 0.3:
		stretch = -_slack_m
		strain = minf(strain, 0.05)
	else:
		stretch = strain * give()
	t_fish = strain
	slack_t = slack_t + dt if stretch < -0.3 else maxf(slack_t - 2.0 * dt, 0.0)
	if strain > OVER and not in_holder and grace <= 0.0:
		var o := strain - OVER
		wear += o * FRAY * dt
		_hurt(o * TEAR * dt, _why)

	# where he is: swinging round the boat, heading for his depth (as tuna/fight.gd's)
	var m: Dictionary = MOVES[move]
	var hd0 := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	var hd := maxf(hd0, 1.0)
	var turn := float(m["turn"])
	if move != "spiral":
		turn *= 0.35 + 0.65 * energy
	var was_b := bearing
	_turn_v = move_toward(_turn_v, turn * _turn_sign, TURN_EASE * dt)
	bearing += _turn_v * dt * clampf(25.0 / hd, 0.3, 0.7 if move == "spiral" else 1.2)
	bearing -= sin(wrapf(bearing, -PI, PI)) * TOW * clampf(strain, 0.0, 1.0) * dt
	if move in ["spiral", "charge"] or (energy < BEATEN and line_out < SPIRAL_IN):
		bearing -= sin(wrapf(bearing, -PI, PI)) * LEAD * clampf(strain / 0.2, 0.3, 1.0) * dt
	_sweep = lerpf(_sweep, (bearing - was_b) / dt, minf(1.0, 4.0 * dt))
	if piece != "jump":
		var goal_d := minf(float(m["depth"]) * (1.4 if nature == "sounder" and move == "sound" else 1.0), line_out * 0.85)
		if move == "spiral":
			goal_d = line_out * (0.85 if _going_under else 0.6) if line_out > 12.0 else 3.0
		elif energy < BEATEN and line_out < SPIRAL_IN:
			goal_d = minf(goal_d, 3.0)
		_dive_v = move_toward(_dive_v, clampf((goal_d - depth) * 0.9, -6.0, 6.0), DIVE_EASE * dt)
		depth = maxf(depth + _dive_v * dt, 0.0)
	else:
		_dive_v = 0.0
	_thrown_t = maxf(_thrown_t - dt, 0.0) if not airborne else _thrown_t

	# the leader at the rod tip: the moment, and his last run at it
	if not leader and line_out < LEADER:
		leader = true
		leader_up.emit()
		if energy >= 0.2 and force_piece.is_empty():
			_last_run = true
			_start("surge")

	# the boat: the line on her rubs; under her with the props turning it's cut (half as hard on it as the classic)
	if rub_now >= 0.0:
		chafe = rub_now
	else:
		chafe = rub(_tip(hd0), _fish(hd0), half_beam, house, fore) * hd0 / (hd0 + depth + 1.0)
		if move == "spiral":
			chafe *= 0.5
	chafe = maxf(chafe, side_rub())
	if grace <= 0.0:
		wear += 0.5 * chafe * (0.4 + 0.6 * clampf(strain, 0.0, 1.0)) * dt / (CHAFE_LIFE * chafe_mul) \
				* (0.4 if energy < BEATEN else 1.0)
		if tangled:
			wear += dt / (TANGLE_LIFE * chafe_mul)
	if wear >= 1.0:
		_end("tangle" if tangled and chafe < 0.05 else ("chafed" if chafe > 0.05 else "broke"))
		return
	if b_now() > UNDER and absf(throttle) > 0.05 and depth < 25.0 and hd0 < 35.0:
		_prop_t += dt
		if _prop_t >= PROP_GRACE:
			_end("cut")
			return
	else:
		_prop_t = 0.0
	if line_out >= CAPACITY:
		_end("spooled")
		return
	if hold <= 0.0:
		hold = 0.0
		_end(_why)
		return

	# tiring; left alone, he gets his breath back. Each stage cleared is a step up.
	if work > 0.0:
		_tire(work * dt * (0.3 if in_holder else 1.0))
	elif energy >= BEATEN and win <= 0.0:
		energy += RECOVER * dt / (_goal_s * pace)
	energy = clampf(energy, 0.0, 1.0)
	var st := _stage_now()
	if st > stage:
		stage = st
		if not in_holder:
			hold = minf(hold + 0.04, 1.0)
			haul += 4.0 * line_mult() / pace
			events.append(["stage", st])

	if energy < 0.2 and line_out <= BOATSIDE:
		done = true
		boatside.emit()
		return
	if piece_t >= piece_len:
		_finish()


## The piece is over: its grade, the streak, and the next one.
func _finish() -> void:
	if not in_holder and grace <= 0.0:
		match piece:
			"jump":
				_score_max = 1.0
				_score = 0.0
				if j_bad < 0.08:
					_score = 0.64 + (0.36 if j_land == 2 else (0.26 if j_land == 1 else 0.0))
					_tire(2.5)
				if j_land == 0:
					_hurt(0.025, "shaken")
			"sound", "dog":
				# (against what a steady hand would have made of it)
				var lift := lerpf(1.6, 0.95, clampf(size_of(kg) / 1.9, 0.2, 1.0))
				var strokes := (piece_len - 1.5) / (1.0 / lift + 0.42 + 0.3) * (0.8 if piece == "sound" else 0.6)
				_score_max = maxf(_score_max + strokes, _score)
		var q := clampf(_score / _score_max, 0.0, 1.0) if _score_max > 0.0 else 0.0
		grade = "perfect" if q >= Q_PERFECT else ("good" if q >= Q_GOOD else ("ok" if q >= Q_OK else "miss"))
		grade_t = 0.0
		match grade:
			"perfect":
				streak += 1
				hold = minf(hold + 0.02, 1.0)
				haul += 3.0 * line_mult() / pace
			"good":
				streak += 1
			"miss":
				streak = 0
				_hurt(0.03, "shaken" if piece in ["shake", "charge", "jump"] else "pulled")
		best = maxi(best, streak)
		events.append(["grade", grade, streak])
	pieces_done += 1
	_last_run = false
	_start(_next())


## What he does next: by how tired he is and how far off, out of a shuffled bag (so a long fight has all of them and
## never the same twice running); fresh and held in close, he's off.
func _next() -> String:
	if not force_piece.is_empty() and PIECES.has(force_piece):
		return force_piece
	var beaten := energy < BEATEN
	var was_run := piece in ["run", "surge"]
	if energy > 0.35 and line_out < CLOSE and not was_run:
		return "run" if rng.randf() < 0.6 else "surge"
	var ph := 3 if beaten and line_out <= SPIRAL_IN else (2 if beaten else (1 if energy <= 0.6 else 0))
	if ph != _bag_phase or _bag.is_empty():
		_bag_phase = ph
		match ph:
			0:
				_bag = ["sound", "shake", "run", "dog", "charge", "sound", "surge"]
				if kg < 120.0 or nature == "jumper":
					_bag.append("jump")
			1:
				_bag = ["sound", "dog", "shake", "circle", "surge", "charge", "dog", "jump", "run", "shake"]
			2:
				_bag = ["circle", "sound", "dog", "circle", "shake"]
			_:
				_bag = ["spiral", "spiral", "shake", "spiral", "surge"]
		for i in range(_bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t: String = _bag[i]
			_bag[i] = _bag[j]
			_bag[j] = t
	for i in _bag.size():
		var p: String = _bag[i]
		if (p == piece and p != "spiral") or (was_run and p in ["run", "surge"]):
			continue
		if (p == "jump" and depth > 30.0) or (p == "charge" and line_out < 50.0):
			continue
		_bag.remove_at(i)
		return p
	_bag.clear()
	return "dog" if piece == "sound" else "sound"


## What the HUD draws and the test anglers read: the piece and where it's at. a, b: what each button wants now
## (0 leave it, 1 hold, 2 tap on the mark, 3 hammer it, -1 hands off).
func view() -> Dictionary:
	var v := {"piece": piece, "t": piece_t, "len": piece_len, "intro": intro, "streak": streak, "mult": mult(),
			"grade": grade, "grade_t": grade_t, "hold": hold, "energy": energy, "stage": stage, "stages": stages(),
			"line_out": line_out, "wear": wear, "kg": kg, "angle": angle_k(), "a": 0, "b": 0, "tension": strain,
			"holder": in_holder, "leader": leader}
	match piece:
		"run", "surge":
			v["needle"] = needle
			v["band_c"] = band_c
			v["band_w"] = band_w
			v["b"] = 1 if needle < band_c else 0
		"shake":
			v["beats"] = beats
			v["beat_hit"] = beat_hit
			v["b"] = 2
		"jump":
			var t_air := piece_t - j_up
			v["air"] = t_air
			v["up"] = j_up
			v["landed"] = j_land
			v["bad"] = j_bad
			if t_air < HANDS_OFF:
				v["a"] = -1
				v["b"] = -1
			elif t_air < AIR + LAND_LATE and j_land == 0:
				v["a"] = 2
				v["b"] = -1
		"sound", "dog":
			v["rod"] = rod_p
			v["dir"] = pump_dir
			v["top"] = top_t
			v["kick"] = 0 if kick_t <= 0.0 else (1 if kick_t > KICK_LEN else 2)
			if kick_t > 0.0 and kick_t <= KICK_LEN + 0.2:
				v["b"] = -1
				v["a"] = 1 if rod_p > 0.0 else 0
			elif pump_dir == -1 or rod_p >= GOLD:
				v["a"] = 1
			else:
				v["b"] = 1
		"charge":
			v["slack"] = slack_n
			v["a"] = 3
		"circle", "spiral":
			v["lap"] = lap()
			v["lap_len"] = lap_len
			v["green"] = GREEN
			v["red_t"] = red_t
			v["arc_perfect"] = arc_perfect
			if lap() < GREEN and intro <= 0.0:
				v["a"] = 1
			else:
				v["b"] = 1
				v["a"] = -1
	return v


func cues() -> Dictionary:
	var c := super()
	c["arcade"] = view()
	return c
