extends CanvasLayer
## Rain on your visor, out in Fathom's storm (fathom.py puts it under the planet's Fx): drops landing on the
## glass and drying off, some running down it, bending what's behind them (visor_rain.gdshader). Only while
## you're out in it: a ray straight up from the camera finds a roof (a deck above, the ship), and the glass
## dries off; step back out and it's wet again. Heavier as the sea rises (the planet's `sea_strength`).
## The hurricane (the sea's `gust`, ocean.gd): face into the wind and the glass is pelted, side-on the runs blow
## across it, back to the wind it's lighter; in a gust it's heavier, the runs race, and out in it the view shakes.
## Late in the night (the sea's `fury`) the glass is pelted harder and the gusts shake it more.
## Spray or the sea hitting it (sea_fx.gd's `splash`, Kevin 2026-10-17: "really REALLY rough"): a sheet of water
## over the glass, white and blurred, draining off top first; facing into a big gust, a lighter sheet of rain. Not
## while the planet's `tame` (the dev panel's compare).
## Each screen its own; nothing synced.

const SHADER := preload("res://sea/visor_rain.gdshader")
const ROOF_UP := 40.0
const WET_RATE := 1.5    # /s wetting, out in it
const DRY_RATE := 0.35   # /s drying, under a roof
## How much rain on the glass facing into the wind, back to it.
const INTO_WIND := 1.3
const BACK_TO_WIND := 0.35
## The shake at a gust's peak (screen uv).
const SHAKE := 0.004
## A splash drains off at this much a second; it jolts the view this much (x SHAKE).
const SPLASH_DRAIN := 0.75
const SPLASH_JOLT := 2.0
## Facing into a gust this strong, a sheet of rain this heavy hits the glass.
const GUST_SHEET := Vector2(0.7, 0.35)

## The dev panels: -1 follow the weather and the roofs, 0 off, 1 on.
var force := -1
## 0 dry .. 1 soaked (for tests too)
var wet := 0.0
## Is the camera out under the sky now?
var out := false
## How much of the rain the glass catches, the way you're facing (BACK_TO_WIND .. INTO_WIND; tests).
var facing := 1.0
## Is the view shaking now? (tests)
var shaking := false
## A sheet of water over the glass now (0..1; tests).
var sheet := 0.0

var _rect: ColorRect
var _mat: ShaderMaterial
var _planet: Node
var _look_in := 0.0
var _ocean: Node
var _flow := 0.0
var _t := 0.0
var _jolt := 0.0
var _gust_was := 0.0


func _ready() -> void:
	layer = -1  # over the 3D view, under the HUD
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)
	_planet = get_parent()
	while _planet != null and not ("weather_strength" in _planet):
		_planet = _planet.get_parent()
	# the sea (its wind and gusts): the planet's, or the lab's, the nearest Ocean up the tree
	var up := get_parent()
	while up != null and _ocean == null:
		_ocean = up.get_node_or_null("Ocean")
		up = up.get_parent()


func _process(delta: float) -> void:
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = 0.15
		out = _under_sky()
	var raining := out if force < 0 else force == 1
	wet = move_toward(wet, 1.0 if raining else 0.0, delta * (WET_RATE if raining else DRY_RATE))
	var sea := float(_planet.get("sea_strength")) if _planet != null else 1.0
	var gust := 0.0
	var gale := 0.0
	var fury := 0.0
	var slant := 0.0
	facing = 1.0
	var cam := get_viewport().get_camera_3d()
	if _ocean != null and cam != null:
		gust = float(_ocean.get("gust"))
		gale = maxf(float(_ocean.get("gusty")), gust)
		fury = float(_ocean.get("fury")) * gale
		var w: Vector2 = _ocean.get("wind")
		var w3 := Vector3(w.x, 0.0, w.y).normalized()
		var ahead := Vector3(-cam.global_basis.z.x, 0.0, -cam.global_basis.z.z).normalized()
		var right := Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
		facing = lerpf(1.0, lerpf(BACK_TO_WIND, INTO_WIND, (1.0 - ahead.dot(w3)) * 0.5), gale)
		slant = right.dot(w3) * lerpf(0.4, 1.1, gust) * gale
		# facing into a big gust as it slams in, a sheet of rain
		if gust >= GUST_SHEET.x and _gust_was < GUST_SHEET.x and facing > 1.0 and not bool(_ocean.get("tame")):
			splash(GUST_SHEET.y * (facing - 1.0) / (INTO_WIND - 1.0))
		_gust_was = gust
	sheet = move_toward(sheet, 0.0, delta * SPLASH_DRAIN)
	_jolt = move_toward(_jolt, 0.0, delta * 3.0)
	wet = maxf(wet, sheet)
	_t += delta
	_flow += delta * lerpf(1.0, 2.4, gust)
	_mat.set_shader_parameter("amount", minf(wet * lerpf(0.65, 1.0, sea) * facing * lerpf(1.0, 1.35, gust)
		* lerpf(1.0, 1.25, fury), 1.6))
	_mat.set_shader_parameter("slant", slant)
	_mat.set_shader_parameter("flow_time", _flow)
	# in a gust, out in it, the view shakes
	var shake := SHAKE * (smoothstep(0.15, 0.8, gust) * lerpf(1.0, 1.4, fury) * (1.0 if raining else 0.0)
		+ SPLASH_JOLT * _jolt)
	shaking = shake > 0.0002
	var jolt := Vector2(sin(_t * 113.0) * sin(_t * 37.0 + 0.4), sin(_t * 97.0 + 1.0) * sin(_t * 29.0))
	_mat.set_shader_parameter("shake", jolt * shake)
	_mat.set_shader_parameter("shaking", 1.0 if shaking else 0.0)
	_mat.set_shader_parameter("splash", sheet)
	_rect.visible = wet > 0.01 or shaking or sheet > 0.005


## Spray or the sea over the glass (sea_fx.gd), 0..1: only out in it (or forced on).
func splash(k: float) -> void:
	var raining := out if force < 0 else force == 1
	if not raining or k <= sheet:
		return
	_jolt = maxf(_jolt, k - sheet)
	sheet = clampf(k, 0.0, 1.0)


func _under_sky() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not cam.is_inside_tree():
		return false
	var from := cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * ROOF_UP)
	var body := cam.get_parent()
	while body != null and not (body is CollisionObject3D):
		body = body.get_parent()
	if body != null:
		query.exclude = [(body as CollisionObject3D).get_rid()]
	return cam.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
