extends RefCounted
## A test angler for tuna/fight.gd: reads only what the rod, the reel and the line show (Fight.cues()) and plays it,
## the way a person reading the rod would. Used by fight_test, strike_test and trip_test.
##
## Styles: "good" (holds through the runs, cranks while the reel will win line, pumps when it grinds, lays the rod
## over against the swing, drops the tip when it jumps), "no_side" (good, never lays the rod over), "reeler" (just
## cranks, easing off only when the reel screams), "cranker" (cranks through everything), "statue" (holds the rod,
## does nothing), "high_tip" (good, but rod high and cranking when it jumps).

## -> {crank 0..1, pitch, side -1..1, drag}. `mem` keeps the angler's state between calls (start with {}).
static func act(c: Dictionary, dt: float, style: String, mem: Dictionary) -> Dictionary:
	var pitch := float(mem.get("pitch", 0.8))
	var state := str(mem.get("state", "crank"))
	var slip_t := float(mem.get("slip_t", 0.0))
	var calm_t := float(mem.get("calm_t", 0.0))
	var grind_t := float(mem.get("grind_t", 0.0))
	var side := float(mem.get("side", 0.0))
	var bend := float(c["bend"])
	var crank := 0.0
	slip_t = slip_t + dt if bool(c["slipping"]) else 0.0
	calm_t = calm_t + dt if not bool(c["slipping"]) else 0.0
	grind_t = grind_t + dt if bool(c["grinding"]) else 0.0
	match style:
		"statue":
			pitch = 0.6
		"cranker":
			crank = 1.0
			pitch = 0.8
		"reeler":
			pitch = 0.8
			crank = 0.0 if slip_t > 0.3 else 1.0
		_:
			if bool(c["airborne"]):
				if style == "high_tip":
					pitch = 1.35
					crank = 1.0
				else:
					pitch = move_toward(pitch, 0.25, 4.0 * dt)     # bow to it
			elif slip_t > 0.3:
				state = "hold"
				pitch = move_toward(pitch, 1.0, 0.9 * dt)
			elif state == "hold":
				pitch = move_toward(pitch, 1.0, 0.9 * dt)
				if calm_t > 0.3:
					state = "crank"
			else:
				var deep := float(c["line_pitch"]) < -0.9
				if state == "crank":
					crank = 1.0
					pitch = move_toward(pitch, 0.8, 1.0 * dt)
					if grind_t > 0.5:
						state = "heave"
				elif state == "heave":
					var top := 0.95 if deep else 1.3
					pitch += clampf((float(c["drag"]) - 0.06 - bend) * 8.0 + 0.2, 0.0, 1.2) * dt
					if pitch >= top:
						state = "drop"
				elif state == "drop":
					var bottom := 0.55 if deep else 0.3
					crank = 1.0
					pitch -= 1.7 * dt
					if pitch <= bottom:
						pitch = bottom
						state = "crank" if bend < 0.3 else "heave"
			if bool(c["thrash"]) and not bool(c["airborne"]):
				pitch = maxf(pitch, 0.9)
				crank = crank if bend < 0.25 else 0.0
			var sweep := float(c["sweep"])
			if style != "no_side" and absf(sweep) > 0.02 and bend > 0.3:
				side = move_toward(side, -signf(sweep), 3.0 * dt)
			else:
				side = move_toward(side, 0.0, 3.0 * dt)
	pitch = clampf(pitch, 0.15, 1.35)
	mem["pitch"] = pitch
	mem["state"] = state
	mem["slip_t"] = slip_t
	mem["calm_t"] = calm_t
	mem["grind_t"] = grind_t
	mem["side"] = side
	# a good angler watching the spool empty pushes the drag up to full, and back to strike once it's safe
	var drag := float(mem.get("drag", 0.72))
	if style in ["good", "no_side", "high_tip"]:
		if float(c["spool"]) > 0.55:
			drag = 0.95
		elif float(c["spool"]) < 0.35:
			drag = 0.72
	mem["drag"] = drag
	return {"crank": crank, "pitch": pitch, "side": side if style not in ["statue", "cranker", "reeler"] else 0.0,
			"drag": drag}
