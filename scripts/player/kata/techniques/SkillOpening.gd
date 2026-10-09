extends TechniqueBehavior
## Opening: one of the skills really doing its thing starts the Kata (params.skill = its display name):
## the Iaijutsu cut being made, or a Kaeshi counter hitting back. Pressing the button is not enough.


func opening_matches(_kata: Node, event: String, payload: Dictionary) -> bool:
	if event != "skill_resolved":
		return false
	var skill: Node = payload.get("skill")
	return is_instance_valid(skill) and skill.display_name == param("skill", "Iaijutsu")


func on_open(kata: Node) -> void:
	kata.add_flow(param("start_flow", 0.3))
