extends "res://tuna/fight.gd"
## The arcade fight: a game in a game (docs/FIGHT_ARCADE.md). The same fish on the same rod as tuna/fight.gd (its
## line, its energy, its hook's hold, its bearing and depth, its signals, its cues: the rod, the fish, the sounds and
## the music read it just the same), but your hands play a run of MINIGAMES on two buttons: A (use_primary: left
## mouse, RT) and B (use_secondary: right mouse, LT). Each is its own small file in tuna/minigames/ (the list is
## tuna/minigames/all.gd); this is the sequencer that deals them out and turns what they do into the fight.
##
## - **Sets.** The fish does one thing at a time (he runs, sounds, dogs, shakes his head, circles, spirals, jumps,
##   charges: `move`, which the world shows), and each thing he does is a SET of two to four minigames back to back, a
##   breath (BREATH s) between. They come out of a shuffled bag: never the same twice running, none again till the bag's
##   gone round; ones that suit what he's doing first. A game that runs past CAP s is swapped out, scored on what was
##   done. The second time a game's seen it may come mirrored, faster, or with its twist.
## - **What a game does.** Each frame the game says how it's going (gain -1..1, tire, hook, fray, tension, pose:
##   minigame.gd) and this turns it into line (LINE: what his move gives and takes at the worst, at nothing, at the
##   best), his energy, the hook's hold and the line's wear. Mistakes cost; none ends it at once.
## - **Grades and the combo.** A game ends PERFECT, GREAT, OK or MISS. Great and perfect each add one to the combo
##   (a perfect gives a little of the hook back and some line as well); a miss halves it. The combo multiplies how
##   fast he tires (mult()) and the line you win (line_mult()).
## - **The BIG PULL.** Every PULL_EVERY steps of the combo (x5, x10, x15...) you're handed one (minigames/pull.gd): one
##   press, can't fail, and he's hauled PULL_M and more metres toward the boat, fast (but never a jump of the line).
## - **Stages and bosses.** His energy is cut into stages(); near the end of each comes a boss (a harder, longer
##   game: minigames/twohands.gd, or a big one of the others): win it and it takes a bite out of him (BOSS_BITE).
## - The boat still matters: off the stern everything you do counts for less (angle_k), backing down wins line, the
##   hull rubs the line and the props cut it. In its holder nobody's playing: he takes line on the drag.
##
## rods.gd makes one of these in place of a Fight while Fight.arcade is set, sets `pull_btn` (B) before each step,
## and step()'s crank is A. ui/fight_arcade_hud.gd draws view() and the game itself; tests/fight_arcade_bot.gd plays
## it by asking the game on (its hint()).

const Minigame := preload("res://tuna/minigames/minigame.gd")
const Games := preload("res://tuna/minigames/all.gd")
const Pull := preload("res://tuna/minigames/pull.gd")
const Clear := preload("res://tuna/minigames/clear.gd")

## What he does (the classic fight's moves, less its rest).
const PIECES := ["run", "surge", "shake", "jump", "sound", "dog", "charge", "circle", "spiral"]

## How long a fish takes: ARC_BASE + ARC_PER_KG x kg seconds of perfect work at no combo (x Fight.pace).
const ARC_BASE := 0.0
const ARC_PER_KG := 6.0
## The combo: each step of it COMBO_STEP more tiring (half that on line), up to COMBO_CAP steps.
const COMBO_STEP := 0.04
const COMBO_CAP := 20
## The BIG PULL: every so many steps of the combo; m of line for the first, more for each after, at most; how fast
## it comes in (m/s); s of tiring it's worth.
const PULL_EVERY := 5
const PULL_M := 14.0
const PULL_M_STEP := 4.0
const PULL_M_MAX := 30.0
const PULL_RATE := 18.0
const PULL_TIRE := 4.0
## Grades: a game's score.
const Q_PERFECT := 0.88
const Q_GREAT := 0.62
const Q_OK := 0.34
## Between games (s), after the rod's changed hands, and the longest a game (and a boss) may run.
const BREATH := 0.4
const BREATH_LONG := 1.5
const CAP := 9.0
const CAP_BOSS := 13.0
## A boss comes when this much of a stage is done; won, it takes this much of a stage out of him.
const BOSS_AT := 0.72
const BOSS_BITE := 0.35
## Over this the line's suffering (rods.gd rumbles on it).
const OVER := 0.58
const FRAY := 0.16
const TEAR := 0.13
## What a game's one-offs and rates are worth: a perfect hit (m of line, s of tiring), a miss (of the hook's hold;
## no more than HURT_CAP of them a game), a second of hook 1 and of fray 1.
const BURST_M := 0.5
const BURST_S := 0.4
const MISS_HOLD := 0.02
const HURT_CAP := 2.0
const HOOK_RATE := 0.06
const FRAY_RATE := 0.035
## What he's owed to you comes in at this (m/s): never a jump of the line.
const HAUL_RATE := 5.0
## The line, by what he's doing: m/s (+ yours) with the game at its worst (gain -1), at nothing (0), at its best (1);
## and what those are in: 0 m/s, 1 his free speed (the runs: he only ever takes), 2 his closing speed (the charge).
const LINE := {
	"run": [-0.8, -0.6, -0.3, 1], "surge": [-0.7, -0.5, -0.24, 1],
	"sound": [-0.5, 0.15, 2.5, 0], "dog": [-0.35, 0.15, 2.7, 0], "shake": [-0.3, 0.1, 2.2, 0],
	"circle": [-0.6, 0.15, 3.0, 0], "spiral": [-0.5, 0.15, 2.8, 0],
	"jump": [-0.4, 0.0, 1.0, 0], "charge": [0.1, 0.5, 1.0, 2],
}
## How tiring a second of a game at its best is, by what he's doing.
const WORK := {"run": 1.5, "surge": 1.5, "sound": 1.25, "dog": 1.25, "shake": 1.25, "circle": 1.25, "spiral": 1.25,
		"jump": 1.6, "charge": 0.6}

## A game forced for every one (dev: -- --piece=<id>, for screenshots; "pull" is the BIG PULL).
static var force_piece := _forced()
## The music's beat, for the games that play to it: a Callable -> [s a beat, s to the next] (the HUD sets it; unset,
## the fight's own tempo).
static var beat_fn := Callable()

## B, 0..1 (rods.gd, before each step).
var pull_btn := 0.0
## The games this player's met (this run of the game): the first time each comes up the fight stops for TEACH s
## with what to do said big (the HUD: "teach"), and that go is practice: nothing's lost by getting it wrong.
static var known := {}
static var teach := true
const TEACH := 3.2
var practice := false
## A hand for whoever's struggling: each miss makes the next games easier (their tier down by this much, to
## ASSIST_MOST), each good one takes it back.
const ASSIST_STEP := 0.2
const ASSIST_MOST := 0.6
var assist := 0.0
## Even played badly a game tires him this much (of its best), so no fight stands still: only hands off does.
const WORK_FLOOR := 0.45
## How near the props are to cutting the line, 0..1 (under her, in gear).
var prop_k := 0.0
## A line saved off her hull (clear.gd): what it's worn back to, and how long it's left alone after (s).
const CLEAR_WEAR := 0.6
const CLEAR_GRACE := 8.0
## The minigame on now (null: the breath between two), s of breath left, and how many more in this set.
var game: Minigame
var breath := 0.6
var set_left := 0
var combo := 0
var best := 0
## The last game's grade, and s since.
var grade := ""
var grade_t := 99.0
## Line he owes you (m): paid in at HAUL_RATE; and the BIG PULL's, at PULL_RATE.
var haul := 0.0
var stage := 0
var games_done := 0
## What just happened, for the HUD and the sounds; whoever reads them takes them (take_events):
## ["game", id, boss], ["hit", 1 or 2], ["miss"], ["near"], ["stroke", q], ["grade", grade, combo, id],
## ["pull_ready", level], ["pull", metres, level], ["stage", n], ["boss", won], ["move", move].
var events: Array = []
## How many times each game's been seen this fight.
var seen := {}
var last_id := ""
## Where the rod wants to be (its elevation, rad): rods.gd eases it there.
var pose := 0.7
## A hit-stop (s): the fight holds its breath (the HUD sets it on a perfect; nothing else does).
var freeze := 0.0

var _a_was := false
var _b_was := false
var _bag: Array = []
var _mbag: Array = []
var _mbag_phase := -1
var _pull_at := PULL_EVERY
var _pull_due := false
var _pull_haul := 0.0
var _boss_stage := -1
var _is_boss := false
var _last_boss := ""
var _hurt_left := HURT_CAP
var _hold_t := 6.0
var _rise := 8.0
var _why := "pulled"
var _jumping := false
var _slack_m := 0.0
var _ready_done := false
var _busy_t := 0.0


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
		_start_move("run")
	else:
		_start_move(_pick_move())


## How hard this fish's games are, 0..1: bigger, and later in the fight.
func difficulty() -> float:
	return clampf(0.1 + 0.5 * minf(kg, 300.0) / 300.0 + 0.4 * (1.0 - energy), 0.0, 1.0)


## What the combo's worth: x this on how fast he tires.
func mult() -> float:
	return 1.0 + COMBO_STEP * mini(combo, COMBO_CAP)


## And on line: half as much (the combo's mostly for wearing him down; the line's still to be won).
func line_mult() -> float:
	return 1.0 + 0.5 * COMBO_STEP * mini(combo, COMBO_CAP)


## How many steps his energy's cut into (a schoolie 2, a giant 7), the one he's on, and how far through it (0..1).
func stages() -> int:
	return clampi(roundi(kg / 45.0), 2, 7)


func _stage_now() -> int:
	return clampi(int((1.0 - energy) / 0.8 * stages()), 0, stages())


func stage_frac() -> float:
	return fposmod((1.0 - energy) / 0.8 * stages(), 1.0)


## The combo the next BIG PULL comes at.
func next_pull() -> int:
	return _pull_at


func take_events() -> Array:
	var e := events
	events = []
	return e


## The combo and where the fight is, to carry across the rod changing hands (rods.gd sends it with the fight).
func arc_save() -> PackedFloat32Array:
	return PackedFloat32Array([combo, best, games_done, stage, _pull_at, _boss_stage, 1.0 if _pull_due else 0.0,
			Games.ids().find(last_id)])


func arc_load(a: PackedFloat32Array) -> void:
	if a.size() >= 4:
		combo = int(a[0])
		best = int(a[1])
		games_done = int(a[2])
		stage = maxi(int(a[3]), _stage_now())
	if a.size() >= 8:
		_pull_at = maxi(int(a[4]), PULL_EVERY)
		_boss_stage = int(a[5])
		_pull_due = a[6] > 0.5
		var ids := Games.ids()
		last_id = str(ids[int(a[7])]) if int(a[7]) >= 0 and int(a[7]) < ids.size() else ""
	else:
		_pull_at = (combo / PULL_EVERY + 1) * PULL_EVERY


# (the classic fight's own picking of moves: not here)
func _set_move(m: String) -> void:
	if not _ready_done:
		move = m
		move_t = 0.0
		return
	_start_move(m)


func _next_move() -> void:
	pass


func _show(m: String) -> void:
	if move != m:
		move = m
		move_t = 0.0
		move_started.emit(m)


func carry_on(m: String, stretch_was := 0.0, turn := 0.0, hold_was := 1.0, burst := 0.0) -> void:
	if m == "rest" or not PIECES.has(m) or m == "jump":
		m = "sound"          # (a jump's picked up as he lands)
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
	game = null
	_start_move(m, true)


## He starts something: a set of games. `long`: with time to get your hands on it.
func _start_move(m: String, long := false) -> void:
	if not PIECES.has(m):
		m = "sound"
	if m in ["jump", "charge"]:
		set_left = 1
	elif m == "surge":
		set_left = 2
	else:
		set_left = rng.randi_range(2, 4)
	if m == "run" and _burst > 0.0 and kg >= 100.0:
		set_left = maxi(set_left, 3)         # (a giant's first run: a good part of the spool)
	if m in ["run", "circle"] and rng.randf() < 0.5:
		_turn_sign = -_turn_sign
	_hold_t = rng.randf_range(6.0, 10.0) * (0.6 + 0.4 * energy)
	if long:
		breath = BREATH_LONG
	_show("dog" if m == "jump" else m)
	_jumping = m == "jump"
	events.append(["move", m])


func _hurt(x: float, why: String) -> void:
	if in_holder or grace > 0.0 or x <= 0.0:
		return
	hold -= x * (1.0 - 0.6 * assist / ASSIST_MOST)
	_why = why


func _tire(secs: float) -> void:
	energy -= secs / (_goal_s * pace) * mult() * lerpf(0.45, 1.0, angle_k())


func _why_now() -> String:
	if airborne or _jumping:
		return "thrown"
	return "shaken" if move in ["shake", "charge"] else "pulled"


## One tick: `crank` is A (0..1), pull_btn is B.
func step(dt: float, crank: float, _rod_pitch: float, _side: float, drag_set: float) -> void:
	if done or dt <= 0.0:
		return
	if freeze > 0.0 and not in_holder:
		freeze -= dt
		return
	drag = clampf(drag_set, 0.0, 1.0)
	var a_on := not in_holder and crank > 0.4
	var b_on := not in_holder and pull_btn > 0.4
	var a_tap := a_on and not _a_was
	var b_tap := b_on and not _b_was
	_a_was = a_on
	_b_was = b_on
	reeling = a_on
	grinding = false
	if events.size() > 32:
		events = events.slice(-12)       # (nobody's reading them: a rod in its holder)
	grace = maxf(grace - dt, 0.0)
	grade_t += dt
	move_t += dt
	_jit += (rng.randf_range(-1.0, 1.0) - _jit) * minf(1.0, 1.5 * dt)
	airborne = false
	_slack_m = move_toward(_slack_m, 0.0, 4.0 * dt)
	var fresh := 0.45 + 0.55 * energy
	var beaten := energy < BEATEN
	var g := 0.0          # how the game's going, -1..1
	var work := 0.0       # how hard he's being worked (s of tiring a second)
	var tens := 0.3
	var surf := false

	if in_holder:
		# (on its drag: he takes line, the hook's left alone, nobody's playing)
		g = -0.5
		work = 0.12
		tens = 0.2
		pose = 0.7
		_hold_t -= dt
		if _hold_t <= 0.0:
			_start_move(_pick_move())
	elif game != null:
		game.step(dt, a_on, b_on, a_tap, b_tap)
		g = clampf(game.gain, -1.0, 1.0)
		if practice:
			g = maxf(g, 0.0)
		var tire_k := clampf(game.tire, 0.0, 1.0)
		if a_on or b_on or _busy_t > 0.0:
			tire_k = maxf(tire_k, WORK_FLOOR + 0.3 * assist / ASSIST_MOST)       # (hands on it at all lately: he's being worked)
		_busy_t = 1.5 if a_on or b_on else maxf(_busy_t - dt, 0.0)
		work = tire_k * float(WORK.get(move, 1.2))
		tens = game.tension
		pose = lerpf(0.35, 1.3, clampf(game.pose, 0.0, 1.0))
		airborne = game.air
		surf = game.surface
		if airborne:
			_thrown_t = 1.0
		if game.leap:
			_show("jump")
		if game.slack > 0.0:
			_slack_m = maxf(_slack_m, game.slack * 5.0)
		for e: Array in game.events:
			if e[0] == "pull":
				_fire_pull()
			else:
				events.append(e)
		if game.burst > 0.0:
			haul += BURST_M * game.burst * line_mult() / pace
			_tire(BURST_S * game.burst)
			game.burst = 0.0
		if game.hurt > 0.0:
			var h := 0.0 if practice else minf(game.hurt, _hurt_left)
			_hurt_left -= h
			_hurt(MISS_HOLD * h, _why_now())
			game.hurt = 0.0
		if game.hook > 0.0 and not practice:
			_hurt(HOOK_RATE * game.hook * dt, _why_now())
		if game.fray > 0.0 and grace <= 0.0 and not practice:
			wear += FRAY_RATE * game.fray * dt * (1.0 - 0.6 * assist / ASSIST_MOST)
			_why = "pulled"
	else:
		work = 0.15
		pose = move_toward(pose, 0.7, 1.5 * dt)
		breath -= dt
		if breath <= 0.0:
			_begin_next()

	# the line: what his move gives and takes, by how the game's going
	var l: Array = LINE.get(move, LINE["sound"])
	var rate := lerpf(float(l[1]), float(l[2]), g) if g >= 0.0 else lerpf(float(l[1]), float(l[0]), -g)
	var k := line_mult() * lerpf(0.45, 1.0, angle_k()) / pace       # (what a metre of your winding's worth)
	var pay := 0.0        # line he takes (m/s)
	var win := 0.0        # line you take (m/s)
	match int(l[3]):
		1:
			pay = -rate * v_free() * fresh * (1.0 + 0.4 * clampf(_burst / BURST, 0.0, 1.0))
		2:
			win = rate * v_free() * 0.55 * (0.5 + 0.5 * energy) / pace
		_:
			if rate >= 0.0:
				win = rate * k * (1.5 if beaten else 1.0)
			else:
				pay = -rate * fresh * (0.3 if beaten else 1.0)
	_burst = maxf(_burst - dt, 0.0)
	if not in_holder:
		pay *= 1.0 - 0.6 * assist / ASSIST_MOST        # (struggling: he takes less)
	if game is Pull or game is Clear:
		pay = 0.0                 # (the BIG PULL's yours: he takes nothing while it's on)
	if move == "charge" and line_out < 22.0 and game != null and game.only:
		game.done = true          # (he's here: he turns away)

	# what he owes you, coming in
	if haul > 0.0:
		var h := minf(haul, HAUL_RATE * dt)
		haul -= h
		win += h / dt
	if _pull_haul > 0.0:
		var h := minf(_pull_haul, PULL_RATE * dt)
		_pull_haul -= h
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
		_pull_haul = 0.0
	paying = maxf(pay - minf(boat_close, 0.0), 0.0)
	slipping = paying > 0.6
	wind = win
	speed = pay - win
	# the tension: eased to where the game puts it; slack when there's a belly in it
	var tgt := 0.1 + 0.58 * clampf(tens, 0.0, 1.0)
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
		var o := (strain - OVER) * (1.0 - 0.6 * assist / ASSIST_MOST)
		wear += o * FRAY * dt
		_hurt(o * TEAR * dt, "pulled")

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
	if move in ["spiral", "charge"] or (beaten and line_out < SPIRAL_IN):
		bearing -= sin(wrapf(bearing, -PI, PI)) * LEAD * clampf(strain / 0.2, 0.3, 1.0) * dt
	_sweep = lerpf(_sweep, (bearing - was_b) / dt, minf(1.0, 4.0 * dt))
	_going_under = move == "spiral" and g < 0.0
	if surf:
		# (the jump: up he comes)
		depth = move_toward(depth, 0.0, maxf(_rise, 4.0) * dt)
		_dive_v = 0.0
	else:
		var goal_d := minf(float(m["depth"]) * (1.4 if nature == "sounder" and move == "sound" else 1.0), line_out * 0.85)
		if move == "spiral":
			goal_d = line_out * (0.85 if _going_under else 0.6) if line_out > 12.0 else 3.0
		elif beaten and line_out < SPIRAL_IN:
			goal_d = minf(goal_d, 3.0)
		_dive_v = move_toward(_dive_v, clampf((goal_d - depth) * 0.9, -6.0, 6.0), DIVE_EASE * dt)
		depth = maxf(depth + _dive_v * dt, 0.0)
	_thrown_t = maxf(_thrown_t - dt, 0.0) if not airborne else _thrown_t

	# the leader at the rod tip: the moment, and his last run at it
	if not leader and line_out < LEADER:
		leader = true
		leader_up.emit()
		if energy >= 0.2 and force_piece.is_empty():
			_start_move("surge")
			_last_run = true

	# the boat: the line on her rubs; under her with the props turning it's cut (half as hard on it as the classic)
	if rub_now >= 0.0:
		chafe = rub_now
	else:
		chafe = rub(_tip(hd0), _fish(hd0), half_beam, house, fore) * hd0 / (hd0 + depth + 1.0)
		if move == "spiral":
			chafe *= 0.5
		chafe = maxf(chafe, side_rub())      # (the estimate only: the real line's own word is enough)
	if game is Clear:
		pass        # (it's being worked clear: nothing more comes off it till that's settled)
	elif grace <= 0.0:
		wear += 0.5 * chafe * (0.4 + 0.6 * clampf(strain, 0.0, 1.0)) * dt / (CHAFE_LIFE * chafe_mul) \
				* (0.4 if beaten else 1.0)
		if tangled:
			wear += dt / (TANGLE_LIFE * chafe_mul)
	if wear >= 1.0 and not game is Clear:
		var how := "tangle" if tangled and chafe < 0.05 else ("chafed" if chafe > 0.05 else "broke")
		if how != "chafed" or in_holder:
			_end(how)
			return
		_start_clear(how)        # (on her hull, and somebody on the rod: a last chance to work it off her)
	if b_now() > UNDER and absf(throttle) > 0.05 and depth < 25.0 and hd0 < 35.0 and grace <= 0.0 and not game is Clear:
		_prop_t += dt
		if _prop_t >= PROP_GRACE:
			if in_holder:
				_end("cut")
				return
			_start_clear("cut")
	else:
		_prop_t = 0.0
	prop_k = clampf(_prop_t / PROP_GRACE, 0.0, 1.0)
	if line_out >= CAPACITY:
		_end("spooled")
		return
	if hold <= 0.0:
		hold = 0.0
		_end(_why)
		return

	# tiring; left alone, he gets his breath back. Each stage cleared is a step up.
	if work > 0.0:
		_tire(work * dt)
	elif energy >= BEATEN and win <= 0.0 and game != null:
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
	if game != null and (game.done or game.t >= (CAP_BOSS if _is_boss else CAP)):
		_finish()


## The game's over (or it ran too long and is swapped out): its grade, the combo, and a breath before the next.
func _finish() -> void:
	var g := game
	game = null
	breath = BREATH
	if g is Pull:
		return
	if g is Clear:
		if not (g as Clear).won:
			_end((g as Clear).why)
			return
		# worked off her: the line's still worn, but it holds, and he's given a while to get clear of her
		wear = minf(wear, CLEAR_WEAR)
		_prop_t = 0.0
		grace = CLEAR_GRACE
		events.append(["saved", (g as Clear).why])
		_start_move("run")
		return
	var q := g.score
	grade = "perfect" if q >= Q_PERFECT else ("great" if q >= Q_GREAT else ("ok" if q >= Q_OK else "miss"))
	grade_t = 0.0
	if grade == "miss":
		assist = minf(assist + ASSIST_STEP, ASSIST_MOST)
	elif grade != "ok":
		assist = maxf(assist - ASSIST_STEP * 0.5, 0.0)
	if practice:
		practice = false
		if grade == "miss":
			grade = "ok"        # (not got yet: it's shown once more, free again; got, it isn't)
		else:
			known[g.id] = 2
	match grade:
		"perfect":
			combo += 1
			hold = minf(hold + 0.02, 1.0)
			haul += 3.0 * line_mult() / pace
		"great":
			combo += 1
		"miss":
			combo = combo / 2
			_pull_at = (combo / PULL_EVERY + 1) * PULL_EVERY
			_hurt(0.015, _why_now())
	best = maxi(best, combo)
	events.append(["grade", grade, combo, g.id])
	if _is_boss:
		var won := q >= Q_GREAT
		if won:
			energy = maxf(energy - BOSS_BITE * 0.8 / stages(), 0.0)
		events.append(["boss", won])
		_is_boss = false
	if combo >= _pull_at:
		_pull_due = true
		_pull_at = (combo / PULL_EVERY + 1) * PULL_EVERY
		events.append(["pull_ready", combo / PULL_EVERY])
	games_done += 1
	set_left -= 1
	_last_run = false
	_jumping = false


## The line's about to part on her hull, or go in her props: whatever game was on is dropped for the one that
## saves it (tuna/minigames/clear.gd). Won, the fight goes on; lost, the fish is gone the way it was going.
func _start_clear(how: String) -> void:
	wear = minf(wear, 0.99)
	var c := Clear.new()
	c.why = how
	game = c
	_is_boss = false
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi()
	c.begin(difficulty(), r, {})
	events.append(["game", c.id, false])
	events.append(["clear", how])


## The BIG PULL goes off: a great chunk of line, coming in fast.
func _fire_pull() -> void:
	var level := maxi((game as Pull).level, 1)
	var m := minf(PULL_M + PULL_M_STEP * (level - 1), PULL_M_MAX)
	m = clampf(m, 0.0, maxf(line_out - BOATSIDE, 0.0))
	_pull_haul += m
	_tire(PULL_TIRE)
	events.append(["pull", m, level])


## The next game: the BIG PULL if one's owed; the game his move is (the jump, the charge); a boss at a stage's end;
## or the next out of the bag.
func _begin_next() -> void:
	if force_piece == "clear":
		_start_clear("chafed")       # (for a picture of it)
		return
	if set_left <= 0 and not _pull_due:
		_start_move(_pick_move())
	var v := {}
	var tier := difficulty()
	_is_boss = false
	_hurt_left = HURT_CAP
	if _pull_due or force_piece == "pull":
		_pull_due = false
		var p := Pull.new()
		p.level = maxi(combo / PULL_EVERY, 1)
		game = p
	else:
		var id := ""
		var about := Games.about()
		if about.has(force_piece):
			id = force_piece
		else:
			for gid: String in about:
				var g := about[gid] as Minigame
				if g.only and g.moves.has("jump" if _jumping else move):
					id = gid
			if id == "" and _boss_due():
				id = _draw_boss()
				_is_boss = true
				_boss_stage = stage
				_last_boss = id
				v["boss"] = true
				tier += 0.15
			elif id == "":
				id = _draw()
		game = Games.make(id)
		var n := int(seen.get(id, 0))
		seen[id] = n + 1
		if n > 0 and not _is_boss:
			match rng.randi_range(0, 3):
				0:
					v["mirror"] = true
				1:
					v["fast"] = 1.2
				2:
					v["twist"] = true
		if not game.only:
			last_id = id
	if beat_fn.is_valid():
		var b: Array = beat_fn.call()
		if b.size() >= 2 and float(b[0]) > 0.1:
			v["beat"] = float(b[0])
			v["to_beat"] = float(b[1])
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi()
	tier = maxf(tier - assist, 0.0)
	game.begin(tier, r, v)
	practice = false
	if teach and not in_holder and int(known.get(game.id, 0)) < 2 and not game is Pull:
		known[game.id] = int(known.get(game.id, 0)) + (2 if known.has(game.id) else 1)
		practice = true
		freeze = TEACH
	_rise = depth / 0.8
	events.append(["game", game.id, _is_boss])


func _boss_due() -> bool:
	return stage < stages() and _boss_stage < stage and stage_frac() >= BOSS_AT and energy > 0.2


## The next out of the bag: one that suits what he's doing if there is one, never the one just played; the bag's
## refilled (and shuffled) when it's gone round.
func _draw() -> String:
	var about := Games.about()
	for again in 2:
		if _bag.is_empty():
			for gid: String in about:
				var g := about[gid] as Minigame
				if not g.boss and not g.only and g.from <= 1.0 - energy:
					_bag.append(gid)
			_shuffle(_bag)
		var pick := -1
		for i in _bag.size():
			var g := about[_bag[i]] as Minigame
			if _bag[i] != last_id and (g.moves.is_empty() or g.moves.has(move)):
				pick = i
				break
		if pick < 0:
			for i in _bag.size():
				if _bag[i] != last_id:
					pick = i
					break
		if pick >= 0:
			var id: String = _bag[pick]
			_bag.remove_at(pick)
			return id
		_bag.clear()
	return "pump" if last_id != "pump" else "ride"


## A boss: one of the boss games, or a big one of those that can be; never the last boss again.
func _draw_boss() -> String:
	var about := Games.about()
	var can: Array = []
	for gid: String in about:
		var g := about[gid] as Minigame
		if (g.boss or g.can_boss) and g.from <= 1.0 - energy and gid != _last_boss and gid != last_id:
			can.append(gid)
			if g.boss:
				can.append(gid)
				can.append(gid)       # (the real ones come up more)
	return str(can[rng.randi_range(0, can.size() - 1)]) if not can.is_empty() else "twohands"


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


## What he does next: by how tired he is and how far off, out of a shuffled bag (so a long fight has all of it and
## never the same twice running); fresh and held in close, he's off.
func _pick_move() -> String:
	var forced := Games.about().get(force_piece) as Minigame
	if forced != null and forced.only:
		return str(forced.moves[0])
	var beaten := energy < BEATEN
	var was_run := move in ["run", "surge"]
	if energy > 0.35 and line_out < CLOSE and not was_run:
		return "run" if rng.randf() < 0.6 else "surge"
	var ph := 3 if beaten and line_out <= SPIRAL_IN else (2 if beaten else (1 if energy <= 0.6 else 0))
	if ph != _mbag_phase or _mbag.is_empty():
		_mbag_phase = ph
		match ph:
			0:
				_mbag = ["sound", "shake", "run", "dog", "charge", "sound", "surge"]
				if kg < 120.0 or nature == "jumper":
					_mbag.append("jump")
			1:
				_mbag = ["sound", "dog", "shake", "circle", "surge", "charge", "dog", "jump", "run", "shake"]
			2:
				_mbag = ["circle", "sound", "dog", "circle", "shake"]
			_:
				_mbag = ["spiral", "spiral", "shake", "spiral", "surge"]
		_shuffle(_mbag)
	for i in _mbag.size():
		var p: String = _mbag[i]
		if (p == move and p != "spiral") or (was_run and p in ["run", "surge"]):
			continue
		if (p == "jump" and depth > 30.0) or (p == "charge" and line_out < 50.0):
			continue
		_mbag.remove_at(i)
		return p
	_mbag.clear()
	return "dog" if move == "sound" else "sound"


## What the HUD draws round the game: where the fight is. a, b: what each button's asked to do now (the game's cue():
## ui/kit.gd's NONE, HOLD, TAP, MASH, RELEASE, OFF).
func view() -> Dictionary:
	var c: Array = game.cue() if game != null else [0, 0]
	return {"game": game.id if game != null else "", "title": game.title if game != null else "",
			"phase": "breath" if game == null else ("pull" if game is Pull else "game"),
			"t": game.t if game != null else 0.0, "len": game.length if game != null else 1.0,
			"combo": combo, "mult": mult(), "next_pull": _pull_at, "grade": grade, "grade_t": grade_t,
			"hold": hold, "energy": energy, "stage": stage, "stages": stages(), "line_out": line_out, "wear": wear,
			"kg": kg, "angle": angle_k(), "a": int(c[0]), "b": int(c[1]), "tension": strain, "holder": in_holder,
			"leader": leader, "boss": _is_boss, "set_left": set_left, "move": move,
			"how": game.how() if game != null else "", "practice": practice, "teach": freeze if practice else 0.0,
			"assist": assist, "chafe": chafe, "prop": prop_k, "last_run": _last_run and move == "surge",
			"bolt": energy > 0.35 and line_out < CLOSE + 12.0 and line_out >= CLOSE and not move in ["run", "surge"]}


func cues() -> Dictionary:
	var c := super()
	c["arcade"] = view()
	return c
