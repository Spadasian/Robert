extends RuleBehavior
## Kills during the Ultimate keep it going a little longer.


func on_kill(_info: Dictionary) -> void:
	for skill in host.player.skills:
		if skill.has_method("extend_time"):
			skill.extend_time(p("seconds", 0.5))
