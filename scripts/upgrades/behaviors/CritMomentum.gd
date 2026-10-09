extends RuleBehavior
## Every critical hit adds a little critical chance for a few seconds; the bonuses stack up to a limit.

var stacks: Array = [] # the timed modifiers that are still running


func on_critical_hit(_info: Dictionary) -> void:
	var stats: Node = host.player.stats
	stacks = stacks.filter(func(effect): return effect in stats.modifiers) # the ones that ended are dropped
	if stacks.size() < int(p("max_stacks", 5)):
		stacks.append(stats.add_timed_modifier("crit_chance", UpgradeEffect.Operation.ADD, p("bonus", 0.04), p("time", 4.0)))
