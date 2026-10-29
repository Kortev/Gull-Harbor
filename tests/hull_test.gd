extends Node
## The boat rides the sea instead of ploughing through it: for a minute of the weather given, how often and how far
## the water rises past her rail (the sheer, art/boat.py), all the way round the hull and across the transom.
## Run: godot --headless --path . res://tests/hull_test.tscn -- --weather=storm
## Passes when, in a storm, a crest slops over her rail under 5% of the time and by under half a metre; under 2%
## and 0.3 m in heavy weather; never in anything calmer. (Inside her the sea is drawn pushed down under the deck,
## ocean.gdshader's hull, so what comes over is a slap at the rail, not a wave through the cockpit.)

const Sea := preload("res://sea/sea.gd")
const L := 12.5

var sea: Sea
var frame := 0
var rail: Array[Vector3] = []
var frames_over := 0
var worst := 0.0
var sampled := 0


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	var z := -6.1
	while z <= 6.25:
		var u := (-z + L * 0.5) / L
		var y := 1.45 + 0.95 * pow(smoothstep(0.5, 1.0, u), 1.4)
		rail.append(Vector3(_s_half(u), y, z))
		rail.append(Vector3(-_s_half(u), y, z))
		z += 0.25
	for i in 9:
		rail.append(Vector3(-1.9 + i * 0.475, 1.45, 6.25))
	get_tree().physics_frame.connect(_tick)


func _s_half(u: float) -> float:
	if u < 0.3:
		return 1.98 + 0.17 * smoothstep(0.0, 0.3, u)
	if u < 0.55:
		return 2.15
	var t := (u - 0.55) / 0.45
	return 0.07 + 2.08 * pow(maxf(0.0, 1.0 - pow(t, 2.2)), 0.55)


func _tick() -> void:
	frame += 1
	if frame < 30:
		return
	var xf := sea.boat.global_transform
	var over := -INF
	for r in rail:
		var p := xf * r
		over = maxf(over, sea.ocean.height_at(p) - p.y)
	sampled += 1
	if over > 0.0:
		frames_over += 1
	worst = maxf(worst, over)
	if frame >= 30 + 3600:
		var share := float(frames_over) / sampled
		var ok := frames_over == 0
		if sea.condition == "storm":
			ok = share < 0.05 and worst < 0.5
		elif sea.condition == "heavy":
			ok = share < 0.02 and worst < 0.3
		print("HULL %s: over the rail %.1f%% of the time, worst %.2f m (closest the rest of the time: see worst<0)" % [sea.condition, share * 100.0, worst])
		print("HULL TEST " + ("PASSED" if ok else "FAILED"))
		get_tree().quit(0 if ok else 1)
