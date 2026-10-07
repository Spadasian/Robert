extends TechniqueBehavior
## Master: a shadow repeats every Finisher a moment later.


func on_finisher_strike(_kata: Node, _heavy: Node, context: Dictionary) -> void:
	context["echo"] = param("echo_damage", 0.6)
