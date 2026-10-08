extends Node
## Hands out Kata techniques. Rewards call offer(): the player picks 1 of 3 techniques (or keeps the Kata as it is).
## The pool is a list of TechniqueData resources set in the Inspector.
## The order does not depend on where the reward comes from: the first offer is 3 Openings, the second 3 Flows, the
## third 3 Finishers (the first empty slot of the chain). After that the cards are random parts of any category, so
## the player builds a style of their own. `categories` passed by the sources is only a hint and is ignored.
## Techniques come only from the mini-boss, bosses, special rooms (they call offer()) and, rarely and expensively,
## from the shop (see get_shop_technique()). Ordinary fight rooms never give any. Each slot does nothing until it has one.

const Category = TechniqueData.Category

@export var technique_pool: Array[Resource] = []

@onready var choice_ui: Node = $"../TechniqueChoice"

var kata: Node
var busy: bool = false
var offer_pending: bool = false # a reward is about to be offered (UpgradeManager waits for it)


func _enter_tree() -> void:
	add_to_group("technique_manager")


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		kata = player.get_node("KataComponent")
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager:
		room_manager.boss_defeated.connect(_on_boss_defeated)
		room_manager.miniboss_defeated.connect(_on_miniboss_defeated)


const CHAIN: Array = [Category.OPENING, Category.FLOW, Category.FINISHER]


## The first empty slot of the chain Opening -> Flow -> Finisher, or -1 when the chain is complete.
func next_chain_category() -> int:
	for category in CHAIN:
		if not kata.slots.has(category):
			return category
	return -1


## The cards of an offer: while the chain is incomplete, `count` techniques of the next category; afterwards a random
## mix of all categories (one of each category first, so the cards are usually different parts).
## `categories` is ignored (kept so the sources do not need to change). Techniques already owned are never offered.
func get_choices(_categories: Array, count: int, add_master: bool = false) -> Array:
	var owned_free: Array = technique_pool.filter(func(data): return not kata.has_technique(data.id))
	var next: int = next_chain_category()
	var choices: Array = []
	if next >= 0:
		var of_next: Array = owned_free.filter(func(data): return data.category == next)
		of_next.shuffle()
		choices = of_next.slice(0, count)
	else:
		var buckets: Array = []
		for category in CHAIN:
			var group: Array = owned_free.filter(func(data): return data.category == category)
			group.shuffle()
			buckets.append(group)
		buckets.shuffle()
		while choices.size() < count and buckets.any(func(group): return not group.is_empty()):
			for group in buckets:
				if not group.is_empty() and choices.size() < count:
					choices.append(group.pop_front())
	if add_master and next < 0:
		# one card becomes a Master technique (a reward for a hard challenge) once the chain is complete,
		# if the player has one left to find
		var masters: Array = owned_free.filter(func(data): return data.category == Category.MASTER)
		if not masters.is_empty():
			if choices.size() >= count:
				choices.pop_back()
			choices.append(masters.pick_random())
	return choices


## Shows the choice and equips the pick. Returns the technique taken (null if none was left or the player kept the Kata).
func offer(categories: Array, count: int = 3, add_master: bool = false) -> Resource:
	while busy or _upgrade_choice_open():
		await get_tree().process_frame
	offer_pending = false
	var choices: Array = get_choices(categories, count, add_master)
	if choices.is_empty():
		return null
	busy = true
	var chosen: Resource = await choice_ui.choose(choices, kata, _title_for(choices))
	busy = false
	if chosen == null:
		return null
	var was_asleep: bool = not kata.is_awake
	kata.set_technique(chosen)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and not was_asleep: # the first one shows "The Kata awakens" instead
		hud.show_message("%s learned" % chosen.display_name)
	return chosen


func _title_for(choices: Array) -> String:
	var next: int = next_chain_category()
	if next >= 0:
		return "Choose your %s" % TechniqueData.CATEGORY_NAMES[next].to_upper()
	return "Choose a technique"


func _upgrade_choice_open() -> bool:
	var upgrades := get_tree().get_first_node_in_group("upgrade_manager")
	return upgrades != null and upgrades.is_choosing


func _is_player_dead() -> bool:
	return kata.get_parent().get_node("HealthComponent").is_dead()


## The mini-boss teaches an Opening or a Flow (the one the Kata is missing, if any).
func _on_miniboss_defeated() -> void:
	offer_pending = true
	await get_tree().create_timer(1.2, false).timeout
	if _is_player_dead():
		offer_pending = false
	else:
		offer([Category.OPENING, Category.FLOW])


## A boss that is not the last one teaches a Finisher.
func _on_boss_defeated(is_final: bool) -> void:
	if is_final:
		return
	offer_pending = true
	await get_tree().create_timer(1.2, false).timeout
	if _is_player_dead():
		offer_pending = false
	else:
		offer([Category.FINISHER])


## A technique the shop can sell: follows the same order as the offers (and may be a Master once the chain is complete).
func get_shop_technique() -> Resource:
	var choices: Array = get_choices([], 1)
	if next_chain_category() < 0:
		var anything: Array = technique_pool.filter(func(data): return not kata.has_technique(data.id))
		return anything.pick_random() if not anything.is_empty() else null
	return choices[0] if not choices.is_empty() else null
