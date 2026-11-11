extends RefCounted
## What the music wants now, worked out from a plain picture of the game (audio/music.gd reads the sea into one each
## frame: world(); the tests hand it their own). No nodes, no sound: all testable headless. docs/MUSIC_SYSTEM.md is
## the design.
##
## A few songs and the fight, nothing switched in the middle of a phrase:
##   - the title's own piece while the title's up;
##   - out there and tied up, the weather's song (fair, rain, fog, night, storm), played through and round, changing
##     only when the weather's turned for a while (audio/music.gd crossfades them slowly); tied up, softer; her speed
##     brings its run layer up;
##   - a fish on: the fight's track, in on the strike (its intro: the hit, the drums rising), its three layers up and
##     down with how hard he's fighting (intensity: the pulse always, the drums from DRUMS, the whole band from FULL);
##   - he's in: the landed flourish, the song back after it; he's gone: the fight let go, a breath of quiet, the song.
## Nothing else cues anything: the thunder, the birds, the leader, boatside, Rivals' lead are the world's own sounds.
##
## It only hears what you could: the rod's bend against what the line will take, the spool, the line on her, his moves.
## Never the hook's hold or how tired he is: the music never tells you what you couldn't feel.
##
## The world, every key optional:
##   title, card, docked, paused: bool
##   counting: s into Rivals' countdown (-1: not counting); card_result: "win"/"lose"/"tie" once the stamp's down
##   race_left: s left in the race home (-1: no race on)
##   condition: the weather (sea.gd's CONDITIONS); night: bool; speed: 0..1 of her top speed ahead
##   fights: [{id, kg, tension (bend / what the line takes), spool (0..1 of the reel gone), depth, line_out, move,
##            slack, airborne, surging, contact (0..1 of the line worn on her), props (s under her props), tangled}]
##   alongside: [ids up alongside]; landed: fish aboard (it going up: one landed)

## Where the music is: "title", "song" (the weather's: out there or tied up), "fight" (a fish on, or alongside),
## "after" (landed: the flourish ringing, the fight let go), "quiet" (a fish lost; Rivals' countdown and card).
var place := "title"
## The weather's song ("fair", "rain", "fog", "night", "storm").
var song := "fair"
## Tied up (the song softer, its run down).
var docked := true
## How hard he's fighting now (0..1, smoothed: up quickly, down slowly), and the fight's own clock (s since the strike).
var intensity := 0.0
var fight_t := 0.0
## How near the line is to going (0..1), from what you could see and feel.
var danger := 0.0
## What happened this step: "strike", "landed", "lost", "countdown", "card:win" (lose, tie).
var events: Array[String] = []
## Meant to be all but quiet (the music log marks it: -- --music-log).
var still := false

## A weather this long (s) before its song comes in (a passing shower doesn't swap the song).
const SONG_HOLD := 8.0
## Her speed (0..1 of the top) the run layer comes in over.
const RUN := Vector2(0.25, 0.8)
## The fight's layers: the drums in over this much intensity, the whole band over this.
const DRUMS := Vector2(0.3, 0.55)
const FULL := Vector2(0.65, 0.9)
## Intensity up in this long (s), down in this long: his run hits at once, the lull after it comes slowly.
const RISE := 0.4
const FALL := 3.0
## Each layer in over this long (s), out over this long: the band joining at once, leaving one by one.
const LAYER_IN := 0.3
const LAYER_OUT := 2.5
const LAYER_HOLD := 4.0
## The fight building the longer it goes: never under this much after FLOOR_T s.
const FLOOR := 0.45
const FLOOR_T := Vector2(20.0, 90.0)
## On the leader (m of line out: he's close), and boatside with the harpoon, how hard the band plays at least / at most.
const LEADER := 16.0
const BOATSIDE := 0.35
## A fish lost: quiet this long (s) before the song comes back.
const HUSH := 3.0
## Landed: the flourish rings this long (s) before the song comes back under it.
const AFTER := 3.5
## How long (s) a fish that's gone from alongside is waited on to show up in the hold before he's counted lost.
const LANDED_WAIT := 1.2
## The bend against what the line takes, near breaking (danger: NEAR.x .. NEAR.y).
const NEAR := Vector2(0.4, 0.6)
## His moves and how hard the band plays to each.
const MOVES := {"run": 1.0, "surge": 1.0, "charge": 1.0, "jump": 0.85, "shake": 0.6, "circle": 0.5, "spiral": 0.55,
		"sound": 0.4, "dog": 0.4}

var hush := 0.0
var _after := 0.0
var _levels := {}            # layer -> level now
var _hold := {}              # layer -> s it holds yet
var _run := 0.0
var _want_song := "fair"
var _want_t := 0.0
var _fight_ids := {}
var _along_ids := {}
var _gone := {}
var _landed := -1
var _counting := false
var _card := ""
var _t := 0.0


func _init(_seed := -1) -> void:
	pass


func step(w: Dictionary, dt: float) -> void:
	events.clear()
	_t += dt
	hush = maxf(hush - dt, 0.0)
	_after = maxf(_after - dt, 0.0)
	docked = bool(w.get("docked", false))
	var fights: Array = w.get("fights", [])
	var f := _worst(fights)
	danger = _danger(f) if not f.is_empty() else 0.0
	_edges(w, fights)
	_weather(w, dt)
	place = _place(w, f)
	fight_t = fight_t + dt if place == "fight" else 0.0
	_fight(w, f, dt)
	_run = move_toward(_run, smoothstep(RUN.x, RUN.y, float(w.get("speed", 0.0))) if not docked else 0.0, dt / 2.0)
	if float(w.get("race_left", -1.0)) >= 0.0:
		_run = maxf(_run, 0.6)          # (the race home: under way whatever her speed)
	still = place == "quiet" or bool(w.get("paused", false))


## A layer's level now (0..1): the fight's ("pulse", "drums", "full"), the song's ("band", "run"), the title's.
func level(k: String) -> float:
	match k:
		"band":
			return 1.0
		"run":
			return _run
		"pulse", "drums", "full", "hit":
			return float(_levels.get(k, 0.0))
	return float(_title().get(k, 0.0))


func _place(w: Dictionary, f: Dictionary) -> String:
	if bool(w.get("title", false)):
		return "title"
	if bool(w.get("card", false)) or float(w.get("counting", -1.0)) >= 0.0:
		return "quiet"
	if not f.is_empty() or not (w.get("alongside", []) as Array).is_empty() or not _gone.is_empty():
		return "fight"                    # (gone from alongside and not yet in the hold or lost: still his moment)
	if hush > 0.0:
		return "quiet"
	if _after > 0.0:
		return "after"
	return "song"


## The weather's song: the one wanted once it's been the weather SONG_HOLD s.
func _weather(w: Dictionary, dt: float) -> void:
	var c := str(w.get("condition", "calm"))
	var want := "fair"
	if c == "storm":
		want = "storm"
	elif c == "fog":
		want = "fog"
	elif bool(w.get("night", false)):
		want = "night"
	elif c == "rain" or c == "heavy":
		want = "rain"
	if want != _want_song:
		_want_song = want
		_want_t = 0.0
	_want_t += dt
	# (the first, and any while the title's up or tied up at the start, at once)
	if want != song and (_want_t >= SONG_HOLD or _t <= dt * 2.0 or bool(w.get("title", false))):
		song = want


## How hard he's fighting, and the fight's three layers from it.
func _fight(w: Dictionary, f: Dictionary, dt: float) -> void:
	var i := 0.0
	if place == "fight":
		if f.is_empty():
			i = BOATSIDE                  # (alongside: the harpoon's moment, the pulse and a little drums)
		else:
			var mv := str(f.get("move", ""))
			i = float(MOVES.get(mv, 0.6))
			if bool(f.get("surging", false)):
				i = 1.0
			i = maxf(i, smoothstep(0.5, 0.85, float(f.get("spool", 0.0))))    # (the backing showing)
			i = maxf(i, danger)                                                # (the line near going)
			i = maxf(i, FLOOR * smoothstep(FLOOR_T.x, FLOOR_T.y, fight_t))
			if float(f.get("line_out", 100.0)) < LEADER:
				i = maxf(i, 0.9)          # (on the leader: the whole band)
	intensity = move_toward(intensity, i, dt / (RISE if i > intensity else FALL))
	var on := 1.0 if place == "fight" else 0.0
	_levels["hit"] = on              # (the strike: there at once, whatever)
	var want := {"pulse": on, "drums": on * smoothstep(DRUMS.x, DRUMS.y, intensity),
			"full": on * smoothstep(FULL.x, FULL.y, intensity)}
	for k: String in want:
		var cur := float(_levels.get(k, 0.0))
		# (in, it holds LAYER_HOLD s before it can go: his moves change faster than a band would)
		var hold := maxf(float(_hold.get(k, 0.0)) - dt, 0.0)
		if want[k] > cur + 0.05:
			hold = LAYER_HOLD
		var to: float = want[k] if want[k] >= cur or hold <= 0.0 or on == 0.0 else cur
		_levels[k] = move_toward(cur, to, dt / (LAYER_IN if to > cur else LAYER_OUT))
		_hold[k] = hold


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


## Things that happen: the strike, a fish lost or landed, Rivals' countdown and its card.
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
		if not _fight_ids.has(id) and not _along_ids.has(id) and _fight_ids.is_empty() and _along_ids.is_empty():
			events.append("strike")       # (a fish on with none on before: a double's second rides the same fight)
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
		_after = AFTER
	else:
		for id: String in _gone.keys():
			if _t - float(_gone[id]) >= LANDED_WAIT:
				_gone.erase(id)          # (not in the hold: he got away from alongside)
				if now.is_empty() and along.is_empty():
					_lost()
	_fight_ids = now
	_along_ids = along
	_landed = landed
	var counting := float(w.get("counting", -1.0)) >= 0.0
	if counting and not _counting:
		events.append("countdown")
	_counting = counting
	var card := str(w.get("card_result", "")) if bool(w.get("card", false)) else ""
	if card != "" and card != _card:
		events.append("card:" + card)
	_card = card


func _lost() -> void:
	if events.has("lost"):
		return
	events.append("lost")
	hush = HUSH


## The title's stems by the weather on it: the whistle and the band in fair weather; in rain the patter under it,
## the whistle softer; in a storm no whistle, the theme low on the bow over the storm's drums; at night the bells; in
## fog almost only the pad and a far whistle.
func _title() -> Dictionary:
	var t := {"lead": 1.0, "counter": 1.0, "guitar": 1.0, "bass": 1.0, "pad": 1.0, "drums": 1.0, "rain": 0.0,
			"storm": 0.0, "night": 0.0, "low": 0.0}
	match song:
		"rain":
			t.merge({"lead": 0.55, "counter": 0.8, "guitar": 0.7, "drums": 0.6, "rain": 1.0}, true)
		"storm":
			t.merge({"lead": 0.0, "counter": 0.4, "guitar": 0.25, "drums": 0.0, "storm": 1.0, "low": 1.0}, true)
		"fog":
			t.merge({"lead": 0.5, "counter": 0.2, "guitar": 0.3, "bass": 0.5, "drums": 0.0, "night": 0.4}, true)
		"night":
			t.merge({"lead": 0.6, "counter": 0.6, "guitar": 0.6, "bass": 0.7, "pad": 0.9, "drums": 0.3, "night": 1.0},
					true)
	return t
