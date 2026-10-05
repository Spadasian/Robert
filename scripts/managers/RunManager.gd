extends Node
## State of the current run (gold for now). Thrown away when the run ends or the player dies.
## Upgrades, relics and the room map will be added here in later phases.

signal gold_changed(gold: int)

var gold: int = 0


func _enter_tree() -> void:
	add_to_group("run_manager")


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true
