extends Node
## All numbers that upgrades can change. Other components ask get_stat("name").
## final = (base + flat bonuses) * (1 + sum of percent bonuses)

signal stats_changed

@export var base_stats: Dictionary = {
	"max_health": 100.0,
	"attack_damage": 10.0,
	"attack_speed": 1.0,
	"move_speed": 6.0,
	"dodge_charges": 1.0,
	"damage_taken": 1.0, # multiplier: 0.85 = takes 15% less
	"crit_chance": 0.0,
	"execute_bonus": 0.0, # extra damage vs enemies at low HP
	"corruption_on_hit": 0.0,
	"life_on_kill": 0.0,
}

var upgrades: Array = [] # UpgradeData taken this run
var modifiers: Array = [] # UpgradeEffect resources
var _cache: Dictionary = {}


func get_stat(stat_name: String) -> float:
	if _cache.is_empty():
		_recalculate()
	return _cache.get(stat_name, 0.0)


func add_upgrade(upgrade: Resource) -> void:
	upgrades.append(upgrade)
	for effect in upgrade.effects:
		if not base_stats.has(effect.stat):
			push_warning("StatsComponent: unknown stat '%s' in upgrade '%s'" % [effect.stat, upgrade.id])
		modifiers.append(effect)
	_recalculate()
	stats_changed.emit()


func has_upgrade(upgrade_id: String) -> bool:
	for upgrade in upgrades:
		if upgrade.id == upgrade_id:
			return true
	return false


func _recalculate() -> void:
	_cache.clear()
	for stat_name in base_stats:
		var flat: float = 0.0
		var percent: float = 0.0
		for effect in modifiers:
			if effect.stat != stat_name:
				continue
			if effect.operation == UpgradeEffect.Operation.ADD:
				flat += effect.value
			else:
				percent += effect.value
		_cache[stat_name] = (float(base_stats[stat_name]) + flat) * (1.0 + percent)
