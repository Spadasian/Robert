extends TechniqueBehavior
## Master: after a Finisher the Kata opens again at once, with some Flow already built.


func after_finisher(kata: Node) -> void:
	kata.force_open()
	kata.set_flow(param("flow", 0.3))
