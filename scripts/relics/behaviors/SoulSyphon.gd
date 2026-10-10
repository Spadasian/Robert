extends RuleBehavior
## Every bleed tick on an enemy heals you for a share of its damage.


func on_bleed_tick(_enemy: Node, damage: float) -> void:
	host.heal(damage * p("ratio", 0.5))
