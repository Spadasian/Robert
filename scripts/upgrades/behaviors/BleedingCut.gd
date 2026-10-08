extends RuleBehavior
## Critical hits make the enemy bleed.


func on_critical_hit(info: Dictionary) -> void:
	var target: Node = info.get("target")
	if is_instance_valid(target) and target.get("status") != null and not target.health.is_dead():
		target.status.apply_bleed(host.attack_damage() * p("dps_ratio", 0.3), p("time", 3.0))
