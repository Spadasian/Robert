extends RuleBehavior
## Every coin you pick up heals a little.


func on_gold_collected(_amount: int) -> void:
	host.heal(p("heal", 1.0))
