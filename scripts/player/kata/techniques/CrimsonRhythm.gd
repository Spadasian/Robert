extends TechniqueBehavior
## Flow: every connecting light swing is worth more than the one before. Getting hit breaks the rhythm.

var streak: int = 0


func on_open(_kata: Node) -> void:
	streak = 0


func on_event(kata: Node, event: String, payload: Dictionary) -> void:
	if event == "hit_dealt" and payload.get("kind", "") in ["light", "shuriken"] and payload.get("hit_count", 1) <= 1:
		streak += 1
		kata.add_flow(param("base_gain", 0.15) + param("streak_gain", 0.07) * mini(streak, 6))
	elif event == "damage_taken":
		streak = 0
		kata.add_flow(-param("loss_when_hit", 0.3))


func on_close(_kata: Node, _reason: String) -> void:
	streak = 0
