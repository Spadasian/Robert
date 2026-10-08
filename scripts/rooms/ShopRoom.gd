extends "res://scripts/rooms/Room.gd"
## Shop room. Needs the same nodes as every room, plus a "Stands" node with ShopStand children.
## There are no enemies, so the base class opens the exit door right away.
## Each stand gets a random upgrade the player does not own yet. With a low chance, one stand sells a Kata technique instead.

const TECHNIQUE_CHANCE: float = 0.2

@onready var stands_root: Node3D = $Stands


func start_room() -> void:
	super()
	_stock_stands()


const BASE_STANDS: int = 3
const RELIC_CHANCE: float = 0.2

func _stock_stands() -> void:
	var all_stands: Array = stands_root.get_children()
	var player := get_tree().get_first_node_in_group("player")
	var extra: int = int(player.get_node("StatsComponent").get_stat("shop_extra_item")) if player else 0
	var count: int = mini(BASE_STANDS + extra, all_stands.size())
	var stands: Array = all_stands.slice(0, count)
	for index in range(count, all_stands.size()):
		all_stands[index].disable() # the extra stand only exists with the Merchant's Seal

	var choices: Array = []
	var upgrade_manager := get_tree().get_first_node_in_group("upgrade_manager")
	if upgrade_manager:
		choices = upgrade_manager.get_random_choices(stands.size())
	# Rare and expensive: a Kata technique and/or a relic instead of an upgrade (one of each at most).
	var special: Dictionary = {} # stand index -> technique or relic
	var free_slots: Array = range(stands.size())
	free_slots.shuffle()
	var technique_manager := get_tree().get_first_node_in_group("technique_manager")
	var technique_chance: float = TECHNIQUE_CHANCE * (player.get_node("StatsComponent").get_stat("shop_technique_mult") if player else 1.0)
	if technique_manager and not free_slots.is_empty() and randf() < technique_chance:
		var technique: Resource = technique_manager.get_shop_technique()
		if technique:
			special[free_slots.pop_back()] = technique
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager and not free_slots.is_empty() and randf() < RELIC_CHANCE:
		var relics: Array = run_manager.get_random_relics(1)
		if not relics.is_empty():
			special[free_slots.pop_back()] = relics[0]
	for index in stands.size():
		if special.has(index):
			stands[index].setup(special[index])
		elif index < choices.size():
			stands[index].setup(choices[index])
		else:
			stands[index].disable()
