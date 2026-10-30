extends Node
## The showcase reel: the sea, directed. A timeline of shots over the game's own world (sea/sea.tscn), each with its
## camera move, its weather and its light, and the boat running through them at the wheel. Rendered frame by frame
## by Godot's Movie Maker, so the waves keep the movie's clock, not the wall's:
##   godot --path . --write-movie docs/video/showcase.avi --fixed-fps 60 --resolution 1920x1080 res://tools/showcase.tscn
## Stills to check the framing (three a shot, no movie): ... --fixed-fps 30 res://tools/showcase.tscn -- --stills=<dir>
## [--from=<s>: start that far in]

const Sea := preload("res://sea/sea.gd")
const Weather := preload("res://sea/weather.gd")

## The weather the director says, not the one the clock says.
class Directed extends Weather:
	var now: Array = ["sunny", "sunny", 0.0]

	func at(_t: float) -> Array:
		return now


## [name, seconds]
const SHOTS := [
	["glide", 12.0],      # sunny, low sun: skimming the water, rising to the long swell to the horizon
	["chase", 8.0],       # the boat running fast, from astern
	["side", 10.0],       # alongside her, the sun beyond: the wake, the bow spray, light through the crests
	["build", 14.0],      # the weather coming in: sunny to rain to heavy, the seas getting up
	["storm", 14.0],      # a storm: big seas, the boat riding them, lightning
	["surf", 9.0],        # the surf on the open coast
	["harbour", 10.0],    # into Gull Harbor: the breakwater lights, the fish pier
	["wide", 11.0],       # a wide sunny sea to end on
]
## Where the waves' clock starts (s): any moment of the sea, this one's a good set.
const WAVE_T0 := 2000.0
const UP := Vector3.UP

var sea: Sea
var cam: Camera3D
var weather := Directed.new()
var t := 0.0
var _total := 0.0
var _shot := -1
var _fade: ColorRect
var _stills := ""
var _still_at: Array = []
var _y := 0.0                      # (the camera's height, smoothed: it rides the sea like a camera boat)
var _start := Vector3.ZERO         # (where a shot's camera began, for the moves that need it)
var _sun_flat := Vector3.FORWARD


func _ready() -> void:
	process_priority = -100        # (before the sea: its clock and the camera set first)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stills="):
			_stills = a.trim_prefix("--stills=")
		elif a.begins_with("--from="):          # (previews: start this far in)
			t = float(a.trim_prefix("--from="))
	var s := 0.0
	for shot: Array in SHOTS:
		var d := float(shot[1])
		if not _stills.is_empty():
			for f: float in [0.15, 0.5, 0.9]:
				if s + d * f > t:
					_still_at.append([s + d * f, "%s_%02d" % [shot[0], int(f * 100.0)]])
		s += d
	_total = s
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.weather = weather
	sea.fish_hold.head_out("sportfisher")
	sea.boat.helm.at = Vector2.ZERO
	sea.boat.helm.heading = 0.0
	# no tips from Dale, no spotter calling, no menu or HUD: just the sea
	for n: Node in [sea.tips, sea.spotter]:
		n.process_mode = Node.PROCESS_MODE_DISABLED
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.1
	cam.far = 6000.0
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 100
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	add_child(layer)


func _process(delta: float) -> void:
	t += delta
	if t >= _total:
		get_tree().quit()
		return
	# the waves on the movie's clock
	sea.ocean.clock_offset = WAVE_T0 + t - Time.get_ticks_msec() / 1000.0
	_hide_overlays()
	# her at the wheel, throttle up (the crew's own way, as --run does)
	var me := sea.crew.me
	if me != null:
		me.force_input = true
		if sea.boat.helm.captain == 0:
			sea.boat.helm.request(true)
	# which shot, and how far through it
	var s := 0.0
	var i := 0
	while i < SHOTS.size() - 1 and t >= s + float(SHOTS[i][1]):
		s += float(SHOTS[i][1])
		i += 1
	var d := float(SHOTS[i][1])
	var u := clampf((t - s) / d, 0.0, 1.0)
	var cut := i != _shot
	_shot = i
	call("_" + str(SHOTS[i][0]), u, d, cut)
	# a fade up at the start, a dip to black into and out of the land, a fade out at the end
	var a := 1.0 - smoothstep(0.0, 1.2, t)
	a = maxf(a, smoothstep(_total - 1.8, _total - 0.2, t))
	for edge: float in [_edge("surf"), _edge("wide")]:
		a = maxf(a, 1.0 - smoothstep(0.0, 0.35, absf(t - edge)))
	_fade.modulate.a = a
	if not _still_at.is_empty() and t >= float(_still_at[0][0]):
		_save_still(str(_still_at.pop_front()[1]))


## The time a shot starts (s).
func _edge(name: String) -> float:
	var s := 0.0
	for shot: Array in SHOTS:
		if shot[0] == name:
			return s
		s += float(shot[1])
	return s


func _save_still(what: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_stills)
	img.save_png(_stills.path_join(what + ".png"))
	print("STILL ", what, " t=%.2f" % t)


func _hide_overlays() -> void:
	if Engine.get_process_frames() % 15 != 0:
		return
	for n: Node in sea.find_children("*", "CanvasLayer", true, false):
		if n.get_script() != Sea.VisorRain:
			(n as CanvasLayer).visible = false


# ---- the light, the weather, the boat ----------------------------------------------------------------------------

func _weather(from: String, to := "", m := 0.0, day := 0.1) -> void:
	weather.now = [from, from if to.is_empty() else to, m]
	(sea.get("_args") as Dictionary)["day"] = str(day)       # (the sun where sea.gd's --day= puts it)


func _drive(gas: float, turn := 0.0) -> void:
	Input.action_press("move_forward", gas)
	if turn > 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left", turn)
	elif turn < 0.0:
		Input.action_release("move_left")
		Input.action_press("move_right", -turn)
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")


## The boat, steadied for the camera: where she is on the water (x, z, her y smoothed), which way she's going, and
## her right side.
func _boat() -> Array:
	var helm := sea.boat.helm
	var a: Vector2 = helm.ahead_of(helm.heading)
	var fwd := Vector3(a.x, 0.0, a.y)
	var at := Vector3(helm.at.x, 0.0, helm.at.y)
	at.y = sea.ocean.height_at(at)
	return [at, fwd, fwd.cross(UP)]


func _water(p: Vector3) -> float:
	return sea.ocean.height_at(Vector3(p.x, 0.0, p.z))


## Puts the camera at `from` (its height smoothed, never under the sea there: `clear` m over it at least) looking at
## `to`.
func _place(from: Vector3, to: Vector3, cut: bool, clear := 1.2, follow := 4.0) -> void:
	var floor_y := _water(from) + clear
	if cut:
		_y = from.y
	else:
		_y = lerpf(_y, from.y, minf(1.0, follow * get_process_delta_time()))
	from.y = maxf(_y, floor_y)
	cam.global_position = from
	if from.distance_to(to) > 0.01:
		cam.look_at(to, UP)


func _ease(u: float) -> float:
	return smoothstep(0.0, 1.0, u)


# ---- the shots ---------------------------------------------------------------------------------------------------

## Sunny, the sun low: skimming the water toward the sun's glitter, rising to the long swell out to the horizon.
func _glide(u: float, _d: float, cut: bool) -> void:
	_weather("sunny", "", 0.0, 0.05)
	_drive(1.0)
	cam.fov = 58.0
	if cut:
		var toward := sea.sun.global_transform.basis.z
		_sun_flat = Vector3(toward.x, 0.0, toward.z).normalized()
		# (well off the boat, which is getting under way at the origin)
		_start = Vector3(-260.0, 0.0, 180.0)
	var e := _ease(u)
	var side := _sun_flat.cross(UP)
	var from := _start + _sun_flat * (90.0 * u) + side * (12.0 * e)
	var h := _water(from)
	from.y = h + lerpf(0.9, 16.0, e * e)
	var to := from + _sun_flat * 100.0 + side * (-8.0 * e)
	to.y = lerpf(h - 4.0, 2.0, e)
	_place(from, to, cut, 0.7, 10.0)


## Running fast: astern of her and above, closing in a little, her wake streaming back under the camera.
func _chase(u: float, _d: float, cut: bool) -> void:
	_weather("sunny", "", 0.0, 0.08)
	_drive(1.0)
	cam.fov = 55.0
	var b := _boat()
	var at: Vector3 = b[0]
	var fwd: Vector3 = b[1]
	var right: Vector3 = b[2]
	var e := _ease(u)
	var from := at - fwd * lerpf(34.0, 22.0, e) + right * 0.0
	from.y = at.y + lerpf(8.0, 5.5, e)
	_place(from, at + fwd * 8.0 + UP * 1.5, cut)


## Alongside to port, the low sun beyond her: tracking with her, from her quarter up to her bow.
func _side(u: float, _d: float, cut: bool) -> void:
	_weather("sunny", "", 0.0, 0.08)
	_drive(1.0)
	cam.fov = 50.0
	var b := _boat()
	var at: Vector3 = b[0]
	var fwd: Vector3 = b[1]
	var right: Vector3 = b[2]
	var e := _ease(u)
	var from := at - right * lerpf(16.0, 20.0, e) + fwd * lerpf(-14.0, 12.0, e)
	from.y = at.y + 2.6
	_place(from, at + fwd * lerpf(-2.0, 3.0, e) + UP * 1.2, cut, 1.4, 2.0)


## The weather coming in: the sun goes, the rain comes across, then it's heavy and the sea gets up. Slowly round her
## from ahead on her bow to abeam.
func _build(u: float, d: float, cut: bool) -> void:
	var secs := u * d
	if secs < 4.0:
		_weather("sunny", "rain", smoothstep(0.0, 4.0, secs), 0.12)
	else:
		_weather("rain", "heavy", smoothstep(4.0, d - 1.5, secs), 0.12)
	_drive(0.75)
	cam.fov = 60.0
	var b := _boat()
	var at: Vector3 = b[0]
	var fwd: Vector3 = b[1]
	var right: Vector3 = b[2]
	var ang := lerpf(0.55, 1.6, _ease(u))         # (radians round from ahead, to starboard)
	var dist := lerpf(24.0, 20.0, u)
	var from := at + (fwd * cos(ang) + right * sin(ang)) * dist
	from.y = at.y + lerpf(4.5, 6.5, u)
	_place(from, at + UP * 1.0, cut, 1.5, 2.0)


## A storm: in close (the fog's a wall twenty metres out), low on her quarter, her climbing the seas and falling off
## them, the lightning going for her.
func _storm(u: float, _d: float, cut: bool) -> void:
	_weather("storm", "", 0.0, 0.15)
	_drive(0.55)
	cam.fov = 64.0
	var b := _boat()
	var at: Vector3 = b[0]
	var fwd: Vector3 = b[1]
	var right: Vector3 = b[2]
	var e := _ease(u)
	var hull := sea.boat.global_position
	var from := at - fwd * lerpf(11.0, 7.0, e) + right * lerpf(9.0, 11.0, e)
	from.y = hull.y + 3.5
	_place(from, hull.lerp(at, 0.5) + fwd * 3.0 + UP * 3.0, cut, 3.0, 2.0)


## The open coast: along the shore just outside the break, looking in at the surf.
func _surf(u: float, _d: float, cut: bool) -> void:
	_weather("sunny", "", 0.0, 0.3)
	_drive(1.0)
	cam.fov = 55.0
	var x := lerpf(-880.0, -760.0, u)
	var shore := float(sea.landmarks.shore_z(x))
	var from := Vector3(x, 0.0, shore - 150.0)
	from.y = _water(from) + 7.0
	var to := Vector3(x + 40.0, 2.0, shore + 10.0)
	_place(from, to, cut, 1.5, 3.0)


## Gull Harbor: in from outside, between the breakwater lights, toward the fish pier and the town.
func _harbour(u: float, _d: float, cut: bool) -> void:
	_weather("sunny", "", 0.0, 0.3)
	_drive(1.0)
	cam.fov = 55.0
	var e := _ease(u)
	var mouth := float(sea.landmarks.shore_z(0.0)) - 210.0
	var from := Vector3(lerpf(-110.0, -30.0, e), lerpf(34.0, 16.0, e), mouth + lerpf(-200.0, -40.0, e))
	var to := Vector3(lerpf(20.0, 55.0, e), 2.0, lerpf(2150.0, 2180.0, e))
	_place(from, to, cut, 2.0, 50.0)


## A wide sunny sea to end on: up and away from her as she runs on, turning a little, the low sun beyond her.
func _wide(u: float, _d: float, cut: bool) -> void:
	_weather("sunny", "", 0.0, 0.07)
	_drive(1.0, 0.25)
	cam.fov = 55.0
	var at: Vector3 = _boat()[0]
	var e := _ease(u)
	if cut:
		_start = at
		var toward := sea.sun.global_transform.basis.z
		_sun_flat = Vector3(toward.x, 0.0, toward.z).normalized()
	# (from down-sun of her, so she runs through the sun's glitter, craning up and back as she goes)
	var side := _sun_flat.cross(UP)
	var from := _start - _sun_flat * lerpf(34.0, 90.0, e) + side * lerpf(8.0, 20.0, e)
	from.y = lerpf(6.0, 42.0, e)
	_place(from, at + _sun_flat * lerpf(4.0, 22.0, e) + UP * 1.0, cut, 2.0, 50.0)
