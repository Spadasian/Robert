extends "res://scripts/rooms/Room.gd"
## Shop room. Needs the same nodes as every room, plus a "Stands" node with ShopStand children.
## There are no enemies, so the base class opens the exit door right away.
## Each stand gets a random upgrade the player does not own yet.

@onready var stands_root: Node3D = $Stands


func start_room() -> void:
	super()
	_stock_stands()


func _stock_stands() -> void:
	var stands: Array = stands_root.get_children()
	var choices: Array = []
	var upgrade_manager := get_tree().get_first_node_in_group("upgrade_manager")
	if upgrade_manager:
		choices = upgrade_manager.get_random_choices(stands.size())
	for index in stands.size():
		if index < choices.size():
			stands[index].setup(choices[index])
		else:
			stands[index].disable()
