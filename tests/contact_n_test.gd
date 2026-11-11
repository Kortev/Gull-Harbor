extends Node
## Any number of boats meeting (vs/contact.gd, vs/horn.gd): with two, then three (when vs/vs.gd has host_set_boats),
## every boat's piled onto A's spot through her helm and each pair's pushed clear of each other, nobody left inside
## anybody; A's horn jerks a fish on every other boat's line and rattles you aboard the last of them, and a boat lying
## too far off is left alone while a near one isn't (each by her own distance). Between the two, the sides are rebuilt
## at the dock and contact's per-boat things are sized to the boats there are.
## First, whatever vs/vs.gd can do yet: vs/contact.gd and vs/horn.gd on their own with stand-in hulls, three and
## four of them (_stand_ins), so every pair's been tried even while the sea only builds two.
## Run: godot --headless --fixed-fps 30 --path . res://tests/contact_n_test.tscn

const Sea := preload("res://sea/sea.gd")
const Vs := preload("res://vs/vs.gd")
const Horn := preload("res://vs/horn.gd")

const AT := Vector2(300.0, -600.0)

var fails: Array[String] = []


func _ready() -> void:
	await _stand_ins()
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var vs := sea.vs
	vs.host_set_on(true)
	await get_tree().process_frame
	_check(bool(vs.on) and (vs.sides as Array).size() == 2, "two boats")
	await _fleet(sea, vs, 2)
	if not vs.has_method("host_set_boats"):
		print("skip three boats: vs/vs.gd has no host_set_boats yet (only two boats were tested)")
		_done()
		return
	# home, back to one boat, and out again as three: the sides rebuilt, contact's things re-sized
	vs.call("host_bring_home")
	await _until(func() -> bool: return (vs.sides as Array).all(func(s: Node) -> bool:
		return bool(s.get("fish_hold").get("docked"))), 5.0)
	vs.ask_team(0)
	await get_tree().create_timer(0.2).timeout
	vs.host_set_on(false)
	await get_tree().create_timer(0.3).timeout
	vs.host_set_on(true)
	await get_tree().process_frame
	vs.call("host_set_boats", 3)
	await get_tree().create_timer(0.3).timeout
	var three := bool(vs.on) and (vs.sides as Array).size() == 3
	_check(three, "three boats (%d)" % (vs.sides as Array).size())
	if three:
		await _fleet(sea, vs, 3)
	_done()


## What contact and the horn ask of a helm, a boat, a side, the sea: nothing else.
class FakeHelm extends Node3D:
	var at := Vector2.ZERO
	var heading := 0.0
	var speed := 0.0
	var drift := Vector2.ZERO
	var spin := 0.0
	var captain := 0
	var boat: Node3D
	func is_mine() -> bool:
		return false


class FakeBoat extends Node3D:
	var helm: FakeHelm
	var beam := 4.2
	var length := 12.0
	var carried: Variant = null
	var rock := Vector2.ZERO


class FakeFight extends RefCounted:
	var shock := 0.0


class FakeRod extends Node:
	var hooked := true
	var alongside := false
	var whip := 0.0
	var fight := FakeFight.new()


class FakeRods extends Node:
	var rods: Array = []


class FakeSide extends Node:
	var boat: Variant
	var rods: Variant


class FakeMe extends Node:
	var boat: Variant
	var steering := false
	var shake := 0.0
	var stumbles := 0
	func gesture(_what: String) -> void:
		stumbles += 1


class FakeCrew extends Node:
	var me: FakeMe


class FakeSea extends Node:
	var crew: FakeCrew
	var ocean: Node


class FakeVs extends Node:
	var on := true
	var sides: Array = []
	var sea: FakeSea
	var contact: Node


## vs/contact.gd and vs/horn.gd with stand-in hulls, three of them then four: piled up and pushed clear pair by pair,
## one run into another lying still (shoved, a thud, rocked: two different pairs), a wake across the rest (A's, then
## C's), the horn by each one's distance; then a boat gone with her side still listed, then one fewer, and nothing
## falls over.
func _stand_ins() -> void:
	var far: Array[float] = [0.0, 30.0, 100.0, 200.0]
	for count: int in [3, 4]:
		var tag := "stand-ins, %d boats: " % count
		var fake := FakeVs.new()
		fake.sea = FakeSea.new()
		fake.sea.crew = FakeCrew.new()
		fake.sea.crew.me = FakeMe.new()
		fake.add_child(fake.sea)
		fake.sea.add_child(fake.sea.crew)
		fake.sea.crew.add_child(fake.sea.crew.me)
		add_child(fake)
		var boats: Array = []
		var helms: Array = []
		for k in count:
			var b := FakeBoat.new()
			b.helm = FakeHelm.new()
			b.helm.boat = b
			b.add_child(b.helm)
			var side := FakeSide.new()
			side.name = "Side" + "ABCD"[k]
			side.boat = b
			var rods := FakeRods.new()
			rods.rods = [FakeRod.new()]
			rods.add_child(rods.rods[0])
			side.rods = rods
			side.add_child(rods)
			side.add_child(b)
			fake.add_child(side)
			fake.sides.append(side)
			boats.append(b)
			helms.append(b.helm)
		var contact: Node = Vs.Contact.new()
		contact.set("vs", fake)
		fake.contact = contact
		fake.add_child(contact)
		fake.sea.crew.me.boat = boats[count - 1]
		# piled on A's spot
		var off: Array[Vector2] = [Vector2.ZERO, Vector2(1.2, 0.4), Vector2(-1.2, -0.6), Vector2(0.3, 1.5)]
		for k in count:
			helms[k].at = AT + off[k]
		_check(_deepest(boats) > 0.5, tag + "piled inside each other (%.1f m)" % _deepest(boats))
		var t := 0.0
		while t < 20.0 and _deepest(boats) > 0.02:
			await _drive(contact, helms)
			t += 1.0 / 30.0
		for i in count:
			for j in range(i + 1, count):
				var c := Vs.Contact.contact(boats[i], boats[j], 1000.0)
				_check(float(c["gap"]) > -0.02, tag + "%s and %s pushed clear of each other (%.2f m apart, %.1f s)"
						% ["ABCD"[i], "ABCD"[j], float(c["gap"]), t])
		_check((contact.get("_rock") as Array).size() == count and (contact.get("bombs") as Array).size() == count
				and (contact.get("_trails") as Array).size() == count
				and (contact.get("_in_arm") as Array).size() == count, tag + "one of everything a boat")
		# the last boat run at B lying still, then at C (A, when C's the last): each shoved off, a thud, rocked
		for target: int in [1, 2]:
			var last: int = count - 1 if count - 1 != target else 0
			for k in count:
				_still(helms[k])
				helms[k].at = AT + Vector2(0.0, 80.0 * k)
			var lay: Vector2 = helms[target].at
			helms[last].at = lay + Vector2(-20.0, 0.0)
			helms[last].heading = -PI * 0.5       # (bow to +x)
			contact.set("_thud_t", -INF)
			var closest := INF
			for i in 150:
				if i < 20:
					helms[last].speed = 5.0
				await _drive(contact, helms)
				var c := Vs.Contact.contact(boats[last], boats[target], 1.0)
				if not c.is_empty():
					closest = minf(closest, float(c["gap"]))
			_check(closest < 1.0 and closest > -0.6, tag + "%s runs into %s and doesn't pass through (overlap at most %.2f m)"
					% ["ABCD"[last], "ABCD"[target], -closest])
			_check((helms[target].at as Vector2).distance_to(lay) > 1.0 and float(contact.get("_thud_t")) > -INF
					and (boats[target] as FakeBoat).rock != Vector2.ZERO, tag + "%s shoved off (%.1f m), a thud, rocked"
					% ["ABCD"[target], (helms[target].at as Vector2).distance_to(lay)])
		# a wake: A runs past the rest lying in a row
		for k in count:
			_still(helms[k])
			helms[k].at = AT + Vector2(float(k - 1) * 12.0, 0.0) if k > 0 else AT + Vector2(-60.0, 25.0)
		var slapped: Array = []
		slapped.resize(count)
		slapped.fill(false)
		for i in 30 * 16:
			helms[0].heading = -PI * 0.5
			helms[0].speed = 9.0
			await _drive(contact, helms)
			for k in range(1, count):
				slapped[k] = slapped[k] or bool((contact.get("_in_arm") as Array)[k])
		_check(range(1, count).all(func(k: int) -> bool: return slapped[k]), tag + "A's wake comes to every other (%s)"
				% [slapped.slice(1)])
		# and C's wake to A and B: any boat's, not only the first's
		for k in count:
			_still(helms[k])
			helms[k].at = AT + Vector2(float(k) * 12.0, 400.0) if k != 2 else AT + Vector2(-60.0, 425.0)
		slapped.fill(false)
		for i in 30 * 16:
			helms[2].heading = -PI * 0.5
			helms[2].speed = 9.0
			await _drive(contact, helms)
			for k in count:
				slapped[k] = slapped[k] or bool((contact.get("_in_arm") as Array)[k])
		_check(slapped[0] and slapped[1] and not slapped[2], tag + "C's wake comes to A and B, not to herself (%s)"
				% [slapped])
		# the horn: A's; B 30 m off, C 100 m, D 200 m; you aboard the last
		for k in count:
			_still(helms[k])
			helms[k].at = AT + Vector2(far[k], 0.0)
		await _drive(contact, helms)
		var horn := Horn.new()
		horn.vs = fake
		horn.team = 0
		horn.boat = boats[0]
		(boats[0] as Node).add_child(horn)
		await get_tree().process_frame
		horn.interact(null)
		_check(horn.blasts == 1, tag + "A's horn blown")
		for k in range(1, count):
			var rod: FakeRod = (fake.sides[k].rods as FakeRods).rods[0]
			var near := k < 3
			_check((rod.whip > 0.9 and rod.fight.shock >= 0.1) == near, tag + "%s, %.0f m off, %s" % ["ABCD"[k], far[k],
					"has her fish jerked" if near else "is left alone"])
		await _drive(contact, helms)
		var me := fake.sea.crew.me
		_check((me.shake > 0.3) == (count - 1 < 3), tag + "you aboard %s: %s (%.2f)" % ["ABCD"[count - 1],
				"rattled" if count - 1 < 3 else "too far off to be", me.shake])
		# a boat gone with her side still listed (the sides being rebuilt), then her side gone too
		var gone := boats[count - 1] as Node
		gone.get_parent().remove_child(gone)
		gone.free()
		for i in 3:
			await _drive(contact, helms.slice(0, count - 1))
		horn.set("_last", -INF)
		horn.interact(null)
		_check(horn.blasts == 2, tag + "a boat gone, her side still listed: nothing falls over")
		(fake.sides.pop_back() as Node).queue_free()
		for i in 3:
			await _drive(contact, helms.slice(0, count - 1))
		_check((contact.get("_rock") as Array).size() == count - 1 and (contact.get("bombs") as Array).size() == count - 1
				and (contact.get("_touching") as Array).size() == (count - 1) * (count - 1),
				tag + "one fewer: contact's things re-sized (%d)" % (contact.get("_rock") as Array).size())
		fake.on = false
		fake.queue_free()
		await get_tree().process_frame


## A frame of the stand-ins: each helm moves her boat as boat/helm.gd does (her way, her drift and spin dying off),
## fends her off the rest, and the boat's put where her helm has her.
func _drive(contact: Node, helms: Array) -> void:
	var delta := 1.0 / 30.0
	for h: FakeHelm in helms:
		h.at += Vs.Contact.Helm.ahead_of(h.heading) * h.speed * delta + h.drift * delta
		h.heading = wrapf(h.heading + h.spin * delta, -PI, PI)
		h.speed *= exp(-delta / 3.0)
		h.drift *= exp(-delta / 1.6)
		h.spin *= exp(-delta / 1.2)
		contact.call("fend", h)
		h.boat.position = Vector3(h.at.x, 0.0, h.at.y)
		h.boat.rotation.y = h.heading
	await get_tree().process_frame


## The `count` boats there are: out from the dock (you aboard the last of them), piled up and pushed clear, the horn.
func _fleet(sea: Sea, vs: Vs, count: int) -> void:
	var tag := "%d boats: " % count
	var sides: Array = vs.sides
	var boats: Array = sides.map(func(s: Node) -> Node3D: return s.get("boat"))
	var helms: Array = boats.map(func(b: Node3D) -> Node: return b.get("helm"))
	vs.ask_team(count - 1)
	await get_tree().process_frame
	_check(sea.crew.me != null and sea.crew.me.boat == boats[count - 1], tag + "you're aboard %s" % "ABCD"[count - 1])
	sea.fish_hold.call("head_out", "sportfisher")
	await get_tree().create_timer(0.3).timeout
	_check(sides.all(func(s: Node) -> bool: return not bool(s.get("fish_hold").get("docked"))), tag + "all out")
	await get_tree().process_frame
	var contact: Node = vs.contact
	_check((contact.get("_rock") as Array).size() == count and (contact.get("_rock_v") as Array).size() == count
			and (contact.get("_trails") as Array).size() == count and (contact.get("_in_arm") as Array).size() == count
			and (contact.get("bombs") as Array).size() == count, tag + "contact keeps one of everything a boat")
	# every boat on A's spot, a little off each other (so there's a way out), lying still
	var off: Array[Vector2] = [Vector2.ZERO, Vector2(1.2, 0.4), Vector2(-1.2, -0.6), Vector2(0.3, 1.5)]
	for k in count:
		_still(helms[k])
		helms[k].set("at", AT + off[k])
	for i in count:
		for j in range(i + 1, count):
			var c := Vs.Contact.contact(boats[i], boats[j])
			_check(not c.is_empty() and float(c["gap"]) < -0.5, tag + "%s and %s start inside each other (%.1f m)"
					% ["ABCD"[i], "ABCD"[j], -float(c.get("gap", 0.0))])
	var t := 0.0
	while t < 20.0 and _deepest(boats) > 0.02:
		await get_tree().process_frame
		t += 1.0 / 30.0
	for i in count:
		for j in range(i + 1, count):
			var c := Vs.Contact.contact(boats[i], boats[j], 1000.0)
			_check(float(c["gap"]) > -0.02, tag + "%s and %s pushed clear of each other (%.2f m apart, %.1f s)"
					% ["ABCD"[i], "ABCD"[j], float(c["gap"]), t])
	for k in count:
		_check((helms[k].get("at") as Vector2).distance_to(AT) < 40.0, tag + "%s not flung off (%.1f m)"
				% ["ABCD"[k], (helms[k].get("at") as Vector2).distance_to(AT)])
	# a wake: A runs past the rest lying in a row, and it comes to every one of them
	for k in count:
		_still(helms[k])
		helms[k].set("at", AT + Vector2(float(k - 1) * 12.0, 0.0) if k > 0 else AT + Vector2(-60.0, 25.0))
	var slapped: Array = []
	slapped.resize(count)
	slapped.fill(false)
	for i in 30 * 16:
		helms[0].set("heading", -PI * 0.5)       # (bow to +x)
		helms[0].set("speed", 9.0)
		for k in range(1, count):
			helms[k].set("speed", 0.0)
		await get_tree().process_frame
		for k in range(1, count):
			slapped[k] = slapped[k] or bool((contact.get("_in_arm") as Array)[k])
	for k in range(1, count):
		_check(slapped[k], tag + "A's wake comes to %s" % "ABCD"[k])
	# the horn: A's, the others 30 m off her either side and ahead, a fish on each one's line
	for k in count:
		_still(helms[k])
	helms[0].set("at", AT)
	var round_her: Array[Vector2] = [Vector2.ZERO, Vector2(30.0, 0.0), Vector2(-30.0, 0.0), Vector2(0.0, -40.0)]
	for k in range(1, count):
		helms[k].set("at", AT + round_her[k])
	var rods: Array = []
	for k in range(1, count):
		rods.append(await _hook(sea, sides[k], "ABCD"[k]))
	var horn := (boats[0] as Node).get_node_or_null("Horn")
	_check(horn != null, tag + "A's horn")
	if horn == null:
		return
	horn.call("interact", sea.crew.me)
	_check(int(horn.get("blasts")) >= 1, tag + "a blast")
	for k in range(1, count):
		var rod: Node = rods[k - 1]
		var fight: Object = rod.get("fight")
		_check(float(rod.get("whip")) > 0.9 and fight != null and float(fight.get("shock")) >= 0.1,
				tag + "A's horn jerks %s's fish on the line" % "ABCD"[k])
	await get_tree().create_timer(0.1).timeout
	_check(float(sea.crew.me.get("shake")) > 0.3, tag + "and rattles you aboard %s (%.2f)"
			% ["ABCD"[count - 1], float(sea.crew.me.get("shake"))])
	# again, the last boat lying 200 m off: she's left alone, the near ones aren't
	await get_tree().create_timer(3.0).timeout
	for rod: Node in rods:
		rod.set("whip", 0.0)
		if rod.get("fight") != null:
			(rod.get("fight") as Object).set("shock", 0.0)
	helms[count - 1].set("at", AT + Vector2(0.0, 200.0))
	await get_tree().create_timer(0.3).timeout
	var was := int(horn.get("blasts"))
	horn.set("_last", -INF)
	horn.call("interact", sea.crew.me)
	_check(int(horn.get("blasts")) == was + 1, tag + "the horn again")
	for k in range(1, count):
		var rod: Node = rods[k - 1]
		if not bool(rod.get("hooked")):
			_check(false, tag + "%s's fish still on for the second blast" % "ABCD"[k])
			continue
		var jerked := float(rod.get("whip")) > 0.9
		if k == count - 1:
			_check(not jerked, tag + "%s, 200 m off, is left alone" % "ABCD"[k])
		else:
			_check(jerked, tag + "%s, still near, isn't" % "ABCD"[k])
	for k in range(1, count):
		(sides[k].get("rods") as Node).call("host_clear")
	for k in count:
		_still(helms[k])


## A fish on side's first rod (as tests/vs_test.gd hooks one). The rod.
func _hook(sea: Sea, side: Node, who: String) -> Node:
	var rods: Node = side.get("rods")
	rods.call("host_clear")
	rods.call("_baited", 0, float(sea.ocean.wave_time), false)
	rods.call("host_cast", 0)
	await get_tree().create_timer(2.5).timeout
	rods.call("strike", 0, 150.0)
	await get_tree().create_timer(1.0).timeout
	var rod: Node = (rods.get("rods") as Array)[0]
	_check(bool(rod.get("hooked")), "a fish on %s's line" % who)
	return rod


func _still(h: Node) -> void:
	h.set("speed", 0.0)
	h.set("drift", Vector2.ZERO)
	h.set("spin", 0.0)
	h.set("heading", 0.0)


## How far the deepest pair of boats are inside each other (m; 0 when none are).
func _deepest(boats: Array) -> float:
	var deep := 0.0
	for i in boats.size():
		for j in range(i + 1, boats.size()):
			var c := Vs.Contact.contact(boats[i], boats[j])
			if not c.is_empty():
				deep = maxf(deep, -float(c["gap"]))
	return deep


func _until(ok: Callable, most: float) -> void:
	var t := 0.0
	while not bool(ok.call()) and t < most:
		await get_tree().process_frame
		t += 1.0 / 30.0


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("CONTACT N TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
