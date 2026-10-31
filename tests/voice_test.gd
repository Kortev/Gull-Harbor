extends Node
## Voice (crew/talk.gd), two processes on this machine: the host and a friend, put on rival boats (VS). No mic: each
## feeds transmit() a made-up voice (a wobbling tone) at the pace a mic would. First the codec and the downsampling on
## their own; then the host talks out loud (the friend hears it from the host's head, nothing on the radio) and then
## over the VHF (the friend hears it from B's dash and in his ear, the squelch breaking); then the friend calls back
## over the VHF and the host hears it on A's dash. Each checks the generators took the voice in, and that the HUD
## showed who was talking, and how, and let it go after.
## Run (two shells, the host first):
##   godot --headless --fixed-fps 30 --path . res://tests/voice_test.tscn -- --role=host
##   godot --headless --fixed-fps 30 --path . res://tests/voice_test.tscn -- --role=join

const Sea := preload("res://sea/sea.gd")
const Talk := preload("res://crew/talk.gd")
const PORT := 7793
## How long each says something (s).
const SAY := 0.8

var fails: Array[String] = []
var sea: Sea
var _host := false
var _ph := 0.0


func _ready() -> void:
	_host = OS.get_cmdline_user_args().has("--role=host")
	_codec()
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	if _host:
		Net.host(PORT)
		await _as_host()
	else:
		Net.join("127.0.0.1", PORT)
		await _as_friend()
	_done()


## The codec and the mic's downsampling, offline.
func _codec() -> void:
	var tone := PackedFloat32Array()
	for i in 1600:
		tone.append(0.5 * sin(TAU * 440.0 * i / Talk.RATE))
	var back := Talk.mulaw_decode(Talk.mulaw(tone))
	var worst := 0.0
	for i in tone.size():
		worst = maxf(worst, absf(back[i] - tone[i]))
	_check(back.size() == tone.size() and worst < 0.02, "mu-law there and back (worst %.4f)" % worst)
	var quiet := Talk.mulaw_decode(Talk.mulaw(PackedFloat32Array([0.001, -0.001, 0.0])))
	_check(absf(quiet[0] - 0.001) < 0.0005 and quiet[1] < 0.0, "the quiet end kept fine")
	var t := Talk.new()
	var frames := PackedVector2Array()
	for i in 44100:
		var v := sin(TAU * 300.0 * i / 44100.0)
		frames.append(Vector2(v, v))
	var a := t.down(frames.slice(0, 20000), 44100.0)
	var b := t.down(frames.slice(20000), 44100.0)
	_check(absi(a.size() + b.size() - Talk.RATE) <= 1, "a second of the mic at 44.1 kHz is %d samples" % (a.size() + b.size()))
	t.free()


func _as_host() -> void:
	while sea.crew.slots.size() < 2:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	sea.vs.host_set_on(true)
	await get_tree().create_timer(2.5).timeout
	var talk := sea.crew.talk
	_check(sea.vs.on and sea.vs.teams.values().count(1) == 1, "VS on, the friend on B")
	# out loud
	await _say(Talk.LOCAL)
	await _real(1.5)
	# over the VHF
	var keys := int(sea.tips.radio.get("keys"))
	await _say(Talk.VHF)
	_check(int(sea.tips.radio.get("keys")) == keys + 1, "my own squelch breaks as I key up")
	# the friend calls back over the VHF
	var friend := 0
	for id: int in sea.crew.slots:
		if id != 1:
			friend = id
	var got := false
	var on_vhf := false
	var shown := false
	var until := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		var s: Talk.Speaker = talk.speakers.get(friend)
		if s == null:
			continue
		on_vhf = on_vhf or int(talk.talking().get(friend, -1)) == Talk.VHF
		shown = shown or talk._rows.has(friend)
		if s.vhf.pushed > int(SAY * 0.6 * Talk.RATE) and s.heard_t > 1.0:
			got = true
			break
	var s: Talk.Speaker = talk.speakers.get(friend)
	_check(got, "the friend's call came in over the radio (%d samples)" % (s.vhf.pushed if s else 0))
	var a_wheel: Node = sea.vs.sides[0].get("boat").get("wheel")
	_check(s != null and s.vhf.outs.size() == 2 and s.vhf.outs[0].get_parent() == a_wheel,
			"from A's dash, my boat's, and in my ear")
	_check(s != null and s.near.outs.size() == 1 and s.near.outs[0].get_parent() == sea.crew.get_player(friend).head,
			"and his own voice from his head, over on B")
	_check(on_vhf and shown, "the HUD showed him on the radio")
	await _real(2.0)


func _as_friend() -> void:
	while not sea.vs.on:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.5).timeout
	var talk := sea.crew.talk
	var b_boat := sea.vs.sides[1].get("boat") as Node3D
	var a_boat := sea.vs.sides[0].get("boat") as Node3D
	_check(sea.vs.my_team == 1 and sea.crew.me.home == b_boat, "on B, the rival's boat")
	var keys := int(sea.tips.radio.get("keys"))
	# the host out loud
	var s: Talk.Speaker = null
	var local := false
	var filled := false
	var until := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		s = talk.speakers.get(1)
		if s == null:
			continue
		local = local or int(talk.talking().get(1, -1)) == Talk.LOCAL
		for o: Node in s.near.outs:
			if not o.call("has_stream_playback"):
				continue
			var pb := o.call("get_stream_playback") as AudioStreamGeneratorPlayback
			filled = filled or (pb != null and pb.get_frames_available() < int(0.4 * Talk.RATE))
		if s.near.pushed > int(SAY * 0.6 * Talk.RATE) and s.heard_t > 0.6:
			break
	_check(s != null and s.near.pushed > int(SAY * 0.6 * Talk.RATE), "heard the skipper out loud (%d samples)"
			% (s.near.pushed if s else 0))
	_check(filled, "his voice is in the generator, waiting to play")
	var head: Node = sea.crew.get_player(1).head
	_check(s != null and s.near.outs.size() == 1 and s.near.outs[0] is AudioStreamPlayer3D
			and s.near.outs[0].get_parent() == head and head.get_parent().get("home") == a_boat,
			"from his head, over on A")
	_check(s != null and s.vhf.pushed == 0 and int(sea.tips.radio.get("keys")) == keys, "and nothing on the radio")
	_check(local, "the HUD showed him talking out loud")
	# the host over the VHF
	var vhf := false
	var rows := false
	until = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		vhf = vhf or int(talk.talking().get(1, -1)) == Talk.VHF
		rows = rows or talk._rows.has(1)
		if s.vhf.pushed > int(SAY * 0.6 * Talk.RATE) and s.heard_t > 0.6:
			break
	_check(s.vhf.pushed > int(SAY * 0.6 * Talk.RATE), "heard him over the radio, rivals and all (%d samples)" % s.vhf.pushed)
	_check(s.vhf.outs.size() == 2 and s.vhf.outs[0] is AudioStreamPlayer3D and s.vhf.outs[0].get_parent() == b_boat.get("wheel")
			and s.vhf.outs[1] is AudioStreamPlayer and str(s.vhf.outs[1].get("bus")) == "Radio",
			"from B's dash and in my ear, through the Radio bus")
	_check(int(sea.tips.radio.get("keys")) == keys + 1, "the squelch broke for him")
	_check(vhf and rows, "the HUD showed him on the radio")
	await _real(1.0)
	_check(not talk.talking().has(1), "and let him go after")
	# calling back
	await _say(Talk.VHF)
	await _real(2.5)


## Talks for SAY seconds on `chan`, at a mic's pace: a voice-ish tone, its pitch and loudness wobbling.
func _say(chan: int) -> void:
	var talk := sea.crew.talk
	var sent := 0
	var total := int(SAY * Talk.RATE)
	var start := Time.get_ticks_msec()
	if chan == Talk.VHF:
		talk.call("_squelch", true)
	while sent < total:
		await get_tree().process_frame
		var due := mini(int((Time.get_ticks_msec() - start) / 1000.0 * Talk.RATE), total)
		var out := PackedFloat32Array()
		out.resize(due - sent)
		for i in due - sent:
			var k := float(sent + i) / Talk.RATE
			_ph += TAU * (180.0 + 40.0 * sin(k * 9.0)) / Talk.RATE
			out[i] = 0.4 * sin(_ph) * (0.6 + 0.4 * sin(k * 13.0))
		sent = due
		talk.transmit(out, chan)
	talk.over(chan)
	if chan == Talk.VHF:
		talk.call("_squelch", false)


## Waits `seconds` on the wall clock (voices go by it; the game's frames here may run quicker or slower).
func _real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("VOICE TEST (%s) " % ("host" if _host else "friend"), "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
