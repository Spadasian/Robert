extends TechniqueBehavior
## Default Finisher: the heavy attack hits harder the more Flow the Kata has built.


func finisher_multiplier(kata: Node) -> float:
	return 1.0 + param("flow_bonus", 0.8) * kata.flow_value
