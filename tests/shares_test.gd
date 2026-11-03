extends Node
## The crew's shares and the quota: the first quota's sized for two ($12,000, then 1.4 times as much each time), the
## same alone (no discount); and each crewmate aboard past the second takes 12% of the gross of every fish sold, a
## "Share, <name>" line on the sale slip (the buyer's slip on the quay and the dock's), off what goes in the bank and
## toward the quota. Two aboard keep it all.
## Run: godot --headless --fixed-fps 30 --path . res://tests/shares_test.tscn

const Sea := preload("res://sea/sea.gd")
const FishHold := preload("res://boat/fish_hold.gd")

var fails: Array[String] = []


func _ready() -> void:
	var q := [FishHold.quota_for(1), FishHold.quota_for(2), FishHold.quota_for(3), FishHold.quota_for(4)]
	_check(q == [12000, 17000, 23500, 33000], "the quotas: %s" % str(q))
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	_check(hold.quota == 12000, "alone, the first quota's the same $12,000 (%d)" % hold.quota)
	# two aboard: no shares
	var slots: Dictionary = sea.crew.slots
	slots[2] = 1
	var two := await _trip(sea, 200.0)
	_check(_shares(two).is_empty(), "two aboard keep it all: no shares on the slip")
	# four aboard: the third and fourth take theirs
	slots[3] = 2
	slots[4] = 3
	var bank0 := hold.bank
	var earned0 := hold.earned
	var four := await _trip(sea, 200.0)
	var lines: Array = four.get("lines", [])
	var gross := 0
	for l: Array in lines:
		gross += int(l[2])
	var shares := _shares(four)
	var names := shares.keys()
	names.sort()
	_check(names == ["Share, Green", "Share, Red"], "four aboard: a share each for the third and fourth (%s)" % str(names))
	var each := roundi(gross * FishHold.SHARE)
	_check(shares.values().all(func(v: int) -> bool: return absi(v - each) <= 1),
			"12%% of the gross each ($%d of $%d: %s)" % [each, gross, str(shares.values())])
	var fuel := 0
	for c: Array in four.get("costs", []):
		if not str(c[0]).begins_with("Share, "):
			fuel += int(c[1])          # (the fuel and the charter)
	var net := gross - 2 * each
	_check(absi(hold.bank - (bank0 + net - fuel)) <= 2 and absi(hold.earned - (earned0 + net)) <= 2,
			"the bank and the quota get the rest (bank +%d, quota +%d, of $%d gross)" % [hold.bank - bank0,
			hold.earned - earned0, gross])
	_check(absi(int(four["total"]) - (net - fuel)) <= 2, "the slip's day total's after the shares (%d)" % int(four["total"]))
	# on the buyer's slip on the quay, in its own pixel letters
	var places: Node = sea.get("places")
	var box := VBoxContainer.new()
	add_child(box)
	places.set("_card_box", box)
	places.call("_fill_slip")
	var texts := _texts(box)
	_check(texts.any(func(t: String) -> bool: return t.begins_with("SHARE, GREEN"))
			and texts.any(func(t: String) -> bool: return t.begins_with("SHARE, RED")),
			"the buyer's slip says so: %s" % ", ".join(texts.filter(func(t: String) -> bool: return t.begins_with("SHARE"))))
	slots.erase(2)
	slots.erase(3)
	slots.erase(4)
	_done()


## A trip: out, a `kg` fish aboard, in, sold. The sale.
func _trip(sea: Sea, kg: float) -> Dictionary:
	var hold := sea.fish_hold
	hold.head_out("sportfisher")
	await get_tree().process_frame
	hold.host_add(kg, 300.0)
	await get_tree().process_frame
	hold.head_in()
	hold.host_sell_all()
	await get_tree().process_frame
	return hold.sale.duplicate(true)


## The slip's share lines: name -> dollars.
func _shares(sale: Dictionary) -> Dictionary:
	var out := {}
	for c: Array in sale.get("costs", []):
		if str(c[0]).begins_with("Share, "):
			out[str(c[0])] = int(c[1])
	return out


func _texts(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	return out


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("SHARES TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
