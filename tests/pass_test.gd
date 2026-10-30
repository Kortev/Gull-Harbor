extends Node
## Working a school (tuna/schools.gd): it travels its own way and feeds at its head, so a bait eats only out in front
## of it, not behind it or off to the side; her baits don't pull it to them; run her hull over it and it goes down,
## slow or not (only a crawl doesn't); working a slick it eats all round.
## Run: godot --headless --path . res://tests/pass_test.tscn

const Sea := preload("res://sea/sea.gd")

var sea: Sea
var failed := 0


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().process_frame
	var schools: Node = sea.schools
	schools.set("_next", 9999.0)
	sea.fish_hold.head_out()
	await get_tree().process_frame
	var t: float = schools.now()
	var seed := 1
	for k in range(1, 500):
		if Sea.Schools.hash1(float(k % 977), 3.7) >= Sea.Schools.BAIT_ONLY:
			seed = k
			break
	# a school 300 m off her, heading east at 1.5 m/s
	var at := sea.boat.helm.at + Vector2(0.0, -300.0)
	schools._start(7, seed, t, at, Vector2(1, 0), 1.5, 200.0)
	var s = schools.schools[-1]
	var c: Vector2 = s.center(t)
	var r: float = s.radius
	_check(s.eats_at(c + Vector2(r + 10.0, 0.0), t), "a bait out in front of its head gets eaten")
	_check(not s.eats_at(c - Vector2(r + 10.0, 0.0), t), "one behind it doesn't")
	_check(not s.eats_at(c + Vector2(0.0, r + 25.0), t), "nor one well off to its side")
	# her baits don't pull it: left alone it goes its own way
	var was: Vector2 = s.center(schools.now())
	schools._drawing()
	await get_tree().create_timer(2.0).timeout
	var went: Vector2 = s.center(schools.now()) - was
	_check(went.normalized().dot(Vector2(1, 0)) > 0.9, "it keeps its own heading (%.1f, %.1f)" % [went.x, went.y])
	# a crawl over it doesn't put it down; trolling speed over it does
	var helm: Node = sea.boat.helm
	helm.set("at", s.center(schools.now()))
	helm.set("speed", 0.6)
	schools._spooking()
	_check(s.spooked_until < schools.now(), "a crawl over it doesn't put it down")
	helm.set("speed", 2.5)
	schools._spooking()
	_check(s.spooked_until > schools.now(), "her hull over it at trolling speed puts it down")
	# working a slick (going nowhere) it eats all round
	schools._start(8, seed, schools.now(), at + Vector2(0, -200), Vector2(1, 0), 0.0, 200.0)
	var w = schools.schools[-1]
	var wc: Vector2 = w.center(schools.now())
	_check(w.eats_at(wc - Vector2(w.radius + 3.0, 0.0), schools.now()), "a school going nowhere eats all round")
	print("PASS TEST %s" % ("PASSED" if failed == 0 else "FAILED"))
	get_tree().quit(1 if failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("FAIL ", what)
