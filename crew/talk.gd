extends Node
## Talking to each other, out loud and over the VHF. Two keys:
## - V held: you talk out loud. Your voice comes from your head (an AudioStreamPlayer3D on your player), so it falls
##   off with distance: the crew on your boat hear you, a rival lying alongside hears you too, nobody a mile off does.
## - R held: you key the VHF. Everyone hears you whatever the range, rivals included, through the radio (ui/radio.gd's
##   Radio bus: a handset's band, crunch, squashed), from the speaker on their own boat's dash and faintly in their
##   ear; the squelch breaks as you key up and tails off with a roger beep as you let go. Anyone near you still hears
##   your real voice as you talk into it.
## (`open_mic`, off by default: your voice goes out loud whenever you're making any, no key.)
##
## Your mic: over Steam (a Steam session), Steam's own voice (startVoiceRecording, its compressed codec, decompressed
## by each listener); otherwise Godot's (AudioStreamMicrophone into a muted Mic bus, an AudioEffectCapture on it),
## down to RATE mono and mu-law (8 bits a sample). Either way it goes in short packets, unreliable (a late one is
## dropped, never waited for), and plays through an AudioStreamGenerator after a short wait (JITTER) so a packet a
## little late still lands in time. The mic only opens the first time you talk, and never headless (the tests feed
## transmit() themselves).
## Top left on the HUD, under the trip: who's talking, a little speaker in their oilskins' colour (its waves with
## their voice), or an amber handset with its aerial lit when it's over the radio.

const Player := preload("res://crew/player.gd")
const Radio := preload("res://ui/radio.gd")
const PixFont := preload("res://ui/pixfont.gd")

const LOCAL := 0
const VHF := 1
## Our own codec (mu-law at RATE) or Steam's.
const MULAW := 0
const STEAM := 1
const RATE := 16000
## Samples a packet (40 ms).
const PACKET := 640
## What's buffered before a voice starts playing (s), and the most it may fall behind (s) before the oldest is dropped.
const JITTER := 0.08
const BEHIND := 0.6
## A voice is done this long after its last packet (s).
const QUIET := 0.4
## Open mic: louder than this (rms) is talking, kept open this long after (s).
const GATE := 0.02
const HANG := 0.45
const MIC_BUS := "Mic"

var crew: Node            # crew/crew.gd
## Talking without a key (see above).
var open_mic := false
## What we're sending: -1 nothing, LOCAL or VHF.
var keyed := -1
## Who's talking that we can hear: peer id -> Speaker.
var speakers := {}
## How loud we are, 0..1 (the HUD's waves).
var my_level := 0.0

var _mic_ok := false
var _mic: AudioStreamPlayer
var _capture: AudioEffectCapture
var _steam: Object
var _seq := 0
var _pending := PackedFloat32Array()
var _lp := 0.0
var _phase := 0.0
var _gate_t := 0.0
var _steam_poll := 0.0
var _steam_tail := 0.0
var _steam_on := false
var _board: Control
var _rows := {}           # id -> [alpha, channel, level]
var _was_us := 0

static var _mu_table := PackedFloat32Array()


## A queue of samples and the generators it feeds once there's JITTER of it (and again after it ever runs dry).
class Line:
	var q := PackedFloat32Array()
	var outs: Array = []      # AudioStreamPlayer / AudioStreamPlayer3D, each with an AudioStreamGenerator
	var started := false
	var ahead := 0.0          # what's in the generators still to play (s)
	var pushed := 0           # samples pushed, ever (the tests)
	var at: Node              # what the speakers hang on

	func add(s: PackedFloat32Array) -> void:
		q.append_array(s)
		var most := int(BEHIND * RATE)
		if q.size() > most:
			q = q.slice(q.size() - most)

	func pump(delta: float) -> void:
		ahead = maxf(ahead - delta, 0.0)
		if not started:
			if q.size() < int(JITTER * RATE):
				return
			started = true
		var n := q.size()
		var pbs: Array = []
		for o: Variant in outs:
			if not is_instance_valid(o) or not (o as Node).is_inside_tree():
				continue
			if not o.call("is_playing"):
				o.call("play")
			if not o.call("has_stream_playback"):
				continue
			var pb := o.call("get_stream_playback") as AudioStreamGeneratorPlayback
			if pb != null:
				pbs.append(pb)
				n = mini(n, pb.get_frames_available())
		if pbs.is_empty() or n <= 0:
			if q.is_empty() and ahead <= 0.0:
				started = false
			return
		var buf := PackedVector2Array()
		buf.resize(n)
		for i in n:
			buf[i] = Vector2(q[i], q[i])
		for pb: AudioStreamGeneratorPlayback in pbs:
			pb.push_buffer(buf)
		q = q.slice(n)
		pushed += n
		ahead += float(n) / RATE

	func idle() -> bool:
		return q.is_empty() and ahead <= 0.0

	## Whether its speakers are all still there, hung on `on`.
	func hung(on: Node) -> bool:
		if outs.is_empty() or not outs.all(func(o: Variant) -> bool: return is_instance_valid(o)):
			return false
		return at == null if on == null else (is_instance_valid(at) and at == on)

	## Takes its speakers down (what's queued waits for the next ones).
	func unhook() -> void:
		for o: Variant in outs:
			if is_instance_valid(o):
				(o as Node).queue_free()
		outs.clear()
		at = null
		started = false
		ahead = 0.0


## One of the others, as we hear them: their voice out loud (`near`, from their head) and over the radio (`vhf`, from
## our dash and in our ear), each its own line of generators fed in step.
class Speaker:
	var id := 0
	var near := Line.new()
	var vhf := Line.new()
	var last_seq := -1
	var chan := LOCAL
	var heard_t := INF        # since their last packet (s)
	var level := 0.0
	var keyed_vhf := false    # (the squelch is open for them)


func _ready() -> void:
	Radio._make_bus()
	_mic_ok = DisplayServer.get_name() != "headless" and not AudioServer.get_input_device_list().is_empty()
	_board = Control.new()
	_board.name = "Talking"
	_board.position = Vector2(18, 66)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.draw.connect(_draw_board)
	(crew.get("hud") as Node).add_child(_board)


func _process(delta: float) -> void:
	# (voices come in and play out on the wall clock, whatever the game's frames are doing)
	var us := Time.get_ticks_usec()
	var real := clampf((us - _was_us) / 1e6, 0.0, 0.25) if _was_us > 0 else delta
	_was_us = us
	_keys()
	if keyed >= 0 or open_mic or _steam_tail > 0.0:
		_listen(real)
	else:
		my_level = 0.0
	for id: int in speakers.keys():
		var s: Speaker = speakers[id]
		s.heard_t += real
		s.level = move_toward(s.level, 0.0, real * 3.0)
		_route(s)
		s.near.pump(real)
		s.vhf.pump(real)
		if s.keyed_vhf and s.heard_t > QUIET and s.vhf.idle():
			s.keyed_vhf = false
			_squelch(false)
		if s.heard_t > 3.0 and s.near.idle() and s.vhf.idle():
			s.near.unhook()
			s.vhf.unhook()
			speakers.erase(id)
	_tick_board(delta)


# ------------------------------------------------------------------ sending

## The keys (not while typing in a box, and not alone at sea: there's nobody to hear).
func _keys() -> void:
	var want := -1
	var focus := get_viewport().gui_get_focus_owner()
	if not (focus is LineEdit or focus is TextEdit) and Net.in_session():
		if Input.is_action_pressed("radio"):
			want = VHF
		elif Input.is_action_pressed("talk"):
			want = LOCAL
	if want == keyed:
		return
	if keyed >= 0:
		_let_go()
	if want >= 0:
		_key_up(want)


func _key_up(chan: int) -> void:
	keyed = chan
	_pending.clear()
	if chan == VHF:
		_squelch(true)
	if _use_steam():
		if not _steam_on:
			_steam.call("startVoiceRecording")
			_steam_on = true
		_steam_tail = 0.0
	else:
		_open_mic()
		if _capture != null:
			_capture.clear_buffer()


func _let_go() -> void:
	if _pending.size() > 0:
		_send(_pending, keyed)
		_pending.clear()
	if keyed == VHF:
		_squelch(false)
	if Net.in_session():
		_over.rpc(keyed)
	if _use_steam() and not open_mic:
		_steam.call("stopVoiceRecording")
		_steam_on = false
		_steam_tail = 0.3       # (Steam still has the last of it)
	keyed = -1


## Sends `samples` (RATE, mono, -1..1) over `chan` the way the mic does: in PACKETs. (The tests talk this way.)
func transmit(samples: PackedFloat32Array, chan: int) -> void:
	_pending.append_array(samples)
	while _pending.size() >= PACKET:
		_send(_pending.slice(0, PACKET), chan)
		_pending = _pending.slice(PACKET)


## Ends a transmission sent with transmit() (the key let go).
func over(chan: int) -> void:
	if _pending.size() > 0:
		_send(_pending, chan)
		_pending.clear()
	if Net.in_session():
		_over.rpc(chan)


func _send(samples: PackedFloat32Array, chan: int) -> void:
	if not Net.in_session():
		return
	my_level = maxf(my_level * 0.7, clampf(_rms(samples) * 6.0, 0.0, 1.0))
	_seq += 1
	_voice.rpc(chan, _seq, MULAW, mulaw(samples))


## What the mic's heard since last frame, on its way out.
func _listen(delta: float) -> void:
	var chan := keyed if keyed >= 0 else LOCAL
	if _use_steam():
		if open_mic and not _steam_on:
			_steam.call("startVoiceRecording")      # (Steam keeps quiet itself between words)
			_steam_on = true
		_steam_tail = maxf(_steam_tail - delta, 0.0)
		_steam_poll -= delta
		if _steam_poll > 0.0:
			return
		_steam_poll = float(PACKET) / RATE
		var r: Variant = _steam.call("getVoice", 8192)
		if r is Dictionary and int(r.get("result", 1)) == 0 and int(r.get("written", 0)) > 0 and Net.in_session():
			var buf: PackedByteArray = (r["buffer"] as PackedByteArray).slice(0, int(r["written"]))
			my_level = 0.6
			_seq += 1
			_voice.rpc(chan, _seq, STEAM, buf)
		return
	if _capture == null:
		_open_mic()
		if _capture == null:
			return
	var n := _capture.get_frames_available()
	if n <= 0:
		return
	var got := down(_capture.get_buffer(n), AudioServer.get_mix_rate())
	if keyed < 0:
		# open mic: only while there's a voice in it
		if _rms(got) > GATE:
			_gate_t = HANG
		_gate_t -= delta
		if _gate_t <= 0.0:
			if _pending.size() > 0:
				over(LOCAL)
			my_level = 0.0
			return
	transmit(got, chan)


## Godot's mic, the first time it's wanted: playing into a muted Mic bus with a capture on it.
func _open_mic() -> void:
	if _mic != null or not _mic_ok:
		return
	var i := AudioServer.get_bus_index(MIC_BUS)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, MIC_BUS)
		AudioServer.set_bus_mute(i, true)        # (captured, never played back at you)
		AudioServer.add_bus_effect(i, AudioEffectCapture.new())
	_capture = AudioServer.get_bus_effect(i, 0) as AudioEffectCapture
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = MIC_BUS
	add_child(_mic)
	_mic.play()


## Steam's voice: in a Steam session, with Steam up.
func _use_steam() -> bool:
	if Net.mode != "steam" or Net.steam == null or not bool(Net.steam.get("available")):
		return false
	_steam = Net.steam.get("steam")
	return _steam != null and _steam.has_method("getVoice")


## The mic's stereo frames at `rate` down to RATE mono: smoothed (a one-pole low-pass under the new Nyquist) and
## picked at RATE, carrying the remainder from call to call.
func down(frames: PackedVector2Array, rate: float) -> PackedFloat32Array:
	var step := rate / RATE
	var a := 1.0 - exp(-TAU * 6500.0 / rate)
	var out := PackedFloat32Array()
	out.resize(int(frames.size() / step) + 2)
	var k := 0
	for f in frames:
		_lp += a * ((f.x + f.y) * 0.5 - _lp)
		_phase += 1.0
		if _phase >= step:
			_phase -= step
			out[k] = _lp
			k += 1
	out.resize(k)
	return out


# ------------------------------------------------------------------ hearing

@rpc("any_peer", "call_remote", "unreliable")
func _voice(chan: int, seq: int, codec: int, data: PackedByteArray) -> void:
	hear(multiplayer.get_remote_sender_id(), chan, seq, codec, data)


@rpc("any_peer", "call_remote", "reliable")
func _over(chan: int) -> void:
	var s: Speaker = speakers.get(multiplayer.get_remote_sender_id())
	if s != null and chan == VHF:
		s.heard_t = maxf(s.heard_t, QUIET)      # (the squelch tails as soon as what's left has played)


## A packet of `id`'s voice.
func hear(id: int, chan: int, seq: int, codec: int, data: PackedByteArray) -> void:
	if data.size() > 16384 or (chan != LOCAL and chan != VHF):
		return
	var s: Speaker = speakers.get(id)
	if s == null:
		s = Speaker.new()
		s.id = id
		speakers[id] = s
	if seq <= s.last_seq and s.last_seq - seq < 1000:
		return          # (late: what came after it has played)
	s.last_seq = seq
	var samples := mulaw_decode(data) if codec == MULAW else _steam_decode(data)
	if samples.is_empty():
		return
	s.heard_t = 0.0
	s.chan = chan
	s.level = maxf(s.level, clampf(_rms(samples) * 6.0, 0.0, 1.0))
	s.near.add(samples)
	if chan == VHF:
		if not s.keyed_vhf:
			s.keyed_vhf = true
			_squelch(true)
		s.vhf.add(_static(samples))


func _steam_decode(data: PackedByteArray) -> PackedFloat32Array:
	var st: Object = Net.steam.get("steam") if Net.steam != null else null
	if st == null or not st.has_method("decompressVoice"):
		return PackedFloat32Array()
	var r: Variant = st.call("decompressVoice", data, RATE, 65536)
	if not (r is Dictionary) or int(r.get("result", 1)) != 0:
		return PackedFloat32Array()
	var pcm: PackedByteArray = r.get("uncompressed", PackedByteArray())
	var n := mini(int(r.get("size", pcm.size())), pcm.size()) / 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = pcm.decode_s16(i * 2) / 32768.0
	return out


## Where `s` is heard from: their head (wherever they are), and our own boat's radio and our ear. Made (again) as the
## players and boats they hang on come and go.
func _route(s: Speaker) -> void:
	var p := crew.call("get_player", s.id) as Player
	var head: Node3D = p.head if p != null else null
	if head == null:
		s.near.unhook()
	elif not s.near.hung(head):
		s.near.unhook()
		var o := _speaker_3d(4.5, 70.0, 0.0, "Master")
		head.add_child(o)
		s.near.outs = [o]
		s.near.at = head
	var dash := _dash()
	if not s.vhf.hung(dash) or (dash == null and s.vhf.outs.size() != 1):
		s.vhf.unhook()
		var ear := AudioStreamPlayer.new()
		ear.stream = _generator()
		ear.bus = Radio.BUS
		ear.volume_db = -13.0
		add_child(ear)
		s.vhf.outs = [ear]
		s.vhf.at = dash
		if dash != null:
			var o := _speaker_3d(2.5, 35.0, 3.0, Radio.BUS)
			o.position = Vector3(0.0, 0.3, 0.0)
			dash.add_child(o)
			s.vhf.outs = [o, ear]


## Our boat's radio: on her dash by the wheel.
func _dash() -> Node3D:
	var me := crew.get("me") as Player
	var boat: Node3D = me.home if me != null else crew.get("sea").get("boat") as Node3D
	if boat == null:
		return null
	var wheel := boat.get("wheel") as Node3D
	return wheel if wheel != null else boat


static func _speaker_3d(unit: float, far: float, db: float, bus: String) -> AudioStreamPlayer3D:
	var o := AudioStreamPlayer3D.new()
	o.stream = _generator()
	o.unit_size = unit
	o.max_distance = far
	o.volume_db = db
	o.bus = bus
	o.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	return o


static func _generator() -> AudioStreamGenerator:
	var g := AudioStreamGenerator.new()
	g.mix_rate = RATE
	g.buffer_length = 0.5
	return g


## Over the radio: a little hiss under the voice, and the odd crackle.
static func _static(samples: PackedFloat32Array) -> PackedFloat32Array:
	var out := samples.duplicate()
	for i in out.size():
		var crackle := randf_range(-0.5, 0.5) if randf() < 0.0015 else 0.0
		out[i] = clampf(out[i] * 1.3 + randf_range(-0.025, 0.025) + crackle, -0.9, 0.9)
	return out


func _squelch(open: bool) -> void:
	var tips: Node = crew.get("sea").get("tips")
	var radio: Node = tips.get("radio") if tips != null else null
	if radio != null:
		radio.call("squelch", open)


# ------------------------------------------------------------------ the codec

## G.711 mu-law: a sample a byte, fine detail kept where a voice is quiet.
static func mulaw(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size())
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32635.0)
		var neg := 0x80 if v < 0 else 0
		v = mini(absi(v), 32635) + 0x84
		var exp_ := 7
		var mask := 0x4000
		while exp_ > 0 and (v & mask) == 0:
			exp_ -= 1
			mask >>= 1
		var mant := (v >> (exp_ + 3)) & 0x0F
		out[i] = ~(neg | (exp_ << 4) | mant) & 0xFF
	return out


static func mulaw_decode(data: PackedByteArray) -> PackedFloat32Array:
	if _mu_table.is_empty():
		_mu_table.resize(256)
		for b in 256:
			var u := ~b & 0xFF
			var t := (((u & 0x0F) << 3) + 0x84) << ((u & 0x70) >> 4)
			_mu_table[b] = float((0x84 - t) if (u & 0x80) != 0 else (t - 0x84)) / 32768.0
	var out := PackedFloat32Array()
	out.resize(data.size())
	for i in data.size():
		out[i] = _mu_table[data[i]]
	return out


static func _rms(s: PackedFloat32Array) -> float:
	if s.is_empty():
		return 0.0
	var sum := 0.0
	for v in s:
		sum += v * v
	return sqrt(sum / s.size())


# ------------------------------------------------------------------ the HUD

## Who's talking, as of now: peer id -> LOCAL or VHF (us too, while we're keyed).
func talking() -> Dictionary:
	var out := {}
	for id: int in speakers:
		var s: Speaker = speakers[id]
		if s.heard_t < QUIET or not s.near.idle():
			out[id] = s.chan
	if keyed >= 0:
		out[Net.my_id()] = keyed
	return out


func _tick_board(delta: float) -> void:
	var now := talking()
	var changed := false
	for id: int in now:
		if not _rows.has(id):
			_rows[id] = [0.0, now[id], 0.0]
	for id: int in _rows.keys():
		var row: Array = _rows[id]
		var a := move_toward(float(row[0]), 1.0 if now.has(id) else 0.0, delta * 6.0)
		if now.has(id):
			row[1] = now[id]
		var lvl := my_level if id == Net.my_id() else (float((speakers[id] as Speaker).level) if speakers.has(id) else 0.0)
		changed = changed or a > 0.0 or float(row[0]) > 0.0
		row[0] = a
		row[2] = lvl
		if a <= 0.0 and not now.has(id):
			_rows.erase(id)
	if changed:
		_board.queue_redraw()


## The speaker (a cone, its waves) and the handset (a box, its aerial), 2 px a pixel.
const CONE := [
	"...#.....",
	"..##..#..",
	"####...#.",
	"####...#.",
	"..##..#..",
	"...#.....",
]
const HANDSET := [
	"#....",
	"#....",
	"####.",
	"#..#.",
	"####.",
	"####.",
]


func _draw_board() -> void:
	var y := 0.0
	var ids: Array = _rows.keys()
	ids.sort()
	for id: int in ids:
		var row: Array = _rows[id]
		var a := float(row[0])
		var radio := int(row[1]) == VHF
		var lvl := float(row[2])
		var colour: Color = Player.OILSKINS[int(crew.get("slots").get(id, 0)) % Player.OILSKINS.size()]
		var icon: Array = HANDSET if radio else CONE
		var tint := Color(1.0, 0.75, 0.35) if radio else colour
		var t := Time.get_ticks_msec() / 1000.0
		for r in icon.size():
			var line: String = icon[r]
			for c in line.length():
				if line[c] != "#":
					continue
				var on := 1.0
				if not radio and c >= 6:
					on = 1.0 if lvl > (0.15 if c == 6 else 0.45) else 0.25      # (the waves, with the voice)
				elif radio and r < 2:
					on = 1.0 if fmod(t * 6.0, 1.0) < 0.6 or lvl > 0.3 else 0.3   # (the aerial, lit)
				_board.draw_rect(Rect2(c * 2 + 1, y + r * 2 + 1, 2, 2), Color(0, 0, 0, 0.7 * a))
				_board.draw_rect(Rect2(c * 2, y + r * 2, 2, 2), Color(tint, a * on))
		var who := "You" if id == Net.my_id() else str(crew.call("call_sign", id))
		PixFont.draw(_board, Vector2(23, y + 2), who, Color(0, 0, 0, 0.7 * a), 2)
		PixFont.draw(_board, Vector2(22, y + 1), who, Color(colour, a), 2)
		y += 18.0 * a
