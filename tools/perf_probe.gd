extends Node
## Where the frame goes: starts the game as usual (sea.tscn at the top of the tree, the same command-line args), lets
## it settle, then measures it, then switches the suspects off one at a time and measures again, each against the same
## noisy machine in the same run. Prints the median frame (ms), the GPU's and the CPU's share of the render, the
## script's process time, draw calls and triangles for each.
## Run: godot --path . res://tools/perf_probe.tscn -- [the game's args: --title, --boat=skiff --weather=storm ...]
##   [--probe=all|base] [--settle=<s>] [--each=<s>]

var sea: Node
var _args := {}
var _steps: Array = []
var _step := -1
var _t := 0.0
var _undo: Callable
var _ms: Array[float] = []
var _gpu: Array[float] = []
var _cpu: Array[float] = []
var _proc: Array[float] = []
var _phys: Array[float] = []
var _draws: Array[float] = []
var _prims: Array[float] = []
var _vp: RID


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(sea)
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_t = -float(_args.get("settle", "8"))
	_steps = [["base", func() -> Callable: return func() -> void: pass]]
	if str(_args.get("probe", "all")) == "time":
		for i in 10:
			_steps.append(["base %d" % (i + 2), func() -> Callable: return func() -> void: pass])
	if str(_args.get("probe", "all")) == "nodes":
		# (the script's share: each of the sea's own children, and the boat's, stopped in turn)
		for n in ["Ocean", "Boat", "Crew", "Rods", "Landing", "FishHold", "Schools", "Chum", "Jig", "Binoculars",
				"Tips", "Spotter", "Plotter", "Sonar", "Radar", "SeaFx", "Menu", "Title", "Harbour", "Landmarks", "Vs", "Hud", "FightHud"]:
			_steps.append(["stop " + n, _stop(n)])
		_steps.append(["base again", func() -> Callable: return func() -> void: pass])
	if str(_args.get("probe", "all")) == "all":
		_steps += [
			["no ocean", _hide("Ocean")],
			["no ssao", _env("ssao_enabled", false)],
			["no glow", _env("glow_enabled", false)],
			["no fog", _env("fog_enabled", false)],
			["no vol fog", _env("volumetric_fog_enabled", false)],
			["no ssr", _env("ssr_enabled", false)],
			["no sun shadow", _shadows()],
			["no sky", _sky()],
			["no rain", _hide("Rain")],
			["no seafx", _hide("SeaFx")],
			["no visor", _canvas_off()],
			["no boat", _hide("Boat")],
			["no harbour", _hide("Harbour")],
			["no landmarks", _hide("Landmarks")],
			["no schools", _hide("Schools")],
			["no crew", _hide("Crew")],
			["no 2d ui", _all_canvas()],
			["base again", func() -> Callable: return func() -> void: pass],
		]


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.0:
		return
	if _step < 0 or _t > float(_args.get("each", "5")):
		if _step >= 0:
			_report(_steps[_step][0])
			_undo.call()
		_step += 1
		_t = -1.0       # (a second to let it settle after the switch)
		_ms.clear(); _gpu.clear(); _cpu.clear(); _proc.clear(); _phys.clear(); _draws.clear(); _prims.clear()
		if _step >= _steps.size():
			get_tree().quit()
			return
		_undo = (_steps[_step][1] as Callable).call()
		return
	_ms.append(delta * 1000.0)
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp))
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp))
	_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


func _report(what: String) -> void:
	var O := load("res://sea/ocean.gd")
	if "dbg_calls" in O:
		var by: Dictionary = O.dbg_by
		var keys := by.keys()
		keys.sort_custom(func(a, b): return by[a] > by[b])
		var top := ""
		for k in keys.slice(0, 6):
			top += "%s %d, " % [k, by[k] / maxi(_ms.size(), 1)]
		print("PROBE   height_at: %d/frame, %.1f us each, %.2f ms/frame: %s" % [O.dbg_calls / maxi(_ms.size(), 1),
				float(O.dbg_us) / maxi(O.dbg_calls, 1), float(O.dbg_us) / 1000.0 / maxi(_ms.size(), 1), top])
		O.set("dbg_calls", 0); O.set("dbg_us", 0); O.set("dbg_by", {})
	print("PROBE %-14s frame %6.2f ms (%5.1f fps)  gpu %6.2f  rcpu %5.2f  script %5.2f  phys %5.2f  draws %5d  tris %8d  [%d %s]" % [
			what, _median(_ms), 1000.0 / maxf(_median(_ms), 0.01), _median(_gpu), _median(_cpu), _median(_proc), _median(_phys),
			int(_median(_draws)), int(_median(_prims)), _ms.size(), get_window().size])


static func _median(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2]


func _hide(n: String) -> Callable:
	return func() -> Callable:
		var found := sea.find_children(n, "", true, false)
		var hid: Array[Node3D] = []
		for f in found:
			if f is Node3D and (f as Node3D).visible:
				(f as Node3D).visible = false
				hid.append(f)
		if hid.is_empty():
			print("PROBE (nothing called %s)" % n)
		return func() -> void:
			for f in hid:
				f.visible = true


func _stop(n: String) -> Callable:
	return func() -> Callable:
		var found := sea.find_children(n, "", true, false)
		if found.is_empty():
			print("PROBE (nothing called %s)" % n)
			return func() -> void: pass
		var f: Node = found[0]
		var was := f.process_mode
		f.process_mode = Node.PROCESS_MODE_DISABLED
		return func() -> void: f.process_mode = was


func _env(prop: String, v: Variant) -> Callable:
	return func() -> Callable:
		var env: Environment = sea.get("env")
		var was: Variant = env.get(prop)
		env.set(prop, v)
		return func() -> void: env.set(prop, was)


func _shadows() -> Callable:
	return func() -> Callable:
		var lights: Array[Light3D] = []
		for l in sea.find_children("*", "Light3D", true, false):
			if (l as Light3D).shadow_enabled:
				(l as Light3D).shadow_enabled = false
				lights.append(l)
		return func() -> void:
			for l in lights:
				l.shadow_enabled = true


func _sky() -> Callable:
	return func() -> Callable:
		var env: Environment = sea.get("env")
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.5, 0.6, 0.7)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		return func() -> void:
			env.background_mode = Environment.BG_SKY
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY


func _canvas_off() -> Callable:
	return func() -> Callable:
		var v: Node = sea.get("visor")
		var was: bool = v.get("visible")
		v.set("visible", false)
		return func() -> void: v.set("visible", was)


func _all_canvas() -> Callable:
	return func() -> Callable:
		var hid: Array[CanvasLayer] = []
		for c in sea.find_children("*", "CanvasLayer", true, false):
			if (c as CanvasLayer).visible:
				(c as CanvasLayer).visible = false
				hid.append(c)
		return func() -> void:
			for c in hid:
				c.visible = true
