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
	"gold_gain": 1.0, # multiplier for gold picked up (Black Pearl: 1.5)
	"shop_discount": 0.0, # 0.2 = shops charge 20% less
	"free_hits_per_room": 0.0, # hits ignored at the start of every room (Fox Mask: 1)
	# --- stats used by the upgrade, relic and Kata lists (see design/KUROTSUKI_Liste.xlsx)
	"dash_recharge": 1.0, # multiplier of how fast dash charges come back (1.15 = 15% faster)
	"dash_distance": 1.0, # multiplier of the dash distance
	"perfect_window": 1.0, # multiplier of the Perfect Dodge window (0.10 s)
	"perfect_slow_bonus": 0.0, # extra seconds the enemies stay slowed after a Perfect Dodge
	"evade_chance": 0.0, # chance that a hit taken does nothing
	"crit_damage": 0.0, # added to the critical multiplier (1.5)
	"execute_threshold": 0.0, # added to the 30% health below which enemies count as "low"
	"flow_gain": 1.0, # multiplier of all Flow the Kata receives
	"flow_loss": 1.0, # multiplier of the Flow lost when hit
	"kata_timeout_bonus": 0.0, # seconds added to the time a running Kata waits before it closes
	"heavy_cooldown": 1.0, # multiplier of the Heavy cooldown
	"heavy_damage": 1.0, # multiplier of the Heavy damage
	"heavy_range": 1.0, # multiplier of the Heavy reach
	"skill_cooldown": 1.0, # multiplier of the Iaijutsu and Kaeshi cooldowns
	"xp_gain": 1.0, # multiplier of the EXP received
	"choice_count": 3.0, # cards in a level up choice
	"rerolls": 0.0, # level up rerolls per run
	"reward_cards": 0.0, # extra cards in the Duel and Arena technique rewards (Scroll of Duels)
	"master_chance": 0.0, # extra chance of a Master technique card in Duel and Arena rewards
	"bleed_power": 1.0, # multiplier of the damage of bleeding (Cursed Wound)
	"ultimate_charge": 1.0, # multiplier of how fast the Ultimate charges
	"ultimate_hit_charge": 0.0, # Ultimate charge from a hit that does not kill (0 = it charges only from kills)
	"shop_extra_item": 0.0, # extra stands in a Shop (Merchant's Seal)
	"shop_technique_mult": 1.0, # multiplier of the chance that a Shop sells a technique
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


## A bonus that ends by itself after `duration` seconds (Riposte Edge, Adrenaline...). Returns the effect so it can
## also be removed earlier with remove_modifier(). Refreshing the same effect is the caller's job.
func add_timed_modifier(stat_name: String, operation: int, value: float, duration: float) -> Resource:
	var effect := UpgradeEffect.new()
	effect.stat = stat_name
	effect.operation = operation
	effect.value = value
	add_modifier(effect)
	get_tree().create_timer(duration, false).timeout.connect(remove_modifier.bind(effect))
	return effect


func remove_modifier(effect: Resource) -> void:
	if effect in modifiers:
		modifiers.erase(effect)
		_recalculate()
		stats_changed.emit()


## A permanent bonus that is not a run upgrade (Soul Shard upgrades): it is not listed in `upgrades`.
func add_modifier(effect: Resource) -> void:
	if not base_stats.has(effect.stat):
		push_warning("StatsComponent: unknown stat '%s' in modifier" % effect.stat)
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
