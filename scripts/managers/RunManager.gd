extends Node
## State of the current run: gold and run statistics. Thrown away when the run ends or the player dies.
## It also holds the relics the player found. The room map will be added here in a later phase.

signal gold_changed(gold: int)
signal relics_changed

@export var relic_pool: Array[Resource] = [] # RelicData resources, set in Run.tscn

var gold: int = 0
var gold_earned: int = 0 # everything picked up this run, even what was spent in the shop
var enemies_defeated: int = 0
var elapsed_time: float = 0.0 # seconds; does not count while the game is paused
var rooms_cleared: int = 0 # combat, elite and boss rooms (a shop does not count)
var boss_defeated: bool = false # at least one boss fell this run
var bosses_defeated: int = 0 # one per biome
var biome_index: int = 0
var mode_name: String = ""
var biome_count: int = 1
## Set by RoomManager for the biome being played (see BiomeData).
var enemy_health_multiplier: float = 1.0
var enemy_damage_multiplier: float = 1.0
var shard_multiplier: float = 1.0 # of the run mode
var relics: Array = [] # RelicData found this run
var stats: Node # the player's StatsComponent


func _enter_tree() -> void:
	add_to_group("run_manager")


func _ready() -> void:
	# Permanent bonuses bought with Soul Shards (extra max HP, starting gold...).
	var player := get_tree().get_first_node_in_group("player")
	if player:
		stats = player.get_node("StatsComponent")
		MetaProgression.apply_to_run(stats, self)


## Gold given at the start of a run. It is not counted as "earned" in the run statistics.
func grant_starting_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func _process(delta: float) -> void:
	elapsed_time += delta


func has_relic(relic_id: String) -> bool:
	for relic in relics:
		if relic.id == relic_id:
			return true
	return false


## Up to `count` different relics the player does not own yet, in random order.
func get_random_relics(count: int) -> Array:
	var candidates: Array = relic_pool.filter(func(relic): return not has_relic(relic.id))
	candidates.shuffle()
	return candidates.slice(0, count)


func add_relic(relic: Resource) -> void:
	relics.append(relic)
	for effect in relic.effects:
		stats.add_modifier(effect)
	relics_changed.emit()


## Gold picked up from the floor. Relics such as the Black Pearl raise it (gold_gain).
func collect_gold(base_amount: int) -> void:
	var gain: float = stats.get_stat("gold_gain") if stats else 1.0
	add_gold(roundi(base_amount * gain))


func register_kill() -> void:
	enemies_defeated += 1


func add_gold(amount: int) -> void:
	gold += amount
	gold_earned += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true
