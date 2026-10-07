class_name MetaUpgradeData
extends Resource
## A permanent upgrade bought with Soul Shards between runs. Each level adds `value_per_level` to a stat
## for the whole next run. The number of levels is the number of entries in `costs`.
## `stat` is a stat name from StatsComponent (max_health, life_on_kill...) or the special value "starting_gold".
## New permanent upgrade = new .tres + add it to MetaProgression.UPGRADES.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = "" # what ONE level gives
@export var stat: String = ""
@export var value_per_level: float = 1.0
@export var costs: PackedInt32Array = PackedInt32Array() # Soul Shard cost of level 1, 2, 3...


func get_max_level() -> int:
	return costs.size()
