extends Node
## Picks and applies upgrades. The pool is a plain list of UpgradeData resources set in the Inspector,
## so new upgrades are just new .tres files added to the list.

@export var upgrade_pool: Array[Resource] = []

var stats: Node


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		stats = player.get_node("StatsComponent")
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager:
		room_manager.room_cleared.connect(_on_room_cleared)


## Random upgrades the player does not own yet, picked by rarity weight, no duplicates.
func get_random_choices(count: int) -> Array:
	var candidates: Array = []
	for upgrade in upgrade_pool:
		if not stats.has_upgrade(upgrade.id):
			candidates.append(upgrade)
	var choices: Array = []
	while choices.size() < count and not candidates.is_empty():
		var total_weight: float = 0.0
		for upgrade in candidates:
			total_weight += upgrade.get_weight()
		var roll: float = randf() * total_weight
		for upgrade in candidates:
			roll -= upgrade.get_weight()
			if roll <= 0.0:
				choices.append(upgrade)
				candidates.erase(upgrade)
				break
	return choices


func apply_upgrade(upgrade: Resource) -> void:
	stats.add_upgrade(upgrade)


# Temporary (livrarea A): grant one random upgrade automatically. Livrarea B replaces this with a choice screen.
func _on_room_cleared() -> void:
	var choices: Array = get_random_choices(1)
	if choices.is_empty():
		return
	var upgrade: Resource = choices[0]
	apply_upgrade(upgrade)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("ROOM CLEARED\n[%s] %s: %s" % [upgrade.get_rarity_name(), upgrade.display_name, upgrade.description], 3.5)
