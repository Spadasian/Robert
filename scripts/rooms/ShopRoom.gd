extends "res://scripts/rooms/Room.gd"
## Shop room. Needs the same nodes as every room, plus a "Stands" node with ShopStand children.
## There are no enemies, so the base class opens the exit door right away.
## Each stand gets a random upgrade the player does not own yet. With a low chance, one stand sells a Kata technique instead.

const TECHNIQUE_CHANCE: float = 0.2

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
	var technique_index: int = -1
	var technique_manager := get_tree().get_first_node_in_group("technique_manager")
	if technique_manager and not stands.is_empty() and randf() < TECHNIQUE_CHANCE:
		var technique: Resource = technique_manager.get_shop_technique()
		if technique:
			technique_index = randi() % stands.size()
			stands[technique_index].setup(technique)
	for index in stands.size():
		if index == technique_index:
			continue
		if index < choices.size():
			stands[index].setup(choices[index])
		else:
			stands[index].disable()
