extends Node
## She really goes places: take the wheel, hold W and she gets going, bow first, still riding the sea; let go and she
## carries her way; hold S and she backs down. The sea's waves belong to the world (moving the ocean's mesh changes no
## wave), and its mesh keeps up under you. A fish fought while she backs down onto it comes in. Schools turn up round
## her wherever she's got to, and the radar paints them.
## Run: godot --headless --path . res://tests/sail_test.tscn

const Sea := preload("res://sea/sea.gd")
const Fight := preload("res://tuna/fight.gd")
const Schools := preload("res://tuna/schools.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var helm: Node = sea.boat.get("helm")
	var me := sea.crew.me
	me.force_input = true
	helm.call("interact", me)
	_check(int(helm.get("captain")) == 1, "took the wheel")
	var from: Vector2 = helm.get("at")
	var bow := -sea.boat.global_basis.z
	# W: away she goes, bow first
	Input.action_press("move_forward")
	await get_tree().create_timer(6.0).timeout
	Input.action_release("move_forward")
	var v := float(helm.get("speed"))
	var at: Vector2 = helm.get("at")
	var went := at - from
	_check(v > 6.0, "hold W for 6 s: %.1f m/s (%.0f knots)" % [v, v * 1.944])
	_check(went.length() > 15.0 and went.normalized().dot(Vector2(bow.x, bow.z).normalized()) > 0.9,
			"she went %.0f m, bow first" % went.length())
	var b := sea.boat.global_position
	_check(Vector2(b.x, b.z).distance_to(at) < 0.5, "the boat's where the helm says she is")
	_check(absf(b.y - sea.ocean.height_at(b)) < 1.5, "and still riding the sea there (%.2f m off the water)"
			% (b.y - sea.ocean.height_at(b)))
	var o := sea.ocean.global_position
	_check(Vector2(o.x, o.z).distance_to(Vector2(b.x, b.z)) < 0.5, "the sea's mesh keeps up under her")
	# let go: she carries her way, slowing
	await get_tree().create_timer(4.0).timeout
	var coasting := float(helm.get("speed"))
	_check(coasting > 1.0 and coasting < v, "let go: she carries her way (%.1f m/s after 4 s)" % coasting)
	# S: she backs down
	Input.action_press("move_back")
	await get_tree().create_timer(5.0).timeout
	Input.action_release("move_back")
	_check(float(helm.get("speed")) < -1.0, "hold S: backing down (%.1f m/s)" % float(helm.get("speed")))
	# the sea's waves belong to the world: moving the mesh changes no wave under a point near both
	var p := sea.boat.global_position + Vector3(4.0, 0.0, -3.0)
	var h1 := sea.ocean.height_at(p)
	sea.ocean.global_position += Vector3(23.0, 0.0, -17.0)
	var h2 := sea.ocean.height_at(p)
	sea.ocean.global_position -= Vector3(23.0, 0.0, -17.0)
	_check(absf(h1 - h2) < 0.002, "the waves are the world's (%.4f vs %.4f m)" % [h1, h2])
	# a fish astern, and she backs down onto it: line comes in without a crank
	var f := Fight.new(150.0, 60.0, 0.6, 3)
	f.bearing = 0.0
	f.depth = 5.0
	f.moving = true
	f.boat_vel = Vector2(0.0, 2.5)        # (astern, her +z)
	f.carry_on("rest")
	var out0 := f.line_out
	for i in 60:
		f.step(1.0 / 30.0, false, 0.0)
	_check(f.line_out < out0 - 3.0, "backing down onto a fish closes on it (%.1f -> %.1f m)" % [out0, f.line_out])
	f.boat_vel = Vector2(0.0, -8.0)       # (ahead, away from it)
	var out1 := f.line_out
	for i in 30:
		f.step(1.0 / 30.0, false, 0.0)
	_check(f.line_out > out1 + 5.0, "running away from it pays out line (%.1f -> %.1f m)" % [out1, f.line_out])
	# far from where she started, schools still turn up round her
	helm.set("at", Vector2(3000.0, -2000.0))
	await get_tree().create_timer(0.2).timeout
	sea.schools.call("_host_start")
	var s: Node = sea.schools.schools[sea.schools.schools.size() - 1]
	var d := (s.call("center", sea.schools.now()) as Vector2).distance_to(helm.get("at"))
	_check(d < Schools.SPAWN.y + 10.0, "a new school turns up round her, wherever she is (%.0f m off)" % d)
	helm.set("speed", Schools.BITE_SPEED + 2.0)
	_check(float(sea.schools.call("boat_speed")) > Schools.BITE_SPEED, "at speed the baits skip (no bites)")
	helm.set("speed", 0.0)
	await get_tree().create_timer(0.4).timeout
	var radar := sea.get_node("Radar")
	_check(radar.get("_img") != null, "the radar's painting")
	_done()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("SAIL TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
