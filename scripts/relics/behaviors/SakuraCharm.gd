extends RuleBehavior
## A Finisher that kills heals.

var window: float = 0.0


func on_finisher(_context: Dictionary) -> void:
	window = 0.6


func on_tick(delta: float) -> void:
	window = maxf(window - delta, 0.0)


func on_kill(info: Dictionary) -> void:
	if window > 0.0 and info.get("kind", "") == "heavy":
		host.heal(info.get("damage", 0.0) * p("ratio", 0.15))
