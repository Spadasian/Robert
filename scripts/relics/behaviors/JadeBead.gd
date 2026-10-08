extends RuleBehavior
## Every level up heals a share of your health.


func on_level_up(_level: int) -> void:
	host.heal_percent(p("ratio", 0.3))
