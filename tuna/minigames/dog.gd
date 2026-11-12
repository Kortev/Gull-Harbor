extends "res://tuna/minigames/pump.gd"
## He's dogging: the pump (pump.gd), but he kicks. When the meter flares, let go of B till he's done.


func _init() -> void:
	super()
	id = "dog"
	title = "HE'S DOGGING"
	moves = ["dog", "sound"]
	can_boss = false
	from = 0.1
	kicks = true
