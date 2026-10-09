extends "res://scripts/player/kata/techniques/FinisherBase.gd"
## Finisher: the arc is followed by a quick narrow thrust straight ahead (60% damage).


func on_finisher_strike(_kata: Node, heavy: Node, context: Dictionary) -> void:
	var direction: Vector3 = heavy.direction
	var timer: SceneTreeTimer = heavy.get_tree().create_timer(param("delay", 0.18), false)
	timer.timeout.connect(func():
		if is_instance_valid(heavy) and not heavy.player.health.is_dead():
			heavy.player.rules.fire_wave(direction, heavy.strike_damage(context) * param("ratio", 0.6), 26.0, 0.16, true)
			VFX.slash_arc(heavy.player.global_position + Vector3(0.0, 0.9, 0.0), atan2(direction.x, direction.z), 2.4, 40.0, Color(1.0, 0.5, 0.5), 0.15))
