extends RuleBehavior
## Hits on an enemy's back have extra critical chance.


func crit_chance_bonus(_kind: String, target: Node) -> float:
	if target != null and host.player._is_behind(target):
		return p("bonus", 0.30)
	return 0.0
