extends RuleBehavior
## Enemies that hit the player get hurt.


func modify_incoming(damage: float, source: Node) -> float:
	if is_instance_valid(source) and source.is_in_group("enemy") and not source.health.is_dead():
		source.health.take_damage(p("damage", 8.0))
	return damage
