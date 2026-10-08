extends RuleBehavior
## After a dash you move faster for a moment.

var effect: Resource


func on_dodge() -> void:
	if effect != null:
		host.player.stats.remove_modifier(effect)
	effect = host.player.stats.add_timed_modifier("move_speed", UpgradeEffect.Operation.PERCENT, p("bonus", 0.2), p("time", 2.2))
