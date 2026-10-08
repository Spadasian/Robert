extends RuleBehavior
## The Heavy attack destroys the enemy projectiles in front of you.


func on_heavy_attack() -> void:
	var origin: Vector3 = host.player.global_position
	var forward: Vector3 = host.player.aim.aim_direction
	for projectile in host.get_tree().get_nodes_in_group("projectile"):
		if projectile.team != "enemy":
			continue
		var offset: Vector3 = projectile.global_position - origin
		offset.y = 0.0
		if offset.length() <= p("range", 4.5) and offset.normalized().dot(forward) > 0.0:
			projectile.queue_free()
