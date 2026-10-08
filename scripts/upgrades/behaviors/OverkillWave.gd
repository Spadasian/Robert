extends RuleBehavior
## The damage beyond a kill spreads to the enemies around it.


func on_kill(info: Dictionary) -> void:
	var overkill: float = info.get("overkill", 0.0)
	var target: Node3D = info.get("target") as Node3D
	if overkill <= 0.0 or not is_instance_valid(target):
		return
	for enemy in host.enemies_near(target.global_position, p("radius", 4.0), target):
		enemy.health.take_damage(overkill * p("ratio", 0.5))
