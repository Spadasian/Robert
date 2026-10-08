extends RuleBehavior
## Below a share of the health: more damage dealt, less damage taken.


func _is_low() -> bool:
	var health: Node = host.player.health
	return health.current_health <= health.max_health * p("threshold", 0.3)


func damage_multiplier(_kind: String, _target_health: Node) -> float:
	return 1.0 + p("damage", 0.25) if _is_low() else 1.0


func modify_incoming(damage: float, _source: Node) -> float:
	return damage * (1.0 - p("defense", 0.2)) if _is_low() else damage
