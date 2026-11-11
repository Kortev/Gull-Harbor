extends AudioStreamPlayer3D
## A rod's fight noises, synthesized as they go (rods/rod.gd feeds it): the reel's clicker, a ratchet tick for every
## few cm of line off the spool, so its rate is the run's speed (a strike, a screaming blur), its ping higher the
## emptier the spool (`arbor`: the smaller it is, the faster it spins); the blank creaking under a heavy load, a slow
## stick-slip groan; and the line hissing as it slices through the water. Only plays while a fish is on. And the line
## going (snap): a crack and a ringing twang when it parts, a dry little flick when the hook comes out, then nothing.

const RATE := 22050.0

## Clicks a second (0: none), how hard it's loaded (0 .. 1: creaks past CREAK), how loud the line hisses (0..1).
var clicks := 0.0
var strain := 0.0
var hiss := 0.0
## How empty the spool is (0 full .. 1 the arbor showing): the clicker's ping climbs with it.
var arbor := 0.0
const CREAK := 0.42
## The line's tension, 0 slack .. 1 parting (0 too when it's slack or gone): the line under load hums, a low note
## that climbs as it tightens, always the same note for the same bend, so you learn it (and it stops dead when he's
## off or it's slack).
var taut := 0.0
var _hum_ph := 0.0
var _hum_f := 0.0
## The hum's and the hiss's loudness now: eased (a few hundredths of a second), so neither ticks as it comes or goes.
var _hum_a := 0.0
var _hiss_a := 0.0
## The snap: s left of it (0: none), and whether it was the line parting (a crack) or the hook coming out (a flick).
var _snap := 0.0
var _snap_hard := false
var _snap_ring := 0.0
var _snap_v := 0.0
var _click_ph := 0.0
var _ring := 0.0         # the click's ping (a decaying resonance)
var _ring_v := 0.0
var _ring_hit := 0.0
var _noise_prev := 0.0
var _hiss_lp := 0.0
var _creak_on := 0.0     # the groan's envelope
var _creak_left := 0.0
var _creak_ph := 0.0
var _creak_f := 40.0
var _body := 0.0
var _body_v := 0.0
var _wob := 0.0


func _init() -> void:
	var g := AudioStreamGenerator.new()
	g.mix_rate = RATE
	g.buffer_length = 0.12
	stream = g
	unit_size = 5.0
	max_distance = 60.0
	volume_db = -3.0
	position = Vector3(0, 0.1, 0.37)


## The line's gone: a crack (parted) or a flick (the hook out), over everything else, which stops.
func snap(parted: bool) -> void:
	_snap = 0.45 if parted else 0.12
	_snap_hard = parted
	_snap_ring = 0.0
	_snap_v = 1.4 if parted else 0.5
	clicks = 0.0
	hiss = 0.0
	strain = 0.0
	taut = 0.0


func _process(_delta: float) -> void:
	var on := clicks > 0.5 or hiss > 0.02 or strain > CREAK or _snap > 0.0 or taut > 0.05 or _hum_a > 0.001 			or _hiss_a > 0.001 or absf(_ring) > 0.001 or absf(_body) > 0.001
	if not on:
		if playing:
			stop()
		return
	if not playing:
		play()
	if not has_stream_playback():
		return
	var pb := get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var n := pb.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	var dt := 1.0 / RATE
	var rate := minf(clicks, 160.0)
	var creak_k := clampf((strain - CREAK) / (1.0 - CREAK), 0.0, 1.0)
	# the click: a hard tick into a ~3 kHz ping that dies in a couple of ms
	var w := TAU * 3100.0 * (1.0 + 0.6 * arbor) * dt
	var damp := exp(-dt / 0.0018)
	# the blank: a ~210 Hz body excited by the stick-slip pulses
	var bw := TAU * 210.0 * dt
	var bdamp := exp(-dt / 0.012)
	var hum_to := 110.0 + 420.0 * clampf(taut, 0.0, 1.2) if taut > 0.05 else 0.0
	for i in n:
		var out := 0.0
		# (a string under load: a fundamental and a little of its octave, gliding to the bend's note)
		var hum_on := hum_to > 0.0 and _snap <= 0.0
		_hum_a = lerpf(_hum_a, 0.035 + 0.075 * clampf(taut, 0.0, 1.0) if hum_on else 0.0, 0.002)
		if hum_on:
			_hum_f = hum_to if _hum_f <= 0.0 else lerpf(_hum_f, hum_to, 0.0008)
		if _hum_a > 0.0005 and _hum_f > 0.0:
			_hum_ph = fmod(_hum_ph + _hum_f * dt, 1.0)
			out += (sin(_hum_ph * TAU) + 0.35 * sin(_hum_ph * TAU * 2.0)) * _hum_a
		elif not hum_on:
			_hum_f = 0.0
			_hum_a = 0.0
		if rate > 0.5 or absf(_ring) > 0.001:
			if rate > 0.5:
				_click_ph += rate * dt * (0.85 + 0.3 * randf())
			if _click_ph >= 1.0:
				_click_ph -= 1.0
				_ring_v += 0.9
				_ring_hit = 1.0
			# (a damped oscillator: x'' = -w^2 x, the hit as a kick in velocity)
			_ring_v = (_ring_v - w * _ring) * damp
			_ring += w * _ring_v
			out += _ring * 0.55 + _ring_hit * randf_range(-0.6, 0.6)
			_ring_hit *= 0.92
		_hiss_a = lerpf(_hiss_a, hiss if hiss > 0.02 else 0.0, 0.002)
		if _hiss_a > 0.001:
			var nz := randf_range(-1.0, 1.0)
			var hp := nz - _noise_prev       # (bright: the high end of white noise)
			_noise_prev = nz
			_hiss_lp = lerpf(_hiss_lp, hp, 0.5)
			_wob += dt * 7.0
			out += _hiss_lp * _hiss_a * 0.22 * (0.8 + 0.2 * sin(_wob))
		if creak_k > 0.0 or absf(_body) > 0.001:
			if creak_k <= 0.0:
				_creak_on = 0.0               # (the load's off: what's ringing in the blank dies away)
				_creak_left = 0.0
			elif _creak_left <= 0.0:
				# (a new groan, or a gap before the next)
				if _creak_on > 0.5:
					_creak_on = 0.0
					_creak_left = randf_range(0.15, 0.6) * (1.2 - creak_k)
				else:
					_creak_on = 1.0
					_creak_left = randf_range(0.25, 0.7)
					_creak_f = randf_range(28.0, 55.0)
			_creak_left -= dt
			if _creak_on > 0.5:
				_creak_ph += _creak_f * dt * (1.0 + 0.25 * sin(_creak_left * 9.0))
				if _creak_ph >= 1.0:
					_creak_ph -= 1.0
					_body_v += 0.5 * creak_k
			_body_v = (_body_v - bw * _body) * bdamp
			_body += bw * _body_v
			out += _body * 0.9
		if _snap > 0.0:
			# the crack: a burst of noise into a ringing twang (the line's own note, falling as it flies back)
			_snap -= dt
			var age := (0.45 if _snap_hard else 0.12) - _snap
			var burst := randf_range(-1.0, 1.0) * exp(-age / (0.012 if _snap_hard else 0.006))
			var sw := TAU * (1450.0 - 900.0 * age) * dt
			_snap_v = (_snap_v - sw * _snap_ring) * exp(-dt / (0.12 if _snap_hard else 0.02))
			_snap_ring += sw * _snap_v
			out = burst * (0.9 if _snap_hard else 0.35) + _snap_ring * (0.5 if _snap_hard else 0.15)
		out = clampf(out, -0.95, 0.95)
		buf[i] = Vector2(out, out)
	pb.push_buffer(buf)
