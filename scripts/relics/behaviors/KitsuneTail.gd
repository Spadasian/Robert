extends RuleBehavior
## After a Perfect Dodge you are faster and the enemies lose sight of you for a moment.

var effect: Resource


func on_perfect_dodge(_source: Node) -> void:
	if effect != null:
		host.player.stats.remove_modifier(effect)
	effect = host.player.stats.add_timed_modifier("move_speed", UpgradeEffect.Operation.PERCENT, p("bonus", 0.3), p("time", 2.0))
	host.hide_player(p("time", 2.0))
