extends TechniqueBehavior
## Base of the new Finishers: damage = base + flow_bonus * Flow. Each Finisher adds its own effect in on_finisher_strike.


func finisher_multiplier(kata: Node) -> float:
	return param("base", 1.0) + param("flow_bonus", 0.6) * kata.flow_value
