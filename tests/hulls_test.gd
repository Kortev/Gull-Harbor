extends Node
## The sea parts round every other boat, not just one (Rivals with three or four boats): ocean.gd's set_other_hulls
## turns on as many of the shader's other hulls (hull2_, hull3_, hull4_) as it's given, each with her own place and
## size, and lets the sea be round the rest; set_other_hull is still the first of them.
## Run: godot --headless --fixed-fps 30 --path . res://tests/hulls_test.tscn
## (Run it windowed once after touching ocean.gdshader: headless doesn't compile shaders.)

const Sea := preload("res://sea/sea.gd")
const U: Array[String] = ["hull2_", "hull3_", "hull4_"]

var sea: Sea
var frame := 0
var failed := false


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().physics_frame.connect(_tick)


func _check(what: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failed = true


func _mat() -> ShaderMaterial:
	return sea.ocean.get("_mat") as ShaderMaterial


func _on(i: int) -> bool:
	# (never set yet: null, the shader's own false)
	return _mat().get_shader_parameter(U[i] + "on") == true


## Where the shader has other hull `i` (world).
func _at(i: int) -> Vector3:
	var p := _mat().get_shader_parameter(U[i] + "xf") as Projection
	return (sea.ocean as Node3D).global_transform * Transform3D(p).origin


func _hull(at: Vector3, turn: float, length: float, beam: float) -> Dictionary:
	return {"xf": Transform3D(Basis(Vector3.UP, turn), at), "length": length, "beam": beam, "deck": 0.5,
			"speed": 3.0, "sheer": Vector2(1.3, 0.8)}


func _tick() -> void:
	frame += 1
	if frame != 10:
		return
	var ocean := sea.ocean as Node
	var m := _mat()
	_check("the sea has its material", m != null)
	if m == null:
		_done()
		return
	_check("the sea has set_other_hulls", ocean.has_method("set_other_hulls"))
	_check("no other hull is on to begin with", not _on(0) and not _on(1) and not _on(2))

	var a := Vector3(30, 0, 10)
	var b := Vector3(-25, 0, 40)
	var c := Vector3(5, 0, -60)
	ocean.call("set_other_hulls", [_hull(a, 0.3, 14.0, 4.8), _hull(b, 1.2, 9.0, 3.2), _hull(c, -2.0, 18.0, 6.0)])
	_check("three given: all three on", _on(0) and _on(1) and _on(2))
	_check("each at her own place", _at(0).distance_to(a) < 0.01 and _at(1).distance_to(b) < 0.01
			and _at(2).distance_to(c) < 0.01)
	_check("each her own length", is_equal_approx(float(m.get_shader_parameter("hull2_length")), 14.0)
			and is_equal_approx(float(m.get_shader_parameter("hull3_length")), 9.0)
			and is_equal_approx(float(m.get_shader_parameter("hull4_length")), 18.0))
	_check("each her own beam (over 4.3 m)", is_equal_approx(float(m.get_shader_parameter("hull3_beam")), 3.2 / 4.3)
			and is_equal_approx(float(m.get_shader_parameter("hull4_beam")), 6.0 / 4.3))
	_check("her deck, way and sheer go too", is_equal_approx(float(m.get_shader_parameter("hull4_deck")), 0.5)
			and is_equal_approx(float(m.get_shader_parameter("hull4_speed")), 3.0)
			and (m.get_shader_parameter("hull4_sheer") as Vector2).is_equal_approx(Vector2(1.3, 0.8)))
	var xf := Transform3D(m.get_shader_parameter("hull3_xf") as Projection)
	var inv := Transform3D(m.get_shader_parameter("hull3_inv") as Projection)
	_check("her inverse is her transform's", (xf * inv).is_equal_approx(Transform3D()))
	_check("her heading goes too", (xf.basis.z).is_equal_approx(Basis(Vector3.UP, 1.2).z))

	# the old call is the first of them, and leaves the others be
	var d := Vector3(-80, 0, -15)
	ocean.call("set_other_hull", Transform3D(Basis(), d), 12.0, 4.0, true, 0.6, 1.0, Vector2(1.4, 0.9))
	_check("set_other_hull sets the first", _on(0) and _at(0).distance_to(d) < 0.01
			and is_equal_approx(float(m.get_shader_parameter("hull2_length")), 12.0))
	_check("and leaves the second and third", _on(1) and _on(2) and _at(1).distance_to(b) < 0.01
			and _at(2).distance_to(c) < 0.01)

	ocean.call("set_other_hulls", [_hull(b, 0.0, 14.0, 4.8)])
	_check("one given: the first on, at her place", _on(0) and _at(0).distance_to(b) < 0.01)
	_check("one given: the other two off", not _on(1) and not _on(2))

	ocean.call("set_other_hulls", [_hull(a, 0.0, 14.0, 4.8), _hull(c, 0.0, 14.0, 4.8)])
	_check("two given: two on, the third off", _on(0) and _on(1) and not _on(2))

	var off := _hull(a, 0.0, 14.0, 4.8)
	off["on"] = false
	ocean.call("set_other_hulls", [off, _hull(c, 0.0, 14.0, 4.8)])
	_check("one that says it's off is off, the next still on", not _on(0) and _on(1) and not _on(2))

	ocean.call("set_other_hulls", [_hull(a, 0.0, 14.0, 4.8), _hull(b, 0.0, 14.0, 4.8), _hull(c, 0.0, 14.0, 4.8),
			_hull(d, 0.0, 14.0, 4.8)])
	_check("more than three: the first three, no error", _on(0) and _on(1) and _on(2) and _at(2).distance_to(c) < 0.01)

	ocean.call("set_other_hull", Transform3D(), 0.0, 0.0, false)
	_check("set_other_hull off: no other boat at all", not _on(0) and not _on(1) and not _on(2))

	ocean.call("set_other_hulls", [_hull(a, 0.0, 14.0, 4.8), _hull(b, 0.0, 14.0, 4.8), _hull(c, 0.0, 14.0, 4.8)])
	ocean.call("set_other_hulls", [])
	_check("none given: all off", not _on(0) and not _on(1) and not _on(2))
	_done()


func _done() -> void:
	print("HULLS TEST " + ("FAILED" if failed else "PASSED"))
	get_tree().quit(1 if failed else 0)
