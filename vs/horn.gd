extends Area3D
## The air horn at each boat's console in VS (vs/vs.gd), beside the wheel: E on it and she blasts, heard a mile off.
## Near the other boat (NEAR m) it rattles her crew (their view jolted: vs/contact.gd's jolt) and jerks any fish on her
## lines: the rod tip snaps and the fight takes a little shock (tuna/fight.gd), never enough on its own to lose it.
## The host says when (a blast every AGAIN s a boat at most); everyone hears it.

const NEAR := 120.0
const AGAIN := 2.0
const SHOCK := 0.12
const LONG := 1.3
const RATE := 22050

var vs: Node                  # vs/vs.gd
var team := 0
var boat: Node3D
## Blasts heard here.
var blasts := 0
var _last := -INF
var _player: AudioStreamPlayer3D
static var _sound: AudioStreamWAV


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	cs.shape = box
	add_child(cs)
	_player = AudioStreamPlayer3D.new()
	_player.stream = _blast()
	_player.unit_size = 30.0
	_player.max_distance = 1500.0
	_player.volume_db = 4.0
	add_child(_player)


func _process(_delta: float) -> void:
	var helm: Node3D = boat.get("helm")
	position = helm.position + Vector3(0.5, -0.05, 0.05)      # (on the dash, to starboard of the wheel)


func interact(_player_node: Node) -> void:
	if Net.is_host():
		_host_blow()
	else:
		_ask.rpc_id(1)


func interact_prompt() -> String:
	return "Horn"


@rpc("any_peer", "call_remote", "reliable")
func _ask() -> void:
	_host_blow()


func _host_blow() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - _last < AGAIN:
		return
	_last = now
	if Net.in_session():
		_blow.rpc()
	else:
		_blow()


@rpc("authority", "call_local", "reliable")
func _blow() -> void:
	blasts += 1
	_player.play()
	var sides: Array = vs.get("sides")
	if sides.size() != 2:
		return
	var other := (sides[1 - team] as Node).get("boat") as Node3D
	if boat.global_position.distance_to(other.global_position) > NEAR:
		return
	# her crew rattled
	var me: Node = vs.get("sea").get("crew").get("me")
	if me != null and me.get("boat") == other:
		vs.get("contact").call("jolt", 0.7)
	# her lines jerked (each fish's fight is played on one machine: the angler's, or the host's in the holder)
	for r: Node in ((sides[1 - team] as Node).get("rods") as Node).get("rods"):
		if bool(r.get("hooked")) and not bool(r.get("alongside")):
			r.set("whip", 1.0)
			var fight: Object = r.get("fight")
			if fight != null:
				fight.set("shock", maxf(float(fight.get("shock")), SHOCK))


## A twin-tone air horn: two reedy notes a third apart, a hard start, sagging a touch as the can empties.
static func _blast() -> AudioStreamWAV:
	if _sound != null:
		return _sound
	var n := int(LONG * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := [0.0, 0.0]
	for i in n:
		var k := float(i) / float(n)
		var sag := 1.0 - 0.03 * k
		var env := minf(1.0, k * LONG / 0.03) * minf(1.0, (1.0 - k) * LONG / 0.15)
		var v := 0.0
		for j in 2:
			ph[j] = fmod(float(ph[j]) + [311.0, 392.0][j] * sag / RATE, 1.0)
			var p := float(ph[j])
			# (a sawtooth with its top rounded off: brassy, not buzzy)
			v += (p * 2.0 - 1.0) * 0.6 + sin(p * TAU) * 0.4
		data.encode_s16(i * 2, int(clampf(v * 0.35 * env, -1.0, 1.0) * 32000.0))
	_sound = AudioStreamWAV.new()
	_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_sound.mix_rate = RATE
	_sound.data = data
	return _sound
