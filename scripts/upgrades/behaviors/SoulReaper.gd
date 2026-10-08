extends RuleBehavior
## Each kill charges the Ultimate.


func on_kill(_info: Dictionary) -> void:
	for skill in host.player.skills:
		if skill.has_method("add_charge"):
			skill.add_charge(skill.max_charge * p("ratio", 0.05))
