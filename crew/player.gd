extends Node3D
## One of the crew, first person. The node's name is its peer id and only that peer (the authority) reads input.
##
## You walk in the boat's DECK SPACE (boat/boat.gd): a still physics world with the hull's collider that never
## moves, so `body` there is a plain CharacterBody3D on a level deck, and its position IS your spot on the boat.
## This node, what everyone sees and your camera, is that spot carried by the boat's pose every frame. No sliding,
## no jitter, whatever the sea does; and you lean with the deck while your eyes keep the horizon half level.
##
## Children: Head/Camera3D, Head/Hand (the rod hangs here later). Press E on anything in group "interactable" that
## has interact(player) (and optionally interact_prompt() for the "E: ..." label).
##
## Off the deck (`mode`): your spot is then in `frame`'s space (a boat, or the world: null) and the same smoothing
## and the same word to the others carry it, so nothing jumps whichever frame you're in. Going from one frame into
## another, what you're shown eases over from where the one you were in would have carried you (_hop_*).
##   SWIM   in the sea: afloat at the real waves' height (ocean.gd's height_at, the boats' own), your eyes at the
##          waterline, lifted by each swell a beat late, drifting down wind and off the face of one. WASD swims where you
##          look, in strokes: a pull that surges you on and a glide, your head rising with each pull, the water slapping
##          (and now and then a wave washing over the lens: the visor). Shift sprints, quicker strokes, blowing hard;
##          Ctrl (or C) held dives you under for a few seconds, the murk round you; coming up after it, a gasp. The two
##          share your breath (AIR_*): run it out and you're winded till it's back. You can't jump out: swim to a boat's
##          boarding ladder (boat/ladder.gd) and E, anywhere near its foot. Going in: a splash and a ring of foam.
##   CLIMB  on a ladder: W up it a step at a time, S down, neither and you hang there; at the top over the transom's
##          cap and down onto her deck (any boat's), at the bottom S lets you back into the water, and E lets go where
##          you are. From her deck, E at the top of her ladder takes you over the cap and onto it, going down.
##   AIR    off every boat in the air (her deck space's floor gone from under you: off her side, her transom, her
##          gunwale): falling through the world, going as her deck was going where you left it (her way, her turn,
##          her heave, pitch and roll there: boat/boat.gd's point_velocity) plus your jump. While any of her is still
##          under any of you, you're reckoned over her; clear of her, in the world's frame; come in over any boat
##          and you're in hers (each change eased: _hop_*), and with your middle over her and room for you, into
##          her deck space still falling (DECK, _drop_in): her collider's yours to bump into and come down on, your
##          knees taking the drop, and a deck going by under you faster than your own leap had you going a stumble,
##          skidding over it (_touch_down). Her side below her gunwale bounces you off it; the sea and you're in.
## Her rail's no mode, just her collider (boat/boat.gd's _deck_shape: her liner, her cap, her topsides): on deck a
## jump's a jump, in her deck space. Jump at an edge you're walking into that's within VAULT_HIGH of where you took
## off (her gunwale, the transom, a hatch) and your legs get you up it (_vault_at: up and over the edge, a step on):
## walking, you're stood up on top (on her gunwale, for a harpoon shot); sprinting, straight on over it and off her.
## Up on her gunwale you just stand there, walk along it, jump off it, or step off it, any way; a lurch in a big sea
## can throw you off it, and a hard shove into the rail sends you up it and over.
## Shoving (F, VS's rough stuff, any boat): a windup everyone sees and hears (arms back, a grunt, SHOVE_WINDUP s),
## then a push on whoever's in front of you then (the host says who and how hard): they stagger off across the deck,
## and hit the rail hard enough and they go over it. Braced (a fish on the rod in your hands, the wheel, the chair)
## you're pushed half as far; going over, the rod's left in its holder for the fish to do what it will on it. One
## shove every SHOVE_AGAIN s; not from the water, the ladder or the wheel.

const WALK := 3.0
const SPRINT := 4.6
const JUMP := 4.0
const GRAVITY := 12.0
const ACCEL := 22.0
const AIR_ACCEL := 5.0
const LOOK := 0.0024
const REACH := 2.5
## How much of the boat's pitch and roll your eyes take out (0: the camera is bolted to the deck).
const STEADY := 0.45
## How far you sit down in the fighting chair (m: your hips and eyes drop this much; a seat says its own).
const SEAT_DROP := 0.37
## Into a seat and back up off it (m/s), and how quickly you turn to face its way (1/s).
const SIT_SPEED := 2.6
const SIT_TURN := 5.0

signal prompt_changed(text: String)

const MODEL := preload("res://crew/crew.glb")
const Hands := preload("res://crew/hands.gd")
const Pad := preload("res://core/pad.gd")
## Each crew member's oilskins, by spawn slot order (crew/crew.gd): yellow, orange, green, red.
const OILSKINS: Array[Color] = [Color(0.85, 0.62, 0.08), Color(0.92, 0.38, 0.06), Color(0.18, 0.45, 0.18),
		Color(0.7, 0.12, 0.08)]

var boat: Node3D
## Your body in the deck space: its transform is boat-local.
var body: CharacterBody3D
var head: Node3D
var cam: Camera3D
var hand: Node3D
var body_mesh: MeshInstance3D
## Your kit and what's in your hands (crew/hands.gd), and what a crewmate's peer last said they're holding.
var hands: Hands
var _net_item := ""
## Tests drive the keys without a captured mouse.
var force_input := false
## A fish pulling on the rod in your hands, 0..1 (rods.gd): your view trembles with it and gets tugged toward it.
var shake := 0.0
## A strike on your boat (rods/fight_fx.gd), 0..1: your view punches in and dips toward it, then eases back.
var kick := 0.0
## Slower looking (a little mouse going a long way; 1 as things are).
var look_scale := 1.0
## With a fish on, the mouse is the rod (rods.gd's _aim): it stamps this frame number each frame you fight, and while
## it's fresh your mouse goes to `fight_mouse` (raw px, rods.gd takes it) instead of your look, and your look eases
## toward `cam_goal` (yaw, pitch) where the line goes in. Drop the rod, lose the fish, and it's your look again.
var rod_lease_frame := -10
var fight_mouse := Vector2.ZERO
var cam_goal := Vector2(NAN, NAN)
## At the wheel (boat/helm.gd): your feet stay put and the keys steer her instead. `_helm_to`: the spot at the wheel
## you're stepping into (boat-local; INF: there), `_helm_t` how long you've been at it.
var steering := false
var _helm_to := Vector3.INF
var _helm_t := 0.0
## In a seat (boat/chair.gd says: the fighting chair, a bench, the leaning post...), and which. On the way into it
## and back up off it you're carried there a step at a time (SIT_SPEED: nothing jumps); `_rise_to` is where you're
## getting up to (INF: not). `chair_k`: how far the rod's butt is down in the fighting chair's gimbal (0..1).
var seated := false
var sat_in: Node3D
var _sit_t := 0.0
var _rise_to := Vector3.INF
var chair_k := 0.0
## Up the tuna tower (boat/tower.gd), or on the way up or down it: you look round but don't walk. The climb's legs
## (the tower's path), how far along it you are (s) and which way you're going (1 up, -1 down).
var aloft := false
var _tower: Node3D
var _tower_legs: Array = []
var _tower_t := 0.0
var _tower_way := 1
var _tower_from := Vector3.ZERO
## Hauling something heavy across the deck (a fish on the gaff: boat/fish_hold.gd), 1 .. slower.
var burden := 1.0
var _yaw := 0.0
var _pitch := 0.0
var _prompt := ""
var _prev_local := Vector3.ZERO
var _local := Vector3.ZERO
## A crewmate's last reported spot and look (their own peer moves them), and their words in hand (_state: each
## [their clock (s), spot, yaw, pitch, mode, frame]), the last one played past, and where on their clock we're playing
## them back (_play_net; below zero: not yet), how fast, and how they were going last (here, m/s, their frame).
var _net_at := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _snaps: Array = []
var _snap_was: Array = []
var _play_t := -1.0
var _play_rate := 1.0
var _net_v := Vector3.ZERO
var _send_in := 0
## The crew model's pieces by name, their rest poses, and the walk's phase (_pose_body).
var _parts := {}
var _rest := {}
var _stride := 0.0
var _body_root: Node3D
## What you're doing that the others can't work out for themselves (sent with your spot, ACT_*), and a one-off
## move you're making (gesture(): its name and how far into it you are, s).
const ACT_GLASSES := 1
const ACT_JIG := 2
const ACT_HAUL := 4
const ACT_CRANK := 8
const ACT_TOWER := 16      # (on the tower's ladder or leg, climbing: the others see you climb)
const ACT_RAIL := 32      # (standing up on her gunwale)
const ACT_VAULT := 64     # (getting up over an edge)
var act := 0
var _net_act := 0
var _gesture := ""
var _gesture_t := 0.0
## The face: art/fisherman.py paints FACES expressions side by side on one strip; showing one slides the strip along.
const FACES := ["neutral", "blink", "happy", "shocked", "strain", "tired", "angry", "dizzy", "smug", "sad"]
var _face_mat: BaseMaterial3D
var _face := ""
var _blink_in := 3.0
## The one-off moves and how long each takes (s).
const GESTURES := {"throw": 0.6, "cast": 0.5, "scoop": 0.7, "bleed": 1.1, "reach": 0.5, "stumble": 0.9,
		"shove": 0.65, "drink": 1.8}
var _crank_ph := 0.0
var _haul_ph := 0.0
## The deck dropping out from under you (a big sea): its heave, how fast, and when you last lost your feet.
var _deck_y := 0.0
var _deck_vy := 0.0
var _stumble_in := 0.0
## How hard a lurch has to be (m/s, the deck's heave changing that much in a tenth of a second) to throw you.
const LURCH := 2.2

## Where you are (see the top): on deck (or up on her gunwale, or falling in her deck space), in the sea, up a
## ladder, in the air.
enum { DECK, SWIM, CLIMB, AIR }
const Voice := preload("res://crew/voice.gd")
const Splash := preload("res://sea/splash.gd")
const Sfx := preload("res://audio/sfx.gd")
const WHOOSH := preload("res://audio/fish/whoosh.wav")
## Afloat: your feet this far under the surface (your eyes at the waterline); swimming, flat out with Shift (m/s: a
## boat goes four times that, so a swim's to her ladder, not a chase after her), how quickly you get going, the sea's
## spring and its damping (your bob lagging the waves), your drift down wind (m/s) and off a slope (m/s per unit).
const FLOAT := 1.42
const SWIM_SPEED := 1.5
const SWIM_FAST := 2.4
const SWIM_ACCEL := 5.0
const BUOY := 22.0
const BUOY_DAMP := 7.5
const DRIFT := 0.2
const SLIDE := 0.9
## Strokes a second (sprinting; treading water, this much of it); how much of your way comes in the pull (the rest
## carries you on between); your head's rise on a pull (m).
const STROKE := 0.95
const STROKE_FAST := 1.45
const TREAD := 0.45
const SURGE := 0.55
const BOB := 0.05
## Diving (Ctrl or C, held): how far under you go (m), how much slower you swim there, the sea's spring on you this
## much softer. Your breath: s of it under, s of sprinting flat out, s to get it all back; winded (run out) till this
## much is back.
const DIVE := 1.7
const DIVE_SLOW := 0.7
const DIVE_SPRING := 0.45
const AIR_UNDER := 5.0
const AIR_SPRINT := 8.0
const AIR_BACK := 4.0
const WINDED := 0.4
## E for a ladder from the water this near its foot (m), or from her deck this near where you'd step off it.
const GRAB := 1.8
const GRAB_DECK := 1.2
## A swimmer is kept this far off any hull (m).
const SWIMMER := 0.35
## A jump's push the way you're going (m/s, at most, on top of the way you had: your legs drive you off, so a
## standing leap off her gunwale goes as far as a running one).
const JUMP_PUSH := 4.6
## Getting up an edge you jump at (_vault_at): no higher than this over where you took off (m: her gunwale's 0.7 to
## 0.9 over her deck), with this much to spare over it walking (m) and this much sprinting, straight on over; at
## most this long (s), coming in to stand over it this quickly (1/s). Stood up on it, a held key doesn't walk you
## straight off the far side for this long (s: finding your feet).
const VAULT_HIGH := 1.05
const VAULT_CLEAR := 0.14
const VAULT_OVER := 0.5
const VAULT_TIME := 0.7
const VAULT_PULL := 9.0
const VAULT_FEET := 0.45
## Up on her gunwale: you're there when this far out past you (m) there's nothing of her under it; a lurch has to be
## this much harder than LURCH to throw you off it.
const RAIL_OUT := 0.45
const RAIL_LURCH := 1.25
## Down on a deck out of the air: of your leap's way over her you keep this much (a step or two on, slowing as you
## walk would); her deck going by under you this much faster (m/s) than your own leap had you going over it and you
## stumble, your feet skidding over it, slowing this much (m/s each s). Your knees take this much of how fast you
## came down (your eyes going on down and springing back up, a spring this stiff, 1/s²).
const LAND_KEEP := 0.7
const LAND_STUMBLE := 1.2
const LAND_DRAG := 12.0
const KNEES := 1.0
const KNEES_SPRING := 60.0
## Into another frame: the step between where you were shown and where you're shown now eases away (a spring, so it
## comes on gently too) no quicker than this (s), and slower the bigger it is, so as never to be taken up harder than
## HOP_ACCEL (m/s²); her tilt (s).
const HOP_EASE := 0.06
const HOP_ACCEL := 15.0
const HOP_TILT := 0.3
## The shove: how far you reach (m), the windup (s), how often (s), the push (m/s across, up), how much of it a braced
## one takes, how fast a pushed one slows (m/s each s: their feet dragging), how long they've no say in it (s), and how
## hard into a rail tips them over it (m/s).
const SHOVE_REACH := 1.6
const SHOVE_WINDUP := 0.4
const SHOVE_AGAIN := 6.0
const SHOVE_PUSH := 4.4
const SHOVE_LIFT := 1.2
const BRACED := 0.5
const KNOCK_DRAG := 5.0
const KNOCK := 0.7
const OVER_SPEED := 1.4
## How long after a shove lands a rival in the sea still counts as you putting them there (s).
const OVERBOARD_IN := 2.5
## A crewmate's word on where they are is played back this far behind their own clock (s: a few of their words in
## hand, so one coming late or two at once doesn't show); the playback goes faster or slower to keep there (their
## clock and ours needn't go at the same rate), by this much for each s it's out, between these, easing to it (1/s);
## past their last word they're carried on the way they were going at most this long (s).
const NET_DELAY := 0.1
const NET_KEEP := 3.0
const NET_RATE := Vector2(0.5, 2.0)
const NET_EASE := 4.0
const NET_ON := 0.2

var mode := DECK
## The space your spot's in: a boat (the one you're aboard, or whose ladder you're on, or you leapt off and are still
## in the air over) or null, the world (swimming).
## `boat` is the boat you're on or were last; `home` your crew's (crew/crew.gd: VS's team, else the one boat).
var frame: Node3D
var home: Node3D
## Swimming: your way through the water (world, m/s); in it yet; your eyes under it (for the gasp coming up); the
## stroke (0..1 round, every peer's own: a slap of water each time round) and strokes made; your breath (1 full) and
## winded (run out of it); the lens's clearance over the water lately (a wave over it), the murk in your eyes under,
## and whether the visor's showing for the sea on the lens.
var _swim_v := Vector3.ZERO
var _wet := false
var _under := false
var _in_for := 0.0
var _stroke := 0.0
var _stroke_was := 0.0
var strokes := 0
var _breath := 1.0
var _winded := false
var _clear := 1.0
var _murk: ColorRect
var _deep: Environment
var _lens := false
## On a ladder: the boat's ladder, where you took hold, the legs of the climb (boat/ladder.gd's path), how far along
## them (s of climbing), which way you last went (+1 up), and the arms' and legs' phase.
var _ladder: Node3D
var _climb_from := Vector3.ZERO
var _climb_legs: Array = []
var _climb_t := 0.0
var _climb_way := 1
var _climb_ph := 0.0
## Tests climb without holding W.
var force_climb := false
## Jumping on her deck: the height you took off from (her space) and s since. Up an edge (_vault_at): s left of it,
## the spot over the edge you're coming in to (her space, flat), the edge's top, your way over it (her space, flat)
## and whether it's straight on over; s left finding your feet up there.
var _jump_y := 0.0
var _jump_t := INF
var _vault_t := 0.0
var _vault_to := Vector3.ZERO
var _vault_top := 0.0
var _vault_v := Vector3.ZERO
var _vault_over := false
var _feet_t := 0.0
## In the air: your way (world, m/s), and how long since you left her (s).
var _air_v := Vector3.ZERO
var _air_t := 0.0
## Your own leap (world, m/s: the part of your way in the air that isn't her deck's); the way of the frame you're
## reckoned in, where you are over it (_air_to). Down off it: s left skidding over her deck; your knees giving (m
## your eyes are down, m/s, and what was shown of it), and where you were last shown (your frame) and how fast you
## were coming down (m/s), for your knees to take it when your feet stop.
var _air_push := Vector3.ZERO
var _air_carry := Vector3.ZERO
## Come in over a boat out of the air and into her deck space, still falling (_drop_in): of your way over her, your
## own leap's part and her deck going by under you (her space, flat), for when your feet find her (_touch_down).
var _dropping := false
var _drop_push := Vector3.ZERO
var _drop_slip := Vector3.ZERO
var _skid := 0.0
var _knees := 0.0
var _knees_v := 0.0
var _knees_shown := 0.0
var _shown_at := Vector3.ZERO
var _shown_vy := 0.0
## Going into another frame (or put down off where you'd have been): the frame you were in, its pose and the new
## one's, your spot in the world then, and the tick (_hop_mark); left to square with where you are now (end of that
## tick), and to carry on as she'd have carried you (the next frame drawn); then what's left to ease away, in your
## frame (m), and her tilt.
var _hop_from: Node3D
var _hop_from_xf := Transform3D.IDENTITY
var _hop_to_xf := Transform3D.IDENTITY
var _hop_w := Vector3.ZERO
var _hop_tick := -1
var _hop_settle := false
var _hop_carry := false
## (in the air, your own: the carry's where you are from then on, nothing to ease: _process)
var _hop_bake := false
var _hop_off := Vector3.ZERO
var _hop_off_v := Vector3.ZERO
## (of it, the part that's a spot squared up, not a frame's way: what the others are told, as they ease their own)
var _hop_fix := Vector3.ZERO
var _hop_fix_v := Vector3.ZERO
var _hop_tilt := Quaternion.IDENTITY
## Steadying your aim (the harpoon, right mouse: tuna/landing.gd sets it), 0..1: your view closes in and your look
## goes slower.
var steady := 0.0
## Shoved: s left with no say in where your feet go.
var _knock := 0.0
## When you can shove again (your own clock, and the host's for you), and shoves made (the tests count them).
var _shove_at := -INF
var _host_shove_at := -INF
var shoves := 0
## Going from one frame to another, your eyes ease from where they were (0 .. 1 over a moment).
var _eyes_from := Basis.IDENTITY
var _eyes_k := 1.0
var _splash: Splash
var _voice: AudioStreamPlayer3D
var _swish: AudioStreamPlayer3D
## Splashes made going in and gasps coming up (the tests count them).
var splashes := 0
var gasps := 0


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int() if str(name).is_valid_int() else 1)


func _ready() -> void:
	add_to_group("players")
	body = CharacterBody3D.new()
	body.name = "Crew_" + str(name)
	body.floor_stop_on_slope = true
	body.floor_max_angle = deg_to_rad(50.0)
	body.floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.75
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.875
	body.add_child(cs)
	(boat.get("deck_root") as Node3D).add_child(body)
	frame = boat
	if home == null:
		home = boat
	_splash = Splash.new()
	_splash.name = "Splash"
	add_child(_splash)
	_voice = AudioStreamPlayer3D.new()
	_voice.position.y = 1.55
	_voice.unit_size = 4.0
	_voice.max_distance = 60.0
	add_child(_voice)
	_swish = AudioStreamPlayer3D.new()
	_swish.stream = WHOOSH
	_swish.position.y = 1.2
	_swish.unit_size = 3.0
	_swish.max_distance = 40.0
	add_child(_swish)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = 1.62
	add_child(head)
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = Settings.fov
	cam.near = 0.05
	cam.far = 6000.0
	head.add_child(cam)
	hand = Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0.28, -0.32, -0.45)
	head.add_child(hand)
	# What the others see: a deckhand in oilskins (art/crew.py), in pieces that swing at the joints
	_build_body()
	hands = Hands.new()
	hands.name = "Hands"
	hands.player = self
	add_child(hands)
	if is_multiplayer_authority():
		for part: MeshInstance3D in _parts.values():
			part.layers = 1 << 19      # layer 20: your own camera leaves it out, it still casts your shadow
		cam.cull_mask &= ~(1 << 19)
		cam.make_current()
		# under the sea, your eyes in the murk (over the 3D, under the visor's water and the HUD)
		var murk := CanvasLayer.new()
		murk.layer = -2
		add_child(murk)
		_murk = ColorRect.new()
		_murk.set_anchors_preset(Control.PRESET_FULL_RECT)
		_murk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_murk.color = Color(0.03, 0.19, 0.21, 0.0)
		_murk.visible = false
		murk.add_child(_murk)
		if not _at_dock():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The crew model's pieces (torso, head, arms, legs) under one node that turns with you; your oilskins in your colour.
func _build_body() -> void:
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	var src := MODEL.instantiate() as Node3D
	var colour := OILSKINS[_slot() % OILSKINS.size()]
	for n: String in ["torso", "head", "arm_l", "arm_r", "fore_l", "fore_r", "leg_l", "leg_r", "shin_l", "shin_r"]:
		var mi := src.find_child(n, true, false) as MeshInstance3D
		if mi == null:
			continue
		var t := mi.transform
		mi.owner = null
		mi.get_parent().remove_child(mi)
		mi.transform = t
		root.add_child(mi)
		_parts[n] = mi
		_rest[n] = t.basis
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if not m is BaseMaterial3D:
				continue
			# (art/fisherman.py's atlas is pixel art: crisp texels, as the space fishing game draws its crew)
			var own := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			own.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			if m.resource_name == "oilskin":
				own.albedo_color = colour
			if m.resource_name == "face":
				_face_mat = own
			mi.set_surface_override_material(i, own)
	src.free()
	# the joints: head and arms ride the torso, forearms the arms, shins the thighs. (Each worked out from where the
	# pieces sit in the model, before any is moved: an arm already hung on the torso has a torso-local transform, and
	# a forearm worked out against that sat 0.92 m too high, up beside the head.)
	var where := {}
	for n: String in _parts:
		where[n] = (_parts[n] as Node3D).transform
	for pair: Array in [["head", "torso"], ["arm_l", "torso"], ["arm_r", "torso"], ["fore_l", "arm_l"],
			["fore_r", "arm_r"], ["shin_l", "leg_l"], ["shin_r", "leg_r"]]:
		var c := _parts.get(pair[0]) as Node3D
		var to := _parts.get(pair[1]) as Node3D
		if c == null or to == null:
			continue
		var t := (where[pair[1]] as Transform3D).affine_inverse() * (where[pair[0]] as Transform3D)
		c.get_parent().remove_child(c)
		to.add_child(c)
		c.transform = t
		_rest[pair[0]] = t.basis
	_body_root = root
	body_mesh = _parts.get("torso") as MeshInstance3D


## Which crew member you are, for your oilskins' colour (crew/crew.gd's spawn slot; 0 alone).
func _slot() -> int:
	var crew := get_parent()
	var slots: Variant = crew.get("slots") if crew else null
	if slots is Dictionary and (slots as Dictionary).has(str(name).to_int()):
		return int((slots as Dictionary)[str(name).to_int()])
	return 0


## The body going with what you're doing, worked out the same on every peer from what everyone knows (the rods,
## the wheel, the harpoon) and what you send (`act`, gestures): walking and running (legs and arms swinging, knees
## and elbows bending, a bob), standing easy with the sea (breathing, knees soft), a rod in your hands (cranking:
## the reel arm going round; pumping: leaning back and dropping; braced against a run), the wheel (hands working it
## as she turns), the harpoon (cocked, and the throw), hauling (leaning back, hand over hand), the jig,
## a scoop of chum, bleeding a fish, a stumble when she slams a wave. Pieces turn about x (forward, + raises a
## limb in front / bends an elbow; a knee bends with -), y (twist) and z (out to the side).
func _pose_body(delta: float) -> void:
	if _parts.is_empty():
		return
	var t := Time.get_ticks_msec() * 0.001
	var moved := (_local - _prev_local) * float(Engine.physics_ticks_per_second)    # (a physics tick's step)
	var pace := clampf(Vector2(moved.x, moved.z).length() / SPRINT, 0.0, 1.0)
	_stride += delta * (2.0 + 9.0 * pace)
	var swing := sin(_stride) * 0.75 * pace
	var sea: Node = boat.get("sea") if boat else null
	var id := str(name).to_int()
	var rods: Node = sea.get("rods") if sea else null
	var landing: Node = sea.get("landing") if sea else null
	var helm: Node = boat.get("helm") if boat else null
	var rod: Node = rods.call("held_by", id) if rods else null
	var harpoon: bool = landing != null and int(landing.get("harpoon_holder")) == id
	var doing := act if is_multiplayer_authority() else _net_act
	if _gesture != "":
		_gesture_t += delta
		if _gesture_t > float(GESTURES.get(_gesture, 0.5)):
			_gesture = ""
	# standing easy: knees soft, a breath, the arms hanging a touch forward; walking over that
	var breath := sin(t * 1.7) * 0.02
	var p := {
		"torso": Vector3(-0.04 * pace + breath, sin(_stride) * 0.1 * pace, 0.0),
		"head": Vector3(clampf(_pitch * 0.6, -0.5, 0.6), 0.0, 0.0),
		"arm_l": Vector3(0.08 - swing * 0.7, 0.0, -0.06), "fore_l": Vector3(0.2 + 0.4 * pace, 0.0, 0.0),
		"arm_r": Vector3(0.08 + swing * 0.7, 0.0, 0.06), "fore_r": Vector3(0.2 + 0.4 * pace, 0.0, 0.0),
		"leg_l": Vector3(swing, 0.0, 0.0), "shin_l": Vector3(-0.08 - maxf(0.0, -sin(_stride)) * 1.1 * pace, 0.0, 0.0),
		"leg_r": Vector3(-swing, 0.0, 0.0), "shin_r": Vector3(-0.08 - maxf(0.0, sin(_stride)) * 1.1 * pace, 0.0, 0.0),
	}
	var drop := absf(sin(_stride)) * 0.035 * pace
	var crouch := 0.0
	if rod != null:
		# both hands on it: the left out on the foregrip, the right on the reel
		var lift := float(rod.get("lift")) + float(rod.get("wind")) * 0.8     # (a pump, or winding up a cast)
		var strain := float(rod.get("strain")) if bool(rod.get("hooked")) else 0.0
		var back := 0.12 + 0.3 * strain + 0.35 * lift          # leaning back into it
		p["torso"] = Vector3(back, -0.3 * float(rod.get("wind")), 0.0)
		p["arm_l"] = Vector3(0.95 + 0.6 * lift, 0.25, -0.1)
		p["fore_l"] = Vector3(0.7, 0.0, 0.0)
		p["arm_r"] = Vector3(0.55 + 0.4 * lift, -0.15, 0.15)
		p["fore_r"] = Vector3(1.15, 0.0, 0.0)
		if doing & ACT_CRANK:
			_crank_ph += delta * 13.0
			p["arm_r"] += Vector3(sin(_crank_ph) * 0.18, 0.0, cos(_crank_ph) * 0.1)
			p["fore_r"] += Vector3(cos(_crank_ph) * 0.35, 0.0, 0.0)
		crouch = 0.08 + 0.12 * strain + 0.1 * lift            # knees bent, braced
	elif harpoon:
		# the harpoon cocked over the shoulder, the off hand pointing; the throw: the arm whips through
		p["arm_l"] = Vector3(1.1, 0.3, -0.1)
		p["fore_l"] = Vector3(0.3, 0.0, 0.0)
		p["arm_r"] = Vector3(2.7, 0.0, 0.25)
		p["fore_r"] = Vector3(1.3, 0.0, 0.0)
		p["torso"] = Vector3(0.08, -0.25, 0.0)
	elif steering:
		# both hands on the wheel, working it as she turns (low on its rim, elbows bent: not up in the dash's screens)
		var steer := float(helm.get("steer")) if helm else 0.0
		p["arm_l"] = Vector3(0.55 + steer * 0.2, 0.0, -0.12)
		p["fore_l"] = Vector3(0.85, 0.0, 0.0)
		p["arm_r"] = Vector3(0.55 - steer * 0.2, 0.0, 0.12)
		p["fore_r"] = Vector3(0.85, 0.0, 0.0)
		p["torso"] = Vector3(-0.04, steer * 0.12, 0.0)
	if hands != null and not hands.stowed() and hands.shown_item() != "":
		# something of the kit in your right hand, held out in front
		p["arm_r"] = Vector3(0.45, 0.0, 0.1)
		p["fore_r"] = Vector3(1.15, 0.0, 0.0)
	if doing & ACT_HAUL:
		# leaning back on it, hand over hand
		_haul_ph += delta * 4.5
		var heave := sin(_haul_ph)
		p["torso"] = Vector3(0.3 + 0.12 * heave, 0.0, 0.0)
		p["arm_l"] = Vector3(0.9 + 0.35 * heave, 0.0, -0.05)
		p["fore_l"] = Vector3(0.5 - 0.3 * heave, 0.0, 0.0)
		p["arm_r"] = Vector3(0.9 - 0.35 * heave, 0.0, 0.05)
		p["fore_r"] = Vector3(0.5 + 0.3 * heave, 0.0, 0.0)
		crouch = 0.22
	if doing & ACT_JIG:
		# working the jig rod up and down
		p["arm_r"] = Vector3(0.9, 0.0, 0.3)
		p["fore_r"] = Vector3(0.7 + sin(t * 5.0) * 0.45, 0.0, 0.0)
		p["arm_l"] = Vector3(0.6, 0.2, -0.05)
		p["fore_l"] = Vector3(0.9, 0.0, 0.0)
	# the one-off moves, over whatever else
	if _gesture != "":
		var gk := clampf(_gesture_t / float(GESTURES[_gesture]), 0.0, 1.0)
		var arc := sin(gk * PI)              # 0 -> 1 -> 0 over the move
		match _gesture:
			"throw":
				# wound back, then whipped through, leaning into it
				var whip := smoothstep(0.15, 0.45, gk)
				p["arm_r"] = Vector3(lerpf(2.9, 0.7, whip), 0.0, 0.2)
				p["fore_r"] = Vector3(lerpf(1.5, 0.1, whip), 0.0, 0.0)
				p["torso"] = Vector3(lerpf(0.15, -0.3, whip) * (1.0 - smoothstep(0.7, 1.0, gk)), -0.3 * (1.0 - whip), 0.0)
			"cast":
				# the rod brought over hard from behind the shoulder, leaning into it
				var through := smoothstep(0.0, 0.5, gk)
				p["torso"] = Vector3(lerpf(0.25, -0.3, through) * (1.0 - smoothstep(0.6, 1.0, gk)), 0.0, 0.0)
				p["arm_l"] = Vector3(lerpf(2.0, 0.9, through), 0.25, -0.1)
				p["arm_r"] = Vector3(lerpf(1.6, 0.5, through), -0.15, 0.15)
			"scoop":
				# down to the bucket, then flung out over the side
				var fling := smoothstep(0.35, 0.7, gk)
				p["arm_r"] = Vector3(lerpf(0.2, 2.0, fling), 0.0, 0.2)
				p["fore_r"] = Vector3(lerpf(0.9, 0.2, fling), 0.0, 0.0)
				p["torso"] = Vector3(-0.35 * arc, -0.35 * (fling - 0.5), 0.0)
				crouch = maxf(crouch, 0.2 * (1.0 - fling))
			"bleed":
				# down on one knee, the knife in, out
				crouch = maxf(crouch, 0.45 * arc)
				p["torso"] = Vector3(-0.5 * arc, 0.0, 0.0)
				p["arm_r"] = Vector3(0.9 + 0.3 * sin(gk * 18.0) * arc, 0.0, 0.1)
				p["fore_r"] = Vector3(0.6, 0.0, 0.0)
			"drink":
				# the can up to your mouth, head tipped back for a long swig
				var up := smoothstep(0.0, 0.25, gk) * (1.0 - smoothstep(0.8, 1.0, gk))
				p["arm_r"] = Vector3(0.1 + 1.25 * up, 0.0, 0.1 + 0.25 * up)
				p["fore_r"] = Vector3(0.3 + 1.8 * up, 0.0, 0.0)
				p["head"] = Vector3(-0.35 * up, 0.0, 0.0)
				p["torso"] = Vector3(-0.08 * up, 0.0, 0.0)
			"reach":
				p["arm_r"] = Vector3(1.1 * arc + 0.1, 0.0, 0.1)
				p["fore_r"] = Vector3(0.3, 0.0, 0.0)
				p["torso"] = Vector3(-0.2 * arc, 0.0, 0.0)
			"stumble":
				# thrown off balance: arms out, a lurch
				p["arm_l"] = Vector3(0.6 * arc, 0.0, -1.1 * arc)
				p["arm_r"] = Vector3(0.6 * arc, 0.0, 1.1 * arc)
				p["torso"] = Vector3(-0.25 * arc, 0.0, 0.15 * sin(gk * 9.0) * arc)
				crouch = maxf(crouch, 0.15 * arc)
			"shove":
				# drawn back (arms cocked at the chest, twisted away, leaning back), then both hands driven out
				var wound := gk / (SHOVE_WINDUP / float(GESTURES["shove"]))
				var out := smoothstep(1.0, 1.35, wound) * (1.0 - smoothstep(0.85, 1.0, gk))
				var back := minf(wound, 1.0) * (1.0 - smoothstep(1.0, 1.2, wound))
				p["torso"] = Vector3(0.15 * back - 0.3 * out, 0.4 * back, 0.0)
				p["arm_l"] = Vector3(lerpf(0.3, 1.5, out) - 0.5 * back, 0.3 * back, -0.25 * back)
				p["arm_r"] = Vector3(lerpf(0.3, 1.5, out) - 0.5 * back, -0.3 * back, 0.25 * back)
				p["fore_l"] = Vector3(lerpf(1.6, 0.15, out), 0.0, 0.0)
				p["fore_r"] = Vector3(lerpf(1.6, 0.15, out), 0.0, 0.0)
				p["leg_l"] = Vector3(0.35 * out, 0.0, 0.0)
				p["leg_r"] = Vector3(-0.3 * out, 0.0, 0.0)
				crouch = maxf(crouch, 0.12 * back)
	# off the deck: treading water, up a ladder (or the tower), over a rail
	var pose_mode := CLIMB if mode == DECK and doing & ACT_TOWER else mode
	match pose_mode:
		SWIM:
			# treading water: arms sculling out to the sides, legs kicking, leaning into a stroke (in time with it)
			var ph := _stroke * TAU
			p["torso"] = Vector3(-0.25 * pace + 0.05 * sin(ph * 0.5), 0.0, 0.0)
			p["head"] = Vector3(clampf(_pitch * 0.6, -0.3, 0.6) + 0.25 * pace, 0.0, 0.0)
			p["arm_l"] = Vector3(0.6 + 0.9 * pace + 0.25 * sin(ph), 0.2 * cos(ph), -0.9 + 0.3 * sin(ph))
			p["arm_r"] = Vector3(0.6 + 0.9 * pace + 0.25 * sin(ph + PI), -0.2 * cos(ph), 0.9 - 0.3 * sin(ph))
			p["fore_l"] = Vector3(0.5 + 0.2 * cos(ph), 0.0, 0.0)
			p["fore_r"] = Vector3(0.5 - 0.2 * cos(ph), 0.0, 0.0)
			p["leg_l"] = Vector3(0.3 + 0.35 * sin(ph * 1.4), 0.0, -0.08)
			p["leg_r"] = Vector3(0.3 - 0.35 * sin(ph * 1.4), 0.0, 0.08)
			p["shin_l"] = Vector3(-0.6 - 0.3 * cos(ph * 1.4), 0.0, 0.0)
			p["shin_r"] = Vector3(-0.6 + 0.3 * cos(ph * 1.4), 0.0, 0.0)
			drop = 0.0
			crouch = 0.0
		CLIMB:
			# hand over hand up the rails, a foot up a step at a time (the phase goes with how fast you're rising)
			_climb_ph += delta * clampf(absf(moved.y), 0.0, 2.0) * 7.0
			var c := sin(_climb_ph)
			p["torso"] = Vector3(-0.15, 0.0, 0.0)
			p["head"] = Vector3(clampf(_pitch * 0.6, -0.5, 0.6), 0.0, 0.0)
			p["arm_l"] = Vector3(2.2 + 0.45 * c, 0.0, -0.12)
			p["arm_r"] = Vector3(2.2 - 0.45 * c, 0.0, 0.12)
			p["fore_l"] = Vector3(0.5 - 0.4 * c, 0.0, 0.0)
			p["fore_r"] = Vector3(0.5 + 0.4 * c, 0.0, 0.0)
			p["leg_l"] = Vector3(0.7 + 0.55 * c, 0.0, -0.06)
			p["leg_r"] = Vector3(0.7 - 0.55 * c, 0.0, 0.06)
			p["shin_l"] = Vector3(-1.0 - 0.5 * c, 0.0, 0.0)
			p["shin_r"] = Vector3(-1.0 + 0.5 * c, 0.0, 0.0)
			drop = 0.0
			crouch = 0.0
		AIR:
			# knees tucked, arms out for the landing (thrown off: flung out)
			var flail := 1.0 if _gesture == "stumble" else 0.0
			p["torso"] = Vector3(-0.35, 0.0, 0.2 * flail)
			p["arm_l"] = Vector3(lerpf(1.2, 0.8, flail), 0.0, lerpf(-0.1, -1.4, flail))
			p["arm_r"] = Vector3(lerpf(0.9, 0.8, flail), 0.0, lerpf(0.1, 1.4, flail))
			p["leg_l"] = Vector3(1.1, 0.0, 0.0)
			p["leg_r"] = Vector3(0.8, 0.0, 0.0)
			p["shin_l"] = Vector3(-1.6, 0.0, 0.0)
			p["shin_r"] = Vector3(-1.3, 0.0, 0.0)
			drop = 0.0
			crouch = 0.0
	# up on her gunwale: the off arm out a little for balance, knees soft; getting up an edge, a knee lifted
	if doing & (ACT_RAIL | ACT_VAULT) and mode == DECK:
		var up := 1.0 if doing & ACT_VAULT else 0.0
		p["arm_l"] = (p["arm_l"] as Vector3) + Vector3(0.0, 0.0, -0.5)
		p["leg_l"] = Vector3(1.0 * up, 0.0, 0.0)
		p["shin_l"] = Vector3(-1.4 * up - 0.1, 0.0, 0.0)
		crouch = maxf(crouch, 0.06 + 0.1 * up)
	# in a seat: sat down, thighs out level, shins hanging to the footrest; on a leaning post, leant back on it, a
	# little down, legs out in front
	if seated and _seat_lean():
		p["leg_l"] += Vector3(0.25, 0.0, 0.0)
		p["leg_r"] += Vector3(0.25, 0.0, 0.0)
		p["torso"] += Vector3(-0.12, 0.0, 0.0)
		drop = _seat_drop()
		crouch = 0.0
	elif seated:
		p["leg_l"] = Vector3(1.45, 0.0, -0.08)
		p["leg_r"] = Vector3(1.45, 0.0, 0.08)
		p["shin_l"] = Vector3(-1.35, 0.0, 0.0)
		p["shin_r"] = Vector3(-1.35, 0.0, 0.0)
		drop = _seat_drop()
		crouch = 0.0
	crouch = maxf(crouch, _knees * 1.5)       # (down out of the air: knees giving)
	# crouching: down at the hips, thighs forward and shins back so the feet stay put
	if crouch > 0.0:
		var bend := acos(clampf(1.0 - crouch / 0.95 * 1.6, -1.0, 1.0)) * 0.6
		p["leg_l"] += Vector3(bend, 0.0, 0.0)
		p["leg_r"] += Vector3(bend, 0.0, 0.0)
		p["shin_l"] += Vector3(-bend * 2.0, 0.0, 0.0)
		p["shin_r"] += Vector3(-bend * 2.0, 0.0, 0.0)
		p["torso"] += Vector3(-bend * 0.6, 0.0, 0.0)
	var k := minf(1.0, delta * 14.0)
	for part: String in p:
		_aim(part, p[part], k)
	if _body_root:
		_body_root.position.y = lerpf(_body_root.position.y, -drop - crouch * 0.55, k)
	_show_face(_face_for(rod, helm, harpoon, id, sea), delta)


## The face for what you're doing (everyone works it out the same way from what they all know): dizzy when the deck
## throws you, wide-eyed when the reel screams or the line's near breaking, gritting your teeth through a fight,
## set on the harpoon, smug at the wheel, chuffed with a fish on deck, glum in a storm, knackered at dusk.
func _face_for(rod: Node, helm: Node, harpoon: bool, id: int, sea: Node) -> String:
	if _gesture == "stumble" or (mode == SWIM and _in_for < 1.5) or _under:
		return "dizzy" if _gesture == "stumble" else "shocked"
	if mode != DECK:
		return "strain"
	if _gesture == "throw" or _gesture == "shove" or harpoon:
		return "angry"
	if rod != null and bool(rod.get("hooked")):
		if str(rod.get("move")) == "run" or float(rod.get("strain")) > 0.85:
			return "shocked"
		return "strain"
	if helm != null and int(helm.get("captain")) == id:
		return "smug"
	var hold: Node = sea.get("fish_hold") if sea else null
	if hold != null and not (hold.get("_deck") as Dictionary).is_empty():
		return "happy"
	if sea != null and str(sea.get("condition")) in ["storm", "heavy"]:
		return "sad"
	if hold != null and float(hold.call("day_fraction")) > 0.85:
		return "tired"          # (a long day: dusk, and after)
	return "neutral"


## Slides the face strip to `want`, blinking every few seconds when the face is a calm one.
func _show_face(want: String, delta: float) -> void:
	if _face_mat == null:
		return
	_blink_in -= delta
	if _blink_in < 0.0 and want in ["neutral", "smug", "sad", "angry"]:
		want = "blink"
		if _blink_in < -0.13:
			_blink_in = randf_range(2.5, 5.0)
	if want == _face:
		return
	_face = want
	_face_mat.uv1_offset.x = float(FACES.find(want)) / float(FACES.size())


## One piece toward its pose (x, y, z: euler, radians), `k` of the way there this frame.
func _aim(part: String, e: Vector3, k: float) -> void:
	var piece := _parts.get(part) as Node3D
	if piece:
		piece.basis = piece.basis.slerp(Basis.from_euler(e) * (_rest[part] as Basis), k)


## A one-off move (GESTURES: the harpoon's throw, a scoop of chum, bleeding a fish, a reach, a stumble): yours, and
## everyone sees it.
func gesture(g: String) -> void:
	if not is_multiplayer_authority():
		return
	if Net.in_session():
		_play_gesture.rpc(g)
	else:
		_play_gesture(g)


@rpc("authority", "call_local", "reliable")
func _play_gesture(g: String) -> void:
	if GESTURES.has(g):
		_gesture = g
		_gesture_t = 0.0


func _exit_tree() -> void:
	if is_instance_valid(body):
		body.queue_free()


## Back aboard after a drop (crew/crew.gd): your oilskins fade in where you stand over `s` s, no pop.
func fade_in(s: float) -> void:
	var tw := create_tween().set_parallel()
	for part: MeshInstance3D in _parts.values():
		part.transparency = 1.0
		tw.tween_property(part, "transparency", 0.0, s).set_trans(Tween.TRANS_SINE)


## Puts you at a boat-local spot, facing `yaw` (radians round the boat's up axis; 0 faces the bow): on `on`'s deck
## (crew/crew.gd's spawn: your own boat), else the one you're on.
func place(local: Vector3, yaw: float, on: Node3D = null) -> void:
	if on == null and frame == null:
		on = boat
	if on != null and on != frame:
		_set_frame(on)
	if mode != DECK:
		_set_mode(DECK)
	aloft = false
	_tower_legs = []
	_rise_to = Vector3.INF
	_helm_to = Vector3.INF
	_vault_t = 0.0
	_feet_t = 0.0
	_jump_t = INF
	_dropping = false
	body.position = local
	body.velocity = Vector3.ZERO
	_prev_local = local
	_local = local
	_net_at = local
	_yaw = yaw
	_net_yaw = yaw
	_snaps.clear()
	_snap_was = []
	_play_t = -1.0
	_hop_clear()


func local_position() -> Vector3:
	return body.position


## Mouse look comes first, before any UI could take the motion.
func _input(event: InputEvent) -> void:
	if is_multiplayer_authority() and event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		if leased():
			fight_mouse += m.relative * look_scale
			return
		look(m.relative)


## Turns your head by a mouse move (px), with the player's own feel (core/settings.gd's sensitivity and invert Y; the
## pad's own, `pad`).
func look(relative: Vector2, pad := false) -> void:
	var k := LOOK * look_scale * (Settings.pad_sensitivity if pad else Settings.sensitivity) * (1.0 - 0.45 * steady)
	var flip := Settings.pad_invert_y if pad else Settings.invert_y
	_yaw -= relative.x * k
	_pitch = clampf(_pitch - relative.y * k * (-1.0 if flip else 1.0), -1.45, 1.45)


## The right stick (core/pad.gd's curve), as so many px of mouse this frame: your look, or the rod with a fish on.
func _pad_look(delta: float) -> void:
	if not (force_input or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		return
	var v := Pad.look_stick()
	if v == Vector2.ZERO:
		return
	var px := v * Pad.LOOK_PX * delta
	if leased():
		fight_mouse += px * look_scale * Settings.pad_sensitivity * Vector2(1.0, -1.0 if Settings.pad_invert_y else 1.0)
	else:
		look(px, true)


## The rod has your mouse (rods.gd stamped it this frame or the last: input comes before its _process).
func leased() -> bool:
	return Engine.get_process_frames() - rod_lease_frame <= 1


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _at_dock():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("shove"):
		shove()
	elif mode != DECK:
		# in the sea the only thing to put your hands on is a ladder; on one, E lets go
		if event.is_action_pressed("interact") and mode == SWIM:
			var target := _target()
			if target and target.is_in_group("ladders"):
				target.call("interact", self)
		elif event.is_action_pressed("interact") and mode == CLIMB:
			_let_go_ladder()
	elif event.is_action_pressed("interact") and steering:
		(boat.get("helm") as Node).call("request", false)
	elif aloft and (event.is_action_pressed("interact") or event.is_action_pressed("drop")):
		climb_down_tower()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and seated and _gets_you_up(_looked_at()):
		if is_instance_valid(sat_in):
			sat_in.call("request", false)
	elif event.is_action_pressed("interact"):
		var target := _target()
		if target:
			target.call("interact", self)


func _physics_process(delta: float) -> void:
	_prev_local = _local
	if is_multiplayer_authority():
		match mode:
			DECK:
				_walk(delta)
			SWIM:
				_swim(delta)
			CLIMB:
				_climbing(delta)
			AIR:
				_airborne(delta)
		if mode == DECK:
			_local = body.position
		if _hop_settle:
			_hop_settled()
		act = _doing()
		_send_in -= 1
		if Net.in_session() and _send_in <= 0:
			_send_in = 2      # 30 a second
			# (where you're shown: a step squared up on landing goes to them eased, as you see it)
			_state.rpc(_local + _hop_fix, _yaw, _pitch, act, hands.item, mode, _boat_index(frame), _clock())
	else:
		_play_net(delta)
		if mode == DECK:
			body.position = _local
		if _hop_settle:
			_hop_settled()


## What you're up to that the others can't see for themselves (ACT_*).
func _doing() -> int:
	var sea: Node = boat.get("sea") if boat else null
	if sea == null:
		return 0
	var out := ACT_VAULT if mode == DECK and _vault_t > 0.0 else (ACT_RAIL if on_rail() != Vector3.ZERO else 0)
	var jig: Node = sea.get("jig")
	if jig != null and bool(jig.call("active")):
		out |= ACT_JIG
	var landing: Node = sea.get("landing")
	if landing != null and int(landing.get("_my_pull")) >= 0:
		out |= ACT_HAUL
	var rods: Node = sea.get("rods")
	var live := force_input or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if rods != null and rods.call("held_by", str(name).to_int()) != null and live \
			and Input.is_action_pressed("use_primary"):
		out |= ACT_CRANK
	if aloft and not _tower_legs.is_empty() and _tower_t > float(_tower_legs[0][1]) and _tower_t < _tower_length():
		out |= ACT_TOWER
	return out


## Where a crew member is and where they look, in which frame (`on`: _boat_index, -1 the world) and how (`m`, the
## mode), by their own clock (`t`, s: _clock): sent by their own peer to everyone else, ~30 a second. Kept, and
## played back a moment behind (_play_net), so however the words come in, they go on smoothly.
@rpc("authority", "call_remote", "unreliable_ordered")
func _state(at: Vector3, yaw: float, pitch: float, doing := 0, item := "", m := DECK, on := -2, t := -1.0) -> void:
	var f := frame
	if on != -2:
		var b := _boat_at(on)
		if b != null or on == -1:
			f = b
	if t < 0.0:
		t = _clock()          # (no clock with it: as it comes)
	if not _snaps.is_empty() and t <= float((_snaps.back() as Array)[0]):
		return
	_snaps.append([t, at, yaw, pitch, m, f])
	if _snaps.size() > 30:
		_snaps.pop_front()
	_net_at = at
	_net_yaw = yaw
	_net_pitch = pitch
	_net_act = doing
	_net_item = item


## This peer's clock for the word to the others (s: its physics ticks, so it goes as the game goes, not the wall).
static func _clock() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


## A crewmate, from their words in hand: NET_DELAY behind the last one on their clock (going faster or slower to
## stay there, easing into it, never a jump unless it's far out), between the two words either side of that moment
## (in their frame; the last in it, on the way they were going); into the frame and mode of a word once it's played
## past (so they go over to another boat, or into the sea, when they did, the step between eased over).
func _play_net(delta: float) -> void:
	if _snaps.is_empty():
		return
	var newest := float((_snaps.back() as Array)[0])
	var want := newest - NET_DELAY
	if _play_t < 0.0 or absf(want - _play_t) > 1.0:
		_play_t = want
		_play_rate = 1.0
	else:
		var aim := clampf(1.0 + (want - _play_t) * NET_KEEP, NET_RATE.x, NET_RATE.y)
		_play_rate = lerpf(_play_rate, aim, minf(delta * NET_EASE, 1.0))
		_play_t += delta * _play_rate
	while _snaps.size() >= 2 and float((_snaps[1] as Array)[0]) <= _play_t:
		_snap_was = _snaps.pop_front()
	var s0: Array = _snaps[0]
	var f: Variant = s0[5]
	if (typeof(f) == TYPE_NIL or is_instance_valid(f)) and f != frame:
		# into the frame they went into: from where they'd have got to in the one they were in (going on as they
		# were), whatever the two of ours make of the step between, eased over (_set_frame, _hop_settled)
		_local += _net_v * delta
		_set_frame(f)         # (a boat gone since: stay where you are)
	if int(s0[4]) != mode:
		_set_mode(int(s0[4]))
	var at: Vector3 = s0[1]
	var yaw := float(s0[2])
	var pitch := float(s0[3])
	var s1: Array = _snaps[1] if _snaps.size() >= 2 else []
	if not s1.is_empty() and s1[5] == s0[5]:
		var k := clampf((_play_t - float(s0[0])) / maxf(float(s1[0]) - float(s0[0]), 0.001), 0.0, 1.0)
		at = at.lerp(s1[1], k)
		yaw = lerp_angle(yaw, float(s1[2]), k)
		pitch = lerpf(pitch, float(s1[3]), k)
	elif not _snap_was.is_empty() and _snap_was[5] == s0[5] and _play_t > float(s0[0]):
		# (past their last word in this frame: on the way they were going, a little while)
		var dt := float(s0[0]) - float(_snap_was[0])
		if dt > 0.0 and dt < 0.3:
			at += (at - (_snap_was[1] as Vector3)) / dt * minf(_play_t - float(s0[0]), NET_ON)
	if s0[5] != frame:
		at = _snap_at([0.0, at, 0.0, 0.0, 0, s0[5]])
		yaw += _snap_turn(s0)
	_net_v = (at - _local) / delta if delta > 0.0 else Vector3.ZERO
	_local = at
	_yaw = yaw
	_pitch = pitch


## A word's spot (`s`, see _snaps) in the frame you're in here, by where both are now.
func _snap_at(s: Array) -> Vector3:
	var f: Node3D = s[5] if is_instance_valid(s[5]) else null
	if f == frame or (f == null and typeof(s[5]) != TYPE_NIL):
		return s[1]
	return _xf(frame).affine_inverse() * _xf(f) * (s[1] as Vector3)


## How much a word's heading (`s`) turns, taken from its frame into yours.
func _snap_turn(s: Array) -> float:
	var f: Node3D = s[5] if is_instance_valid(s[5]) else null
	if f == frame or (f == null and typeof(s[5]) != TYPE_NIL):
		return 0.0
	return (_xf(frame).affine_inverse() * _xf(f)).basis.orthonormalized().get_euler(EULER_ORDER_YXZ).y


func _walk(delta: float) -> void:
	if aloft:
		_on_tower(delta)
		return
	if steering:
		body.velocity = Vector3.ZERO
		if _helm_to != Vector3.INF:
			# a step in to the wheel and round to face her bow, the way into a seat: nothing jumps
			body.position = body.position.move_toward(_helm_to, SIT_SPEED * delta)
			_helm_t += delta
			if _helm_t < 1.2:
				_yaw = lerp_angle(_yaw, 0.0, 1.0 - exp(-SIT_TURN * delta))
			if body.position.distance_to(_helm_to) < 0.01 and _helm_t >= 1.2:
				_helm_to = Vector3.INF
		return
	if seated and not is_instance_valid(sat_in):
		seated = false            # (she's been rebuilt under you: the seat's gone)
	if seated:
		# into the seat a step at a time, then held there; a jump gets you up
		body.velocity = Vector3.ZERO
		var to: Vector3 = sat_in.call("seat")
		body.position = body.position.move_toward(to, SIT_SPEED * delta)
		_sit_t += delta
		if sat_in.get("chair") == null and _sit_t < 1.2:
			_yaw = lerp_angle(_yaw, float(sat_in.get("face")), 1.0 - exp(-SIT_TURN * delta))   # (turning to sit)
		var live := force_input or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		if live and Input.is_action_just_pressed("jump"):
			sat_in.call("request", false)
		return
	if _rise_to != Vector3.INF:
		# up off the seat and a step out, then you're walking
		body.velocity = Vector3.ZERO
		body.position = body.position.move_toward(_rise_to, SIT_SPEED * delta)
		if body.position.distance_to(_rise_to) < 0.01:
			_rise_to = Vector3.INF
		return
	var live := force_input or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if live else Vector2.ZERO
	var wish := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y)
	wish = wish.normalized() * (SPRINT if Input.is_action_pressed("sprint") else WALK) * minf(input.length(), 1.0) * burden
	var rate := ACCEL if body.is_on_floor() else AIR_ACCEL
	_jump_t += delta
	var leg := wish        # (what a jump pushes you toward)
	if _feet_t > 0.0:
		# just up on top of an edge: finding your feet, not walking on off it yet
		_feet_t -= delta
		wish = Vector3.ZERO
	if _knock > 0.0:
		# shoved: your feet dragging, no say in where they go
		_knock -= delta
		wish = Vector3.ZERO
		rate = KNOCK_DRAG
	elif _skid > 0.0:
		# down off a leap onto a deck going by under you: skidding over it till your feet have caught up with her
		_skid -= delta
		wish = Vector3.ZERO
		rate = LAND_DRAG
	var v := body.velocity
	var pre := Vector3(v.x, 0.0, v.z)
	var flat := pre.move_toward(wish, rate * delta) if not _dropping else pre
	if _vault_t > 0.0:
		# up an edge: on over it the way you went at it, or in to stand over it
		_vault_t -= delta
		if _vault_over:
			flat = _vault_v
		else:
			var to := _vault_to - body.position
			flat = Vector3(to.x, 0.0, to.z) * VAULT_PULL
			flat = flat.limit_length(maxf(_vault_v.length(), WALK))
		if body.is_on_floor() and body.position.y >= _vault_top - 0.05 and v.y <= 0.0:
			_vault_t = 0.0        # (up: stood on it)
			if not _vault_over:
				_feet_t = VAULT_FEET
				flat = Vector3.ZERO
	v.x = flat.x
	v.z = flat.z
	if body.is_on_floor() and v.y <= 0.0:
		v.y = 0.0
		if live and _knock <= 0.0 and Input.is_action_just_pressed("jump"):
			# a jump, pushing off the way you're going
			v.y = JUMP
			var push := Vector3(leg.x - v.x, 0.0, leg.z - v.z).limit_length(JUMP_PUSH)
			v.x += push.x
			v.z += push.z
			_jump_y = body.position.y
			_jump_t = 0.0
			_feet_t = 0.0
	else:
		v.y -= GRAVITY * delta
	body.velocity = v
	body.move_and_slide()
	if _dropping and body.is_on_floor():
		_touch_down()
	if _vault_t <= 0.0 and not body.is_on_floor() and (_jump_t < 0.8 or _knock > 0.0):
		_vault_at(wish, pre)
	if not body.is_on_floor() and (_nothing_under(boat, body.position)
			or body.position.y < float(boat.get("deck")) - 0.8):
		# off her somewhere the rail doesn't stop you: in the air
		_take_off(boat.global_basis * body.velocity, _deck_velocity(boat, body.position))


## Into seat `s` (boat/chair.gd, the host's word, on every peer): you're carried to it and down into it.
func sit_in(s: Node3D) -> void:
	seated = true
	sat_in = s
	_sit_t = 0.0
	_rise_to = Vector3.INF


## The wheel's yours (boat/helm.gd, every peer): on her deck within a stride or two of it you step in to its spot
## (`to`, boat-local) and turn to her bow; from anywhere else (a test, the dock) you're put there. A crewmate's copy
## follows their own word.
func take_wheel(to: Vector3) -> void:
	if can_step_to(to):
		if is_multiplayer_authority():
			_helm_to = to
			_helm_t = 0.0
		return
	place(to, 0.0)


## Whether you could step straight to `to` (boat-local, on her deck): on her, on your feet, a stride or two off, nothing
## in the way at chest height (the console, the leaning post, a bulkhead). Else being put there would be a jump.
func can_step_to(to: Vector3) -> bool:
	if mode != DECK or frame != boat or aloft or _vault_t > 0.0 or body.position.distance_to(to) >= 4.0:
		return false
	var up := Vector3(0.0, 0.9, 0.0)
	return _ray(_deck_space(boat), body.position + up, to + up).is_empty()


## Up out of your seat (the host's word, on every peer), to `to` (boat-local, on her deck) a step at a time.
func stand_up(to: Vector3) -> void:
	seated = false
	sat_in = null
	if is_multiplayer_authority() and mode == DECK:
		_rise_to = to


## In a seat, E on `t` gets you up (nothing there, the wheel, a seat), rather than using it (a rod, say).
func _gets_you_up(t: Node) -> bool:
	return t == null or t == boat.get("helm") or t.has_method("stand")


## How far down you sit in your seat (m), and whether it's a leaning post.
func _seat_drop() -> float:
	return float(sat_in.get("drop")) if is_instance_valid(sat_in) else SEAT_DROP


func _seat_lean() -> bool:
	return is_instance_valid(sat_in) and bool(sat_in.get("lean"))


## E on the tuna tower's ladder (boat/tower.gd): up you go, the whole way, from where you stand.
func climb_tower(tower: Node3D) -> void:
	if mode != DECK or steering or seated or aloft or tower == null:
		return
	_tower = tower
	_tower_from = body.position
	_tower_legs = tower.call("path", body.position)
	_tower_t = 0.0
	_tower_way = 1
	aloft = true
	body.velocity = Vector3.ZERO


## E or Q up the tower (or on the way up): back down it the way you came, to the foot of the ladder.
func climb_down_tower() -> void:
	if not aloft or _tower_legs.is_empty():
		return
	if _tower_t <= float(_tower_legs[0][1]):
		aloft = false             # (not on it yet: still on her deck, walking)
		_tower_legs = []
		return
	_tower_way = -1           # (down to the foot of the ladder, not back across the deck to where you started)


## The whole tower climb (s).
func _tower_length() -> float:
	var total := 0.0
	for leg: Array in _tower_legs:
		total += float(leg[1])
	return total


## Up (or down) the tower: carried along its path a step at a time; at the top you stay put, looking round; at the
## foot of the ladder you're back on deck, walking.
func _on_tower(delta: float) -> void:
	body.velocity = Vector3.ZERO
	if _tower == null or not is_instance_valid(_tower) or boat.get("tower") != _tower or _tower_legs.is_empty():
		# (she's been rebuilt under you: back on her deck)
		aloft = false
		_tower_legs = []
		body.position.y = float(boat.get("deck")) + 0.05
		return
	var total := _tower_length()
	_tower_t = clampf(_tower_t + delta * _tower_way, 0.0, total)
	body.position = _tower_at(_tower_t)
	var foot := float(_tower_legs[0][1])
	if _tower_way < 0 and _tower_t <= foot:
		aloft = false
		_tower_legs = []


## Where `t` s along the tower climb puts you (boat-local): up the ladder and the leg a rung at a time.
func _tower_at(t: float) -> Vector3:
	var from := _tower_from
	for i in _tower_legs.size():
		var leg: Array = _tower_legs[i]
		var dur := float(leg[1])
		if t <= dur or i == _tower_legs.size() - 1:
			var u := clampf(t / dur, 0.0, 1.0)
			var rungs := 6
			var k := u - 0.6 * sin(TAU * rungs * u) / (TAU * rungs) if i == 1 or i == 3 else smoothstep(0.0, 1.0, u)
			return from.lerp(leg[0], k)
		t -= dur
		from = leg[0]
	return from


# ------------------------------------------------------------------ up an edge, on her gunwale, and off her

## In the air on her deck, into something you're going at (`wish`, or knocked `pre`: her space, m/s): if it's an
## edge with its top within VAULT_HIGH of where you took off and room to stand on it, your legs get you up it
## (_walk carries it on): rising to clear it, then in to stand over it, or (sprinting, or knocked) straight on over.
func _vault_at(wish: Vector3, pre: Vector3) -> void:
	var space := body.get_world_3d().direct_space_state
	for i in body.get_slide_collision_count():
		var c := body.get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) > 0.5:
			continue
		var into := -Vector3(n.x, 0.0, n.z).normalized()
		var going := wish.dot(into)
		var knocked := _knock > 0.0 and pre.dot(into) > OVER_SPEED
		if going < WALK * 0.5 and not knocked:
			continue
		var at := c.get_position() + into * 0.05
		var hi := _jump_y + VAULT_HIGH
		var hit := _ray(space, Vector3(at.x, hi + 0.05, at.z), Vector3(at.x, body.position.y - 0.05, at.z))
		if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
			continue
		var top := float((hit["position"] as Vector3).y)
		var stand := Vector3(at.x, top + 0.03, at.z)
		if top <= body.position.y + 0.02 or not _fits(space, stand + Vector3(0.0, 0.1, 0.0)):
			continue
		_vault_over = knocked or wish.length() > WALK + 0.3
		var speed := maxf(maxf(going, pre.dot(into)), WALK if knocked else 0.0)
		var along := pre - into * pre.dot(into)
		_vault_v = into * speed + along
		_vault_to = stand
		_vault_top = top
		_vault_t = VAULT_TIME
		var rise := top + (VAULT_OVER if _vault_over else VAULT_CLEAR) - body.position.y
		body.velocity.y = maxf(body.velocity.y, sqrt(2.0 * GRAVITY * rise))
		if knocked:
			gesture("stumble")
		return


## Standing up on her gunwale (or her transom): the way out over it (her space, flat), else zero.
func on_rail() -> Vector3:
	if mode != DECK or boat == null or aloft or seated or not body.is_on_floor() \
			or body.position.y < float(boat.get("deck")) + 0.3:
		return Vector3.ZERO
	for out: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK]:
		if _nothing_under(boat, body.position + out * RAIL_OUT):
			return out
	return Vector3.ZERO


## Off her into the air, your own leap `push` on top of the way her deck's going there, `deck_v` (world, m/s):
## whatever you had hold of is let go. Clear of her, you're in the world's frame from here (_air_frame).
func _take_off(push: Vector3, deck_v: Vector3) -> void:
	_local = body.position
	_let_go()
	_vault_t = 0.0
	_feet_t = 0.0
	_dropping = false
	_air_t = 0.0
	_air_push = push
	_air_v = push + deck_v
	_set_mode(AIR)
	_air_frame(_xf(frame) * _local)


## In the air: falling through the world, going your way; each tick, any boat under you or in your way
## (_air_meets), else on, and into the sea when you get to it. Your spot's kept in the frame you're over
## (_air_frame: a boat, or the world), going over it as your way and its differ (_air_to): its pose carries the
## rest, every frame drawn, so over a boat you're shown going on with her as smoothly as on her deck.
func _airborne(delta: float) -> void:
	_air_t += delta
	_air_v.y -= GRAVITY * delta
	_air_carry = _deck_velocity(frame, _local) if frame != null else Vector3.ZERO
	var from := _xf(frame) * _local
	for b: Node3D in _boats():
		if _air_meets(b, from, delta):
			return
	var at := _air_to(from, delta)
	_local = _xf(frame).affine_inverse() * at
	_air_frame(at)
	if frame != null and _drop_in(frame):
		return
	var ocean := _ocean()
	# (over a boat her hull keeps the sea out: a crest at her transom isn't the sea under you)
	var aboard := frame != null and _local.y > 0.2
	if ocean != null and not aboard and at.y < float(ocean.call("height_at", at)):
		_into_sea(_air_v)


## In the air at `at` (world): over a boat (anything of her under any of you) you're in her frame, else the
## world's; each change mid-air, carried across where you are (_set_frame: nothing moves). Clear of one and already
## over another lying alongside, you go straight into hers.
func _air_frame(at: Vector3) -> void:
	if frame != null and _over(frame, at):
		return
	var over: Node3D = null
	for b: Node3D in _boats():
		if _over(b, at):
			over = b
			break
	if over != frame:
		_hop_bake = true
		_set_frame(over)


## In over boat `b` out of the air (her frame's yours: _air_frame), your middle over her and room for you there:
## into her deck space, still falling, going as you were over her (true). Her collider's yours to bump into and come
## down on from now (_walk); your feet on her, _touch_down.
func _drop_in(b: Node3D) -> bool:
	if _nothing_under(b, _local) or not _fits(_deck_space(b), _local):
		return false
	var turn := b.global_basis.inverse()
	var deck_v := _deck_velocity(b, _local)
	var push := turn * Vector3(_air_push.x, 0.0, _air_push.z)
	var by := _air_v - _air_push - deck_v
	var slip := turn * Vector3(by.x, 0.0, by.z)
	_drop_push = Vector3(push.x, 0.0, push.z)
	_drop_slip = Vector3(slip.x, 0.0, slip.z)
	_set_mode(DECK)
	body.position = _local
	body.velocity = turn * (_air_v - deck_v)
	_dropping = true
	_jump_t = INF
	_follow_me()
	return true


## Your feet down on her deck after coming in over her out of the air: of your own leap's way over her you keep some
## (LAND_KEEP: a step on), and her deck going by under you past that you keep all of: a stumble, skidding till your
## feet have caught up with her.
func _touch_down() -> void:
	_dropping = false
	body.velocity = _drop_push * LAND_KEEP + _drop_slip
	_skid = 0.0
	if _drop_slip.length() > LAND_STUMBLE:
		_skid = body.velocity.length() / LAND_DRAG
		gesture("stumble")


## Anything of boat `b` under you at `at` (world): your middle or the edge of you.
func _over(b: Node3D, at: Vector3) -> bool:
	var l := _xf(b).affine_inverse() * at
	if absf(l.z) > float(b.get("length")) * 0.5 + 0.4 or absf(l.x) > float(b.get("beam")) * 0.5 + 0.4:
		return false
	for off: Vector3 in [Vector3.ZERO, Vector3(0.3, 0.0, 0.0), Vector3(-0.3, 0.0, 0.0), Vector3(0.0, 0.0, 0.3),
			Vector3(0.0, 0.0, -0.3)]:
		if not _nothing_under(b, l + off):
			return true
	return false


## Where this tick takes you from `from` (world, by the poses the boats had when it began: they move on between
## frames, not ticks): on over the frame you're in by your way less hers there.
func _air_to(from: Vector3, delta: float) -> Vector3:
	return from + (_air_v - _air_carry) * delta


## Boat `b` on your way from `from` (world) this tick: her side below her gunwale bounces you off it (over it,
## your toes catching it are let off); coming down on her deck, or her gunwale, or anything of her to stand on,
## you land there (true), in her deck space from now.
func _air_meets(b: Node3D, from: Vector3, delta: float) -> bool:
	var x := b.global_transform
	var inv := x.affine_inverse()
	var lf := inv * from
	var lt := inv * _air_to(from, delta)
	var half := float(b.get("length")) * 0.5
	if absf(lt.z) > half + 1.0 or absf(lt.x) > float(b.get("beam")) * 0.5 + 1.0 or lt.y > 12.0:
		return false
	var space := _deck_space(b)
	var outside := _nothing_under(b, lf)
	var move := Vector3(lt.x - lf.x, 0.0, lt.z - lf.z)
	if move.length() > 0.0001:
		for h: float in [0.15, 1.0]:
			var hit := _ray(space, lf + Vector3(0.0, h, 0.0), lt + Vector3(0.0, h, 0.0) + move.normalized() * 0.1)
			if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.5:
				continue
			var n: Vector3 = hit["normal"]
			n = Vector3(n.x, 0.0, n.z).normalized()
			if n.dot(move) > 0.0:
				n = -n
			if outside and lf.y >= _wall_top(space, hit["position"], -n, (hit["position"] as Vector3).y) - 0.15:
				continue        # (over her rail: your toes catching it are let off)
			var nw := x.basis * n
			var into := (_air_v - _deck_velocity(b, lt)).dot(nw)
			if into < 0.0:
				_air_v -= nw * into * 1.3
			lt = inv * _air_to(from, delta)
			break
	var rel := inv.basis * (_air_v - _deck_velocity(b, lt))       # (your way over her deck)
	if rel.y > 0.0:
		return false
	# her deck (or anything of her to stand on: her gunwale) under you
	var hit := _ray(space, Vector3(lt.x, maxf(lf.y, lt.y) + 0.6, lt.z), Vector3(lt.x, lt.y - 0.02, lt.z))
	if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.7:
		_hop_to(_air_to(from, delta))
		_land(b, _fit(space, hit["position"] + Vector3(0.0, 0.03, 0.0)))
		return true
	return false


## Down on boat `b`'s deck at `stand` (her space), out of the air: aboard her from now. Your knees take the
## drop (_process); of your own leap's way over her you keep some (LAND_KEEP: a step on), and her deck going by
## under you past that (she's going her way, the one you left was going its own) you keep all of: a stumble,
## skidding till your feet have caught up with her.
func _land(b: Node3D, stand: Vector3) -> void:
	var turn := b.global_basis.inverse()
	var push := turn * Vector3(_air_push.x, 0.0, _air_push.z)
	var by := _air_v - _air_push - _deck_velocity(b, stand)
	var slip := turn * Vector3(by.x, 0.0, by.z)
	_set_frame(b)
	_set_mode(DECK)
	_dropping = false
	body.position = stand
	body.velocity = Vector3(push.x, 0.0, push.z) * LAND_KEEP + Vector3(slip.x, 0.0, slip.z)
	_skid = 0.0
	if Vector2(slip.x, slip.z).length() > LAND_STUMBLE:
		_skid = body.velocity.length() / LAND_DRAG
		gesture("stumble")
	_local = stand
	_follow_me()


## The top of the wall at `wall` (a ray going `toward` finds it at height `lo`): up it till a ray over it finds
## nothing.
func _wall_top(space: PhysicsDirectSpaceState3D, wall: Vector3, toward: Vector3, lo: float) -> float:
	var hi := lo + 3.0
	for i in 9:
		var m := (lo + hi) * 0.5
		var a := Vector3(wall.x, m, wall.z) - toward * 0.25
		if _ray(space, a, a + toward * 0.5).is_empty():
			hi = m
		else:
			lo = m
	return lo


## You'd stand at `at` (that space) without your body in anything: there, or a little in from it toward her middle.
func _fits(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var fit := PhysicsShapeQueryParameters3D.new()
	fit.shape = (body.get_child(0) as CollisionShape3D).shape
	fit.transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.9, 0.0))
	fit.exclude = [body.get_rid()]
	return space.intersect_shape(fit, 1).is_empty()


func _fit(space: PhysicsDirectSpaceState3D, stand: Vector3) -> Vector3:
	if _fits(space, stand):
		return stand
	# (in off her side, her transom, or both: the least way that does)
	var across := Vector3(-signf(stand.x), 0.0, 0.0)
	var along := Vector3(0.0, 0.0, -signf(stand.z))
	for k in range(1, 7):
		for inward: Vector3 in [across, along, (across + along).normalized()]:
			var p := stand + inward * 0.06 * k
			if _fits(space, p):
				return p
	return stand


## Nothing of boat `b` under `at` (her space): off her, over the sea.
func _nothing_under(b: Node3D, at: Vector3) -> bool:
	return _ray(_deck_space(b), at + Vector3(0.0, 0.3, 0.0), at - Vector3(0.0, 6.0, 0.0)).is_empty()


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [body.get_rid()]
	return space.intersect_ray(q)


static func _deck_space(b: Node3D) -> PhysicsDirectSpaceState3D:
	return (b.get("deck_root") as Node3D).get_world_3d().direct_space_state


## How the spot `local` of boat `b` (her space) is going through the world (m/s): what you take with you going over
## her side there, and what her deck's doing under you coming down on it (boat/boat.gd's point_velocity: her way,
## turn, heave, pitch and roll), else just her way over the water.
static func _deck_velocity(b: Node3D, local: Vector3) -> Vector3:
	if b != null and b.has_method("point_velocity"):
		return b.call("point_velocity", local)
	return _boat_velocity(b)


## How boat `b`'s going over the water (world, m/s).
static func _boat_velocity(b: Node3D) -> Vector3:
	var h: Node = b.get("helm")
	if h == null:
		return Vector3.ZERO
	var heading := float(h.get("heading"))
	var v := Vector2(-sin(heading), -cos(heading)) * float(h.get("speed")) + (h.get("drift") as Vector2)
	return Vector3(v.x, 0.0, v.y)


## Into the sea, going `v` (world, m/s): whatever you had hold of is let go, and you're in the world's space.
func _into_sea(v: Vector3) -> void:
	_let_go()
	_set_frame(null)
	_swim_v = v
	_set_mode(SWIM)


## Screenshots: in the sea at `at` (world: the surface there), afloat, facing `toward`.
func overboard(at: Vector3, toward: Vector3) -> void:
	_into_sea(Vector3.ZERO)
	var ocean := _ocean()
	var y := float(ocean.call("height_at", at)) - FLOAT if ocean else -FLOAT
	_local = Vector3(at.x, y, at.z)
	_prev_local = _local
	_wet = true
	var d := toward - at
	_yaw = atan2(-d.x, -d.z)
	_hop_clear()


## Off the deck: the rod back in its holder (its fish, if it's on, still on it, for the fight to do what it does with
## a rod nobody's holding), the wheel and the chair let go, the harpoon back in its rack.
func _let_go() -> void:
	var id := str(name).to_int()
	for b: Node3D in _boats():
		var sea: Node = b.get("sea")
		var rods: Node = sea.get("rods") if sea else null
		var r: Node = rods.call("held_by", id) if rods else null
		if r != null:
			rods.call("request_return", int(r.get("index")))
		var landing: Node = sea.get("landing") if sea else null
		if landing != null and int(landing.get("harpoon_holder")) == id:
			landing.call("_request_harpoon", false)
	if steering:
		steering = false
		(boat.get("helm") as Node).call("request", false)
	if seated and is_instance_valid(sat_in):
		sat_in.call("request", false)
	_knock = 0.0


## Afloat: the sea lifts you to its surface and lets you down again a beat behind the waves; you swim where you look,
## stroke by stroke, and dive under while you've the breath; the wind and the slope of a swell carry you; no hull lets
## you through it.
func _swim(delta: float) -> void:
	var ocean := _ocean()
	var at := _local
	var water := float(ocean.call("height_at", at)) if ocean else 0.0
	var v := _swim_v
	if at.y > water + 0.02 and not _wet:
		# still falling in
		v.y -= GRAVITY * delta
		_local = at + v * delta
		_swim_v = v
		return
	var live := force_input or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if live else Vector2.ZERO
	var going := minf(input.length(), 1.0)
	var dive := live and not _winded and Input.is_action_pressed("swim_down")
	var fast := live and not _winded and not dive and going > 0.1 and Input.is_action_pressed("sprint")
	# your breath: going under it, sprinting it, and back again at the surface
	if at.y + 1.62 < water - 0.05:
		_breath -= delta / AIR_UNDER
	elif fast:
		_breath -= delta / AIR_SPRINT
	else:
		_breath += delta / AIR_BACK
	_breath = clampf(_breath, 0.0, 1.0)
	if _breath <= 0.0:
		_winded = true
	elif _winded and _breath >= WINDED:
		_winded = false
	# the stroke: the pull surges you on, the glide carries you to the next (treading water, slower and nowhere)
	_stroke = fmod(_stroke + delta * (STROKE_FAST if fast else STROKE) * maxf(going, TREAD), 1.0)
	var pull := pow(sin(PI * _stroke), 2.0)
	var speed := (SWIM_FAST if fast else SWIM_SPEED) * (DIVE_SLOW if dive else 1.0)
	var wish := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y)
	wish = wish.normalized() * speed * going * (1.0 - SURGE + 2.0 * SURGE * pull)
	var flat := Vector3(v.x, 0.0, v.z)
	# (water's thick: going in fast, it soon takes your way off you)
	flat = flat.move_toward(wish, (SWIM_ACCEL + maxf(flat.length() - SWIM_FAST, 0.0) * 2.5) * delta)
	var rest := water - FLOAT - (DIVE if dive else 0.0)
	# (going in hard, you go right under before the sea brings you up; diving, you go down softer)
	var plunge := 0.25 if v.y < -1.2 and not dive else (DIVE_SPRING if dive or at.y < water - FLOAT - 0.6 else 1.0)
	v = Vector3(flat.x, v.y + (BUOY * plunge * (rest - at.y) - BUOY_DAMP * plunge * v.y) * delta, flat.z)
	var sea := Vector3.ZERO
	if ocean:
		var wind: Vector2 = ocean.get("wind")
		var n: Vector3 = ocean.call("normal_at", Vector3(at.x, water, at.z))
		var drift := (wind.normalized() if wind.length() > 0.01 else Vector2.ZERO) * DRIFT + Vector2(n.x, n.z) * SLIDE
		sea = Vector3(drift.x, 0.0, drift.y)
	_swim_v = v
	_local = _clear_hulls(at + (v + sea) * delta)


## `at` (world) moved out of any boat's hull, SWIMMER m off her side, her transom or her bow.
func _clear_hulls(at: Vector3) -> Vector3:
	for b: Node3D in _boats():
		var x := b.global_transform
		var l := x.affine_inverse() * at
		var half := float(b.get("length")) * 0.5
		var stern := half - 0.08
		if l.y > 2.0 or l.z > stern + SWIMMER or l.z < -half - SWIMMER:
			continue
		# her sides come in toward the bow (art/boat.py, art/skiff.py: about so)
		var u := (half - l.z) / (half * 2.0)
		var t := clampf((u - 0.55) / 0.45, 0.0, 1.0)
		var w := float(b.get("beam")) * 0.5 * (0.95 if u < 0.55 else pow(maxf(0.0, 1.0 - t * t), 0.55))
		if absf(l.x) >= w + SWIMMER:
			continue
		var side := w + SWIMMER - absf(l.x)
		var aft := stern + SWIMMER - l.z
		if aft < side:
			l.z = stern + SWIMMER
		else:
			l.x = (1.0 if l.x >= 0.0 else -1.0) * (w + SWIMMER)
		var out := x * l
		at = Vector3(out.x, at.y, out.z)
	return at


## Hold of boat `on`'s ladder (boat/ladder.gd's interact): from the sea, at its foot, to climb; from her deck, at its
## top, to go down it (your path's last leg ends where you stand, so nothing moves as you take hold).
func climb(on: Node3D) -> void:
	var ladder: Node3D = on.get("ladder") if on else null
	if ladder == null:
		return
	if mode == SWIM:
		_set_frame(on)
		_climb_from = _local
		_climb_legs = ladder.call("path", _local)
		_climb_t = 0.0
		_climb_way = 1
	elif mode == DECK and on == boat and not steering and not seated and not aloft:
		_let_go()
		var foot: Vector3 = (ladder.call("path", Vector3.ZERO) as Array)[0][0]
		_climb_from = foot
		_climb_legs = ladder.call("path", foot)
		var last: Array = _climb_legs.back()
		var was: Vector3 = (_climb_legs[_climb_legs.size() - 2] as Array)[0]
		_climb_legs[_climb_legs.size() - 1] = [body.position, clampf(was.distance_to(body.position) / 1.4,
				float(last[1]), 1.0)]
		_climb_t = _climb_length()
		_climb_way = -1
	else:
		return
	_ladder = ladder
	_set_mode(CLIMB)


## The whole climb, foot to deck (s).
func _climb_length() -> float:
	var total := 0.0
	for leg: Array in _climb_legs:
		total += float(leg[1])
	return total


## On a ladder: W up, S down, neither and you hang there. The swim in to its foot and the way over her transom's cap
## carry you along by themselves (the cap's no place to hang); at the foot S lets you back into the water, at the
## top W steps you onto her deck.
func _climbing(delta: float) -> void:
	if _ladder == null or not is_instance_valid(_ladder):
		_into_sea(Vector3.ZERO)
		return
	var live := force_input or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var up := force_climb or (live and Input.is_action_pressed("move_forward"))
	var down := not force_climb and live and Input.is_action_pressed("move_back")
	var foot := float(_climb_legs[0][1])
	var cap := foot + float(_climb_legs[1][1])
	var total := _climb_length()
	if up:
		_climb_way = 1
	elif down:
		_climb_way = -1
	var was := _climb_t
	if _climb_t < foot:
		_climb_t += delta                 # (in to it)
	elif _climb_t > cap or up or down:
		_climb_t += delta * _climb_way * (1.0 if _climb_way > 0 else 1.25)
	_climb_t = clampf(_climb_t, minf(was, foot), total)
	if _climb_t != was:
		# (facing her, the way you'll go over her transom)
		_yaw = lerp_angle(_yaw, 0.0, 1.0 - exp(-4.0 * delta))
	_local = _climb_at(_climb_t)
	if _climb_t >= total and _climb_way > 0:
		# aboard
		body.position = _local
		body.velocity = Vector3.ZERO
		_set_mode(DECK)
		_follow_me()
	elif _climb_t <= foot and was <= foot + 0.001 and down and _climb_way < 0:
		# at the foot and down: back into the water
		_into_sea(_deck_velocity(boat, _local))
		_wet = true


## Where `t` s along the climb puts you (boat-local).
func _climb_at(t: float) -> Vector3:
	var steps := int(_ladder.call("steps"))
	var from := _climb_from
	for i in _climb_legs.size():
		var leg: Array = _climb_legs[i]
		var dur := float(leg[1])
		if t <= dur or i == _climb_legs.size() - 1:
			var u := clampf(t / dur, 0.0, 1.0)
			# (up the ladder a step at a time: a pause on each, then the next)
			var s := u - 0.6 * sin(TAU * steps * u) / (TAU * steps) if i == 1 else smoothstep(0.0, 1.0, u)
			return from.lerp(leg[0], s)
		t -= dur
		from = leg[0]
	return from


## E on a ladder: let go. On it, you drop into the water below; over her transom's cap, you go on over onto her deck.
func _let_go_ladder() -> void:
	if mode != CLIMB:
		return
	if _climb_t > float(_climb_legs[0][1]) + float(_climb_legs[1][1]):
		_climb_way = 1
		return
	_into_sea(_deck_velocity(boat, _local))


## Takes you into `to`'s space (a boat, or null: the world) where you are now: your spot, your heading and your eyes
## carried across, so nothing moves; aboard a boat, your body goes into her deck space.
func _set_frame(to: Node3D) -> void:
	if to == frame:
		return
	_hop_mark()
	_hop_to_xf = _xf(to)       # (both as they are this instant: someone else's word may come between the boats moving)
	_eyes_from = head.global_basis.orthonormalized() if head else Basis.IDENTITY
	_eyes_k = 0.0
	var m := _xf(to).affine_inverse() * _xf(frame)
	_local = m * _local
	_prev_local = m * _prev_local
	_net_at = m * _net_at
	_shown_at = m * _shown_at
	_hop_off = m.basis * _hop_off
	_hop_off_v = m.basis * _hop_off_v
	_hop_fix = m.basis * _hop_fix
	_hop_fix_v = m.basis * _hop_fix_v
	var mb := m.basis.orthonormalized()
	var turn := mb.get_euler(EULER_ORDER_YXZ).y
	# (her tilt and the one you were in aren't the same: you're turned as you were, easing over to hers)
	var was := Basis(Vector3.UP, _yaw)
	_yaw += turn
	_net_yaw += turn
	_hop_tilt = (mb * Basis(_hop_tilt) * was * Basis(Vector3.UP, -_yaw)).orthonormalized().get_rotation_quaternion()
	frame = to
	_stumble_in = maxf(_stumble_in, 1.0)      # (her heave isn't the last one's: no lurch from the change)
	if to != null:
		boat = to
		var root := to.get("deck_root") as Node3D
		if body.get_parent() != root:
			body.get_parent().remove_child(body)
			root.add_child(body)
		body.position = _local
		if is_multiplayer_authority():
			_boarded(to)


## You've gone aboard `to`: the other crew's boat out at sea in Rivals is Boarding Party (core/achievements.gd).
func _boarded(to: Node3D) -> void:
	var sea: Node = to.get("sea")
	var vs: Node = sea.get("vs") if sea else null
	var hold: Node = sea.get("fish_hold") if sea else null
	if vs == null or not bool(vs.get("on")) or hold == null or bool(hold.get("docked")):
		return
	var sides: Array = vs.get("sides")
	var team := int(vs.get("my_team"))
	if team < sides.size() and (sides[team] as Node).get("boat") != to:
		Net.achievements.unlock("BOARDED")


func _set_mode(m: int) -> void:
	if m == mode:
		return
	mode = m
	# (only on deck does your body stand in her deck space for the others to bump into)
	body.collision_layer = 1 if m == DECK else 0
	body.collision_mask = 1 if m == DECK else 0
	if m == SWIM:
		_wet = false
		_in_for = 0.0


## Where you're shown now is where you were: before going into another frame, or being put somewhere you'd not
## have got to by yourself (once a tick).
func _hop_mark() -> void:
	var tick := Engine.get_physics_frames()
	if tick == _hop_tick and _hop_settle:
		return
	_hop_tick = tick
	_hop_from = frame
	_hop_from_xf = _xf(frame)
	_hop_to_xf = _hop_from_xf
	_hop_w = _hop_from_xf * _local
	_hop_settle = true


## You're at `at` (world) this tick, by the frame you're in: then wherever you're put, you're shown from there.
func _hop_to(at: Vector3) -> void:
	_local = _xf(frame).affine_inverse() * at
	_hop_mark()


## The tick's done: whatever's moved you since _hop_mark (a frame's change, a spot squared up) is eased away, from
## your last spot on (so the tick's own step is still drawn), and if it was into another frame, the next drawn carries
## you on as the one you were in would have.
func _hop_settled() -> void:
	_hop_settle = false
	var d := _local - (_hop_to_xf.affine_inverse() * _hop_w)
	_prev_local += d
	_hop_off -= d
	_hop_fix -= d
	_hop_carry = frame != _hop_from


## A step `off` (m) eased on by a frame (`v`, its way, m/s): a spring, critically damped, as quick as HOP_EASE for a
## small one and gentler for a big one (HOP_ACCEL at most to begin with); [off, v], both nothing once it's gone.
static func _ease_hop(off: Vector3, v: Vector3, delta: float) -> Array:
	var w := minf(1.0 / HOP_EASE, sqrt(HOP_ACCEL / maxf(off.length(), 0.001)))
	v += (-w * w * off - 2.0 * w * v) * delta
	off += v * delta
	if off.length() < 0.0005 and v.length() < 0.01:
		return [Vector3.ZERO, Vector3.ZERO]
	return [off, v]


func _hop_clear() -> void:
	_hop_settle = false
	_hop_carry = false
	_hop_bake = false
	_hop_off = Vector3.ZERO
	_hop_off_v = Vector3.ZERO
	_hop_fix = Vector3.ZERO
	_hop_fix_v = Vector3.ZERO
	_hop_tilt = Quaternion.IDENTITY
	_skid = 0.0
	_knees = 0.0
	_knees_v = 0.0
	_shown_at = _local
	_shown_vy = 0.0


static func _xf(f: Node3D) -> Transform3D:
	return f.global_transform if f != null and is_instance_valid(f) else Transform3D.IDENTITY


## Every boat on the sea (both, in VS), in an order every peer agrees on.
func _boats() -> Array:
	var out := get_tree().get_nodes_in_group("boats")
	out.sort_custom(func(a: Node, b: Node) -> bool: return str(a.get_path()) < str(b.get_path()))
	return out


func _boat_index(b: Node3D) -> int:
	return _boats().find(b) if b != null else -1


func _boat_at(i: int) -> Node3D:
	var all := _boats()
	return all[i] if i >= 0 and i < all.size() else null


func _ocean() -> Node:
	var sea: Node = boat.get("sea") if boat else null
	return sea.get("ocean") if sea else null


## The sea's drawn round the boat you're on (her hull keeps the crests out of her deck).
func _follow_me() -> void:
	var ocean := _ocean()
	if is_multiplayer_authority() and ocean != null and boat != null:
		ocean.set("follow", boat)


# ------------------------------------------------------------------ the shove

## F: wind up to shove whoever's in front of you (the host's to say).
func shove() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if mode != DECK or steering or seated or aloft or _knock > 0.0 or now - _shove_at < SHOVE_AGAIN:
		return
	_shove_at = now
	if Net.is_host():
		_host_shove()
	else:
		_ask_shove.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _ask_shove() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == str(name).to_int():
		_host_shove()


## Host: the windup, everyone sees it; SHOVE_WINDUP s later, the push on whoever's in front then.
func _host_shove() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if mode != DECK or steering or seated or now - _host_shove_at < SHOVE_AGAIN - 0.25:
		return
	_host_shove_at = now
	shoves += 1
	if Net.in_session():
		_wind_up.rpc()
	else:
		_wind_up()
	get_tree().create_timer(SHOVE_WINDUP).timeout.connect(_host_push)


@rpc("any_peer", "call_local", "reliable")
func _wind_up() -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	_gesture = "shove"
	_gesture_t = 0.0
	_voice.stream = Voice.grunt()
	_voice.pitch_scale = randf_range(0.92, 1.08)
	_voice.play()
	get_tree().create_timer(SHOVE_WINDUP).timeout.connect(func() -> void:
		if is_instance_valid(_swish):
			_swish.pitch_scale = randf_range(0.9, 1.1)
			_swish.play())


## Host: the push lands on the nearest one in reach in front of you, if anyone's there (they had the windup to get
## out of the way), half of it on someone braced.
func _host_push() -> void:
	if not is_inside_tree() or mode != DECK:
		return
	var fwd := -global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var best: Node3D = null
	var near := SHOVE_REACH
	for p: Node3D in get_tree().get_nodes_in_group("players"):
		if p == self or int(p.get("mode")) != DECK:
			continue
		var d := p.global_position - global_position
		var flat := Vector3(d.x, 0.0, d.z)
		if absf(d.y) > 1.0 or flat.length() > near or flat.normalized().dot(fwd) < 0.35:
			continue
		near = flat.length()
		best = p
	if best == null:
		return
	var to := best.global_position - global_position
	var way := (fwd + Vector3(to.x, 0.0, to.z).normalized()).normalized()
	var k := BRACED if bool(best.call("braced")) else 1.0
	var v := way * SHOVE_PUSH * k + Vector3.UP * SHOVE_LIFT * k
	if Net.in_session():
		best.rpc("_pushed", v)
	else:
		best.call("_pushed", v)
	# (a rival in the sea a moment after: Man Overboard for whoever shoved, core/achievements.gd)
	var vs: Node = (boat.get("sea") as Node).get("vs") if boat and boat.get("sea") else null
	if vs == null or not bool(vs.get("on")):
		return
	var teams: Dictionary = vs.get("teams")
	var me := str(name).to_int()
	var them := str(best.name).to_int()
	if int(teams.get(me, 0)) == int(teams.get(them, 0)):
		return
	get_tree().create_timer(OVERBOARD_IN).timeout.connect(func() -> void:
		if is_instance_valid(best) and is_inside_tree() and int(best.get("mode")) == SWIM:
			if me == Net.my_id():
				_shoved_over()
			elif Net.in_session():
				_shoved_over.rpc_id(me))


## The host's word: someone you shoved went over the side.
@rpc("any_peer", "call_remote", "reliable")
func _shoved_over() -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	Net.achievements.unlock("OVERBOARD")


## Whether you're braced against a shove: a fish on the rod in your hands, the wheel in them, sat in the chair.
func braced() -> bool:
	if steering or seated:
		return true
	var id := str(name).to_int()
	for b: Node3D in _boats():
		var sea: Node = b.get("sea")
		var rods: Node = sea.get("rods") if sea else null
		var r: Node = rods.call("held_by", id) if rods else null
		if r != null and bool(r.get("hooked")):
			return true
	return false


## Shoved, `v` (world, m/s): everyone hears it land and sees you stagger; your own machine sends you off across the
## deck (off the wheel; in the chair it only rocks you).
@rpc("any_peer", "call_local", "reliable")
func _pushed(v: Vector3) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	_gesture = "stumble"
	_gesture_t = 0.0
	Sfx.play_point(self, global_position + Vector3.UP, "kit.bodyfall", 0.8)
	if not is_multiplayer_authority() or mode != DECK or seated or aloft:
		return
	if steering:
		steering = false
		(boat.get("helm") as Node).call("request", false)
	# (off across her deck, and hard into her rail up it and over: _walk, _vault_at; up on it, off it either way)
	body.velocity = boat.global_basis.inverse() * v
	_knock = KNOCK
	_vault_t = 0.0
	_feet_t = 0.0
	_jump_y = body.position.y
	_jump_t = 0.0


## Every peer, every frame: going in (a splash, a ring of foam, water over your eyes) and coming up again (a gasp).
func _water_fx(delta: float) -> void:
	var ocean := _ocean()
	if mode != SWIM:
		_wet = mode == CLIMB
		_under = false
		_breath = 1.0
		_winded = false
		if _lens and ocean != null:
			# (out of it: the visor's the weather's again)
			_lens = false
			var sea: Node = boat.get("sea") if boat else null
			var visor: CanvasLayer = sea.get("visor") if sea else null
			if visor != null:
				visor.visible = float(ocean.get("rain")) > 0.0
		return
	if ocean == null:
		return
	_strokes(delta, ocean)
	var at := global_position
	var water := float(ocean.call("height_at", at))
	_in_for += delta
	if not _wet and at.y < water:
		_wet = true
		_in_for = 0.0
		var hard := clampf(absf(_swim_v.y) * 0.3 + 0.6, 0.6, 1.8) if is_multiplayer_authority() else 1.2
		_splash.burst(Vector3(at.x, water, at.z), hard)
		splashes += 1
		if is_multiplayer_authority():
			var sea: Node = boat.get("sea") if boat else null
			var visor: Node = sea.get("visor") if sea else null
			if visor != null:
				visor.call("splash", 1.0)
	var eye := at.y + 1.62           # (your own camera's kept out of it: where your eyes would be)
	var under := eye < water - 0.05
	if _under and not under and _wet:
		gasps += 1
		_voice.stream = Voice.gasp()
		_voice.pitch_scale = randf_range(0.95, 1.08)
		_voice.play()
	_under = under


## Every peer, swimming: each stroke's pull a slap of water at your hands (none treading water, none under), and
## going hard (sprinting, or out of breath) a blow every other one. Your own stroke's yours (_swim); a crewmate's is
## worked out here from how fast they're going, near enough.
func _strokes(delta: float, ocean: Node) -> void:
	var moved := (_local - _prev_local) * float(Engine.physics_ticks_per_second)
	var pace := Vector2(moved.x, moved.z).length()
	if not is_multiplayer_authority():
		var k := clampf(pace / SWIM_SPEED, 0.0, 1.0)
		_stroke = fmod(_stroke + delta * lerpf(STROKE * TREAD, STROKE, k) * (1.0 + 0.5 * smoothstep(SWIM_SPEED,
				SWIM_FAST, pace)), 1.0)
	var came_round := _stroke < _stroke_was
	_stroke_was = _stroke
	if not came_round or pace < 0.4 or _under or not _wet:
		return
	strokes += 1
	var hands := global_transform * Vector3(0.0, 0.0, -0.5)
	var water := float(ocean.call("height_at", hands))
	Sfx.play_point(self, Vector3(hands.x, water, hands.z), "dock.slap", clampf(0.12 + 0.12 * pace, 0.12, 0.45),
			randf_range(1.3, 1.55))
	var hard := pace > SWIM_SPEED * 1.2 or _breath < 0.35
	if hard and strokes % 2 == 0 and not _voice.playing:
		_voice.stream = Voice.blow()
		_voice.pitch_scale = randf_range(0.94, 1.08)
		_voice.play()


## Every frame: your spot (smoothed between physics ticks) carried by its frame as it is right now: the boat, or the
## world in the sea.
func _process(delta: float) -> void:
	var f := Engine.get_physics_interpolation_fraction()
	if _hop_settle:
		_hop_settled()        # (someone else, gone into another frame by their word)
	var x := _xf(frame)
	var local := _prev_local.lerp(_local, f)
	if is_multiplayer_authority():
		_pad_look(delta)
	if _hop_carry:
		# (into another frame since the last one drawn: each has gone on its own way since; you're shown where the one
		# you were in would have carried you, easing over)
		_hop_carry = false
		var carried := _xf(_hop_from) * _hop_from_xf.affine_inverse() * _hop_to_xf * (local + _hop_off)
		var off := x.affine_inverse() * carried - local
		if _hop_bake:
			# (in the air, from one frame into the next: the step's only the frames being posed at different moments,
			# not you going anywhere, so it's where you are from now on rather than a step to ease away)
			var by := off - _hop_off
			_local += by
			_prev_local += by
			local += by
			_shown_at += by
			if mode == DECK:
				body.position += by       # (down into her deck space already: _drop_in)
			off = _hop_off
		_hop_bake = false
		_hop_off = off
	if delta > 0.0:
		# coming down fast and your feet stopped (out of the air, a jump on deck; anyone, as they're shown): your
		# knees take it, your eyes going on down
		var vy := (local.y + _hop_off.y - _shown_at.y) / delta
		if mode == DECK and not seated and not aloft and _shown_vy < -1.0 and vy > _shown_vy:
			_knees_v += (minf(vy, 0.0) - _shown_vy) * KNEES
		_shown_vy = vy
	_shown_at = local + _hop_off
	if _hop_off != Vector3.ZERO:
		var o := _ease_hop(_hop_off, _hop_off_v, delta)
		_hop_off = o[0]
		_hop_off_v = o[1]
	if _hop_fix != Vector3.ZERO:
		var o := _ease_hop(_hop_fix, _hop_fix_v, delta)
		_hop_fix = o[0]
		_hop_fix_v = o[1]
	if _hop_tilt != Quaternion.IDENTITY:
		_hop_tilt = _hop_tilt.slerp(Quaternion.IDENTITY, 1.0 - exp(-delta / HOP_TILT))
		if _hop_tilt.angle_to(Quaternion.IDENTITY) < 0.0005:
			_hop_tilt = Quaternion.IDENTITY
	global_transform = x * Transform3D(Basis(_hop_tilt) * Basis(Vector3.UP, _yaw), local + _hop_off)
	_pose_body(delta)
	_water_fx(delta)
	# (the settings page's field of view, live as it's dragged; closing in steadying the harpoon)
	cam.fov = (Settings.fov - 9.0 * kick) * (1.0 - 0.18 * steady)
	# Your eyes: lower in the fighting chair; level out part of the deck's tilt, keep your own look.
	head.position.y = move_toward(head.position.y + _knees_shown, 1.62 - (_seat_drop() if seated else 0.0),
			delta * 2.0)
	# (and down out of the air: your knees give, your eyes going on down a little and springing back up)
	if _knees != 0.0 or _knees_v != 0.0:
		_knees_v -= (KNEES_SPRING * _knees + 1.7 * sqrt(KNEES_SPRING) * _knees_v) * delta
		_knees = clampf(_knees + _knees_v * delta, -0.05, 0.35)
		if absf(_knees) < 0.001 and absf(_knees_v) < 0.01:
			_knees = 0.0
			_knees_v = 0.0
	head.position.y -= _knees
	_knees_shown = _knees
	# the rod's butt down in the fighting chair's gimbal, or out of it (rods.gd's _in_hands), a bit at a time
	var in_chair := seated and is_instance_valid(sat_in) and sat_in.get("chair") != null
	chair_k = move_toward(chair_k, 1.0 if in_chair else 0.0, delta * 3.0)
	var tilted := global_transform.basis.orthonormalized()
	var level := Basis(Vector3.UP, tilted.get_euler(EULER_ORDER_YXZ).y)
	var eyes := tilted.slerp(level, STEADY)
	var ocean := _ocean() if mode == SWIM and is_multiplayer_authority() else null
	if ocean != null:
		# afloat, the swell rolls you a little
		var n: Vector3 = ocean.call("normal_at", global_position + Vector3(0.0, FLOAT, 0.0))
		var lean := Vector3.UP.lerp(n, 0.35).normalized()
		eyes = Basis(Quaternion(Vector3.UP, lean)) * level
	if _eyes_k < 1.0:
		# (just come from another frame: your eyes ease over from where they were)
		_eyes_k = minf(_eyes_k + delta / 0.6, 1.0)
		var was := _eyes_from * Basis(Vector3.RIGHT, -_pitch)
		eyes = was.slerp(eyes, smoothstep(0.0, 1.0, _eyes_k))
	if is_multiplayer_authority() and leased() and not is_nan(cam_goal.x):
		# a fish on: your look eases round to where the line goes in, following the rod part of the way
		var k := 1.0 - exp(-8.0 * delta)
		_yaw += clampf(wrapf(cam_goal.x - _yaw, -PI, PI) * k, -6.0 * delta, 6.0 * delta)
		_pitch += clampf((cam_goal.y - _pitch) * k, -6.0 * delta, 6.0 * delta)
	head.global_basis = eyes * Basis(Vector3.RIGHT, _pitch)
	if ocean != null:
		_eyes_afloat(ocean, delta)
	elif is_multiplayer_authority() and _murk != null and _murk.visible:
		_murk.visible = false
		cam.environment = null
	if is_multiplayer_authority():
		if mode == DECK:
			_lurch(delta)
		if shake > 0.02:
			var t := Time.get_ticks_msec() * 0.001
			var tremble := Vector3(sin(t * 31.0) + sin(t * 13.0 + 2.0), sin(t * 23.0 + 1.0), 0.0) * 0.006 * shake
			head.global_basis = head.global_basis * Basis.from_euler(tremble + Vector3(-0.035 * shake, 0.0, 0.0))
		if kick > 0.002:
			var jolt := Time.get_ticks_msec() * 0.001
			head.global_basis = head.global_basis * Basis.from_euler(Vector3(-0.06 * kick,
					0.012 * kick * sin(jolt * 41.0), 0.02 * kick * sin(jolt * 29.0 + 1.0)))
		_update_prompt()


## Your eyes in the sea: rising with each stroke's pull and nodding with it; kept at the waterline, never under it
## unless you are (diving, or plunged in), and the waves washing over the lens (the visor) when one comes up round it;
## under, the murk, darker as your breath runs out.
func _eyes_afloat(ocean: Node, delta: float) -> void:
	var going := clampf(Vector2(_swim_v.x, _swim_v.z).length() / SWIM_SPEED, 0.0, 1.0)
	var bob := BOB * sin(TAU * _stroke) * lerpf(0.4, 1.0, going)
	head.global_basis = head.global_basis * Basis(Vector3.RIGHT, 0.04 * cos(TAU * _stroke) * going)
	head.global_position.y += bob
	var water := float(ocean.call("height_at", head.global_position))
	var at_water := float(ocean.call("height_at", global_position))
	# (how far under where the sea would hold you you are: your eyes may go that far under the waterline too)
	var deep := maxf(0.0, at_water - FLOAT - global_position.y - 0.2)
	head.global_position.y = maxf(head.global_position.y, water + 0.06 - deep)
	var clear := head.global_position.y - water
	if clear < 0.09 and _clear >= 0.15 and _wet and deep <= 0.0:
		var sea: Node = boat.get("sea") if boat else null
		var visor: Node = sea.get("visor") if sea else null
		if visor != null:
			visor.call("splash", randf_range(0.25, 0.45))
	_clear = clear if clear < 0.09 or clear >= 0.15 else _clear
	# the lens wet while you're in (the visor, shown whatever the weather: sea/sea.gd hides it when it isn't raining)
	var sea: Node = boat.get("sea") if boat else null
	var visor: CanvasLayer = sea.get("visor") if sea else null
	if visor != null and not visor.visible:
		visor.visible = true
		_lens = true
	if _murk != null:
		var under := clear < -0.02
		_murk.visible = under
		# (and the sea's own murk: your camera's world under the surface, a few metres of seeing in it)
		cam.environment = _deep_sea() if under else null
		if under:
			_murk.color.a = clampf(0.2 + 0.08 * -clear + 0.5 * (1.0 - _breath), 0.2, 0.85)


## Under the sea: green-blue water all round, thick enough that a hull a few metres off is a shadow and past ten
## metres there's nothing; the light from above.
func _deep_sea() -> Environment:
	if _deep == null:
		_deep = Environment.new()
		_deep.background_mode = Environment.BG_COLOR
		_deep.background_color = Color(0.04, 0.2, 0.22)
		_deep.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_deep.ambient_light_color = Color(0.3, 0.55, 0.55)
		_deep.ambient_light_energy = 0.8
		_deep.fog_enabled = true
		_deep.fog_light_color = Color(0.05, 0.24, 0.26)
		_deep.fog_density = 0.18
		_deep.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		_deep.fog_sky_affect = 1.0
	return _deep


## A big sea throwing the deck about: lose your feet now and then (a stumble, everyone sees), not at the wheel.
func _lurch(delta: float) -> void:
	if delta <= 0.0:
		return
	var y := boat.global_position.y
	var vy := (y - _deck_y) / delta
	var jerk := absf(vy - _deck_vy)
	_deck_y = y
	_deck_vy = lerpf(_deck_vy, vy, minf(delta * 10.0, 1.0))
	_stumble_in -= delta
	var out := on_rail() if jerk > LURCH * RAIL_LURCH and _stumble_in <= 0.0 else Vector3.ZERO
	if out != Vector3.ZERO:
		# thrown off her rail: over the side if it's dipping that way, else down onto her deck
		_stumble_in = 5.0
		gesture("stumble")
		var way := out if (boat.global_basis * out).y < -0.04 else -out
		body.velocity = way * 2.2 + Vector3.UP * 1.2
		_knock = KNOCK
	elif jerk > LURCH and _stumble_in <= 0.0 and not steering and body.is_on_floor():
		_stumble_in = 5.0
		gesture("stumble")


## At the dock (boat/fish_hold.gd): the dock screen's up, and a click on it mustn't put you back on deck.
func _at_dock() -> bool:
	var sea: Node = boat.get("sea") if boat else null
	var hold: Node = sea.get("fish_hold") if sea else null
	var vs: Node = sea.get("vs") if sea else null        # (the sea's, or a VS side's: vs/side.gd)
	if vs != null and bool(vs.get("on")):
		return false        # (rivals: no shop at the dock, walk about while the countdown runs)
	return hold != null and bool(hold.get("docked"))


## What you're looking at that you could press E on (null: nothing): tuna/landing.gd checks you're still on the
## tuna door while you haul.
func looking_at() -> Node:
	return _looked_at()


func _looked_at() -> Node:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * REACH)
	q.collide_with_areas = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return null
	var n := hit["collider"] as Node
	while n and not n.is_in_group("interactable"):
		n = n.get_parent()
	return n


## What E would act on: what you're looking at, else a ladder you're right by (its foot from the water, its top on
## her deck facing aft: no need to find it with the crosshair).
func _target() -> Node:
	var t := _looked_at()
	return t if t != null else _ladder_near()


func _ladder_near() -> Node3D:
	if mode == SWIM:
		var best: Node3D = null
		var near := GRAB
		for b: Node3D in _boats():
			var ladder: Node3D = b.get("ladder")
			if ladder == null:
				continue
			var foot := ladder.global_transform * Vector3(0.0, 0.0, 0.42)
			var d := Vector2(foot.x - global_position.x, foot.z - global_position.z).length()
			if d < near:
				near = d
				best = ladder
		return best
	if mode == DECK and boat != null and not steering and not seated and not aloft:
		var ladder: Node3D = boat.get("ladder")
		if ladder == null:
			return null
		var spot: Vector3 = ladder.get("spot")
		var top := Vector3(spot.x, body.position.y, spot.z - 0.75)
		var aft := (Basis(Vector3.UP, _yaw) * Vector3.FORWARD).z
		if body.position.distance_to(top) < GRAB_DECK and aft > 0.4:
			return ladder
	return null


func _update_prompt() -> void:
	var t := _target()
	var text := ""
	if mode == CLIMB:
		text = "W|Up the ladder, S down, E lets go"
	elif t:
		text = str(t.call("interact_prompt")) if t.has_method("interact_prompt") else "Use"
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
