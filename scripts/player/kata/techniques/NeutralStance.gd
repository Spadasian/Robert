extends TechniqueBehavior
## Default Opening: the first light attack that connects starts the Kata.


func opening_matches(_kata: Node, event: String, payload: Dictionary) -> bool:
	return event == "hit_dealt" and payload.get("kind", "") == "light"
