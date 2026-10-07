extends "res://scripts/rooms/Interactable.gd"
## Treasure room chest: gives some gold and lets you pick 1 of 3 upgrades.

@export var gold_bonus: int = 25

var opened: bool = false

@onready var lid_pivot: Node3D = $LidPivot


func get_prompt_text() -> String:
	return "Open chest"


func _interact() -> void:
	if opened:
		return
	opened = true
	set_enabled(false)
	create_tween().tween_property(lid_pivot, "rotation:x", deg_to_rad(-100.0), 0.3)
	get_tree().get_first_node_in_group("run_manager").add_gold(gold_bonus)
	await get_tree().create_timer(0.4).timeout
	await get_tree().get_first_node_in_group("upgrade_manager").offer_upgrade_choice()
