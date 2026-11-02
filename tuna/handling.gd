extends RefCounted
## Working a bluefin on deck the way it's done for the sashimi market, and what that does to its grade (boat/fish_hold.gd
## runs it, each act a few seconds in your own hands; this has the spots, the numbers, the grade and its reasons, and
## the bits you see and hear). Spots are along the fish, snout -0.5 .. tail +0.5 (tuna/tuna.gd's unit model):
##
## - Spike it (ikejime): the knife's point into the brain, on top of the head just behind the eye (BRAIN). Hold left
##   mouse SPIKE_HOLD s; within SPIKE_OK of the spot and still (no kick while you push) it's clean: a shiver runs
##   through it and it goes limp. Off the spot, or it kicked, it glances off and the fish fights you (MISS_THRASH).
## - Bleed it: the cut under the pectoral fin on the lateral line (CUT_AT) through to the artery. Hold to cut deeper
##   (CUT_FULL s is through the loin); let go in CUT_BAND for a clean cut, short of it a shallow one that bleeds slow,
##   past it you've cut into the meat. Then it runs out on its own over BLEED_RUN s, quicker for every pump of its tail
##   (empty hands on the tail: PUMP each).
## - Gut it: the knife along the belly (GUT_AT), once it's spiked, GUT_HOLD s. A little better, and it chills through.
## - Pin it: a mate with empty hands holding it down. It can't flop while you work (no kicks spoil the knife), and it
##   burns itself up a lot slower (PINNED).
## - Ice it: into the fish box (the gaff, as ever), then scoop ice over it (the scoop on the open box, PACK a scoop).
##
## A live fish thrashing on deck heats its own meat ("burnt", yake): every second it's alive and loose up there counts
## (`thrash`), and the grade's mostly in how quick and clean the kill, the bleed and the chill were.

const Sfx := preload("res://audio/sfx.gd")

const BRAIN := -0.38
const CUT_AT := -0.2
const GUT_AT := 0.02
## Where the knife's doing what (along the fish): the head ahead of HEAD_END, the fin's run to FIN_END, the belly to
## BELLY_END, the tail from TAIL_FROM.
const HEAD_END := -0.31
const FIN_END := -0.09
const BELLY_END := 0.2
const TAIL_FROM := 0.28
const SPIKE_OK := 0.035
const SPIKE_HOLD := 0.45
const CUT_FULL := 1.4
const CUT_BAND := Vector2(0.45, 0.75)
## Off the line of the artery by this much (along the fish) and the cut only does half as well; a kick mid-cut slips
## the knife this far.
const CUT_OFF := 0.09
const SLIP := 0.06
const GUT_HOLD := 1.3
const BLEED_RUN := 24.0
const PUMP := 0.07
const PUMP_EVERY := 0.3
const PUMPS := 14
const PACK := 0.25
const MISS_THRASH := 4.0
const PINNED := 0.35
## Grades: quality at least this for #1, #2 (else #3).
const ONE := 0.85
const TWO := 0.65


## What the knife (or a hand) is on at `u` along the fish: "head", "fin", "belly", "tail" or "" (the middle, or off it).
static func region(u: float) -> String:
	if is_nan(u):
		return ""
	if u < HEAD_END:
		return "head"
	if u < FIN_END:
		return "fin"
	if u < BELLY_END:
		return "belly"
	if u >= TAIL_FROM:
		return "tail"
	return ""


## A new fish's handling, nothing done yet (fish_hold.gd adds it to the books).
static func fresh() -> Dictionary:
	return {"spiked_s": -1.0, "misses": 0, "thrash": 0.0, "cut_q": -1.0, "cut_d": 0.0, "cut_t": -1.0, "pumps": 0,
			"drain": -1.0, "gutted": false, "packed": 0.0, "packed_s": -1.0, "pins": 0}


## How good a cut `depth` (0..1 of CUT_FULL) deep, `off` along the fish from the artery, is: 0..1.
static func cut_quality(depth: float, off: float) -> float:
	var d := 1.0
	if depth < CUT_BAND.x:
		d = lerpf(0.25, 1.0, clampf((depth - 0.15) / (CUT_BAND.x - 0.15), 0.0, 1.0))
	elif depth > CUT_BAND.y:
		d = lerpf(1.0, 0.45, clampf((depth - CUT_BAND.y) / (1.0 - CUT_BAND.y), 0.0, 1.0))
	var at := lerpf(1.0, 0.5, clampf((absf(off) - 0.03) / (CUT_OFF - 0.03), 0.0, 1.0))
	return d * at


## How much of its blood's out (0..1) at sea clock `now`: frozen once it's iced; otherwise from when it was cut, as
## fast as the cut's good, and every pump.
static func drain(f: Dictionary, now: float) -> float:
	if float(f.get("drain", -1.0)) >= 0.0:
		return float(f["drain"])
	var t := float(f.get("cut_t", -1.0))
	if t < 0.0:
		return 1.0 if float(f.get("bled_s", -1.0)) >= 0.0 and not f.has("cut_t") else 0.0   # (an old fish: bled)
	var q := float(f.get("cut_q", 1.0))
	return clampf((now - t) / BLEED_RUN * lerpf(0.3, 1.0, q) + int(f.get("pumps", 0)) * PUMP, 0.0, 1.0)


## A fish's handling, a fish from before there was handling filled in as it was then (bled meant done right).
static func _h(f: Dictionary) -> Dictionary:
	var bled := float(f.get("bled_s", -1.0))
	var iced := float(f.get("iced_s", -1.0))
	return {
		"spiked_s": float(f.get("spiked_s", bled)), "thrash": float(f.get("thrash", maxf(bled, 0.0))),
		"cut_q": float(f.get("cut_q", 1.0 if bled >= 0.0 else -1.0)), "cut_d": float(f.get("cut_d", 0.6)),
		"gutted": bool(f.get("gutted", false)), "packed": float(f.get("packed", 1.0 if iced >= 0.0 else 0.0)),
		"iced_s": iced, "misses": int(f.get("misses", 0)),
	}


## The parts of a fish's quality at sea clock `now`: {fight, kill, burn, bleed, gut, chill}, each what it adds (or
## takes off) on top of 0.4.
static func parts(f: Dictionary, now: float) -> Dictionary:
	var h := _h(f)
	var kg := float(f["kg"])
	var goal := 40.0 + kg * 0.38            # (tuna/fight.gd: how long it takes to tire, fought right)
	var fight := clampf((5.0 * goal - float(f["fight_s"])) / (3.5 * goal), 0.0, 1.0)
	var thrash := float(h["thrash"])
	var spiked := float(h["spiked_s"]) >= 0.0
	var kill := 0.12 * (1.0 - clampf((thrash - 10.0) / 80.0, 0.0, 1.0)) if spiked else -0.04
	var burn := -0.12 * clampf((thrash - 40.0) / 120.0, 0.0, 1.0)
	var cq := float(h["cut_q"])
	var bleed := 0.13 * cq * drain(f, now) if cq >= 0.0 else -0.03
	var iced := float(h["iced_s"])
	var chill := -0.1
	if iced >= 0.0:
		chill = 0.16 * (1.0 if iced <= 180.0 else (0.6 if iced <= 600.0 else 0.3)) * (0.35 + 0.65 * float(h["packed"]))
	return {"fight": 0.15 * fight, "kill": kill, "burn": burn, "bleed": bleed, "gut": 0.04 if bool(h["gutted"]) else 0.0,
			"chill": chill}


## How well a fish was handled, 0..1, at sea clock `now`.
static func quality(f: Dictionary, now: float) -> float:
	var q := 0.4
	for v: float in parts(f, now).values():
		q += v
	return clampf(q, 0.0, 1.0)


static func grade(q: float) -> String:
	return "#1" if q >= ONE else ("#2" if q >= TWO else "#3")


## Why it graded what it did, in a word or two each, the ones that mattered most first: [[words, good], ...].
static func reasons(f: Dictionary, now: float) -> Array:
	var h := _h(f)
	var p := parts(f, now)
	var out := []      # [weight, words, good]
	var fight := float(p["fight"]) / 0.15
	if fight >= 0.8:
		out.append([0.05, "FOUGHT FAST", true])
	elif fight < 0.3:
		out.append([0.1, "FOUGHT LONG", false])
	var thrash := float(h["thrash"])
	if float(h["spiked_s"]) < 0.0:
		out.append([0.12, "NOT SPIKED", false])
	elif thrash <= 25.0 and int(h["misses"]) == 0:
		out.append([0.1, "CLEAN SPIKE", true])
	elif thrash > 25.0:
		out.append([0.06, "SPIKED LATE", false])
	if thrash > 70.0:
		out.append([0.2, "BURNT", false])
	var cq := float(h["cut_q"])
	var dr := drain(f, now)
	if cq < 0.0:
		out.append([0.1, "NOT BLED", false])
	elif float(h["cut_d"]) > CUT_BAND.y + 0.05:
		out.append([0.08, "CUT THE LOIN", false])
	elif cq * dr >= 0.8:
		out.append([0.08, "BLED OUT", true])
	elif dr < 0.6:
		out.append([0.07, "HALF BLED", false])
	else:
		out.append([0.05, "POOR CUT", false])
	if bool(h["gutted"]):
		out.append([0.03, "GUTTED", true])
	var iced := float(h["iced_s"])
	if iced < 0.0:
		out.append([0.15, "WARM", false])
	elif float(h["packed"]) < 1.0:
		out.append([0.09, "LOOSE ICE", false])
	elif iced > 600.0:
		out.append([0.09, "ICED LATE", false])
	elif iced <= 180.0:
		out.append([0.07, "ICED FAST", true])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	return out.map(func(r: Array) -> Array: return [r[1], r[2]])


# ------------------------------------------------------------------ what you see and hear

## Chunky pixels of something wet (blood, guts, ice): a burst of `n` (or a stream, `stream`), `col`, `size` m, flung
## up `speed` m/s, falling. One-shot bursts free themselves.
static func pixels(parent: Node, at: Vector3, col: Color, n: int, size: float, speed: Vector2, stream := false) \
		-> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = n
	p.lifetime = 0.7
	p.one_shot = not stream
	p.explosiveness = 0.0 if stream else 0.85
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 30.0 if stream else 45.0
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	if not stream:
		parent.get_tree().create_timer(p.lifetime + 0.6).timeout.connect(p.queue_free)
	return p


const BLOOD := Color(0.5, 0.03, 0.04)
const GUTS := Color(0.62, 0.22, 0.25)
const ICE := Color(0.84, 0.92, 0.96)

const RATE := 22050
static var _sounds := {}


## A wet or crunchy noise of the work, made here (no file): "cut" (a squelch through skin), "spike" (a crack of bone),
## "gut" (a long wet tear), "pump" (a gurgle), "ice" (a scoop of ice tipped out, crunching).
static func sound(kind: String) -> AudioStreamWAV:
	if _sounds.has(kind):
		return _sounds[kind]
	var spec: Array = {
		"cut": [0.28, 900.0, 0.004, 0.5, 6.0], "spike": [0.09, 3200.0, 0.001, 0.0, 0.0],
		"gut": [0.55, 600.0, 0.02, 0.7, 4.5], "pump": [0.3, 380.0, 0.01, 0.9, 9.0],
		"ice": [0.42, 4200.0, 0.002, 0.0, 0.0],
	}.get(kind, [0.2, 1000.0, 0.01, 0.0, 0.0])
	var secs := float(spec[0])
	var n := int(secs * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var out := PackedFloat32Array()
	out.resize(n)
	var lo := 0.0
	var bp := 0.0
	var peak := 0.001
	var grains := kind == "ice" or kind == "spike"
	var next_grain := 0
	var grain := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / float(spec[2])) * pow(1.0 - t / secs, 1.6)
		# (a wobble in the band for the wet ones: the gurgle)
		var fc := float(spec[1]) * (1.0 + float(spec[3]) * sin(t * TAU * float(spec[4])) * 0.5)
		var g := 2.0 * sin(PI * minf(fc, RATE * 0.45) / RATE)
		var src := rng.randf_range(-1.0, 1.0)
		if grains:
			# (crunch: little bursts, each a few ms)
			if i >= next_grain:
				next_grain = i + rng.randi_range(120, 900)
				grain = 1.0
			grain *= 0.993
			src *= grain
		lo += g * bp
		var hi := src - lo - 0.3 * bp
		bp += g * hi
		var v := bp * env
		out[i] = v
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(out[i] / peak * 0.8, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	_sounds[kind] = s
	return s


## One of those at a point in the world.
static func play(parent: Node, at: Vector3, kind: String, volume := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = sound(kind)
	p.volume_db = linear_to_db(volume)
	p.pitch_scale = randf_range(0.92, 1.08)
	p.unit_size = 4.0
	p.max_distance = 30.0
	p.top_level = true
	p.position = at
	p.autoplay = true
	p.finished.connect(p.queue_free)
	parent.add_child.call_deferred(p)
	Sfx.heard[kind] = int(Sfx.heard.get(kind, 0)) + 1
