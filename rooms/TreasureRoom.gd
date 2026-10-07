extends "res://scripts/rooms/Room.gd"
## Treasure room: no enemies, so the exit opens at once. Up to three random relics (that the player does not own yet)
## stand on pedestals; taking one removes the others. Needs a "Pedestals" node with RelicPedestal children.

@onready var pedestals_root: Node3D = $Pedestals


func start_room() -> void:
	super()
	_stock_pedestals()


func _stock_pedestals() -> void:
	var pedestals: Array = pedestals_root.get_children()
	var choices: Array = []
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		choices = run_manager.get_random_relics(pedestals.size())
	for index in pedestals.size():
		if index < choices.size():
			pedestals[index].setup(choices[index])
			pedestals[index].taken.connect(_on_relic_taken.bind(pedestals[index]))
		else:
			pedestals[index].disable()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("Choose one relic" if not choices.is_empty() else "The treasure room is empty", 2.5)


func _on_relic_taken(taken_pedestal: Node) -> void:
	for pedestal in pedestals_root.get_children():
		pedestal.disable() # the chosen one and all the others
