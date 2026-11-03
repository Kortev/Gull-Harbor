extends RefCounted
## What the music wants now, worked out from a plain picture of the game (audio/music.gd reads the sea into one each
## frame: world(); the tests hand it their own). No nodes, no sound: section, stem levels and events, all testable
## headless. docs/MUSIC_SYSTEM.md is the design.
##
## It only hears what you could: the rod's bend against what the line will take, the spool, the line on her, his moves.
## Never the hook's hold or how tired he is: the music never tells you what you couldn't feel.
##
## The world, every key optional:
##   title, card, docked, paused, underwater: bool
##   counting: s into Rivals' countdown (-1: not counting); card_result: "win"/"lose"/"tie" once the stamp's down
##   race_left: s left in the race home (-1: no race on); standing: 1 ahead, -1 behind, 0 level/none (Rivals)
##   lbs: [yours, theirs] (Rivals, out there); their_on: how many fish they've got on
##   condition: the weather (sea.gd's CONDITIONS); night: bool; day: day fraction (0 dawn .. 1 dusk)
##   birds: 0..1, how near feeding birds are (1 right there); speed: 0..1 of her top speed ahead
##   fights: [{id, kg, tension (bend / what the line takes), spool (0..1 of the reel gone), depth, line_out, move,
##            slack, airborne, surging, contact (0..1 of the line worn on her), props (s under her props), tangled}]
##   alongside: [ids up alongside]; draw: the harpoon's wind-up 0..1; flying: the harpoon's in the air
##   landed: fish aboard (it going up: one landed)

const Cues := preload("res://audio/music_cues.gd")

const FIGHT := ["fight", "tired", "leader"]
const FRESH_MOVES := ["run", "sound", "dog", "jump"]
const TIRED_MOVES := ["circle", "spiral"]
## The leader's up at the rod tip under this much line (tuna/fight.gd's LEADER); it stays the leader till he's taken
## this much back out.
const LEADER := 16.0
const LEADER_OUT := 40.0
## A fight section holds at least this long (s: two bars at 112) before it changes (the leader doesn't wait).
const SECTION_HOLD := 4.3
## The bend against what the line takes (tuna/fight.gd: the drag holds at most DRAG_MAX 0.55 of it, past HOOK_T 0.5
## the hook tears; a played fish sits round 0.1, a heavy moment 0.3): the rod loaded (the tension stem coming in),
## and near going (danger).
const LOADED := Vector2(0.18, 0.4)
const NEAR := Vector2(0.4, 0.6)
## The line about to part: danger past PARTING, over till it's back under PARTED.
const PARTING := 0.85
const PARTED := 0.72
## Each stem: [attack s (0 to full), release s (full to 0), hold s (once up, it stays at least this long)].
const SMOOTH := {
	"bed": [0.5, 2.0, 0.0], "pulse": [0.2, 0.3, 0.0], "drive": [0.25, 3.0, 4.3], "shaker": [0.25, 3.0, 4.3],
	"click": [0.25, 3.0, 4.3], "tension": [0.5, 2.5, 4.3], "tension_hi": [1.0, 3.0, 4.3], "deep": [1.5, 4.0, 4.3],
	"tune": [1.0, 4.0, 8.6], "tick": [1.5, 3.0, 0.0], "glint": [2.0, 4.0, 0.0], "shimmer": [0.15, 0.4, 0.0],
	"a": [2.0, 4.0, 0.0], "b": [4.0, 4.0, 0.0], "c": [4.0, 4.0, 0.0], "d": [3.0, 4.0, 0.0],
	"pad": [3.0, 4.0, 0.0], "bass": [3.0, 4.0, 0.0], "pick": [4.0, 5.0, 0.0], "lead": [4.0, 5.0, 0.0],
	"rain": [4.0, 5.0, 0.0], "storm": [4.0, 6.0, 0.0], "night": [5.0, 5.0, 0.0], "run": [2.0, 4.0, 4.3],
	"heavy": [2.0, 4.0, 0.0], "fill": [0.01, 0.01, 0.0],
}
const SMOOTH_ELSE := [1.0, 2.0, 0.0]
## The sea's stems by mood (an endless song: the pad and the bass always, the guitar and the lead in fair weather, the
## rain's patter, the storm's drums and drone, the night's bells), and how bright a passage it leans to (0 dark .. 1
## bright: audio/music.gd picks each next one by it).
const SEA := {
	"calm": {"pad": 0.8, "bass": 0.7, "pick": 1.0, "lead": 0.9},
	"fog": {"pad": 1.0, "bass": 0.35, "pick": 0.25, "lead": 0.45, "night": 0.3},
	"rain": {"pad": 0.8, "bass": 0.8, "pick": 0.6, "lead": 0.35, "rain": 1.0},
	"storm": {"pad": 1.0, "bass": 1.0, "rain": 0.6, "storm": 1.0},
	"night": {"pad": 0.75, "bass": 0.45, "pick": 0.5, "lead": 0.3, "night": 1.0},
}
const SEA_STEMS := ["pad", "bass", "pick", "lead", "rain", "storm", "night", "run", "fill"]
## Under way: the sea's run stem (and the bass with it) from this share of her top speed to that.
const RUN := Vector2(0.25, 0.8)
## A fish this heavy (kg) to that: the fight's heavy stem in (a giant's weight, felt on the rod).
const HEAVY := Vector2(120.0, 320.0)
const BRIGHT := {"calm": 0.75, "fog": 0.35, "rain": 0.3, "storm": 0.0, "night": 0.35}
## Dusk: past this far through the day the sea leans darker (to half as bright by its end).
const DUSK := 0.75
## A fish lost: dead silence this long (s), then the sea again.
const HUSH := 6.0
## A fish gone from alongside: this long to see it in the hold (landed) before it counts as got away.
const LANDED_WAIT := 1.2
## The weather there's no waltz in, tied up: the sea's song in its storm instead.
const STORMY := ["storm", "heavy"]
## Birds: in at this near, out under this.
const BIRDS_IN := 0.12
const BIRDS_OUT := 0.05
## The race home's length (s: sea.gd's and vs.gd's HOME), and the last chance (s left, trailing).
const HOME := 360.0
const LAST := 90.0
## Lead changes: no more than one sting in this long (s).
const LEAD_GAP := 30.0

## The section wanted ("sea", "title", "harbour", "hunt", "fight", "tired", "leader", "gaff", "afterglow", "race",
## or "rest": quiet, only under Rivals' countdown and card, and the hush after a fish is lost).
var section := "sea"
## Each of its stems' level now (0..1), smoothed; and the fast mask over the fight's (the jump, the line parting).
var gains := {}
var masks := {}
## What happened this step: "strike", "lost", "landed", "leader", "their_on", "lead_up", "lead_down", "countdown",
## "card:win" (lose, tie), "dawn".
var events: Array[String] = []
## The mood at sea, and the worst fight's danger (0..1) and its id ("" none).
var mood := "calm"
var danger := 0.0
var fight_id := ""
var parting := false
## Meant to be all but silent now: the hush after a loss, him in the air, the harpoon flying, the quiet under Rivals'
## countdown and card (tools/music_check.py leaves these out of "never quiet").
var still := false
## s of the loss's silence left (music.gd drops everything at once while it's on).
var hush := 0.0
## How bright a sea passage to pick next (0 dark .. 1 bright).
var bright := 0.75

var _t := 0.0
var _section_t := 0.0
var _fight_ids := {}          # id -> true, last step
var _along_ids := {}
var _gone := {}               # alongside id -> when it went (waiting to see it in the hold)
var _landed := -1
var _their := -1
var _lead := 0
var _lead_t := -INF
var _counting := false
var _card := ""
var _dawned := false
var _after := 0.0             # s of the afterglow left
var _held := {}               # stem -> [level held, s left]
var _rng := RandomNumberGenerator.new()


func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func step(w: Dictionary, dt: float) -> void:
	events.clear()
	_t += dt
	_section_t += dt
	hush = maxf(hush - dt, 0.0)
	_after = maxf(_after - dt, 0.0)
	mood = _mood(w)
	var fights: Array = w.get("fights", [])
	var f := _worst(fights)
	danger = _danger(f) if not f.is_empty() else 0.0
	fight_id = str(f.get("id", ""))
	_edges(w, fights)
	var want := _section(w, f)
	if want != section:
		if not (section in FIGHT and want in FIGHT and want != "leader" and _section_t < SECTION_HOLD):
			if want == "leader" and section in FIGHT:
				events.append("leader")
			section = want
			_section_t = 0.0
	var wants := _wants(w, f)
	_smooth(wants, dt)
	_mask(w, f, dt)
	bright = float(BRIGHT.get(mood, 0.5)) * lerpf(1.0, 0.5, smoothstep(DUSK, 1.0, float(w.get("day", 0.0))))
	if events.has("dawn"):
		bright = 1.0


## The fight that's worst off (the most danger; the newest of equals).
func _worst(fights: Array) -> Dictionary:
	var best := {}
	var d := -1.0
	for f: Dictionary in fights:
		var k := _danger(f)
		if k > d + 0.001 or (absf(k - d) <= 0.001 and str(f.get("id", "")) > str(best.get("id", ""))):
			best = f
			d = k
	return best


## A fight's feel from its own cues (tuna/fight.gd's cues(), on the machine holding the rod; `strength` what the
## line takes now): the bend against it, the spool, slack, in the air, a run (the reel screaming), the line on her.
static func feel(c: Dictionary, strength: float) -> Dictionary:
	return {"tension": float(c["tension"]) / maxf(strength, 0.05), "spool": float(c["spool"]), "slack": bool(c["slack"]),
			"airborne": bool(c["airborne"]), "surging": bool(c["surging"]) or float(c["paying"]) > 1.5,
			"contact": float(c["contact"]), "props": float(c["props"])}


## How near the line is to going, from what you could see and feel: the bend against what the line takes, the backing
## showing, the line worn on her, under her props, tangled.
static func _danger(f: Dictionary) -> float:
	var d := smoothstep(NEAR.x, NEAR.y, float(f.get("tension", 0.0)))
	d = maxf(d, smoothstep(0.5, 0.9, float(f.get("spool", 0.0))))
	d = maxf(d, smoothstep(0.4, 0.9, float(f.get("contact", 0.0))))
	d = maxf(d, clampf(float(f.get("props", 0.0)) / 2.5, 0.0, 1.0))
	if bool(f.get("tangled", false)):
		d = maxf(d, 0.7)
	return d


func _mood(w: Dictionary) -> String:
	var c := str(w.get("condition", "calm"))
	if c == "storm":
		return "storm"
	if c == "fog":
		return "fog"
	if bool(w.get("night", false)):
		return "night"
	if c == "rain" or c == "heavy":
		return "rain"
	return "calm"


## Things that happen: the strike, a fish lost or landed, their fish on, the lead changing, the countdown, the card,
## the dawn.
func _edges(w: Dictionary, fights: Array) -> void:
	var now := {}
	for f: Dictionary in fights:
		now[str(f.get("id", ""))] = true
	var along := {}
	for id: Variant in w.get("alongside", []):
		along[str(id)] = true
	var landed := int(w.get("landed", 0))
	var got := _landed >= 0 and landed > _landed
	for id: String in now:
		if not _fight_ids.has(id) and not _along_ids.has(id):
			events.append("strike")
			hush = 0.0
			break
	for id: String in _fight_ids:
		if not now.has(id) and not along.has(id) and now.is_empty() and along.is_empty() and not got:
			_lost()
	for id: String in _along_ids:
		if not along.has(id) and not now.has(id):
			_gone[id] = _t
	if got:
		_gone.clear()
		events.append("landed")
		# the afterglow till its last chord's ringing (its last two bars): the sea comes in under the ring
		var ag: Dictionary = Cues.CUES.get("afterglow", {})
		_after = (int(ag.get("bars", 10)) - 2) * int(ag.get("bar_beats", 4)) * 60.0 / float(ag.get("bpm", 112.0))
	else:
		for id: String in _gone.keys():
			if _t - float(_gone[id]) >= LANDED_WAIT:
				_gone.erase(id)          # (not in the hold: he got away from alongside)
				if now.is_empty() and along.is_empty():
					_lost()
	_fight_ids = now
	_along_ids = along
	_landed = landed
	# Rivals
	var their := int(w.get("their_on", 0))
	if _their >= 0 and their > _their and not bool(w.get("docked", false)):
		events.append("their_on")
	_their = their
	var lbs: Array = w.get("lbs", [])
	if lbs.size() == 2:
		var lead := 0
		var gap := float(lbs[0]) - float(lbs[1])
		if absf(gap) >= 1.0:
			lead = 1 if gap > 0.0 else -1
		if lead != 0 and lead != _lead and _t - _lead_t >= LEAD_GAP and not bool(w.get("docked", false)):
			events.append("lead_up" if lead > 0 else "lead_down")
			_lead_t = _t
			_lead = lead               # (held back by LEAD_GAP, it's still a change to tell once the gap's up)
	var counting := float(w.get("counting", -1.0)) >= 0.0
	if counting and not _counting:
		events.append("countdown")
	_counting = counting
	var card := str(w.get("card_result", "")) if bool(w.get("card", false)) else ""
	if card != "" and card != _card:
		events.append("card:" + card)
	_card = card
	# the dawn: once a trip, as the first light comes
	if bool(w.get("docked", true)):
		_dawned = false
	elif not _dawned and float(w.get("day", 0.0)) > 0.015:
		_dawned = true
		if float(w.get("day", 0.0)) < 0.08:
			events.append("dawn")


func _lost() -> void:
	if events.has("lost"):
		return
	events.append("lost")
	hush = HUSH


func _section(w: Dictionary, f: Dictionary) -> String:
	if bool(w.get("title", false)):
		return "title"
	if bool(w.get("card", false)) or float(w.get("counting", -1.0)) >= 0.0:
		return "rest"
	if not f.is_empty():
		var out := float(f.get("line_out", 100.0))
		var mv := str(f.get("move", ""))
		var same := str(f.get("id", "")) == fight_id
		if out < LEADER or (section == "leader" and same and out < LEADER_OUT):
			return "leader"
		if mv in TIRED_MOVES:
			return "tired"
		if section == "tired" and not mv in FRESH_MOVES:
			return "tired"
		return "fight"
	if hush > 0.0:
		return "rest"
	if not (w.get("alongside", []) as Array).is_empty():
		return "gaff"
	if _after > 0.0:
		return "afterglow"
	if float(w.get("race_left", -1.0)) >= 0.0:
		return "race"
	if bool(w.get("docked", false)):
		return "sea" if str(w.get("condition", "calm")) in STORMY else "harbour"
	var birds := float(w.get("birds", 0.0))
	if birds >= BIRDS_IN or (section == "hunt" and birds >= BIRDS_OUT):
		return "hunt"
	return "sea"


## Each stem's level wanted (before smoothing).
func _wants(w: Dictionary, f: Dictionary) -> Dictionary:
	match section:
		"title", "afterglow":
			return {"main": 1.0}
		"harbour":
			return _harbour(w)
		"sea":
			var want := {}
			var m: Dictionary = SEA.get(mood, SEA["calm"])
			for k: String in SEA_STEMS:
				want[k] = float(m.get(k, 0.0))
			# under way: the drums' eighths and the bass pushing; the faster she goes, the more
			var run := smoothstep(RUN.x, RUN.y, float(w.get("speed", 0.0)))
			want["run"] = run * (0.5 if mood == "storm" else 1.0)
			want["bass"] = maxf(float(want["bass"]), 0.6 + 0.4 * run)
			return want
		"hunt":
			var b := float(w.get("birds", 0.0))
			return {"pulse": smoothstep(0.05, 0.6, b), "tick": smoothstep(0.3, 0.8, b),
					"glint": 0.8 * smoothstep(0.05, 0.4, b)}
		"gaff":
			return {"bed": 1.0, "pulse": 1.0, "shimmer": maxf(float(w.get("draw", 0.0)), 0.15)}
		"race":
			return _race(w)
		"fight", "tired", "leader":
			return _fight(w, f)
	return {}


## Tied up, by the weather: the waltz in fair weather; in rain the guitar alone, quieter; in fog the concertina far
## off down the quay, the guitar barely; at night both soft. (A storm or a downpour: no waltz at all, STORMY.)
func _harbour(w: Dictionary) -> Dictionary:
	match str(w.get("condition", "calm")):
		"rain":
			return {"guitar": 0.6, "reed": 0.0}
		"fog":
			return {"guitar": 0.25, "reed": 0.8}
	if bool(w.get("night", false)):
		return {"guitar": 0.6, "reed": 0.45}
	return {"guitar": 1.0, "reed": 1.0}


func _race(w: Dictionary) -> Dictionary:
	var left := float(w.get("race_left", HOME))
	var p := clampf(1.0 - left / HOME, 0.0, 1.0)
	var st := int(w.get("standing", 0))
	var tune := 0.3 + 0.7 * smoothstep(0.05, 0.4, p)
	if st > 0:
		tune = maxf(tune, 0.85)
	var urge := smoothstep(0.5, 0.88, p)
	var last := 0.0
	if st < 0:
		urge = maxf(urge, smoothstep(LAST + 30.0, LAST, left))
		last = smoothstep(LAST, LAST - 60.0, left)
	return {"a": 1.0, "b": tune, "c": urge, "d": last}


func _fight(w: Dictionary, f: Dictionary) -> Dictionary:
	var mv := str(f.get("move", ""))
	var spool := float(f.get("spool", 0.0))
	var drive := 0.6
	match mv:
		"run", "surge", "charge":
			drive = 1.0
		"jump":
			drive = 0.8
		"shake":
			drive = 0.55
		"sound", "dog":
			drive = 0.25
		"circle", "spiral":
			drive = 0.6               # (tiring, circling: the drums stay up under the tune, the end's not won yet)
	if bool(f.get("surging", false)):
		drive = 1.0
	if section == "leader":
		drive = maxf(drive, 0.8)
	if spool > 0.5:
		drive = maxf(drive, 0.85)
	var night := bool(w.get("night", false))
	var depth := float(f.get("depth", 0.0))
	var deep := 1.0 if mv in ["sound", "dog"] or depth > 40.0 else (0.3 if depth > 20.0 else 0.0)
	if str(w.get("condition", "")) == "storm":
		deep = maxf(deep, 0.5)
	var heavy := smoothstep(HEAVY.x, HEAVY.y, float(f.get("kg", 0.0)))
	deep = maxf(deep, 0.5 * heavy)
	return {"heavy": heavy, "bed": 1.0, "pulse": 0.0 if bool(f.get("slack", false)) else 1.0, "drive": drive,
			"shaker": 0.0 if night else drive, "click": drive if night else 0.0,
			"tension": maxf(smoothstep(LOADED.x, LOADED.y, float(f.get("tension", 0.0))), smoothstep(0.2, 0.8, danger)),
			"tension_hi": maxf(smoothstep(0.5, 0.85, spool), 0.6 * smoothstep(0.7, 0.95, danger)),
			"deep": deep, "tune": {"tired": 0.85, "leader": 1.0}.get(section, 0.0)}


func _smooth(wants: Dictionary, dt: float) -> void:
	for k: String in gains.keys():
		if not wants.has(k):
			gains.erase(k)
			_held.erase(k)
	for k: String in wants:
		var want := clampf(float(wants[k]), 0.0, 1.0)
		var sm: Array = SMOOTH.get(k, SMOOTH_ELSE)
		if not gains.has(k):
			gains[k] = want          # (a section's stems start where they're wanted: it comes in by its own fade)
			continue
		var g := float(gains[k])
		var h: Array = _held.get(k, [0.0, 0.0])
		# up, it holds; and as long as it's wanted that high again within the hold, the hold starts over
		if float(sm[2]) > 0.0 and want > 0.05 and (want > g + 0.05 or (float(h[1]) > 0.0 and want >= float(h[0]) - 0.05)):
			h = [maxf(want, float(h[0]) if float(h[1]) > 0.0 else 0.0), float(sm[2])]
		h[1] = maxf(float(h[1]) - dt, 0.0)
		if float(h[1]) > 0.0:
			want = maxf(want, float(h[0]))
		_held[k] = h
		g = move_toward(g, want, dt / maxf(float(sm[0] if want > g else sm[1]), 0.01))
		gains[k] = g


## The fast masks over the fight: him in the air (everything all but gone till he's back in), the line about to part
## (only the heartbeat and one shaking note: the barest music in the game), the harpoon flying (silence).
func _mask(w: Dictionary, f: Dictionary, dt: float) -> void:
	if danger >= PARTING:
		parting = true
	elif danger < PARTED:
		parting = false
	parting = parting and section in FIGHT
	var air := section in FIGHT and bool(f.get("airborne", false))
	var flying := section == "gaff" and bool(w.get("flying", false))
	for k: String in gains:
		var m := 1.0
		if parting:
			m = {"bed": 0.3, "pulse": 1.0, "tension": 1.0, "heavy": 0.5}.get(k, 0.0)
		if air:
			m = minf(m, 0.15)
		if flying:
			m = 0.08 if k == "bed" else 0.0
		var cur := float(masks.get(k, 1.0))
		masks[k] = move_toward(cur, m, dt / (0.08 if m < cur else 0.2))
		if parting and k == "tension":
			gains[k] = maxf(float(gains[k]), 1.0)
	for k: String in masks.keys():
		if not gains.has(k):
			masks.erase(k)
	still = hush > 0.0 or air or flying or section == "rest"


## A stem's level as it should sound (its gain under its mask).
func level(k: String) -> float:
	return float(gains.get(k, 0.0)) * float(masks.get(k, 1.0))
