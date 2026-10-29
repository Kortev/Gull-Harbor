extends Node
## Dale on the radio (audio/radio_voice.gd, ui/tips.gd): a tip on the card and his voice from the dash by the wheel:
## static as he keys the mike, a voice talking about as long as the words take, static as he lets go, then quiet.
## Made fast enough to run while you play (GDScript, a sample at a time). And a WAV of it to listen to:
## <user data>/radio_test.wav. Run: godot --headless --path . res://tests/radio_test.tscn

const Sea := preload("res://sea/sea.gd")
const RadioVoice := preload("res://audio/radio_voice.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.tips.reset()
	sea.tips.show_tip("out")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().create_timer(0.5).timeout
	var voice: Node3D = sea.tips.get("voice")
	_check(voice != null and voice.get_parent() == sea.boat, "a tip comes over the radio on her dash")
	if voice != null:
		var wheel: Vector3 = (sea.boat.get("helm") as Node3D).position
		_check(voice.position.distance_to(wheel) < 0.6, "the voice comes from by the wheel")
	# the voice itself, a sample at a time: 20 words
	var v := RadioVoice.new()
	add_child(v)
	v.say(20)
	var out := PackedFloat32Array()
	var t0 := Time.get_ticks_usec()
	while v.talking() and out.size() < int(RadioVoice.RATE * 30.0):
		out.append(v._sample())
	var us := float(Time.get_ticks_usec() - t0) / out.size()
	var secs := out.size() / RadioVoice.RATE
	_check(secs > 4.0 and secs < 9.0, "20 words take %.1f s to say" % secs)
	var win := []
	for w in range(0, out.size() - 2205, 2205):
		var e := 0.0
		for i in 2205:
			e += out[w + i] * out[w + i]
		win.append(snappedf(sqrt(e / 2205.0), 0.01))
	var sorted := win.duplicate()
	sorted.sort()
	var quiet := win.filter(func(x: float) -> bool: return x < 0.05).size()
	_check(float(win[0]) > 0.05 and float(sorted[sorted.size() / 2]) > 0.1 and quiet >= 2,
			"it's heard: static as he keys the mike (%.2f), talking (%.2f), and breaths between phrases (%d)"
			% [win[0], sorted[sorted.size() / 2], quiet])
	_check(us < 20.0, "fast enough: %.1f us a sample (%.0f%% of a CPU)" % [us, us * RadioVoice.RATE / 1e4])
	_write_wav(out, "user://radio_test.wav")
	_done()


func _write_wav(samples: PackedFloat32Array, path: String) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, clampi(int(samples[i] * 32000.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RadioVoice.RATE)
	w.data = data
	w.save_to_wav(path)


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("RADIO TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
