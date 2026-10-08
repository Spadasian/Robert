extends RuleBehavior
## Light attacks kill enemies that are almost dead.


func executes(kind: String, target_health: Node) -> bool:
	return kind == "light" and target_health != null and target_health.current_health <= target_health.max_health * p("threshold", 0.1)
