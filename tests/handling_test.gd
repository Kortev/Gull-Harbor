extends Node
## Working a fish on deck with your own hands (boat/fish_hold.gd, tuna/handling.gd), each act done the way a player
## does it (the knife, bare hands, the gaff, the scoop, aimed with the crosshair): the spike (on the spot it shivers
## and goes limp; off it, or as it kicks, it glances off and the fish fights), the bleed (the cut's depth by how long
## you hold; the blood running out, faster for every pump of the tail; too light a cut can be cut again), the gut, a
## mate pinning it down (no flops, a slower burn), into the box and packed under ice a scoop at a time; and the sale's
## grades with why, on the slip: a fish worked quick and clean grades #1, one left to thrash and sold warm #3.
## Run: godot --headless --fixed-fps 30 --path . res://tests/handling_test.tscn

const Sea := preload("res://sea/sea.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const Handling := preload("res://tuna/handling.gd")
const Tuna := preload("res://tuna/tuna.gd")

var fails: Array[String] = []
var sea: Sea
var me: Node3D
var hold: FishHold


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await _wait(0.3)
	sea.schools.set("_next", 9999.0)
	hold = sea.fish_hold
	hold.owned = ["skiff", "sportfisher"]
	hold.head_out("sportfisher")
	await _wait(0.3)
	me = sea.crew.me
	me.force_input = true
	await _spike()
	await _bleed()
	await _gut_and_pin()
	await _ice()
	await _grades()
	for f in fails:
		print("FAIL ", f)
	print("HANDLING TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


## A fresh fish on deck: its id, its Tuna, its handle; it lies still between kicks unless `kicks`.
func _fish(kg := 150.0, kicks := false) -> Array:
	hold.host_add(kg, 60.0)
	await _frames(2)
	var f: Dictionary = hold.fish[hold.fish.size() - 1]
	var id := int(f["id"])
	if not kicks:
		hold._kick_in[id] = 999.0
	var t: Tuna = hold._deck[id]
	return [id, t, t.get_node("Handle"), f]


func _f(id: int) -> Dictionary:
	return hold._fish_of(id)


## Stand beside fish `t` and put the crosshair on it at `u` along it (snout -0.5 .. tail 0.5), nudging it on as a
## player would till it's there.
func _aim(t: Tuna, u: float) -> void:
	var boat := sea.boat as Node3D
	var local := boat.global_transform.affine_inverse() * hold._on_fish(t, u)
	me.place(Vector3(local.x, float(boat.spec["deck"]) + 0.05, local.z - 1.2), PI)
	var goal := u
	for k in 6:
		var at: Vector3 = hold._on_fish(t, goal)
		for j in 2:
			await get_tree().process_frame
			var cam: Camera3D = me.get("cam")
			var d := boat.global_basis.inverse() * (at - cam.global_position)
			me.set("_yaw", atan2(-d.x, -d.z))
			me.set("_pitch", atan2(d.y, Vector2(d.x, d.z).length()))
		await get_tree().process_frame
		var now := hold.aim_u(int(str(t.name).trim_prefix("OnDeck")), me)
		if not is_nan(now):
			goal += (u - now) * 0.8


## Left mouse held on fish `handle` with `item` for `s` seconds, then let go (as crew/hands.gd does it).
func _hold_on(handle: Node, item: String, s: float) -> bool:
	var took := bool(handle.call("use_item", me, item, true))
	await _wait(s)
	handle.call("use_item", me, item, false)
	await _frames(2)
	return took


func _spike() -> void:
	var a := await _fish()
	var id: int = a[0]
	var t: Tuna = a[1]
	var h: Node = a[2]
	me.hands.pick("knife")
	await _frames(6)
	# where the knife's going in says itself
	await _aim(t, Handling.BRAIN)
	_check(is_nan(hold.aim_u(id, me)) == false and absf(hold.aim_u(id, me) - Handling.BRAIN) < 0.02,
			"the crosshair on its head, just behind the eye (%.3f)" % hold.aim_u(id, me))
	_check(str(h.call("interact_prompt")) == "HOLD LMB|SPIKE HIM", "on the spot: %s" % h.call("interact_prompt"))
	await _aim(t, Handling.CUT_AT)
	_check(str(h.call("interact_prompt")).contains("CUT"), "under the fin: %s" % h.call("interact_prompt"))
	# off the spot, still on its head: it glances off
	await _aim(t, Handling.BRAIN + 0.06)
	await _hold_on(h, "knife", Handling.SPIKE_HOLD + 0.2)
	await _frames(2)
	_check(float(_f(id)["spiked_s"]) < 0.0 and int(_f(id)["misses"]) == 1, "a hand's width off: glanced off, still alive")
	_check(float(_f(id)["thrash"]) >= Handling.MISS_THRASH, "and it fought you (thrash %.1f s)" % float(_f(id)["thrash"]))
	# a tap is nothing
	await _aim(t, Handling.BRAIN)
	await _hold_on(h, "knife", 0.1)
	_check(float(_f(id)["spiked_s"]) < 0.0 and int(_f(id)["misses"]) == 1, "a tap of the point: nothing done")
	# it kicks under the knife: glances off
	hold._kick_in[id] = 0.15
	await _hold_on(h, "knife", Handling.SPIKE_HOLD + 0.2)
	hold._kick_in[id] = 999.0
	_check(float(_f(id)["spiked_s"]) < 0.0 and int(_f(id)["misses"]) == 2, "it flopped while you pushed: glanced off")
	# on the spot, held still: clean
	await _aim(t, Handling.BRAIN)
	var took := await _hold_on(h, "knife", Handling.SPIKE_HOLD + 0.2)
	_check(took and float(_f(id)["spiked_s"]) >= 0.0, "on the spot, held still: spiked")
	await _frames(3)
	_check(t.limp and t.shiver > 0.3, "it shivers (%.2f) and goes limp" % t.shiver)
	var kicked := t.effort
	hold._kick_in[id] = 0.0
	await _frames(10)
	_check(t.effort <= kicked + 0.01, "dead still: no more kicks")
	_check(int(Handling.Sfx.heard.get("spike", 0)) > 0, "a crack as it goes in")
	me.hands.pick("")


func _bleed() -> void:
	var a := await _fish()
	var id: int = a[0]
	var t: Tuna = a[1]
	var h: Node = a[2]
	me.hands.pick("knife")
	await _frames(6)
	await _aim(t, Handling.CUT_AT)
	# too light: a shallow cut
	await _hold_on(h, "knife", Handling.CUT_FULL * 0.25)
	var shallow := float(_f(id)["cut_q"])
	_check(shallow > 0.0 and shallow < 0.6 and float(_f(id)["bled_s"]) >= 0.0, "a light cut: shallow (%.2f)" % shallow)
	_check(str(h.call("interact_prompt")).contains("CUT"), "a poor cut can be cut again: %s" % h.call("interact_prompt"))
	# to the mark: clean
	await _hold_on(h, "knife", Handling.CUT_FULL * 0.6)
	var clean := float(_f(id)["cut_q"])
	_check(clean > 0.9, "held to the mark: a clean cut (%.2f)" % clean)
	await _frames(4)
	var stream: GPUParticles3D = hold._streams.get(id)
	_check(stream != null and stream.emitting, "its blood running from the cut")
	var blood := t.get_node_or_null("Blood") as Node3D
	_check(blood != null and blood.visible, "the pool under it")
	var d0 := Handling.drain(_f(id), hold._now())
	await _wait(1.0)
	var d1 := Handling.drain(_f(id), hold._now())
	_check(d1 > d0 and d1 < 0.3, "it runs out on its own, slowly (%.2f -> %.2f)" % [d0, d1])
	# empty-handed, pump its tail
	me.hands.pick("")
	await _frames(6)
	await _aim(t, 0.4)
	_check(str(h.call("interact_prompt")) == "LMB|PUMP THE TAIL", "bare hands on its tail: %s" % h.call("interact_prompt"))
	for k in 6:
		await _hold_on(h, "", 0.05)
		await _wait(Handling.PUMP_EVERY)
	_check(int(_f(id)["pumps"]) == 6, "six pumps of the tail (%d)" % int(_f(id)["pumps"]))
	var d2 := Handling.drain(_f(id), hold._now())
	_check(d2 > d1 + 0.35, "each a gout: it's run out a lot faster (%.2f)" % d2)
	_check(int(Handling.Sfx.heard.get("pump", 0)) >= 6 and int(Handling.Sfx.heard.get("cut", 0)) > 0, "heard: the cut, the pumps")
	# a fish cut too deep
	me.hands.pick("knife")
	var b := await _fish()
	await _frames(6)
	await _aim(b[1], Handling.CUT_AT)
	await _hold_on(b[2], "knife", Handling.CUT_FULL + 0.3)
	var deep: Dictionary = _f(b[0])
	_check(float(deep["cut_d"]) >= 0.99 and float(deep["cut_q"]) < 0.6, "held on: through to the loin (%.2f)" % float(deep["cut_q"]))
	_check(Handling.reasons(deep, hold._now()).any(func(r: Array) -> bool: return r[0] == "CUT THE LOIN"),
			"and the slip will say so")
	# the knife held well off the line of the artery
	var c := await _fish()
	await _frames(6)
	await _aim(c[1], Handling.CUT_AT + 0.09)
	await _hold_on(c[2], "knife", Handling.CUT_FULL * 0.6)
	_check(float(_f(c[0])["cut_q"]) < 0.65, "deep enough but off the artery: a poor cut (%.2f)" % float(_f(c[0])["cut_q"]))
	me.hands.pick("")


func _gut_and_pin() -> void:
	var a := await _fish(150.0, true)
	var id: int = a[0]
	var t: Tuna = a[1]
	var h: Node = a[2]
	# a mate's bare hands pinning it down (as the host hears it from another peer)
	hold._act_on(2, id, "pin", 1.0, 0.0)
	_check(int(_f(id)["pins"]) == 1, "a mate's pinning it down")
	var th0 := float(_f(id)["thrash"])
	await _wait(1.0)
	var pinned_rate := float(_f(id)["thrash"]) - th0
	_check(pinned_rate < 0.6, "pinned, it burns itself up slower (%.2f s a second)" % pinned_rate)
	hold._kick_in[id] = 0.0
	await _frames(2)
	_check(t.effort < 0.5, "and its kicks come to nothing (%.2f)" % t.effort)
	hold._act_on(2, id, "pin", 0.0, 0.0)
	_check(int(_f(id)["pins"]) == 0, "let go")
	th0 = float(_f(id)["thrash"])
	await _wait(1.0)
	_check(float(_f(id)["thrash"]) - th0 > 0.8, "loose, it thrashes (%.2f s)" % (float(_f(id)["thrash"]) - th0))
	# your own bare hands on its body: you pin it
	hold._kick_in[id] = 999.0
	me.hands.pick("")
	await _frames(6)
	await _aim(t, -0.1)
	h.call("use_item", me, "", true)
	await _frames(3)
	_check(int(_f(id)["pins"]) == 1 and str(me.get_meta("work", {}).get("kind", "")) == "pin", "you lean on it: pinned")
	await _frames(4)
	_check(me.hands.get("_shown") == "bare", "your gloves come up into view to do it")
	h.call("use_item", me, "", false)
	await _frames(2)
	_check(int(_f(id)["pins"]) == 0, "and let go")
	# not dead yet: no gutting
	me.hands.pick("knife")
	await _frames(6)
	await _aim(t, Handling.GUT_AT)
	await _hold_on(h, "knife", Handling.GUT_HOLD + 0.2)
	_check(not bool(_f(id)["gutted"]), "alive: the belly's not for opening yet")
	await _aim(t, Handling.BRAIN)
	await _hold_on(h, "knife", Handling.SPIKE_HOLD + 0.2)
	await _aim(t, Handling.GUT_AT)
	_check(str(h.call("interact_prompt")) == "HOLD LMB|GUT HIM", "spiked: %s" % h.call("interact_prompt"))
	await _hold_on(h, "knife", Handling.GUT_HOLD + 0.2)
	_check(bool(_f(id)["gutted"]), "drawn along the belly: gutted")
	me.hands.pick("")


func _ice() -> void:
	var a := await _fish()
	var id: int = a[0]
	hold._work(id)          # (spiked and bled: tested above)
	var lid: Node = hold._lid.get_node("Lid")
	lid.call("interact", me)
	await _wait(0.8)
	var spec: Dictionary = sea.boat.spec
	hold._ask_drop(id, spec["box"], 0.0)
	await _frames(3)
	var f := _f(id)
	_check(float(f["iced_s"]) >= 0.0 and float(f["packed"]) == 0.0, "in the box, on the ice, not packed yet")
	_check(Handling.reasons(f, hold._now()).any(func(r: Array) -> bool: return r[0] == "LOOSE ICE"), "loose: the slip would say")
	me.hands.pick("scoop")
	await _frames(6)
	_check(str(lid.call("interact_prompt")) == "LMB|ICE OVER HIM", "the scoop over the open box: %s" % lid.call("interact_prompt"))
	var heap := hold._inside.get_node("Heap%d" % (hold.iced() - 1)) as Node3D
	for k in 4:
		_check(bool(lid.call("use_item", me, "scoop", true)), "a scoop of ice over him (%d)" % (k + 1))
		await _wait(0.4)
	_check(float(_f(id)["packed"]) >= 1.0 and float(_f(id)["packed_s"]) >= 0.0, "four scoops: packed under ice")
	await _wait(0.6)
	_check(heap.visible and heap.scale.y > 0.9, "the ice heaped up over him (%.2f)" % heap.scale.y)
	_check(not (hold._inside.get_node("Back%d" % (hold.iced() - 1)) as Node3D).visible, "his back gone under it")
	_check(not bool(lid.call("use_item", me, "scoop", true)), "nothing left to pack")
	_check(int(Handling.Sfx.heard.get("ice", 0)) >= 4, "the crunch of each scoop")
	lid.call("interact", me)
	me.hands.pick("")


func _grades() -> void:
	# start the sale clean: just these two on board
	hold.fish = []
	hold._host_changed()
	await _frames(2)
	# worked quick and clean: spiked, cut right, pumped out, gutted, iced and packed, all inside a few minutes
	var good: Dictionary = {"id": 900, "kg": 180.0, "fight_s": 90.0, "aboard_t": hold._now() - 200.0, "bled_s": 20.0,
			"iced_s": 120.0, "spot": 0}
	good.merge(Handling.fresh(), true)
	good.merge({"spiked_s": 8.0, "thrash": 8.0, "cut_q": 1.0, "cut_d": 0.6, "cut_t": hold._now() - 180.0, "drain": 1.0,
			"gutted": true, "packed": 1.0, "packed_s": 140.0}, true)
	# left to thrash, never spiked, a shallow nick, sold off the deck warm
	var bad: Dictionary = {"id": 901, "kg": 180.0, "fight_s": 900.0, "aboard_t": hold._now() - 800.0, "bled_s": 500.0,
			"iced_s": -1.0, "spot": 1}
	bad.merge(Handling.fresh(), true)
	bad.merge({"thrash": 800.0, "cut_q": 0.3, "cut_d": 0.25, "cut_t": hold._now() - 300.0}, true)
	# middling: spiked late, bled half, iced but loose
	var mid: Dictionary = {"id": 902, "kg": 180.0, "fight_s": 300.0, "aboard_t": hold._now() - 400.0, "bled_s": 60.0,
			"iced_s": 300.0, "spot": 2}
	mid.merge(Handling.fresh(), true)
	mid.merge({"spiked_s": 50.0, "thrash": 50.0, "cut_q": 0.8, "cut_d": 0.5, "cut_t": hold._now() - 340.0,
			"drain": 0.55, "packed": 0.5}, true)
	hold.fish = [good, bad, mid]
	hold._host_changed()
	await _frames(2)
	hold.head_in()
	hold.host_sell_all()
	var lines: Array = hold.sale["lines"]
	_check(lines.size() == 3, "three on the slip")
	var g: Array = lines[0]
	var b: Array = lines[1]
	var m: Array = lines[2]
	print("     ", g, "\n     ", b, "\n     ", m)
	_check(str(g[1]) == "#1", "quick and clean: #1 (%s)" % g[1])
	_check(str(b[1]) == "#3", "left to thrash and sold warm: #3 (%s)" % b[1])
	_check(str(m[1]) == "#2", "late and loose: #2 (%s)" % m[1])
	_check(int(g[2]) > int(m[2]) * 1.2 and int(m[2]) > int(b[2]) * 1.2, "and paid that way: $%d, $%d, $%d" % [g[2], m[2], b[2]])
	var says := func(l: Array, w: String) -> bool: return (l[3] as Array).any(func(r: Array) -> bool: return r[0] == w)
	_check(says.call(g, "CLEAN SPIKE") and says.call(g, "ICED FAST"), "why #1: %s" % str(g[3]))
	_check((g[3] as Array).all(func(r: Array) -> bool: return bool(r[1])), "nothing against it")
	_check(says.call(b, "BURNT") and says.call(b, "WARM") and says.call(b, "NOT SPIKED"), "why #3: %s" % str(b[3]))
	_check(str((b[3] as Array)[0][0]) == "BURNT", "the worst first: %s" % str((b[3] as Array)[0][0]))
	_check(says.call(m, "LOOSE ICE") and says.call(m, "HALF BLED"), "why #2: %s" % str(m[3]))
	# on the dock board's slip, a line of why under each fish
	var menu: Node = sea.get_children().filter(func(n: Node) -> bool: return n.get_script() == load("res://ui/menu.gd"))[0]
	menu.call("_fill_board", hold, true)
	var whys: Array = menu.find_children("*", "HBoxContainer", true, false).filter(func(n: Node) -> bool: return n.has_meta("why"))
	_check(whys.size() == 3, "the slip: why under each of them (%d)" % whys.size())
	if whys.size() > 0:
		var words: Array = (whys[0] as Node).get_children().slice(1).map(func(l: Label) -> String: return l.text)
		_check(words.size() == 3 and words.has("CLEAN SPIKE"), "three words or so each: %s" % str(words))
