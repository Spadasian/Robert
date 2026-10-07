extends Node
## Hands out Kata techniques. Rewards call offer(categories): the player picks 1 of 3 techniques (or keeps the Kata
## as it is). The pool is a list of TechniqueData resources set in the Inspector.
## Temporary sources until the mini-boss and special rooms exist: the first cleared fight room teaches an Opening,
## the first Elite room a Flow (the boss teaches the Finisher). Each slot does nothing until it has a technique.

const Category = TechniqueData.Category

@export var technique_pool: Array[Resource] = []

@onready var choice_ui: Node = $"../TechniqueChoice"

var kata: Node
var busy: bool = false
var combat_reward_given: bool = false
var elite_reward_given: bool = false


func _enter_tree() -> void:
	add_to_group("technique_manager")


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		kata = player.get_node("KataComponent")
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager:
		room_manager.boss_defeated.connect(_on_boss_defeated)
		room_manager.room_cleared.connect(_on_room_cleared)


## Techniques of the given categories that the player does not own. Categories that are still empty come first:
## when any of them has techniques left, only those are used.
func get_choices(categories: Array, count: int) -> Array:
	var empty_slots: Array = categories.filter(func(category): return not kata.slots.has(category))
	var wanted: Array = empty_slots if not empty_slots.is_empty() else categories
	var candidates: Array = technique_pool.filter(func(data): return data.category in wanted and not kata.has_technique(data.id))
	candidates.shuffle()
	return candidates.slice(0, count)


## Shows the choice and equips the pick. Returns the technique taken (null if none was left or the player kept the Kata).
func offer(categories: Array, count: int = 3) -> Resource:
	while busy or _upgrade_choice_open():
		await get_tree().process_frame
	var choices: Array = get_choices(categories, count)
	if choices.is_empty():
		return null
	busy = true
	var chosen: Resource = await choice_ui.choose(choices, kata)
	busy = false
	if chosen == null:
		return null
	var was_asleep: bool = not kata.is_awake
	kata.set_technique(chosen)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and not was_asleep: # the first one shows "The Kata awakens" instead
		hud.show_message("%s learned" % chosen.display_name)
	return chosen


func _upgrade_choice_open() -> bool:
	var upgrades := get_tree().get_first_node_in_group("upgrade_manager")
	return upgrades != null and upgrades.is_choosing


func _is_player_dead() -> bool:
	return kata.get_parent().get_node("HealthComponent").is_dead()


## A boss that is not the last one teaches a Finisher.
func _on_boss_defeated(is_final: bool) -> void:
	if is_final:
		return
	await get_tree().create_timer(1.2, false).timeout
	if not _is_player_dead():
		offer([Category.FINISHER])


func _on_room_cleared() -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var type: int = room_manager.current_room_data.room_type
	var category: int
	if type == RoomData.RoomType.ELITE and not elite_reward_given:
		elite_reward_given = true
		category = Category.FLOW
	elif type == RoomData.RoomType.COMBAT and not combat_reward_given:
		combat_reward_given = true
		category = Category.OPENING
	else:
		return
	await get_tree().create_timer(1.0, false).timeout
	if not _is_player_dead():
		offer([category])
