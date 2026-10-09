extends "res://scripts/player/kata/techniques/FinisherBase.gd"
## Finisher: +20% damage for every enemy inside the arc when the strike begins.


func on_finisher_strike(_kata: Node, heavy: Node, context: Dictionary) -> void:
	var player: Node = heavy.player
	var reach: float = 3.6 * player.stats.get_stat("heavy_range") * context.get("scale", 1.0)
	var spin: bool = context.get("spin", false)
	var count: int = 0
	for enemy in player.rules.enemies_near(player.global_position, reach):
		var offset: Vector3 = enemy.global_position - player.global_position
		offset.y = 0.0
		if spin or offset.length() < 0.5 or heavy.direction.angle_to(offset) <= deg_to_rad(90.0):
			count += 1
	context["damage_multiplier"] = context.get("damage_multiplier", 1.0) * (1.0 + param("per_enemy", 0.2) * count)
	context["enemies_in_arc"] = count
