extends TechniqueBehavior
## Master: the Kata never closes by itself, but the Flow slowly drains.


func prevents_timeout() -> bool:
	return true


func on_tick(kata: Node, delta: float) -> void:
	kata.add_flow(-param("decay", 0.05) * delta, false)
