extends CanvasLayer
## The whole-screen late PS1 / early PS2 look (world/screen/screen_look.tscn): a full-screen
## ColorRect whose shader (assets/world/shaders/psx_screen.gdshader) redraws the finished 3D frame
## at about 640x360 in square pixels, crushes it to 15-bit colour with a 4x4 ordered dither, and
## optionally adds CRT softness, scanlines and a vignette. No project setting needed.
##
## It sits on canvas layer -1: above the 3D world, below every HUD (CanvasLayers default to 1, the
## dev panel is 50), so 2D text stays sharp while the world, its Label3D screens and the fog crunch.
## It lives in world/sky/universe.tscn, so it's everywhere the ship is. A lab without the ship can
## instance screen_look.tscn anywhere in its scene.
##
## API: set_enabled(on), toggle(), apply_preset(id), set_setting(name, value), get_setting(name),
## PRESETS. Dev panels: ScreenLook.add_dev_section(panel) (finds the look, or adds one).
## Launch argument: -- --screen=<preset id|off>.

const SCENE_PATH := "res://screen/screen_look.tscn"
const GROUP := "screen_look"
const DEFAULT_PRESET := "psx_360"
## Preset id -> [label, settings]. Settings are the shader's uniforms.
## 360 and 480 average each block (thin text like the cockpit's CRT strip stays readable, edges
## shimmer less); 240 point-samples like a raw PS1.
const PRESETS := {
	"ps2_480": ["PS2 480", {"target_height": 480.0, "color_bits": 6.0, "dither": 0.5, "average": 1.0,
		"softness": 0.0, "scanlines": 0.0, "vignette": 0.0}],
	"psx_360": ["PS1/PS2 360", {"target_height": 360.0, "color_bits": 5.0, "dither": 0.6, "average": 1.0,
		"softness": 0.0, "scanlines": 0.0, "vignette": 0.0}],
	"ps1_240": ["PS1 240", {"target_height": 240.0, "color_bits": 5.0, "dither": 1.0, "average": 0.0,
		"softness": 0.0, "scanlines": 0.0, "vignette": 0.0}],
	"crt_360": ["CRT 360 (soft, scanlines, vignette)", {"target_height": 360.0, "color_bits": 5.0,
		"dither": 0.6, "average": 1.0, "softness": 0.5, "scanlines": 0.35, "vignette": 0.35}],
}
## Every setting's value before a preset touches it (the shader's own defaults).
const DEFAULTS := {"target_height": 360.0, "snap_integer": true, "color_bits": 5.0, "dither": 0.6,
	"average": 1.0, "softness": 0.0, "scanlines": 0.0, "vignette": 0.0}
## Dev panel sliders: setting, label, min, max, step.
const SLIDERS := [["target_height", "Pixel rows", 120.0, 720.0, 8.0],
	["color_bits", "Colour bits a channel (8 = off)", 3.0, 8.0, 1.0],
	["dither", "Dither (colour steps)", 0.0, 1.5, 0.0],
	["average", "Point sample (0) / block average (1)", 0.0, 1.0, 0.0],
	["softness", "CRT softness", 0.0, 1.0, 0.0],
	["scanlines", "Scanlines", 0.0, 1.0, 0.0],
	["vignette", "Vignette", 0.0, 1.0, 0.0]]

var enabled := true
var preset := DEFAULT_PRESET

var _panel_toggle: Button
var _panel_sliders := {}  # setting -> HSlider


func _init() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	layer = -1
	apply_preset(preset)
	for arg: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--screen="):
			var id := arg.trim_prefix("--screen=")
			if id == "off":
				set_enabled(false)
			elif PRESETS.has(id):
				apply_preset(id)


## The screen look in this scene tree, or null.
static func find_in(tree: SceneTree) -> CanvasLayer:
	return tree.get_first_node_in_group(GROUP) as CanvasLayer


## Adds the "Screen look" section to a lab's dev panel (world/dev/dev_panel.gd). Uses the screen
## look already in the scene (the universe has one), or adds one next to the panel.
static func add_dev_section(panel: Node) -> void:
	var look := find_in(panel.get_tree())
	if look == null:
		look = (load(SCENE_PATH) as PackedScene).instantiate() as CanvasLayer
		panel.get_parent().add_child.call_deferred(look)
	look.call("add_to_dev_panel", panel)


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	if _panel_toggle != null:
		_panel_toggle.text = "Screen look: %s (press to turn %s)" % ["ON" if on else "OFF", "off" if on else "on"]


func toggle() -> void:
	set_enabled(not enabled)


func apply_preset(id: String) -> void:
	if not PRESETS.has(id):
		push_warning("Screen look: no preset '%s'" % id)
		return
	preset = id
	var settings: Dictionary = PRESETS[id][1]
	for setting: String in settings:
		set_setting(setting, settings[setting])
	set_enabled(true)


func set_setting(setting: String, value: Variant) -> void:
	_material().set_shader_parameter(setting, value)
	var slider := _panel_sliders.get(setting) as HSlider
	if slider != null:
		slider.set_value_no_signal(float(value))


## A setting's value now.
func get_setting(setting: String) -> Variant:
	var value: Variant = _material().get_shader_parameter(setting)
	return DEFAULTS.get(setting) if value == null else value


## The low-res rows actually on screen now: whole screen pixels per row, so it follows the window
## (a 1080p screen at 360 is exact; a 648-high window gets 2-pixel rows, 324 of them).
func rows() -> int:
	if not is_inside_tree():
		return 0
	var height := float(get_viewport().get_texture().get_size().y)
	var target := float(get_setting("target_height"))
	if not enabled or target <= 0.0:
		return int(height)
	var px := maxf(height / target, 1.0)
	if bool(get_setting("snap_integer")):
		px = maxf(floorf(px + 0.5), 1.0)
	return int(height / px)


func add_to_dev_panel(panel: Node) -> void:
	panel.call("add_section", "Screen look (PS1/PS2)")
	_panel_toggle = panel.call("add_button", "", toggle)
	set_enabled(enabled)
	for id: String in PRESETS:
		panel.call("add_button", "Preset: " + String(PRESETS[id][0]), func() -> void:
			apply_preset(id)
			if panel.has_method("log_line"):
				panel.call("log_line", "Screen look: %s, %d rows in this window" % [PRESETS[id][0], rows()]))
	# Sliders on the labs' panel; the game's (Lane A's) has buttons only.
	if not panel.has_method("add_slider"):
		return
	for row: Array in SLIDERS:
		var setting: String = row[0]
		var slider: HSlider = panel.call("add_slider", row[1], row[2], row[3], float(get_setting(setting)),
			func(value: float) -> void: set_setting(setting, value))
		slider.step = row[4]
		_panel_sliders[setting] = slider


func _material() -> ShaderMaterial:
	return ($Effect as ColorRect).material as ShaderMaterial
