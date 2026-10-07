extends TechniqueBehavior
## Flow: builds fast while you are not hit, but the first hit you take wipes all of it.


func on_event(kata: Node, event: String, payload: Dictionary) -> void:
	if event == "hit_dealt" and payload.get("kind", "") == "light" and payload.get("hit_count", 1) <= 1:
		kata.add_flow(param("gain_per_hit", 0.4))
	elif event == "damage_taken":
		kata.add_flow(-kata.flow_cap)
