extends RuleBehavior
## A Perfect Dodge pushes the enemies around you away.


func on_perfect_dodge(_source: Node) -> void:
	var center: Vector3 = host.player.global_position
	for enemy in host.enemies_near(center, p("radius", 5.0)):
		enemy.knockback(enemy.global_position - center, p("strength", 14.0))
