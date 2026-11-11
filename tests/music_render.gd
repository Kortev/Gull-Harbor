extends Node
## The music as it leaves the mixer, for measuring (tools/music_check.sh --render; tools/music_render.py reads the
## recording): a scripted trip handed to the music as pictures (world_test), recorded by the movie maker. Prints
## "MARK <s> <what>" at each step, and what the music played at the end.
##   godot --path . --resolution 160x90 --fixed-fps 30 --write-movie out.avi res://tests/music_render.tscn

var m: Node
var t := 0.0
var i := 0
var steps: Array = []


func _ready() -> void:
	m = get_node("/root/Music")
	var sea := {"docked": false, "condition": "calm", "landed": 0, "speed": 0.2}
	var f := {"id": "0:1.00", "kg": 200.0, "tension": 0.25, "spool": 0.2, "line_out": 150.0, "move": "run"}
	var on := func(mv: String, more := {}) -> Dictionary:
		var w := sea.duplicate()
		var ff := f.duplicate()
		ff["move"] = mv
		ff.merge(more, true)
		w["fights"] = [ff]
		return w
	steps = [
		[0.0, "title", {"title": true, "docked": true, "condition": "calm"}],
		[14.0, "dock", {"docked": true, "condition": "calm", "landed": 0}],
		[26.0, "sea", sea],
		[50.0, "strike", on.call("run")],
		[62.0, "sound", on.call("sound")],
		[80.0, "circle", on.call("circle")],
		[95.0, "run2", on.call("run")],
		[102.0, "leader", on.call("spiral", {"line_out": 10.0})],
		[110.0, "alongside", sea.merged({"alongside": ["0:1.00"]}, true)],
		[116.0, "landed", sea.merged({"landed": 1}, true)],
		[136.0, "strike2", sea.merged({"landed": 1, "fights": [f.merged({"id": "1:2.00"}, true)]}, true)],
		[148.0, "lost", sea.merged({"landed": 1}, true)],        # (no fish on, none more aboard: he's gone)
		[166.0, "fast", sea.merged({"landed": 1, "speed": 1.0}, true)],
		[186.0, "storm", sea.merged({"landed": 1, "condition": "storm"}, true)],
		[216.0, "end", {}],
	]


func _process(delta: float) -> void:
	t += delta
	if i < steps.size() and t >= float(steps[i][0]):
		print("MARK %.2f %s" % [t, steps[i][1]])
		if str(steps[i][1]) == "end":
			for e: Array in m.played:
				print("PLAYED %.2f %s" % e)
			get_tree().quit(0)
			return
		m.world_test = steps[i][2]
		i += 1
