extends Node
## Mouse look with the mouse captured: moving the mouse must turn your head (the HUD sits where the captured
## cursor is, the middle of the screen, and must not swallow the motion).
## Run (needs a window): xvfb-run -a godot --path . res://tests/look_test.tscn

const Sea := preload("res://sea/sea.gd")

var sea: Sea
var frame := 0
var start_yaw := 0.0


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().process_frame.connect(_tick)


func _tick() -> void:
	frame += 1
	if frame < 30:
		return
	var p := sea.crew.me
	if frame == 30:
		start_yaw = float(p.get("_yaw"))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mid := get_viewport().get_visible_rect().size * 0.5
	if frame < 60:
		var ev := InputEventMouseMotion.new()
		ev.position = mid
		ev.global_position = mid
		ev.relative = Vector2(8, 3)
		get_viewport().push_input(ev)
	elif frame == 60:
		var yaw := float(p.get("_yaw")) - start_yaw
		var pitch := float(p.get("_pitch"))
		var ok := absf(yaw) > 0.3 and absf(pitch) > 0.1
		print("LOOK yaw %.3f pitch %.3f mode %d" % [yaw, pitch, Input.mouse_mode])
		print("LOOK TEST " + ("PASSED" if ok else "FAILED"))
		get_tree().quit(0 if ok else 1)
