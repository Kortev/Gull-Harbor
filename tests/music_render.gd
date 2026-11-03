extends Node
## The music played through the real mixer and written down (Godot's movie maker: the frames and a .wav of
## everything heard), for tools/music_check.py to listen to: the sea, a whole fish from the birds to the
## afterglow, then another lost, and the sea again for two of its passages. No sea, no game: audio/music.gd is handed each moment's world (world_test). At the end the clips
## and stings it played, and when, go next to the .wav as <name>.json.
## Run: tools/music_check.sh   (or: godot --path . --fixed-fps 30 --write-movie <dir>/f.png
##      res://tests/music_render.tscn -- --out=<dir>/f.json; python tools/music_check.py <dir>)

const DT := 1.0 / 30.0

var m: Node
var t := 0.0
var out := ""
var until := INF
var weather := false


func _fish(more := {}) -> Dictionary:
	var f := {"id": "0:1.00", "kg": 300.0, "tension": 0.3, "spool": 0.2, "depth": 10.0, "line_out": 150.0, "move": "run"}
	f.merge(more, true)
	return f


## (--sea) The sea alone through the weather: fair (drifting, then running hard), rain, a storm, night, fog, a
## sunny dusk.
func _weather() -> Array:
	return [
		[0.0, {"docked": false, "condition": "calm", "day": 0.3}],
		[17.0, {"docked": false, "condition": "calm", "day": 0.3, "speed": 0.9}],
		[35.0, {"docked": false, "condition": "rain", "day": 0.4}],
		[70.0, {"docked": false, "condition": "storm", "day": 0.5}],
		[105.0, {"docked": false, "condition": "calm", "night": true, "day": 1.2}],
		[140.0, {"docked": false, "condition": "fog", "day": 0.6}],
		[170.0, {"docked": false, "condition": "sunny", "day": 0.95}],
		[205.0, {}],
	]


## [from s, world]: each holds till the next.
func _script() -> Array:
	var sea := {"docked": false, "condition": "calm", "day": 0.3, "landed": 0}
	var at := func(more: Dictionary) -> Dictionary:
		var w := sea.duplicate()
		w.merge(more, true)
		return w
	return [
		[0.0, at.call({})],
		[3.0, at.call({"birds": 0.7})],
		[10.0, at.call({"fights": [_fish()]})],
		[16.0, at.call({"fights": [_fish({"move": "sound", "depth": 80.0, "tension": 0.2})]})],
		[24.0, at.call({"fights": [_fish({"move": "dog", "depth": 60.0, "tension": 0.62})]})],
		[27.0, at.call({"fights": [_fish({"move": "jump", "airborne": true, "tension": 0.1})]})],
		[28.6, at.call({"fights": [_fish({"move": "circle", "depth": 40.0, "tension": 0.2, "line_out": 60.0})]})],
		[40.0, at.call({"fights": [_fish({"move": "spiral", "depth": 5.0, "tension": 0.2, "line_out": 12.0})]})],
		[50.0, at.call({"alongside": ["0:1.00"]})],
		[53.0, at.call({"alongside": ["0:1.00"], "draw": 0.5})],
		[54.5, at.call({"alongside": ["0:1.00"], "draw": 1.0})],
		[56.0, at.call({"alongside": ["0:1.00"], "flying": true})],
		[56.8, at.call({"landed": 1})],
		[88.0, at.call({"landed": 1, "fights": [_fish({"id": "1:88.0"})]})],
		[96.0, at.call({"landed": 1})],
		[146.0, {}],
	]


func _ready() -> void:
	m = get_node("/root/Music")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--until="):
			until = float(a.substr(8))
		elif a == "--sea":
			weather = true


func _process(delta: float) -> void:
	t += delta
	var s := _weather() if weather else _script()
	var w: Dictionary = s[0][1]
	for step: Array in s:
		if t >= float(step[0]):
			w = step[1]
	if w.is_empty() or t >= until:
		_finish()
		return
	m.set("world_test", w)


func _finish() -> void:
	set_process(false)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"played": m.get("played"), "fps": 30, "heard": m.get("heard"),
				"put_right": m.get("put_right")}))
		f.close()
	print("MUSIC RENDER DONE (%d played)" % (m.get("played") as Array).size())
	get_tree().quit()
