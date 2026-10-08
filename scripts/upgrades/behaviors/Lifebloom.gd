extends RuleBehavior
## Every level up heals.


func on_level_up(_level: int) -> void:
	host.heal(p("heal", 20.0))
