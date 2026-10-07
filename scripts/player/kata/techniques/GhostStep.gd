extends TechniqueBehavior
## Opening: a hit on an enemy's back opens the Kata.


func opening_matches(_kata: Node, event: String, payload: Dictionary) -> bool:
	return event == "hit_dealt" and payload.get("from_behind", false)


func on_open(kata: Node) -> void:
	kata.add_flow(param("start_flow", 0.3))
