extends Node
## The fish finder at the helm: a scrolling echogram painted into the dash screen's texture (128 x 96, a column
## every tenth of a second). Deep blue water, the surface clutter on top, a faint thermocline, and when a school
## passes under or near the boat, the tuna: fat red-and-yellow arches at their depth, deeper and fainter the
## further off they are. Every peer paints its own from the shared schools, so everyone sees the same marks.

const W := 128
const H := 96
## Depth shown, m (the screen's bottom).
const RANGE := 80.0
## How far to the side a school still shows (m from the boat).
const REACH := 70.0

var schools: Node            # tuna/schools.gd
var _img: Image
var _tex: ImageTexture
var _in := 0.0
var _col := 0


func attach(boat: Node3D) -> void:
	_img = Image.create(W, H, false, Image.FORMAT_RGB8)
	_img.fill(Color(0.03, 0.06, 0.2))
	_tex = ImageTexture.create_from_image(_img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _tex
	mat.emission_enabled = true
	mat.emission_texture = _tex
	mat.emission_energy_multiplier = 1.3
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi: Node in boat.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(i)
			if sm and sm.resource_name == "sonar":
				m.set_surface_override_material(i, mat)


func _process(delta: float) -> void:
	if _img == null:
		return
	_in -= delta
	if _in > 0.0:
		return
	_in = 0.1
	_col += 1
	# scroll left a pixel, paint the new column on the right
	_img.blit_rect(_img, Rect2i(1, 0, W - 1, H), Vector2i(0, 0))
	var marks: Array = []
	if schools:
		for s: Node in schools.call("near", Vector3.ZERO, REACH):
			var c: Vector2 = s.call("center", float(schools.call("now")))
			var off := c.length() / REACH
			var depth := 12.0 + 30.0 * float(schools.call("hash1", float(int(s.get("seed")) % 977), 3.0)) + off * 10.0
			marks.append(Vector3(depth / RANGE * H, 1.0 - off, float(int(s.get("seed")) % 7)))
	for y in H:
		var c := Color(0.03, 0.06, 0.2).lerp(Color(0.02, 0.03, 0.12), float(y) / H)
		# surface clutter and the odd speck of bait
		if y < 4 + (_col * 7 % 3):
			c = Color(0.25, 0.45, 0.9)
		elif randf() < 0.012:
			c = Color(0.2, 0.5, 0.85)
		if absi(y - 34) < 1 and _col % 2 == 0:
			c = c.lerp(Color(0.2, 0.35, 0.7), 0.4)
		for m: Vector3 in marks:
			# an arch per fish: a few of them stacked, each a short fat smear
			for k in 3:
				var fy := m.x + (k - 1) * 6.0 + sin(_col * 0.37 + k * 2.0 + m.z) * 2.0
				var d := absf(y - fy)
				if d < 2.5 * m.y + 0.5 and fmod(_col + k * 5 + m.z, 9.0) < 6.0:
					c = Color(1.0, 0.85, 0.15).lerp(Color(0.95, 0.15, 0.08), clampf(d / 2.5, 0.0, 1.0)) \
							.lerp(c, 1.0 - m.y * 0.9)
		_img.set_pixel(W - 1, y, c)
	_tex.update(_img)
