class_name CombatManager
extends RefCounted
## Damage rules in one place. Called by Hitbox; no node needed.
## The attacker's StatsComponent (if it has one) adds crits, execute damage, corruption and life on kill.

const CRIT_MULTIPLIER: float = 1.5
const LOW_HEALTH_RATIO: float = 0.3

## True when the last calculate_damage() call rolled a critical hit (Hitbox reads it right after).
static var last_hit_was_crit: bool = false


static func calculate_damage(base_damage: float, attacker: Node, target_health: Node) -> float:
	last_hit_was_crit = false
	var stats := _get_stats(attacker)
	if stats == null:
		return base_damage
	var damage: float = base_damage
	if randf() < stats.get_stat("crit_chance"):
		damage *= CRIT_MULTIPLIER
		last_hit_was_crit = true
	if target_health and target_health.current_health <= target_health.max_health * LOW_HEALTH_RATIO:
		damage *= 1.0 + stats.get_stat("execute_bonus")
	return damage


static func after_hit(attacker: Node, target_health: Node, info: Dictionary = {}) -> void:
	if attacker and attacker.has_method("on_hit_dealt"):
		attacker.on_hit_dealt(target_health, info) # the player's ultimate charges and the Kata hears about it
	var stats := _get_stats(attacker)
	if stats == null:
		return
	var corruption_gain: float = stats.get_stat("corruption_on_hit")
	if corruption_gain > 0.0:
		var corruption := attacker.get_node_or_null("CorruptionComponent")
		if corruption:
			corruption.add_corruption(corruption_gain)
	if target_health and target_health.is_dead():
		var heal_amount: float = stats.get_stat("life_on_kill")
		var health := attacker.get_node_or_null("HealthComponent")
		if heal_amount > 0.0 and health:
			health.heal(heal_amount)


static func _get_stats(attacker: Node) -> Node:
	if attacker == null:
		return null
	return attacker.get_node_or_null("StatsComponent")
