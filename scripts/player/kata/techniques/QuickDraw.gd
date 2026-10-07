extends TechniqueBehavior
## Opening: dashing opens the Kata, with a little Flow already built.


func opening_matches(_kata: Node, event: String, _payload: Dictionary) -> bool:
	return event == "dodge"


func on_open(kata: Node) -> void:
	kata.add_flow(param("start_flow", 0.25))
