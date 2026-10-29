extends Node
## The weather on its own: over a long trip every kind turns up (some sun, some storms), and it wanders rather
## than jumps (never more than two steps fair-to-foul from one spell to the next). Two peers with the same seed
## get the same sky.
## Run: godot --headless --path . res://tests/weather_test.tscn

const Weather := preload("res://sea/weather.gd")


func _ready() -> void:
	var fails: Array[String] = []
	var counts := {}
	var worst := 0
	for s in 5:
		var w := Weather.new()
		w.seed = 1234 + s * 777
		var prev := -1
		for k in range(1780000000 / 300, 1780000000 / 300 + 300):
			var kind := w.spell(k)
			counts[kind] = int(counts.get(kind, 0)) + 1
			var i := Weather.KINDS.find(kind)
			if prev >= 0:
				worst = maxi(worst, absi(i - prev))
			prev = i
	var b := Weather.new()
	b.seed = 1234
	var a := Weather.new()
	a.seed = 1234
	if str(a.at(1780001234.5)) != str(b.at(1780001234.5)):
		fails.append("two peers disagree")
	for kind: String in Weather.KINDS:
		if int(counts.get(kind, 0)) < 15:
			fails.append("hardly any %s (%d of 1500)" % [kind, int(counts.get(kind, 0))])
	if worst > 2:
		fails.append("jumped %d steps in one spell" % worst)
	print("WEATHER spells %s, biggest step %d" % [counts, worst])
	print("WEATHER TEST " + ("PASSED" if fails.is_empty() else "FAILED: " + ", ".join(fails)))
	get_tree().quit(0 if fails.is_empty() else 1)
