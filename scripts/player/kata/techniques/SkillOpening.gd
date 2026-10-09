extends TechniqueBehavior
## Opening: using one of the skills (params.skill = its display name, e.g. "Iaijutsu" or "Kaeshi") starts the Kata.


func opening_matches(_kata: Node, event: String, payload: Dictionary) -> bool:
	if event != "skill_used":
		return false
	var skill: Node = payload.get("skill")
	return is_instance_valid(skill) and skill.display_name == param("skill", "Iaijutsu")


func on_open(kata: Node) -> void:
	kata.add_flow(param("start_flow", 0.3))
