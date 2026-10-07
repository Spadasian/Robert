extends TechniqueBehavior
## Flow: hitting a different enemy than the last one is worth a lot, hitting the same one only a little.

var last_target_id: int = 0


func on_open(_kata: Node) -> void:
	last_target_id = 0


func on_event(kata: Node, event: String, payload: Dictionary) -> void:
	if event == "hit_dealt" and payload.get("kind", "") == "light":
		var target: Object = payload.get("target")
		var id: int = target.get_instance_id() if is_instance_valid(target) else 0
		if id != last_target_id:
			kata.add_flow(param("switch_gain", 0.5))
		elif payload.get("hit_count", 1) <= 1:
			kata.add_flow(param("same_gain", 0.12))
		last_target_id = id
	elif event == "damage_taken":
		kata.add_flow(-param("loss_when_hit", 0.3))
