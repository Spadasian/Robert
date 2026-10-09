extends TechniqueBehavior
## Master: every kill in the room makes the next Finisher stronger (+1% each, up to +100%). Resets in a new room.

var kills: int = 0


func on_event(_kata: Node, event: String, _payload: Dictionary) -> void:
	if event == "kill":
		kills += 1


func on_room(_kata: Node) -> void:
	kills = 0


func finisher_multiplier(_kata: Node) -> float:
	return 1.0 + minf(kills * param("per_kill", 0.01), param("max_bonus", 1.0))
