extends TechniqueBehavior
## Opening: the skill in a slot (params.slot: "shift" or "q") really doing its thing starts the Kata: the Iaijutsu cut
## being made, a Kaeshi counter hitting back... Pressing the button is not enough.


func opening_matches(_kata: Node, event: String, payload: Dictionary) -> bool:
	if event != "skill_resolved":
		return false
	var skill: Node = payload.get("skill")
	return is_instance_valid(skill) and skill.get_slot() == param("slot", "shift")


func on_open(kata: Node) -> void:
	kata.add_flow(param("start_flow", 0.3))
