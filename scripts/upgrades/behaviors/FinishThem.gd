extends RuleBehavior
## Heavy does more damage to wounded enemies.


func damage_multiplier(kind: String, target_health: Node) -> float:
	if kind == "heavy" and target_health != null and target_health.current_health <= target_health.max_health * p("threshold", 0.4):
		return 1.0 + p("bonus", 0.3)
	return 1.0
