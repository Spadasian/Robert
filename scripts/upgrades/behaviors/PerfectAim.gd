extends RuleBehavior
## After a Perfect Dodge your critical chance is much higher for a few seconds (renewed, not stacked).

var effect: Resource


func on_perfect_dodge(_source: Node) -> void:
	if effect != null:
		host.player.stats.remove_modifier(effect)
	effect = host.player.stats.add_timed_modifier("crit_chance", UpgradeEffect.Operation.ADD, p("bonus", 0.40), p("time", 3.0))
