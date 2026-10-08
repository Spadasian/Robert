extends RuleBehavior
## Every bleed tick on an enemy heals you.


func on_bleed_tick(_enemy: Node, _damage: float) -> void:
	host.heal(p("heal", 1.0))
