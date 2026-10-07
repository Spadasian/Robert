extends "res://scripts/rooms/Room.gd"
## A room with no enemies and a "Pedestals" node. Fills the upgrade pedestals with random upgrades.

@onready var pedestals: Node3D = $Pedestals


func start_room() -> void:
	super.start_room()
	var upgrade_manager := get_tree().get_first_node_in_group("upgrade_manager")
	var slots: Array = pedestals.get_children().filter(func(pedestal): return pedestal.item_type == 0)
	var choices: Array = upgrade_manager.get_random_choices(slots.size())
	for index in slots.size():
		if index < choices.size():
			slots[index].setup_upgrade(choices[index])
		else:
			slots[index].disable_empty()
