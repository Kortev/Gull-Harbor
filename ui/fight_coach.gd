extends RefCounted
## The fight taught in the moment, a line at a time, while he fights (never frozen): ui/fight_hud.gd asks it every
## frame what to say over the fight in your hands, and draws it. It reads the fight the way you would (the reel
## screaming, the bend, the rod up or down, your hand on the crank), and says the one thing to do now:
##
##   he's taking line          LET HIM RUN - DON'T WIND             (hands off)
##   he's stopped              LIFT (MOUSE UP)  >  WIND AS YOU DROP (HOLD LMB)   (the half you're on lit)
##   he's jumping              DROP THE TIP (MOUSE DOWN)
##   slack, coming at you      WIND! KEEP IT TIGHT (HOLD LMB)
##   near parting              TOO TIGHT! EASE THE DRAG (SCROLL DOWN)
##
## Each fades out once you've shown you've got it (a couple of runs let go, three pumps done), and comes back, in red,
## the moment you flounder (cranking into a run, winding against him without lifting, sitting there doing nothing).
## The drag's notches say what they do as you move the lever. What you've learned is kept on this machine with the
## tutor's (ui/fight_tutor.gd's SAVE) in real play, so the next fight starts quieter. Presentation only: it never
## touches the fight.

const Fight := preload("res://tuna/fight.gd")
const SAVE := "user://bluefin_tutor.cfg"
## Shown it right this many times and it's learned (it fades).
const RUNS_TO_LEARN := 2
const PUMPS_TO_LEARN := 4
## How long a flounder keeps its line up (s), and how long winding into a run / grinding / sitting idle before it's
## one.
const FLOUNDER_T := 6.0
const CRANK_INTO_RUN := 0.5
const GRIND_T := 1.6
const IDLE_T := 7.0
## The rod's elevation (rods.gd's aim_pitch) at the top of a lift and the bottom of a drop.
const TOP := 1.05
const BOTTOM := 0.55

## Kept in real play (rods.gd sets it from the tutor's `keep`).
var keep := false
var runs := 0                 # runs let go hands off
var pumps := 0                # pumps done (lifted to the top, wound back down)
## What to say now: `say` the line (the pump's two halves: `say` and `then`, `first` which is lit), `keys` which of
## the keys to light ("lift", "wind", "drop", "drag_down", "drag_up", "none"), `tone` "do" / "hold" / "bad", `a`
## how much it's showing (0..1, eased).
var say := ""
var then := ""
var first := true
var keys := ""
var tone := "do"
var a := 0.0
## The key caps by the reel: how much they're showing (0..1, eased).
var caps_a := 1.0
## His state in a word (RUNNING, DEEP, TIRED, SURGING, JUMPING, SHAKING, CHARGING, SLACK) and its tone.
var word := ""
var word_tone := "hold"
## The drag lever's last move: what that notch does, and s since.
var drag_note := ""
var drag_t := 99.0

var _phase := "lift"          # the pump: "lift" or "drop"
var _drop_wound := 0.0        # s of winding on this drop
var _drop_t := 0.0
var _run_t := 0.0             # s into this run
var _run_crank := 0.0         # s cranked into it
var _grind := 0.0
var _idle := 0.0
var _last_pitch := NAN
var _flounder := 0.0          # s left of the flounder's line
var _flounder_say := ""
var _flounder_keys := ""
var _fight_t := 0.0
var _loaded := false


func _load() -> void:
	_loaded = true
	if not keep:
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		runs = int(cfg.get_value("coach", "runs", 0))
		pumps = int(cfg.get_value("coach", "pumps", 0))


func _save() -> void:
	if not keep:
		return
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("coach", "runs", runs)
	cfg.set_value("coach", "pumps", pumps)
	cfg.save(SAVE)


## Forget what's been learned (the field guide's "show them all again").
func reset() -> void:
	runs = 0
	pumps = 0
	_save()


func learned() -> bool:
	return runs >= RUNS_TO_LEARN and pumps >= PUMPS_TO_LEARN


## A new fish in your hands.
func begin() -> void:
	if not _loaded:
		_load()
	_fight_t = 0.0
	_phase = "lift"
	_run_t = 0.0
	_run_crank = 0.0
	_grind = 0.0
	_idle = 0.0
	_flounder = 0.0
	_last_pitch = NAN
	caps_a = 1.0


## The lever moved to `drag` (0 free .. 1 full), tighter or not: what that notch does.
func dragged(drag: float, tighter: bool) -> void:
	drag_t = 0.0
	if drag <= 0.01:
		drag_note = "FREE SPOOL: NOTHING ON HIM"
	elif is_equal_approx(drag, Fight.STRIKE_DRAG):
		drag_note = "STRIKE: THE SETTING HE CAME ON AT"
	elif drag >= 0.99:
		drag_note = "FULL: HARDEST ON HIM, AND ON THE LINE"
	elif tighter:
		drag_note = "TIGHTER: HE TAKES LESS LINE, THE LINE TAKES MORE"
	else:
		drag_note = "LIGHTER: HE TAKES LINE EASIER, SAFER ON THE LINE"


## His state in a word, from what everyone aboard can see of a rod (its move, the reel paying out, the line slack,
## how deep): RUNNING or SURGING only while he's really taking line (hands off), TIRED in his tired moments and once
## he's beaten (pump him), DEEP or PULLING while he leans on it and the drag holds (pump him).
static func word_of(move: String, paying: bool, slack: bool, energy: float, lull := 1.0, depth := 30.0) -> Array:
	if slack:
		return ["SLACK", "bad"]
	match move:
		"jump":
			return ["JUMPING", "bad"]
		"charge":
			return ["CHARGING", "bad"]
	if paying:
		return ["SURGING" if move == "surge" else "RUNNING", "hold"]
	if move == "shake":
		return ["SHAKING", "hold"]
	if move in ["circle", "spiral"] or energy < Fight.BEATEN or lull < 0.5:
		return ["TIRED", "do"]
	return ["DEEP" if depth > 20.0 else "PULLING", "do"]


## A frame on, with fight `f` in your hands: `pitch` the rod's elevation, `crank` your hand on the reel.
func tick(dt: float, f: Fight, pitch: float, crank: bool) -> void:
	_fight_t += dt
	drag_t += dt
	_flounder = maxf(_flounder - dt, 0.0)
	var slack := f.stretch < -0.5 or f.slack_t > 0.4
	var running := f.slipping or f.paying > 0.5
	var w := word_of(f.move, running, slack, f.energy, f.lull, f.depth)
	word = w[0]
	word_tone = w[1]
	var danger := f.t_fish / maxf(f.strength(), 0.01)
	var dp := 0.0 if is_nan(_last_pitch) else pitch - _last_pitch
	_last_pitch = pitch
	then = ""
	first = true
	var show := 1.0
	# the run: hands off. Let one go cleanly and it counts; crank into it and you're told, in red
	if running and not slack and f.move != "jump":
		_run_t += dt
		if crank:
			_run_crank += dt
			if _run_crank > CRANK_INTO_RUN:
				_flounder_at("DON'T WIND WHILE HE RUNS! HANDS OFF", "none")
				runs = 0
	elif _run_t > 0.0:
		if _run_t > 1.2 and _run_crank < _run_t * 0.25:
			runs += 1
			_save()
		_run_t = 0.0
		_run_crank = 0.0
		if _flounder_keys == "none":
			_flounder = 0.0        # (the run's over: that telling-off is too)
	# the pump: up to the top, then wound back down
	if pitch >= TOP and _phase == "lift":
		_phase = "drop"
		_drop_wound = 0.0
		_drop_t = 0.0
	elif _phase == "lift" and not running and f.strain >= f.drag_now * 0.97 and f.drag_now > 0.05 and dp > 0.0:
		_phase = "drop"          # (lifted till the drag gives: that's as far as it'll go)
		_drop_wound = 0.0
		_drop_t = 0.0
	elif pitch <= BOTTOM and _phase == "drop":
		_phase = "lift"
		if _drop_t > 0.3 and _drop_wound > _drop_t * 0.5:
			pumps += 1
			_save()
	if _phase == "drop":
		_drop_t += dt
		if crank:
			_drop_wound += dt
	# floundering in the pump: winding against him without lifting, or sitting there
	if not running and not slack and f.move != "jump":
		_grind = _grind + dt if crank and f.grinding and dp < 0.002 else 0.0
		if _grind > GRIND_T:
			_flounder_at("WINDING WON'T MOVE HIM. LIFT FIRST (MOUSE UP)", "lift")
			pumps = maxi(pumps - 2, 0)
			_grind = 0.0
		_idle = _idle + dt if not crank and absf(dp) < 0.002 else 0.0
		if _idle > IDLE_T and _fight_t > 8.0:
			_flounder_at("HE'S RESTING. MOVE HIM: LIFT (MOUSE UP)", "lift")
			pumps = maxi(pumps - 1, 0)
			_idle = 0.0
	# what to say: the one that can't wait first
	tone = "do"
	if slack:
		say = "SLACK! WIND! KEEP IT TIGHT (HOLD LMB)"
		keys = "wind"
		tone = "bad"
	elif f.move == "jump" or f.airborne:
		say = "HE'S JUMPING! DROP THE TIP (MOUSE DOWN)"
		keys = "drop"
		tone = "bad"
	elif danger > 0.8:
		say = "TOO TIGHT! EASE THE DRAG (SCROLL DOWN)"
		keys = "drag_down"
		tone = "bad"
	elif _flounder > 0.0:
		say = _flounder_say
		keys = _flounder_keys
		tone = "bad"
	elif running:
		say = "LET HIM RUN - DON'T WIND"
		keys = "none"
		tone = "hold"
		show = 0.0 if runs >= RUNS_TO_LEARN else 1.0
		if f.line_out > Fight.CAPACITY * 0.6:
			say = "HE'S TAKING IT ALL! MORE DRAG (SCROLL UP)"
			keys = "drag_up"
			show = 1.0
	else:
		say = "LIFT (MOUSE UP)"
		then = "WIND AS YOU DROP (HOLD LMB)"
		first = _phase == "lift"
		keys = "lift" if first else "wind"
		show = 0.0 if pumps >= PUMPS_TO_LEARN else 1.0
	a = move_toward(a, show, dt * (4.0 if show > a else 0.8))
	# the key caps: the first moments of every fight, till it's all learned, and whenever you flounder
	var caps := _fight_t < 6.0 or not learned() or _flounder > 0.0
	caps_a = move_toward(caps_a, 1.0 if caps else 0.0, dt * (4.0 if caps else 0.5))


func _flounder_at(text: String, k: String) -> void:
	_flounder = FLOUNDER_T
	_flounder_say = text
	_flounder_keys = k
