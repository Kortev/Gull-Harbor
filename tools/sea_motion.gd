extends SceneTree
## How much the sea moves under a still eye, by weather: for each group of waves (the big swells, the FFT swell tile's
## biggest, the chop's biggest), its height (Hs, m), its mean period (s), how fast a point on the water rises and falls
## (RMS m/s) and how far and fast it slides sideways (RMS m, m/s). The waves ocean.gd's height_at rides (the GPU draws
## those and the smaller ones besides). Run: godot --headless --path . -s res://tools/sea_motion.gd

const Ocean := preload("res://sea/ocean.gd")


func _initialize() -> void:
	var o := Ocean.new()
	root.add_child(o)
	for wx in [0.12, 0.25, 0.5, 0.75, 1.0]:
		o.weather = wx
		o.call("_update_waves")
		var waves: Array = o.get("_waves")
		var nbig: int = (o.get("_big") as Array).size()
		var groups := {"big": [0, nbig], "swell": [nbig, nbig + Ocean.SWELL_N], "chop": [nbig + Ocean.SWELL_N, waves.size()]}
		var line := "weather %.2f swell %.1f m:" % [wx, float(o.get("swell"))]
		var all := [0.0, 0.0, 0.0, 0.0]
		for gname: String in groups:
			var r: Array = groups[gname]
			var s := [0.0, 0.0, 0.0, 0.0]     # sum a^2, sum (a w)^2, sum (Q a)^2, sum (Q a w)^2
			for i in range(r[0], r[1]):
				var w: PackedFloat32Array = waves[i]
				var a := w[3]
				var om := w[4]
				var q := w[6] if w.size() > 6 else 0.0
				s[0] += a * a
				s[1] += a * a * om * om
				s[2] += q * q * a * a
				s[3] += q * q * a * a * om * om
			for j in 4:
				all[j] += s[j]
			line += "  %s Hs %.2f T %.1f s vy %.2f sideways %.2f m %.2f m/s |" % [gname, 4.0 * sqrt(s[0] / 2.0),
					TAU * sqrt(s[0] / maxf(s[1], 1e-9)), sqrt(s[1] / 2.0), sqrt(s[2] / 2.0), sqrt(s[3] / 2.0)]
		line += "  ALL Hs %.2f T %.1f vy %.2f side %.2f m %.2f m/s" % [4.0 * sqrt(all[0] / 2.0),
				TAU * sqrt(all[0] / maxf(all[1], 1e-9)), sqrt(all[1] / 2.0), sqrt(all[2] / 2.0), sqrt(all[3] / 2.0)]
		print(line)
	quit()
