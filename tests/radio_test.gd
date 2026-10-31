extends Node
## Dale on the radio (ui/tips.gd, ui/radio.gd, audio/radio_voice.gd): a tip comes up on the card and, with no
## recording of it, his voice comes over the VHF made up as it plays, through the Radio bus: talking about as long as
## the card's words take, breaths between phrases, then quiet (and the card stays up as long as he talks). Made fast
## enough to run while you play (GDScript, a sample at a time). And a WAV of it to listen to:
## <user data>/radio_test.wav. Run: godot --headless --fixed-fps 30 --path . res://tests/radio_test.tscn

const Sea := preload("res://sea/sea.gd")
const RadioVoice := preload("res://audio/radio_voice.gd")
const Radio := preload("res://ui/radio.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.tips.reset()
	sea.tips.show_tip("out")
	await get_tree().create_timer(0.5).timeout
	var radio: Node = sea.tips.get("radio")
	var garble: RadioVoice = radio.get("garble")
	_check(garble != null and garble.bus == Radio.BUS, "his voice goes through the radio's bus (%s)"
			% (garble.bus if garble else "none"))
	_check(garble != null and garble.talking() and garble.playing, "a tip with no recording: Dale's voice over the VHF")
	var left := float(sea.tips.get("_left"))
	var words := str(sea.tips.TIPS["out"]).split(" ", false).size()
	_check(left > 1.5, "the card's up while he talks (%.1f s more, %d words)" % [left, words])
	# the voice itself, a sample at a time: 20 words
	var v := RadioVoice.new()
	add_child(v)
	var said := v.say(20)
	var out := PackedFloat32Array()
	var t0 := Time.get_ticks_usec()
	while v.talking() and out.size() < int(RadioVoice.RATE * 30.0):
		out.append(v._sample())
	var us := float(Time.get_ticks_usec() - t0) / out.size()
	var secs := out.size() / RadioVoice.RATE
	_check(secs > 4.0 and secs < 9.0 and absf(secs - said) < 0.1, "20 words take %.1f s to say (said %.1f)" % [secs, said])
	var win := []
	for w in range(0, out.size() - 2205, 2205):
		var e := 0.0
		for i in 2205:
			e += out[w + i] * out[w + i]
		win.append(snappedf(sqrt(e / 2205.0), 0.01))
	var sorted := win.duplicate()
	sorted.sort()
	var quiet := win.filter(func(x: float) -> bool: return x < 0.05).size()
	_check(float(sorted[sorted.size() / 2]) > 0.1 and quiet >= 2,
			"it's heard: talking (%.2f), and breaths between phrases (%d)" % [sorted[sorted.size() / 2], quiet])
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
