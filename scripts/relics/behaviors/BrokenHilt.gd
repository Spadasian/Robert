extends RuleBehavior
## The Finisher also sends a slash wave forward.


func on_finisher(context: Dictionary) -> void:
	var damage: float = host.attack_damage() * 1.8 * context.get("damage_multiplier", 1.0) * p("ratio", 0.6)
	host.fire_wave(host.player.aim.aim_direction, damage, 16.0, 0.6, true)
