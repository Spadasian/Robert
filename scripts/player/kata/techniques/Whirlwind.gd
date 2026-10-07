extends TechniqueBehavior
## Finisher: the slash becomes a circle around the player.


func finisher_multiplier(kata: Node) -> float:
	return 0.8 + param("flow_bonus", 0.8) * kata.flow_value


func on_finisher_strike(_kata: Node, _heavy: Node, context: Dictionary) -> void:
	context["spin"] = true
	context["scale"] = param("scale", 1.5)
