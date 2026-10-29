extends Node
## The radar at the helm (the dash's right-hand screen, 96 x 96): heading up, RANGE m to the edge, the sweep going
## round with the bar on the hardtop, and birds in the air painted as a blob where the sweep last crossed them, fading
## till it comes round again (birds sitting on the water don't paint, and it can't tell gulls over little bait from
## birds over bluefin: you have to get closer and look, crew/spotter.gd). Flocks the crew have called (tuna/schools.gd's marks) show as a
## mark wherever they are, pinned to the edge if they're further than the radar reaches. Every peer paints its own
## from the shared schools.

const S := 96
## Metres to the screen's edge, and the range rings' spacing.
const RANGE := 1500.0
const RING := 500.0
## The sweep (rad/s): boat.gd spins the bar at the same rate.
const SWEEP := 2.6

var schools: Node            # tuna/schools.gd
var boat: Node3D             # boat/boat.gd
var _img: Image
var _tex: ImageTexture
var _in := 0.0


func attach(to: Node3D) -> void:
	boat = to
	_img = Image.create(S, S, false, Image.FORMAT_RGB8)
	_img.fill(Color(0.02, 0.05, 0.03))
	_tex = ImageTexture.create_from_image(_img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _tex
	mat.emission_enabled = true
	mat.emission_texture = _tex
	mat.emission_energy_multiplier = 1.3
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi: Node in to.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(i)
			if sm and sm.resource_name == "radar_scope":
				m.set_surface_override_material(i, mat)


func _process(delta: float) -> void:
	if _img == null or schools == null or boat == null:
		return
	_in -= delta
	if _in > 0.0:
		return
	_in = 0.1
	var t := float(schools.call("now"))
	var helm: Node = boat.get("helm")
	var h := float(helm.get("heading"))
	var at: Vector2 = helm.get("at")
	var fwd := Vector2(-sin(h), -cos(h))
	var right := Vector2(cos(h), -sin(h))
	var mid := Vector2(S, S) * 0.5
	var scale := (S * 0.5 - 2.0) / RANGE
	var sweep := fposmod(t * SWEEP, TAU)
	_img.fill(Color(0.02, 0.05, 0.03))
	# the range rings
	var r := RING
	while r <= RANGE:
		for k in 120:
			var a := TAU * k / 120.0
			_dot(mid + Vector2(sin(a), -cos(a)) * r * scale, Color(0.06, 0.2, 0.1))
		r += RING
	# the sweep, and a faint trail behind it
	for k in 4:
		var a := sweep - k * 0.06
		var c := Color(0.2, 0.75, 0.35).lerp(Color(0.04, 0.12, 0.06), k / 4.0)
		for j in int(S * 0.5):
			_dot(mid + Vector2(sin(a), -cos(a)) * j, c)
	# the birds over each school: brightest just swept, fading till the sweep comes round again
	var marks: Dictionary = schools.get("marks")
	for s: Node in schools.get("schools"):
		var c2: Vector2 = s.call("center", t)
		var rel := c2 - at
		var p := Vector2(rel.dot(right), rel.dot(fwd))
		if marks.has(int(s.get("id"))):
			# a called flock: a cross, at the edge if it's beyond the range
			var q := p if p.length() < RANGE else p.normalized() * RANGE
			var mp := mid + Vector2(q.x, -q.y) * scale
			for k in range(-2, 3):
				_dot(mp + Vector2(k, k), Color(0.4, 0.9, 1.0))
				_dot(mp + Vector2(k, -k), Color(0.4, 0.9, 1.0))
		var flying := bool(s.call("feeding", t)) or t < float(s.get("spooked_until")) \
				or float(s.call("scattering", t)) > 0.0
		if p.length() > RANGE or not flying:
			continue
		var a := atan2(p.x, p.y)
		var age := fposmod(sweep - a, TAU) / SWEEP
		var glow := exp(-age / 1.6) * (1.0 - float(s.call("scattering", t)))
		var size := 2 if bool(s.call("feeding", t)) else 1
		var px := mid + Vector2(p.x, -p.y) * scale
		for dx in range(-size, size + 1):
			for dy in range(-size, size + 1):
				_dot(px + Vector2(dx, dy), Color(0.02, 0.05, 0.03).lerp(Color(1.0, 0.9, 0.4), glow))
	# her, in the middle
	_dot(mid, Color(0.9, 1.0, 0.9))
	_dot(mid + Vector2(0, -1), Color(0.9, 1.0, 0.9))
	_tex.update(_img)


func _dot(p: Vector2, c: Color) -> void:
	var x := int(p.x)
	var y := int(p.y)
	if x >= 0 and y >= 0 and x < S and y < S:
		_img.set_pixel(x, y, c)
