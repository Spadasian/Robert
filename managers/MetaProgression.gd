extends Node
## Progress that survives between runs: Soul Shards and the permanent upgrades bought with them.
## Registered as the autoload "MetaProgression" in project.godot, so it is not thrown away when a run restarts.
## SaveManager (also an autoload) saves it to disk every time it changes and loads it when the game starts.

signal shards_changed(total: int)
signal data_changed # anything worth saving changed (SaveManager listens to this)

const SHARDS_PER_ROOM: int = 3 # every combat, elite or boss room cleared
const KILLS_PER_SHARD: int = 2
const BOSS_BONUS: int = 30

# Add new permanent upgrades here.
const UPGRADES: Array[Resource] = [
	preload("res://resources/meta/vitality.tres"),
	preload("res://resources/meta/pouch.tres"),
	preload("res://resources/meta/hungry_blade.tres"),
]

var soul_shards: int = 0
var upgrade_levels: Dictionary = {} # upgrade id -> level bought
var runs_played: int = 0
var bosses_defeated: int = 0


func get_level(upgrade_id: String) -> int:
	return upgrade_levels.get(upgrade_id, 0)


## Cost of the next level, or -1 when the upgrade is already at its maximum.
func get_cost(upgrade: Resource) -> int:
	var level: int = get_level(upgrade.id)
	if level >= upgrade.get_max_level():
		return -1
	return upgrade.costs[level]


func can_buy(upgrade: Resource) -> bool:
	var cost: int = get_cost(upgrade)
	return cost >= 0 and soul_shards >= cost


func buy(upgrade: Resource) -> bool:
	if not can_buy(upgrade):
		return false
	soul_shards -= get_cost(upgrade)
	upgrade_levels[upgrade.id] = get_level(upgrade.id) + 1
	shards_changed.emit(soul_shards)
	data_changed.emit()
	return true


func calculate_shards(rooms_cleared: int, enemies_defeated: int, boss_defeated: bool) -> int:
	var shards: int = rooms_cleared * SHARDS_PER_ROOM + enemies_defeated / KILLS_PER_SHARD
	if boss_defeated:
		shards += BOSS_BONUS
	return shards


## Called once when a run ends (death or victory). Returns the shards earned.
func finish_run(run_manager: Node) -> int:
	var earned: int = calculate_shards(run_manager.rooms_cleared, run_manager.enemies_defeated, run_manager.boss_defeated)
	soul_shards += earned
	runs_played += 1
	if run_manager.boss_defeated:
		bosses_defeated += 1
	shards_changed.emit(soul_shards)
	data_changed.emit()
	return earned


## Called by RunManager at the start of every run: stat bonuses go to the player, gold goes to the run.
func apply_to_run(stats: Node, run_manager: Node) -> void:
	for upgrade in UPGRADES:
		var level: int = get_level(upgrade.id)
		if level <= 0:
			continue
		var amount: float = upgrade.value_per_level * level
		if upgrade.stat == "starting_gold":
			run_manager.grant_starting_gold(int(amount))
			continue
		var effect := UpgradeEffect.new()
		effect.stat = upgrade.stat
		effect.operation = UpgradeEffect.Operation.ADD
		effect.value = amount
		stats.add_modifier(effect)


## Everything that must survive closing the game, as plain data (numbers and strings only).
func to_dict() -> Dictionary:
	return {
		"soul_shards": soul_shards,
		"upgrade_levels": upgrade_levels.duplicate(),
		"runs_played": runs_played,
		"bosses_defeated": bosses_defeated,
	}


## Loads data written by to_dict(). Missing or broken values fall back to defaults, so old saves keep working
## when new fields are added later. Does not emit data_changed (nothing needs saving after a load).
func from_dict(data: Dictionary) -> void:
	soul_shards = maxi(int(data.get("soul_shards", 0)), 0)
	runs_played = maxi(int(data.get("runs_played", 0)), 0)
	bosses_defeated = maxi(int(data.get("bosses_defeated", 0)), 0)
	upgrade_levels = {}
	var saved_levels = data.get("upgrade_levels", {})
	if saved_levels is Dictionary:
		for upgrade_id in saved_levels:
			upgrade_levels[str(upgrade_id)] = maxi(int(saved_levels[upgrade_id]), 0)
	# A level can never be above the maximum (costs may have been shortened in a later version).
	for upgrade in UPGRADES:
		if upgrade_levels.has(upgrade.id):
			upgrade_levels[upgrade.id] = mini(upgrade_levels[upgrade.id], upgrade.get_max_level())
	shards_changed.emit(soul_shards)


func reset() -> void:
	from_dict({})
