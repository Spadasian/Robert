extends TechniqueBehavior
## Opening: one kind of event starts the Kata (params.event: "kill", "critical_hit", "damage_taken", "hit_dealt"...).
## Hunter's Mark (kill) also marks the nearest enemy; Thousand Cuts only opens on the first hit on an unhurt enemy.


func opening_matches(_kata: Node, event: String, payload: Dictionary) -> bool:
	if event != param("event", "kill"):
		return false
	if param("needs_full_health", false) and not payload.get("was_full", false):
		return false
	return true


func on_open(kata: Node) -> void:
	kata.add_flow(param("start_flow", 0.3))
	var mark: float = param("mark_bonus", 0.0)
	if mark > 0.0:
		var player: Node = kata.get_parent()
		var target: Node = player.rules.nearest_enemy(player.global_position, 12.0)
		if target and target.get("status") != null:
			target.status.apply_mark(mark, param("mark_time", 4.0))
