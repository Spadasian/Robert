extends RuleBehavior
## More damage while the Kata is open.


func damage_multiplier(kind: String, _target_health: Node) -> float:
	if host.player.kata.is_open and kind in ["light", "heavy", "skill"]:
		return 1.0 + p("bonus", 0.15)
	return 1.0
