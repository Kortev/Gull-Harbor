extends Node
## The world heard (audio/ambience.gd) follows what's going on. Lying at her berth on a calm day: the town over the
## water, the water lapping the quay and her hull, gulls, her lines creaking and her fenders squeaking, no gale, no rain.
## Out at sea in a storm: the gale whistling, the heavy sea, the rain round you (drumming on the T-top once you're under
## it), none of the harbour, her gear knocking about and her hull groaning as she rolls, a sea slapping her bow. Running
## flat out: the water rushing past her, her exhaust and her rigging up with it. A calm night out there: quieter wind,
## no birds, the bell buoy carrying. Fog: the lighthouse's horn. Prints every bed's level in each, as it goes.
## Run: godot --headless --fixed-fps 30 --path . res://tests/ambience_test.tscn

const Sea := preload("res://sea/sea.gd")
const Sfx := preload("res://audio/sfx.gd")
const BEDS := ["sea_calm", "sea_open", "swell", "wind_low", "wind_high", "gale", "rain", "rain_roof", "harbour", "night",
		"quay_lap", "pier_lap", "lap", "rush", "rigging", "exhaust", "pump"]

var fails: Array[String] = []
var sea: Sea
var amb: Node


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().process_frame
	amb = sea.ambience
	sea.schools.set("_next", 9999.0)
	sea.schools.set_process(false)
	sea.set_night(false)
	# 1. at her berth, a calm day, her lines fast
	sea.set_condition("calm")
	var helm := sea.boat.helm
	helm.at = sea.harbour.berth(float(sea.boat.beam) * 0.5, float(sea.boat.length))
	helm.heading = 0.0
	sea.boat.global_transform = sea.boat.pose()
	var free: Array = (sea.boat.lines.get("lines") as Array).duplicate(true)
	sea.boat.lines.call("host_make_fast_here")
	var berth := await _settle("berth, calm day", 40.0)
	_check(berth["harbour"] > 0.3, "the town's heard over the water (%.2f)" % berth["harbour"])
	_check(berth["quay_lap"] > 0.2 and berth["lap"] > 0.2, "water lapping the quay (%.2f) and her hull (%.2f)"
			% [berth["quay_lap"], berth["lap"]])
	_check(berth["wind_high"] < 0.05 and berth["gale"] < 0.01 and berth["rain"] < 0.01, "no gale and no rain")
	_check(berth["sea_calm"] > berth["sea_open"], "a calm sea's chuckles over the open sea's wash")
	_check(berth["night"] < 0.05, "no crickets by day")
	_check(int(Sfx.heard.get("amb.gull", 0)) > 0, "gulls calling (%d)" % int(Sfx.heard.get("amb.gull", 0)))
	_check(int(Sfx.heard.get("amb.creak", 0)) + int(Sfx.heard.get("amb.fender", 0)) > 0,
			"her lines creak and her fenders squeak, lying alongside")
	_check(amb.get("aboard"), "you're aboard her")
	# 2. out at sea in a storm, out on deck
	sea.boat.lines.set("lines", free)         # (her lines let go and aboard)
	helm.at = Vector2(0.0, -600.0)
	sea.boat.global_transform = sea.boat.pose()
	sea.set_condition("storm")
	amb.set("under", 0.0)
	var storm := await _settle("at sea, storm, out on deck", 40.0)
	_check(storm["wind_high"] > 0.5 and storm["gale"] > 0.3, "the gale whistling (%.2f, %.2f)"
			% [storm["wind_high"], storm["gale"]])
	_check(storm["swell"] > 0.4 and storm["sea_open"] > 0.5, "the heavy sea (%.2f, %.2f)"
			% [storm["swell"], storm["sea_open"]])
	_check(storm["rain"] > 0.6 and storm["rain_roof"] < storm["rain"], "the rain round you (%.2f) more than the roof's"
			% storm["rain"])
	_check(storm["harbour"] < 0.02 and storm["quay_lap"] < 0.02, "none of the harbour out here")
	_check(storm["rigging"] > berth["rigging"] + 0.3, "the wind singing in her rigging (%.2f)" % storm["rigging"])
	_check(int(Sfx.heard.get("amb.knock", 0)) > 0, "her gear knocking about as she rolls (%d)"
			% int(Sfx.heard.get("amb.knock", 0)))
	_check(int(Sfx.heard.get("amb.slap", 0)) > 0, "seas slapping her bow (%d)" % int(Sfx.heard.get("amb.slap", 0)))
	_check(int(Sfx.heard.get("amb.groan", 0)) > 0, "her hull groaning in the seaway")
	_check(int(Sfx.heard.get("amb.gull", 0)) == 0, "no gulls in a storm")
	amb.set("under", 1.0)
	var roof := await _settle("at sea, storm, under the T-top", 6.0)
	_check(roof["rain_roof"] > roof["rain"] and roof["rain_roof"] > 0.6, "under the T-top: the rain drumming on it "
			+ "(%.2f) over the rain round (%.2f)" % [roof["rain_roof"], roof["rain"]])
	_check(roof["wind_low"] < storm["wind_low"] - 0.1, "in its lee, the wind a little less (%.2f -> %.2f)"
			% [storm["wind_low"], roof["wind_low"]])
	amb.set("under", 0.0)
	# 3. a calm day at sea, lying still, then flat out
	sea.set_condition("sunny")
	var still := await _settle("at sea, sunny, lying still", 25.0)
	var me := sea.crew.me
	me.force_input = true
	helm.call("interact", me)
	Input.action_press("move_forward")
	var run := await _settle("at sea, sunny, flat out", 15.0)
	Input.action_release("move_forward")
	_check(run["rush"] > still["rush"] + 0.4, "under way the water rushes past her (%.2f -> %.2f)"
			% [still["rush"], run["rush"]])
	_check(run["lap"] < still["lap"] - 0.2, "and the lapping's gone (%.2f -> %.2f)" % [still["lap"], run["lap"]])
	_check(run["exhaust"] > still["exhaust"] + 0.3, "her exhaust up with the throttle")
	_check(run["wind_low"] > still["wind_low"], "the wind of her going")
	helm.call("interact", me)
	helm.throttle = 0.0
	helm.speed = 0.0
	# 4. a calm night out there
	sea.set_condition("calm")
	sea.set_night(true)
	var night := await _settle("at sea, calm night", 50.0)
	_check(float(amb.get("night_k")) > 0.8, "it's night")
	_check(night["wind_low"] < still["wind_low"], "the wind drops at night (%.2f < %.2f)"
			% [night["wind_low"], still["wind_low"]])
	_check(int(Sfx.heard.get("amb.gull", 0)) + int(Sfx.heard.get("amb.tern", 0)) == 0, "no birds at night")
	_check(int(Sfx.heard.get("amb.bell", 0)) > 0, "the bell buoy carrying (%d)" % int(Sfx.heard.get("amb.bell", 0)))
	# 5. at the quay at night: the crickets along the shore, the town quieter
	helm.at = sea.harbour.berth(float(sea.boat.beam) * 0.5, float(sea.boat.length))
	sea.boat.global_transform = sea.boat.pose()
	var quay_night := await _settle("berth, calm night", 25.0)
	_check(quay_night["night"] > 0.3, "crickets along the shore (%.2f)" % quay_night["night"])
	_check(quay_night["harbour"] < berth["harbour"], "the town quieter at night")
	# 6. fog: the lighthouse's horn
	sea.set_night(false)
	sea.set_condition("fog")
	await _settle("berth, fog", 40.0)
	_check(int(Sfx.heard.get("amb.foghorn", 0)) > 0, "the lighthouse's horn in the fog (seeing %.0f m)" % sea.seeing)
	for f in fails:
		print("FAIL ", f)
	print("AMBIENCE TEST %s" % ("PASSED" if fails.is_empty() else "FAILED"))
	get_tree().quit(1 if not fails.is_empty() else 0)


## Lets it run `secs` s (heard counts start afresh), then every bed's level, printed in a row.
func _settle(what: String, secs: float) -> Dictionary:
	Sfx.heard.clear()
	await get_tree().create_timer(secs).timeout
	var out := {}
	var row := ""
	for k: String in BEDS:
		out[k] = float(amb.call("level_of", k))
		row += " %s %.2f" % [k, out[k]]
	var shots := ""
	for e: String in Sfx.heard.keys():
		if e.begins_with("amb.") and not ((Sfx.EVENTS[e] as Dictionary).get("loop", false)):
			shots += " %s x%d" % [e.trim_prefix("amb."), int(Sfx.heard[e])]
	print("%-30s%s\n%-30s%s" % [what, row, "", shots])
	return out


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)
