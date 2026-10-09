extends TechniqueBehavior
## Master: with the Flow full, the Finisher is always a critical hit.


func on_finisher_strike(kata: Node, _heavy: Node, context: Dictionary) -> void:
	if kata.flow_value >= kata.flow_cap - 0.01:
		context["force_crit"] = true
