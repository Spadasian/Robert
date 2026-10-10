extends Node
## Picks and applies upgrades. The pool is a plain list of UpgradeData resources set in the Inspector,
## so new upgrades are just new .tres files added to the list.

@export var upgrade_pool: Array[Resource] = []
## An UpgradePool resource (written by tools/content/generate_upgrades.py); when set it fills upgrade_pool.
@export var pool_resource: Resource

@onready var choice_ui: Node = $"../UpgradeChoice"

var stats: Node
var is_processing_levels: bool = false
var is_choosing: bool = false # TechniqueManager waits while an upgrade choice is open


func _enter_tree() -> void:
	add_to_group("upgrade_manager")


func _ready() -> void:
	if pool_resource != null:
		upgrade_pool = pool_resource.upgrades.duplicate()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		stats = player.get_node("StatsComponent")
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.level_up.connect(func(_level: int): process_pending_levels())
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager:
		room_manager.room_cleared.connect(process_pending_levels)
		room_manager.map_changed.connect(process_pending_levels) # also fires when a room without a fight is cleared
		room_manager.miniboss_defeated.connect(process_pending_levels)
		room_manager.boss_defeated.connect(func(_final: bool): process_pending_levels())
		room_manager.room_loaded.connect(func(_room: Node): process_pending_levels())


## Rerolls the player can still use (stat "rerolls" minus the ones already used).
func rerolls_left() -> int:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var used: int = run_manager.rerolls_used if run_manager else 0
	return maxi(int(stats.get_stat("rerolls")) - used, 0)


## Uses one reroll and returns new cards (empty if none is left).
func reroll(count: int) -> Array:
	if rerolls_left() <= 0:
		return []
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.rerolls_used += 1
	return get_random_choices(count)


const CHARACTER_WEIGHT: float = 3.0 # the style upgrades of the chosen character come up this much more often


## The chance weight of an upgrade for the character of this run.
func weight_of(upgrade: Resource) -> float:
	var character: Resource = GameManager.selected_character
	if upgrade.character != "" and character != null and upgrade.character == character.id:
		return upgrade.get_weight() * CHARACTER_WEIGHT
	return upgrade.get_weight()


## Random upgrades the player does not own yet, picked by rarity weight, no duplicates.
func get_random_choices(count: int) -> Array:
	var candidates: Array = []
	var corruption: Node = stats.get_parent().get_node_or_null("CorruptionComponent")
	var cursed_open: bool = corruption != null and corruption.cursed_unlocked # Corruption reached 50% once
	for upgrade in upgrade_pool:
		if upgrade.rarity == UpgradeData.Rarity.CURSED and not cursed_open:
			continue
		if not stats.has_upgrade(upgrade.id):
			candidates.append(upgrade)
	var choices: Array = []
	while choices.size() < count and not candidates.is_empty():
		var total_weight: float = 0.0
		for upgrade in candidates:
			total_weight += weight_of(upgrade)
		var roll: float = randf() * total_weight
		for upgrade in candidates:
			roll -= weight_of(upgrade)
			if roll <= 0.0:
				choices.append(upgrade)
				candidates.erase(upgrade)
				break
	return choices


func apply_upgrade(upgrade: Resource) -> void:
	stats.add_upgrade(upgrade)
	var rules: Node = stats.get_parent().get_node_or_null("RuleHost")
	if rules:
		rules.add_behavior(upgrade)


## Each level up gives one upgrade choice (1 of 3). It is shown between fights: while enemies are alive the level ups
## wait, and after a mini-boss or boss the technique reward comes first. Safe to call often; only one runs at a time.
func process_pending_levels() -> void:
	if is_processing_levels:
		return
	is_processing_levels = true
	await get_tree().create_timer(0.6, false).timeout # let the player see the last kill (false: waits while paused)
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var techniques := get_tree().get_first_node_in_group("technique_manager")
	while run_manager and run_manager.pending_levels > 0:
		if stats.get_parent().get_node("HealthComponent").is_dead() or _fight_going_on():
			break
		if techniques and (techniques.busy or techniques.offer_pending):
			await get_tree().process_frame
			continue
		run_manager.pending_levels -= 1
		var choices: Array = get_random_choices(int(stats.get_stat("choice_count")))
		if choices.is_empty():
			continue # every upgrade is owned: the level is still gained
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_message("LEVEL %d" % (run_manager.level - run_manager.pending_levels), 1.5)
		is_choosing = true
		var chosen: Resource = await choice_ui.choose(choices, self)
		is_choosing = false
		apply_upgrade(chosen)
		if hud:
			hud.show_message("%s acquired" % chosen.display_name)
	is_processing_levels = false


func _fight_going_on() -> bool:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var room: Node = room_manager.current_room if room_manager else null
	return room != null and room.alive_enemies > 0
