extends AudioStreamPlayer3D
## A rod's fight noises, synthesized as they go (rods/rod.gd feeds it): the reel's clicker, a ratchet tick for every
## few cm of line off the spool, so its rate is the run's speed (a strike, a screaming blur); the blank creaking under
## a heavy load, a slow stick-slip groan; and the line hissing as it slices through the water. Only plays while a fish
## is on.

const RATE := 22050.0

## Clicks a second (0: none), how hard it's loaded (0 .. 1: creaks past CREAK), how loud the line hisses (0..1).
var clicks := 0.0
var strain := 0.0
var hiss := 0.0
const CREAK := 0.7
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


func _process(_delta: float) -> void:
	var on := clicks > 0.5 or hiss > 0.02 or strain > CREAK
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
	var w := TAU * 3100.0 * dt
	var damp := exp(-dt / 0.0018)
	# the blank: a ~210 Hz body excited by the stick-slip pulses
	var bw := TAU * 210.0 * dt
	var bdamp := exp(-dt / 0.012)
	for i in n:
		var out := 0.0
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
		if hiss > 0.02:
			var nz := randf_range(-1.0, 1.0)
			var hp := nz - _noise_prev       # (bright: the high end of white noise)
			_noise_prev = nz
			_hiss_lp = lerpf(_hiss_lp, hp, 0.5)
			_wob += dt * 7.0
			out += _hiss_lp * hiss * 0.22 * (0.8 + 0.2 * sin(_wob))
		if creak_k > 0.0:
			if _creak_left <= 0.0:
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
		out = clampf(out, -0.95, 0.95)
		buf[i] = Vector2(out, out)
	pb.push_buffer(buf)
