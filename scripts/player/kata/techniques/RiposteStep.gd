extends TechniqueBehavior
## Opening: a Perfect Dodge opens the Kata with a lot of Flow.


func opening_matches(_kata: Node, event: String, _payload: Dictionary) -> bool:
	return event == "perfect_dodge"


func on_open(kata: Node) -> void:
	kata.add_flow(param("start_flow", 0.6))
