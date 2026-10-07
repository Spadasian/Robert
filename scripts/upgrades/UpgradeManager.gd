extends Node
## Picks and applies upgrades. The pool is a plain list of UpgradeData resources set in the Inspector,
## so new upgrades are just new .tres files added to the list.

@export var upgrade_pool: Array[Resource] = []

@onready var choice_ui: Node = $"../UpgradeChoice"

var stats: Node
var is_choosing: bool = false # TechniqueManager waits while an upgrade choice is open


func _enter_tree() -> void:
	add_to_group("upgrade_manager")


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


func _on_room_cleared() -> void:
	await get_tree().create_timer(0.6, false).timeout # let the player see the last kill (false: waits while paused)
	if stats.get_parent().get_node("HealthComponent").is_dead():
		return
	var choices: Array = get_random_choices(3)
	if choices.is_empty():
		return
	is_choosing = true
	var chosen: Resource = await choice_ui.choose(choices)
	is_choosing = false
	apply_upgrade(chosen)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("%s acquired" % chosen.display_name)
