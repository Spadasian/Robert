extends RuleBehavior
## After the player is hit he attacks faster for a moment.

var effect: Resource


func on_damage_taken(_amount: float) -> void:
	if effect != null:
		host.player.stats.remove_modifier(effect)
	effect = host.player.stats.add_timed_modifier("attack_speed", UpgradeEffect.Operation.PERCENT, p("bonus", 0.3), p("time", 3.0))
