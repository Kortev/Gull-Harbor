extends Node
## Standing and walking on the deck in a storm: the deck must stay solid under your feet.
## Run: godot --headless --path . res://tests/deck_test.tscn -- --weather=storm
## (A scene, not a -s script: the Net autoload has to exist when the game's scripts compile.)

const Sea := preload("res://sea/sea.gd")

var sea: Sea
var frame := 0
var fails: Array[String] = []
var start_local := Vector3.ZERO
var max_drift := 0.0
var min_y := INF
var max_y := -INF
var max_z := -INF
var jumped_high := 0.0


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().physics_frame.connect(_tick)


## Where the player you SEE stands, in the boat's frame (should be the deck-space spot, exactly).
func _local() -> Vector3:
	return sea.boat.global_transform.affine_inverse() * sea.crew.me.global_position


func _tick() -> void:
	frame += 1
	var p := sea.crew.me
	p.force_input = true
	var l := _local()
	if frame == 60:
		start_local = l
	elif frame > 60 and frame <= 660:
		# 10 s standing still in a storm: no sliding, no sinking into the deck, no floating off it
		max_drift = maxf(max_drift, Vector2(l.x - start_local.x, l.z - start_local.z).length())
		min_y = minf(min_y, l.y)
		max_y = maxf(max_y, l.y)
	elif frame == 661:
		Input.action_press("move_forward")      # facing aft: walk to the transom
	elif frame > 661 and frame <= 900:
		max_z = maxf(max_z, l.z)
	elif frame == 901:
		Input.action_release("move_forward")
	elif frame == 960:
		start_local = l
		Input.action_press("jump")
	elif frame == 962:
		Input.action_release("jump")
	elif frame > 962 and frame < 1080:
		jumped_high = maxf(jumped_high, l.y - start_local.y)
	elif frame == 1080:
		_check(max_drift < 0.05, "stood still: drifted %.3f m across the deck" % max_drift)
		_check(min_y > 0.5 and max_y < 0.62, "stood still: feet between %.3f and %.3f (deck 0.55)" % [min_y, max_y])
		_check(max_z > 5.0 and max_z < 6.2, "walked aft to the transom: got to z %.2f (transom 6.15)" % max_z)
		_check(jumped_high > 0.4, "jumped %.2f m" % jumped_high)
		_check(absf(l.y - 0.55) < 0.06, "landed back on deck at %.3f" % l.y)
		for f in fails:
			print("FAIL ", f)
		print("DECK TEST ", "PASSED" if fails.is_empty() else "FAILED")
		get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
