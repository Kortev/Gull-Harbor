extends Node
## Hosting without port forwarding: join codes turn into the right address and back, and hosting asks the router
## (UPnP) and comes back with a code either way: over the internet if the router opened the port, else for the
## home network. (There's no router in the test machine, so here it's the home-network one.)
## Run: godot --headless --path . res://tests/code_test.tscn

var fails: Array[String] = []
var t0 := 0


func _ready() -> void:
	for ip: String in ["127.0.0.1", "192.168.1.23", "86.12.200.5", "255.255.255.255", "0.0.0.0"]:
		var c := Net.encode(ip)
		if Net.decode(c) != ip or c.length() != 8:
			fails.append("%s -> %s -> %s" % [ip, c, Net.decode(c)])
	if Net.decode(Net.encode("86.12.200.5").to_lower().replace("-", " ")) != "86.12.200.5":
		fails.append("lower case / spaces not read")
	for bad: String in ["hello", "127.0.0.1", "ABCD-EF0", ""]:
		if not Net.decode(bad).is_empty():
			fails.append("'%s' read as a code" % bad)
	Net.opened.connect(_on_opened)
	t0 = Time.get_ticks_msec()
	if Net.host() != OK:
		fails.append("couldn't host")
		_done()


func _on_opened(ok: bool, code: String) -> void:
	print("CODE opened ok=%s code=%s (%s) after %d ms" % [ok, code, Net.decode(code), Time.get_ticks_msec() - t0])
	if Net.decode(code).is_empty():
		fails.append("no usable code")
	Net.leave()
	_done()


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - t0 > 10000:
		fails.append("the router never answered (10 s)")
		_done()


func _done() -> void:
	print("CODE TEST " + ("PASSED" if fails.is_empty() else "FAILED: " + ", ".join(fails)))
	get_tree().quit(0 if fails.is_empty() else 1)
	set_process(false)
