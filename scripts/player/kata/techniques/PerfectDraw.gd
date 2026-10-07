extends TechniqueBehavior
## Master: a Perfect Dodge (even with the Kata closed) makes your next Finisher a guaranteed critical hit.

var armed: bool = false


func on_event(_kata: Node, event: String, _payload: Dictionary) -> void:
	if event == "perfect_dodge":
		armed = true


func on_finisher_strike(_kata: Node, _heavy: Node, context: Dictionary) -> void:
	if armed:
		context["force_crit"] = true
		armed = false
