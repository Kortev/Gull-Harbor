extends Node3D
## An ocean to the horizon: a real sea's spectrum of waves (sea/ocean_spectrum.gd), the long swell down to the
## ripples, drawn whole by an FFT on the GPU (sea/ocean_fft.gd, the way Sea of Thieves does it): sharp crests, wide
## troughs, whitecaps where the crests are squeezed till they break. Never tidy: the swell comes in sets, rough patches
## drift through with the wind, and it dies away in the shallows and behind the breakwaters (the shelter). Drawn by
## ocean.gdshader on a polar grid that's fine near this node and coarse out to the horizon. The sea's biggest waves
## are worked out here too, as rolling waves, so anything can ask how high the sea is at a point right now
## (`height_at`): the boat riding the swell, the fish, the line. `weather` sets how rough
## it is: 0 calm, 0.5 the usual rain, 1 a storm; on a planet (planet.gd up the tree) it follows
## tonight's weather (`weathers`, a storm building through the night) and the planet's wind. The
## waves run on `wave_time`: the night clock while a night's on (every peer shares it, so everyone
## sees the same wave at the same moment), else the engine's clock. `glow_spot` lights something
## huge under the water (the night's moment). This node's origin is the sea's mean level.
##
## The waves belong to the world, not to the mesh: with `follow_camera` the mesh (and its fine middle, the fade and the
## curve away to the horizon) moves along under whoever's looking, while every crest stays where it is in the world
## (the shader reads world x, z through `origin`; height_at does the same). So a boat can sail across the sea.

const NIGHT_LENGTH := 15.0 * 60.0
const SHADER := preload("res://sea/ocean.gdshader")
const NOISE := preload("res://sea/textures/sky_noise.png")
const G := 9.81
## The sea is a spectrum (sea/ocean_spectrum.gd: Tessendorf's FFT ocean, three tiles from the long swell to the
## ripples), drawn whole on the GPU (sea/ocean_fft.gd). Worked out here, for height_at: the biggest SWELL_N of the swell
## tile's waves and CHOP_N of the chop's, as rolling waves (Gerstner); the shader falls back to the first of them where
## there's no GPU sea. Each tile's height is its significant height (m) for the weather: the swell's from `swell`
## (crest to trough) times SWELL_HS, the chop's and the ripples' from the chop.
const Spectrum := preload("res://sea/ocean_spectrum.gd")
const Fft := preload("res://sea/ocean_fft.gd")
const SWELL_N := 48
const CHOP_N := 24
const SWELL_HS := 0.35
const RIPPLE_HS := Vector2(0.1, 0.24)
## The chop under the swell, as a share of the weather's chop (less of it: the wide swell's what you see).
const CHOP_HS := 1.6
## The big swells (Gerstner, on top of the FFT sea): BIG_N long-crested rolling waves, their lengths spread unevenly
## over BIG_LENGTHS (m) so they never fall into step, fanned off the wind (one a cross swell), each with its own phase:
## the long wide ridges with sharp tops. BIG_HS of the weather's swell height is theirs (the FFT's swell tile carries
## the rest), and their crests together are BIG_STEEP sharp (1: just touching a point).
const BIG_N := 7
const BIG_LENGTHS := Vector2(30.0, 110.0)
const BIG_HS := 0.55
const BIG_STEEP := 0.78
## How sharp each tile's crests are: its water's typical squeeze, as a share of the sea's steepness (`_steep`, the
## weather's). A few times that where the waves line up, and the crest folds over and breaks (the foam).
const TILE_STEEP := Vector3(0.5, 0.5, 0.2)
## The shader's arrays hold 32: where there's no GPU sea it draws this many of the swell and the rest of the chop.
const SHADER_SWELL := 20
const SEA_SEED := 20261029
## Calm, the usual rain, a storm: (swell crest to trough m, chop, steepness 0..1, whitecaps 0..1).
const CALM := [3.2, 0.5, 0.5, 0.0]
const RAIN := [5.8, 0.6, 0.68, 0.45]
const STORM := [12.0, 0.9, 0.9, 1.0]
## How fast the rough patches drift with the wind (m/s), calm to storm: about the speed the chop's groups go, slow
## enough that the ripples riding them don't seem to stream past a boat that's lying still (at 4 to 12 they did).
const GUSTS := Vector2(1.5, 5.0)
## The swell comes in sets: wide bands where it's bigger, then smaller, travelling with the wind at about the speed a
## group of long waves goes (half their own speed). SETS_SCALE m across the noise (the bands are a few hundred m), the
## speed in m/s; the chop's rough and smooth stretches, as wide again, drift slower.
const SETS_SCALE := 520.0
const SETS_SPEED := 5.0
const STRETCH_SCALE := 640.0
## Real deep-water wave speeds times this (a touch slower reads heavier).
const PACE := 0.85
## Where the waves fade out (the mesh gets too coarse) and the sea starts to curve away.
const FADE := Vector2(900.0, 2200.0)
const CURVE_START := 350.0
const CURVE_RADIUS := 12000.0
## The hurricane's gusts (a storm night; a lab's weather near 1): one in each GUST_SLOT s of the wave clock, starting
## up to GUST_SPREAD s into it, lasting GUST_LENGTH s (so one every 5 to 13 s), slamming in and easing off.
const GUST_SLOT := 9.0
const GUST_SPREAD := 4.0
const GUST_LENGTH := Vector2(3.5, 5.5)
## Late in a hurricane's night (`fury`), squalls on a faster clock on top of the gusts: one in each SQUALL_SLOT s,
## up to SQUALL_SPREAD s in, SQUALL_LENGTH s long, so the gusts come every few seconds and run into each other.
const SQUALL_SLOT := 4.2
const SQUALL_SPREAD := 1.4
const SQUALL_LENGTH := Vector2(2.6, 4.0)

## 0 calm, 0.5 the usual rain, 1 a storm.
@export_range(0.0, 1.0) var weather := 0.5:
	set(v):
		weather = v
		_dirty = true
## Where the wind and the swell go, in this node's x, z.
@export var wind := Vector2(0.8, 0.6):
	set(v):
		wind = v
		_dirty = true
## How wild the hurricane has got (0 at landing .. 1 late in the night): the planet's `fury` (or its dev
## override), a lab's own. More squalls, a denser gale, the fog closer (sea_fx.gd), the visor pelted harder.
@export_range(0.0, 1.0) var fury := 0.0
## The rig's legs, where the swell breaks into foam: (x, z, radius) in this node's space.
@export var legs: Array[Vector3] = []
## A sheltered patch where the sea is nearly still (the moon pool): center x, z, half sizes x, z.
@export var calm_rect := Vector4.ZERO
## How far the sea reaches (m).
@export var reach := 5000.0
## Keep the mesh under the camera (the bluefin game, where the boat goes places): x, z follow it every frame. With
## `follow` set (the boat), it follows that instead while the camera's near it: your head's heave and roll and your
## walking about don't drag the mesh over the waves, so at anchor it stays put (no crawl), only moving with her.
@export var follow_camera := false
var follow: Node3D
## On a planet: tonight's weather (by name) -> how rough, 0..1 (a storm builds through the night).
@export var weathers := {"rain": 0.5, "heavy rain": 0.75, "storm": 1.0}
## Something huge glowing under the water: x, z (this node's space), size (m), strength; and the way
## it's heading (x, z).
var glow_spot := Vector4.ZERO:
	set(v):
		glow_spot = v
		if _mat != null:
			_mat.set_shader_parameter("glow_spot", v)
var glow_heading := Vector2(1, 0):
	set(v):
		glow_heading = v
		if _mat != null:
			_mat.set_shader_parameter("glow_heading", v)
## Added to the engine's clock for the waves' time (a synced clock can drive it instead).
var clock_offset := 0.0
## How much it's raining (dots on the water), 0..1.
var rain := 0.6:
	set(v):
		rain = v
		if _mat != null:
			_mat.set_shader_parameter("rain", v)

var wave_time := 0.0
## The swell's height now (crest to trough, m).
var swell := 4.0
## How hard it's gusting now: 0 between the gusts .. 1 at a big one's peak (0 unless `gusty`). From the wave clock, so
## every peer feels the same gust (a dev panel's `force_gust` is that screen's own).
var gust := 0.0
## Whether the gusts blow, 0..1: a storm night 1, else 0; in a lab, from `weather` (1 at a storm).
var gusty := 0.0
## The storm as it was (no white sea): the planet's `tame`, or a lab's own.
var tame := false
var _forced_at := -100.0
var _waves: Array[PackedFloat32Array] = []  # each: dir x, dir z, k, amplitude, omega, phase, sharpness (the swell's first)
var _spectrum: Spectrum
var _big: Array = []          # [length m, share of height, off the wind (rad), phase]
var _spectrum_wind := Vector2.ZERO
var _fft: Fft
var _swirl_r := PackedFloat32Array()
var _swirl_g := PackedFloat32Array()
var _swirl_size := 128
var _group_drift := Vector2.ZERO
var _q := 0.0
var _steep := 0.6
var _mat: ShaderMaterial
var _hull := Transform3D.IDENTITY
var _hull_on := false
var _hull_size := Vector2(14.0, 4.8)
var _dirty := true
var _planet: Node
var _clock: Node
var _night_t := -1.0


func _ready() -> void:
	# before anything that asks how high the sea is this frame
	process_priority = -10
	add_to_group("ocean")
	_planet = get_parent()
	while _planet != null and not ("weather_strength" in _planet):
		_planet = _planet.get_parent()
	_clock = get_tree().get_first_node_in_group("night_clock")
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("noise", NOISE)
	_mat.set_shader_parameter("swirl", NOISE)
	_make_spectrum()
	# the noise, here too, so height_at works the patches and the warp out the same way
	var img := NOISE.get_image()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	_swirl_size = img.get_width()
	_swirl_r.resize(_swirl_size * _swirl_size)
	_swirl_g.resize(_swirl_size * _swirl_size)
	for y in _swirl_size:
		for x in _swirl_size:
			var c := img.get_pixel(x, y)
			_swirl_r[y * _swirl_size + x] = c.r
			_swirl_g[y * _swirl_size + x] = c.g
	_mat.set_shader_parameter("fade_start", FADE.x)
	_mat.set_shader_parameter("fade_end", FADE.y)
	_mat.set_shader_parameter("curve_start", CURVE_START)
	_mat.set_shader_parameter("curve_radius", CURVE_RADIUS)
	_mat.set_shader_parameter("rain", rain)
	if _hull_on:
		set_hull(global_transform * _hull, _hull_size.x, _hull_size.y)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = _build_mesh()
	sea.material_override = _mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	_update_waves()


func _process(delta: float) -> void:
	if follow_camera:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var at := cam.global_position
			if follow != null and follow.global_position.distance_to(at) < 60.0:
				at = follow.global_position
			global_position = Vector3(at.x, global_position.y, at.z)
	var o := _origin()
	_mat.set_shader_parameter("origin", o)
	# (the rain's cells and the foam's grain wrap every km, worked out here in full precision: far from where you
	# started, the shader's floats would turn them to bands)
	_mat.set_shader_parameter("origin_km", Vector2(fposmod(o.x, 1000.0), fposmod(o.y, 1000.0)))
	if _planet != null:
		var target := float(weathers.get(String(_planet.get("weather")), 0.5))
		var w := lerpf(0.5, target, float(_planet.get("sea_strength")))
		if absf(w - weather) > 0.004:
			weather = w
		var wd: Vector2 = _planet.get("wind_dir")
		if wd != wind:
			wind = wd
	if _dirty:
		_update_waves()
	wave_time = _wave_clock(delta)
	_mat.set_shader_parameter("wave_time", wave_time)
	if _fft != null:
		_fft.update(wave_time)
	if _planet != null:
		gusty = 1.0 if String(_planet.get("weather")) == "storm" else 0.0
		var pin := float(_planet.get("fury_override"))
		fury = pin if pin >= 0.0 else float(_planet.get("fury"))
		tame = bool(_planet.get("tame"))
	else:
		gusty = smoothstep(0.85, 1.0, weather)
	var forced := 0.0
	if wave_time - _forced_at < GUST_LENGTH.y and wave_time >= _forced_at:
		forced = _gust_shape((wave_time - _forced_at) / GUST_LENGTH.y)
	gust = maxf(storm_at(wave_time, fury) * gusty, forced)
	# the wind tearing the crests into streaks and haze, more in a gust
	_mat.set_shader_parameter("spume", maxf(gusty, forced) * (0.55 + 0.45 * gust))
	# a hurricane's sea white with foam, all of it (Kevin, 2026-10-17: "really REALLY rough"), whiter in a gust
	_mat.set_shader_parameter("white", 0.0 if tame else gusty * (0.75 + 0.25 * gust))
	# (from the time, not added up: every peer on the same clock sees the same patches)
	_group_drift = _drift_at(wave_time)
	_mat.set_shader_parameter("group_drift", _group_drift)
	_mat.set_shader_parameter("sets_drift", _sets_at(wave_time))


## The night clock while a night's on (every peer shares it: the host corrects it each second, so
## this eases toward it instead of jumping), else the engine's clock.
func _wave_clock(delta: float) -> float:
	if _clock != null and (_clock.get("running") or _clock.get("stranded")):
		var target := NIGHT_LENGTH - float(_clock.get("seconds_left"))
		if _night_t < 0.0 or absf(target - _night_t) > 3.0:
			_night_t = target
		else:
			_night_t += delta
			if _clock.get("running"):
				_night_t += (target - _night_t) * minf(1.0, delta * 0.5)
		return _night_t + clock_offset
	_night_t = -1.0
	return Time.get_ticks_msec() / 1000.0 + clock_offset


## The sea's surface height (world y) at a world point, right now, or `ahead` seconds from now (the
## same waves worked forward: every peer on the same clock sees the same crest coming).
func height_at(at: Vector3, ahead := 0.0) -> float:
	var t := wave_time + ahead
	var drift := _group_drift if ahead == 0.0 else _drift_at(t)
	var p := to_local(at)
	var q := Vector2(p.x, p.z)
	# the waves are the world's: w is where q is in the world (the mesh's fade and curve stay round this node)
	var o := _origin()
	var w := q + o
	# the waves move the water sideways too: find the bit of sea that's ended up over w
	var x := w
	for i in 3:
		var d := _displace(x, t, drift, x - o)
		x = w - Vector2(d.x, d.z)
	var y := _displace(x, t, drift, x - o).y - pow(maxf(q.length() - CURVE_START, 0.0), 2.0) / (2.0 * CURVE_RADIUS)
	return to_global(Vector3(q.x, y, q.y)).y


## Where this node is over the world (x, z): what the shader adds to the mesh's x, z to find the waves there.
func _origin() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## How hard the hurricane gusts at wave time `t` (0 .. 1, before `gusty`): every peer on the same clock gets the same.
func gust_at(t: float) -> float:
	var k := floori(t / GUST_SLOT)
	var g := 0.0
	for i: int in [k - 1, k]:
		var start := i * GUST_SLOT + _gust_hash(i, 1.0) * GUST_SPREAD
		var u := (t - start) / lerpf(GUST_LENGTH.x, GUST_LENGTH.y, _gust_hash(i, 2.0))
		if u > 0.0 and u < 1.0:
			g = maxf(g, _gust_shape(u) * lerpf(0.65, 1.0, _gust_hash(i, 3.0)))
	return g


## The hurricane's wind at wave time `t` and fury `f` (0 .. 1, before `gusty`): the gusts, and the squalls fading
## in with the fury. The same on every peer on the same clock.
func storm_at(t: float, f: float) -> float:
	var g := gust_at(t)
	var squalls := smoothstep(0.12, 0.85, f)
	if squalls <= 0.0:
		return g
	var k := floori(t / SQUALL_SLOT)
	for i: int in [k - 1, k]:
		var start := i * SQUALL_SLOT + _gust_hash(i, 5.0) * SQUALL_SPREAD
		var u := (t - start) / lerpf(SQUALL_LENGTH.x, SQUALL_LENGTH.y, _gust_hash(i, 6.0))
		if u > 0.0 and u < 1.0:
			g = maxf(g, _gust_shape(u) * lerpf(0.5, 0.9, _gust_hash(i, 7.0)) * squalls)
	return g


## A big gust now, on this screen only (the dev panels): it blows whatever the weather.
func force_gust() -> void:
	_forced_at = wave_time


## A gust over its life (u 0..1): slamming in, holding, easing off.
func _gust_shape(u: float) -> float:
	return smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.3, 1.0, u))


func _gust_hash(i: int, salt: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


## The sea's surface normal (world) at a world point, right now.
func normal_at(at: Vector3) -> Vector3:
	var e := 0.4
	var hx := height_at(at + Vector3(e, 0, 0)) - height_at(at - Vector3(e, 0, 0))
	var hz := height_at(at + Vector3(0, 0, e)) - height_at(at - Vector3(0, 0, e))
	return Vector3(-hx, 2.0 * e, -hz).normalized()


## A deck over the sea (Fathom's wave deck, fathom_hazards.gd): inside this box the sea isn't drawn over `top`, so a
## crest never shows through its grating. Its middle (x, z), half sizes along `axis` (x, z) and across it, the height:
## all in this node's space. A zero `half` turns it off.
## The boat, where she is right now (her global transform): the sea is drawn pushed down inside her hull, so a
## crest never shows through her deck (ocean.gdshader). Only the drawing: height_at is the open sea.
## Keeps the sea out of her: where she is, her length and her beam (m; art/boat.py's hull shape, stretched to fit).
func set_hull(boat: Transform3D, length := 14.0, beam := 4.8) -> void:
	_hull_on = true
	_hull_size = Vector2(length, beam)
	_hull = global_transform.affine_inverse() * boat
	if _mat != null:
		_mat.set_shader_parameter("hull_on", true)
		_mat.set_shader_parameter("hull_length", length)
		_mat.set_shader_parameter("hull_beam", beam / 4.3)
		_mat.set_shader_parameter("hull_xf", Projection(_hull))
		_mat.set_shader_parameter("hull_inv", Projection(_hull.affine_inverse()))


## The other boat (Rivals): the sea's cut away inside her too, so her deck stays dry to look at; null lets it be.
func set_other_hull(boat: Transform3D, length := 14.0, beam := 4.8, on := true) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("hull2_on", on)
	if on:
		_mat.set_shader_parameter("hull2_length", length)
		_mat.set_shader_parameter("hull2_beam", beam / 4.3)
		var xf := global_transform.affine_inverse() * boat
		_mat.set_shader_parameter("hull2_xf", Projection(xf))
		_mat.set_shader_parameter("hull2_inv", Projection(xf.affine_inverse()))


## Where the sun is (toward it, world), its colour, how dark it is (0 day .. 1 night): the water's shading and the
## light through the crests come from the sun's side; the water's own colours dim and warm with it (no teal glow at
## night, the crests catching the low sun's colour at dawn and dusk).
func set_light(toward: Vector3, color: Color, dark: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("shade_from", toward.normalized())
	var day := 1.0 - dark
	_mat.set_shader_parameter("glass", 0.55 * day * day)
	_mat.set_shader_parameter("glass_color", Color(0.1, 0.62, 0.55).lerp(Color(color.r, color.g, color.b) * 0.6, 0.35 * (1.0 - color.b)))
	# (only once it's really getting dark: at dawn and dusk the water's still the sky's colour, not black)
	var dim := smoothstep(0.5, 1.0, dark)
	_mat.set_shader_parameter("deep_color", Color(0.008, 0.055, 0.11).lerp(Color(0.006, 0.018, 0.03), dim))
	_mat.set_shader_parameter("crest_color", Color(0.03, 0.24, 0.32).lerp(Color(0.015, 0.05, 0.07), dim))


func set_sky_color(c: Color) -> void:
	_mat.set_shader_parameter("sky_color", c)


## How far the rough patches have drifted with the wind at wave time `t` (wrapped, as the shader reads it).
## How far the swell's sets have travelled at wave time `t` (uv of the noise at SETS_SCALE).
func _sets_at(t: float) -> Vector2:
	var d := wind.normalized() * SETS_SPEED / SETS_SCALE * t
	return Vector2(fposmod(d.x, 1.0), fposmod(d.y, 1.0))


func _drift_at(t: float) -> Vector2:
	var d := wind.normalized() * lerpf(GUSTS.x, GUSTS.y, weather) / 70.0 * t
	return Vector2(fposmod(d.x, 1.0), fposmod(d.y, 1.0))


## Where the bit of sea that starts at world point p has moved to (and how high) at wave time `t`, the
## patches drifted to `drift`; `from_middle` is p from this node (where the waves fade out toward the horizon).
func _displace(p: Vector2, t: float, drift: Vector2, from_middle := Vector2.ZERO) -> Vector3:
	var out := Vector3.ZERO
	var g := 0.35 + 1.3 * _swirl(_swirl_r, p / 70.0 - drift)
	g *= 0.45 + 1.1 * _swirl(_swirl_g, p / STRETCH_SCALE + Vector2(0.53, 0.19) - drift * (70.0 / STRETCH_SCALE))
	var sw := (0.85 + 0.3 * _swirl(_swirl_g, p / 180.0 + Vector2(0.31, 0.77))) 			* (0.3 + 1.4 * _swirl(_swirl_r, p / SETS_SCALE + Vector2(0.71, 0.43) - _sets_at(t)))
	var sh := _shelter_at(p)
	g *= sh.y
	sw *= sh.x
	for i in _waves.size():
		var w := _waves[i]
		var swell_wave := i < _big.size() + SWELL_N
		var a: float = w[3] * (sw if swell_wave else g)
		var th: float = w[2] * (w[0] * p.x + w[1] * p.y) - w[4] * t + w[5]
		var c := cos(th)
		out.x += w[6] * a * w[0] * c
		out.z += w[6] * a * w[1] * c
		out.y += a * sin(th)
	out += _surf_at(p, t)
	return out * (1.0 - smoothstep(FADE.x, FADE.y, from_middle.length())) * _calm_at(p)


## The noise, smooth (bilinear, wrapping), as the shader samples it.
func _swirl(ch: PackedFloat32Array, uv: Vector2) -> float:
	var n := _swirl_size
	var x := uv.x * n - 0.5
	var y := uv.y * n - 0.5
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := x - x0
	var fy := y - y0
	var x1 := posmod(x0 + 1, n)
	var y1 := posmod(y0 + 1, n)
	x0 = posmod(x0, n)
	y0 = posmod(y0, n)
	return lerpf(lerpf(ch[y0 * n + x0], ch[y0 * n + x1], fx), lerpf(ch[y1 * n + x0], ch[y1 * n + x1], fx), fy)


## How much of the open sea gets to world p (x the swell, y the chop): the shader's shelter_at.
static func _shelter_at(p: Vector2) -> Vector2:
	var x := p.x
	var sz := 1900.0 + 140.0 * sin(x / 1100.0 + 0.5) + 50.0 * sin(x / 370.0 + 2.0)
	sz += 220.0 * exp(-(x * x) / (2.0 * 260.0 * 260.0))
	sz -= 330.0 * exp(-((x - 1150.0) * (x - 1150.0)) / (2.0 * 240.0 * 240.0))
	var d := sz - p.y
	var k := Vector2(lerpf(0.85, 1.0, smoothstep(0.0, 300.0, d)), lerpf(0.8, 1.0, smoothstep(0.0, 150.0, d)))
	var e := (p - Vector2(0.0, 2170.0)) / Vector2(300.0, 150.0)
	var inside := 1.0 - smoothstep(0.75, 1.05, e.length())
	return k.lerp(Vector2(0.2, 0.45), inside)


## The surf rolling into the open coast (the shader's surf_at, the same): how far the water's moved by it at world p.
const SURF_K := TAU / 34.0
const SURF_Q := 2.5
var surf_height := 1.0


func _surf_at(p: Vector2, t: float) -> Vector3:
	var x := p.x
	var sz := 1900.0 + 140.0 * sin(x / 1100.0 + 0.5) + 50.0 * sin(x / 370.0 + 2.0)
	sz += 220.0 * exp(-(x * x) / (2.0 * 260.0 * 260.0))
	sz -= 330.0 * exp(-((x - 1150.0) * (x - 1150.0)) / (2.0 * 240.0 * 240.0))
	var d := sz - p.y
	if d > 420.0 or d < -1.0:
		return Vector3.ZERO
	var e := (p - Vector2(0.0, 2170.0)) / Vector2(300.0, 150.0)
	var sect := 0.45 + 1.1 * _swirl(_swirl_g, Vector2(x / 420.0 + 0.17, 0.61))
	var env := smoothstep(420.0, 90.0, d) * smoothstep(-1.0, 14.0, d) * smoothstep(0.85, 1.25, e.length()) * sect
	var a := surf_height * env
	var a1 := a * (0.35 + 0.65 * (0.5 + 0.5 * sin(t * TAU / 70.0 + x / 520.0)))
	var a2 := a * 0.55 * (0.3 + 0.7 * (0.5 + 0.5 * sin(t * TAU / 47.0 + x / 520.0 + 2.1)))
	var th := SURF_K * d + sqrt(G * SURF_K) * 0.85 * t + sin(x / 160.0) * 2.2
	var k2 := TAU / 23.0
	var th2 := k2 * (d + x * 0.2) + sqrt(G * k2) * 0.85 * t + sin(x / 97.0 + 1.3) * 1.6
	return Vector3(0.0, a1 * cos(th) + a2 * cos(th2), SURF_Q * (a1 * sin(th) + a2 * 0.6 * sin(th2)))


## Her wake: a trail of points she leaves (world x, z), each with the wave time and how hard she was going (0..1),
## the newest first; the shader paints the churn and the V's arms from them. And splashes: rings of foam.
const WAKE_POINTS := 64
var _wake := PackedVector4Array()
var _splashes := PackedVector4Array()
var _splash_next := 0


func add_wake(at: Vector3, power: float) -> void:
	_wake.insert(0, Vector4(at.x, at.z, wave_time, clampf(power, 0.0, 1.0)))
	if _wake.size() > WAKE_POINTS:
		_wake.resize(WAKE_POINTS)
	_mat.set_shader_parameter("wake_pts", _wake)
	_mat.set_shader_parameter("wake_count", _wake.size())
	# (a circle round the lot, so the rest of the sea doesn't look through it)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for w in _wake:
		lo = lo.min(Vector2(w.x, w.y))
		hi = hi.max(Vector2(w.x, w.y))
	var mid := (lo + hi) * 0.5
	_mat.set_shader_parameter("wake_bound", Vector3(mid.x, mid.y, (hi - lo).length() * 0.5 + 50.0))


## Something went in at `at` (world), `size` m across: a ring of foam opening out from it.
func add_splash(at: Vector3, size: float) -> void:
	if _splashes.size() < 8:
		_splashes.resize(8)
	_splashes[_splash_next % 8] = Vector4(at.x, at.z, wave_time, size)
	_splash_next += 1
	_mat.set_shader_parameter("splash_pts", _splashes)


func _calm_at(p: Vector2) -> float:
	if calm_rect.z <= 0.0:
		return 1.0
	var d := Vector2(absf(p.x - calm_rect.x) - calm_rect.z, absf(p.y - calm_rect.y) - calm_rect.w)
	return lerpf(0.08, 1.0, smoothstep(-2.0, 1.0, maxf(d.x, d.y)))


## The waves for this weather, here and in the shader.
func _update_waves() -> void:
	_dirty = false
	var t := weather * 2.0
	var a: Array = CALM if t <= 1.0 else RAIN
	var b: Array = RAIN if t <= 1.0 else STORM
	var f := t if t <= 1.0 else t - 1.0
	swell = lerpf(a[0], b[0], f)
	var chop := lerpf(a[1], b[1], f)
	_steep = lerpf(a[2], b[2], f)
	var whitecaps := lerpf(a[3], b[3], f)
	if wind != _spectrum_wind:
		_make_spectrum()
	# (in the worst of it the chop eases a little under the big seas: stacked on them it came up through her)
	var hs := Vector3(swell * SWELL_HS, chop * CHOP_HS * lerpf(1.0, 0.6, smoothstep(0.6, 1.0, weather)),
			lerpf(RIPPLE_HS.x, RIPPLE_HS.y, weather))
	_waves.clear()
	# the big swells first, sharp by their own measure
	var base := atan2(wind.y, wind.x)
	var big_a := swell * BIG_HS * 0.5           # (Hs to the amplitudes' root sum square: about half)
	# (the rougher it gets, the more of that height is in the long ones: a storm's seas are big and long, steep short
	# ones that size would come aboard; the same height in all)
	var lean := 1.6 * smoothstep(0.5, 1.0, weather)
	var shares := PackedFloat32Array()
	var sq := 0.0
	for w: Array in _big:
		var sh := float(w[1]) * pow(float(w[0]) / BIG_LENGTHS.y, lean)
		shares.append(sh)
		sq += sh * sh
	for i in shares.size():
		shares[i] /= sqrt(maxf(sq, 1e-6))
	var ka := 0.0
	for i in _big.size():
		ka += TAU / float(_big[i][0]) * big_a * shares[i]
	for i in _big.size():
		var w: Array = _big[i]
		var big := _wave(float(w[0]), big_a * shares[i], base + float(w[2]), float(w[3]))
		big.append(BIG_STEEP / maxf(ka, 0.0001))
		_waves.append(big)
	for c in 2:
		for w: Array in _spectrum.biggest[c]:
			var kv := Vector2(float(w[1]), float(w[2]))
			var k := kv.length()
			# (the spectrum's wave 2|h0| cos(k.x + w t + phase) going toward -k, as a rolling wave: a sin(k dir.x - w t + p))
			_waves.append(_wave(TAU / k, float(w[0]) * hs[c], atan2(-kv.y, -kv.x), PI * 0.5 - float(w[3])))
	# each tile's crests as sharp as its share of the weather's steepness, every wave in it counted (the rolling waves
	# here get their tile's: the GPU sea and these are the same waves)
	var q := Vector3.ZERO
	for c in 3:
		q[c] = _steep * TILE_STEEP[c] / maxf(_spectrum.steepness[c] * hs[c], 0.0001)
	for i in range(_big.size(), _waves.size()):
		var w := _waves[i]
		w.append(q[0] if i < _big.size() + SWELL_N else q[1])
		_waves[i] = w
	_q = q[0]
	var wa := PackedVector4Array()
	var wb := PackedVector4Array()
	for i in _waves.size():
		var fft_swell := i >= _big.size() and i < _big.size() + SWELL_N
		if (fft_swell and i >= _big.size() + SHADER_SWELL) or wa.size() >= 32:
			continue
		var w := _waves[i]
		wa.append(Vector4(w[0], w[1], w[2], w[3]))
		wb.append(Vector4(w[4], w[5], w[6], 0.0))
	_mat.set_shader_parameter("waves", wa)
	_mat.set_shader_parameter("waves_b", wb)
	_mat.set_shader_parameter("wave_count", wa.size())
	_mat.set_shader_parameter("swell_count", _big.size() + mini(SHADER_SWELL, SWELL_N))
	_mat.set_shader_parameter("big_count", _big.size())
	_mat.set_shader_parameter("fft_gain", hs)
	# the surf: the bigger the swell, the bigger it breaks on the coast
	surf_height = swell * 0.17
	_mat.set_shader_parameter("surf_height", surf_height)
	if _fft != null:
		_fft.chops = PackedFloat32Array([q[0], q[1], q[2]])
	_mat.set_shader_parameter("steep", _steep)
	_mat.set_shader_parameter("swell", swell)
	_mat.set_shader_parameter("whitecaps", whitecaps)
	var lw := PackedVector4Array()
	for leg in legs:
		lw.append(Vector4(leg.x, leg.y, leg.z, 0.0))
	_mat.set_shader_parameter("legs", lw)
	_mat.set_shader_parameter("leg_count", legs.size())
	_mat.set_shader_parameter("calm_rect", calm_rect)
	_mat.set_shader_parameter("wind", wind)


## The sea's spectrum, from SEA_SEED and the wind (made again if the wind ever changes), and the GPU sea drawing it.
func _make_spectrum() -> void:
	_spectrum_wind = wind
	# the big swells: lengths spread unevenly (log-spaced, jittered: no two ever in step), heights rising with length,
	# directions fanned round the wind, the third of them a cross swell
	var rng := RandomNumberGenerator.new()
	rng.seed = SEA_SEED + 7
	_big.clear()
	var sq := 0.0
	for i in BIG_N:
		var f := (i + rng.randf_range(0.15, 0.85)) / BIG_N
		var length := BIG_LENGTHS.x * pow(BIG_LENGTHS.y / BIG_LENGTHS.x, f)
		var off := deg_to_rad(rng.randf_range(35.0, 55.0) * (1.0 if rng.randf() < 0.5 else -1.0)) if i == 2 \
				else deg_to_rad(rng.randfn(0.0, 16.0))
		var share := pow(length / BIG_LENGTHS.y, 0.7) * rng.randf_range(0.75, 1.25)
		sq += share * share
		_big.append([length, share, off, rng.randf_range(0.0, TAU)])
	for w: Array in _big:
		w[1] = float(w[1]) / sqrt(sq)
	_spectrum = Spectrum.new(SEA_SEED, wind, PackedInt32Array([SWELL_N, CHOP_N, 0]))
	if _fft != null:
		_fft.free_all()
	_fft = Fft.new(_spectrum)
	_fft.pace = PACE
	if not _fft.ok():
		_fft = null
	_mat.set_shader_parameter("fft_on", _fft != null)
	if _fft != null:
		for c in 3:
			_mat.set_shader_parameter("fft_a%d" % c, _fft.tex_a[c])
			_mat.set_shader_parameter("fft_b%d" % c, _fft.tex_b[c])
		_mat.set_shader_parameter("fft_size", Vector3(Spectrum.CASCADES[0]["size"], Spectrum.CASCADES[1]["size"],
				Spectrum.CASCADES[2]["size"]))
		_mat.set_shader_parameter("fft_n", float(Spectrum.N))


static func _wave(length: float, amplitude: float, angle: float, phase: float) -> PackedFloat32Array:
	var k := TAU / length
	return PackedFloat32Array([cos(angle), sin(angle), k, amplitude, sqrt(G * k) * PACE, phase])


## Rings round the middle, close together near it and further apart out to the horizon, with as
## many points round each ring: no seams to crack open when the waves move it.
func _build_mesh() -> ArrayMesh:
	var radii := PackedFloat32Array([0.0])
	# fine round the boat (so the sea meets her hull cleanly), coarser and coarser out to the horizon
	var step := 0.3
	var r := 0.0
	while r < reach:
		r += step
		radii.append(r)
		if r > 14.0:
			step *= 1.08 if step < 1.2 else 1.035
	var seg := 320
	var verts := PackedVector3Array([Vector3.ZERO])
	for i in range(1, radii.size()):
		for j in seg:
			var ang := TAU * j / seg
			verts.append(Vector3(cos(ang) * radii[i], 0.0, sin(ang) * radii[i]))
	var idx := PackedInt32Array()
	for j in seg:
		idx.append_array([0, 1 + (j + 1) % seg, 1 + j])
	for i in range(1, radii.size() - 1):
		var a0 := 1 + (i - 1) * seg
		var b0 := 1 + i * seg
		for j in seg:
			var j1 := (j + 1) % seg
			idx.append_array([a0 + j, a0 + j1, b0 + j1, a0 + j, b0 + j1, b0 + j])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-reach, -80.0, -reach), Vector3(reach * 2.0, 160.0, reach * 2.0))
	return mesh
