extends TechniqueBehavior
## Finisher: enemies left below a share of their health die on the spot.


func finisher_multiplier(kata: Node) -> float:
	return 1.0 + param("flow_bonus", 0.6) * kata.flow_value


func on_finisher_strike(_kata: Node, _heavy: Node, context: Dictionary) -> void:
	context["execute_below"] = param("execute_below", 0.3)
