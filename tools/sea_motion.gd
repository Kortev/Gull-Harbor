extends SceneTree
## How much the sea moves under a still eye, by weather: for each group of waves (the big swells, the FFT swell tile's
## biggest, the chop's biggest), its height (Hs, m), its mean period (s), how fast a point on the water rises and falls
## (RMS m/s) and how far and fast it slides sideways (RMS m, m/s). The waves ocean.gd's height_at rides (the GPU draws
## those and the smaller ones besides).
## Then a hull lying stopped in it (the sportfisher, 14 x 4.8 m, `--at=x,z` world, default out on the grounds): how far
## and how fast the water right beside her (1.5 m off her sides, her bow and her transom) slides past her, as RMS m
## and m/s and the worst of it (m), with her pinned where the helm has her ("pinned": the boat before ocean.gd's carry)
## and carried by the water's orbits ("carried"), and how far she's carried (RMS m, the slew RMS deg, its mean: none).
## Run: godot --headless --path . -s res://tools/sea_motion.gd [-- --at=x,z --heading=rad --secs=s]

const Ocean := preload("res://sea/ocean.gd")


func _initialize() -> void:
	var o := Ocean.new()
	root.add_child(o)
	# (once it's in the tree and ready: its patches' noise loaded, the shader made)
	process_frame.connect(_go.bind(o), CONNECT_ONE_SHOT)


func _go(o: Ocean) -> void:
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
		_hull(o)
	quit()


func _hull(o: Ocean) -> void:
	var at := Vector2(0.0, -900.0)
	var heading := 0.3
	var secs := 180.0
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"at": at = Vector2(float(kv[1].split(",")[0]), float(kv[1].split(",")[1]))
			"heading": heading = float(kv[1])
			"secs": secs = float(kv[1])
	# (the sea's mesh, its fade toward the horizon, round her: as it follows her in the game)
	o.global_position = Vector3(at.x, 0.0, at.y)
	var length := 14.0
	var beam := 4.8
	var turn := Basis(Vector3.UP, heading)
	# (boat-local: her sides, her bow, her transom, and the water 1.5 m off each)
	var spots: Array[Vector3] = [Vector3(beam * 0.5, 0, 0), Vector3(-beam * 0.5, 0, 0), Vector3(0, 0, -length * 0.5),
			Vector3(0, 0, length * 0.5)]
	var off: Array[Vector3] = [Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0), Vector3(0, 0, -1.5), Vector3(0, 0, 1.5)]
	var dt := 0.1
	var n := int(secs / dt)
	var stats := {}
	for mode in ["pinned", "carried"]:
		var sq := 0.0
		var vsq := 0.0
		var worst := 0.0
		var trail := []
		for k in spots.size():
			trail.append([])
		var cs := Vector2.ZERO
		var csq := 0.0
		var ysq := 0.0
		var ysum := 0.0
		for f in n + 1:
			var t := 1000.0 + f * dt
			o.wave_time = t
			o.set("_group_drift", o.call("_drift_at", t))
			var c: PackedFloat64Array = o.carry(Vector3(at.x, 0, at.y), heading, length, beam) if mode == "carried" 					else PackedFloat64Array([0, 0, 0, 0, 0, 0])
			var hull := Transform3D(Basis(Vector3.UP, heading + c[2]), Vector3(at.x + c[0], 0, at.y + c[1]))
			cs += Vector2(c[0], c[1])
			csq += c[0] * c[0] + c[1] * c[1]
			ysq += c[2] * c[2]
			ysum += c[2]
			for k in spots.size():
				# the bit of water that'd be 1.5 m off her there on still water, where the waves have it now
				var x0 := Vector3(at.x, 0, at.y) + turn * (spots[k] + off[k])
				var p := Vector2(x0.x, x0.z)
				var d: Vector3 = o.call("_displace", p, t, o.get("_group_drift"), p - Vector2(o.global_position.x, o.global_position.z))
				var water := Vector2(p.x + d.x, p.y + d.z)
				var h := hull * (spots[k] + off[k])
				(trail[k] as Array).append(water - Vector2(h.x, h.z))
		for k in spots.size():
			var tr: Array = trail[k]
			var m := Vector2.ZERO
			for r: Vector2 in tr:
				m += r
			m /= tr.size()
			for i in tr.size():
				var r: Vector2 = tr[i] - m
				sq += r.length_squared()
				worst = maxf(worst, r.length())
				if i > 0:
					vsq += ((tr[i] - tr[i - 1]) as Vector2).length_squared() / (dt * dt)
		var cnt := float(spots.size() * (n + 1))
		stats[mode] = [sqrt(sq / cnt), sqrt(vsq / (cnt - spots.size())), worst, sqrt(csq / (n + 1)),
				rad_to_deg(sqrt(ysq / (n + 1))), (cs / (n + 1)).length(), rad_to_deg(ysum / (n + 1))]
	for mode: String in stats:
		var r: Array = stats[mode]
		print("    hull at (%.0f, %.0f) %s: water beside her slides %.2f m RMS, %.2f m/s RMS, worst %.2f m;" % [at.x, at.y,
				mode, r[0], r[1], r[2]] + " carried %.2f m RMS (mean %.3f m), slew %.2f deg RMS (mean %.3f)" % [r[3], r[5],
				r[4], r[6]])
