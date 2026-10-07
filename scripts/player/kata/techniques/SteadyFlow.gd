extends TechniqueBehavior
## Default Flow: every light swing that connects adds Flow; taking damage takes some away.


func on_event(kata: Node, event: String, payload: Dictionary) -> void:
	if event == "hit_dealt" and payload.get("kind", "") == "light" and payload.get("hit_count", 1) <= 1:
		kata.add_flow(param("gain_per_hit", 0.5))
	elif event == "damage_taken":
		kata.add_flow(-param("loss_when_hit", 0.35))
