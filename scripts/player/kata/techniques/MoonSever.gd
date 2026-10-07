extends TechniqueBehavior
## Finisher: a huge slash, wider and harder with Flow.


func finisher_multiplier(kata: Node) -> float:
	return 1.0 + param("flow_bonus", 1.0) * kata.flow_value


func on_finisher_strike(_kata: Node, _heavy: Node, context: Dictionary) -> void:
	context["scale"] = param("scale", 1.6)
