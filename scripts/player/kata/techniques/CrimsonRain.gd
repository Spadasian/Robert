extends "res://scripts/player/kata/techniques/FinisherBase.gd"
## Finisher: a pool of blood in front of you makes the enemies in it bleed for 3 s.


func on_finisher_strike(_kata: Node, heavy: Node, _context: Dictionary) -> void:
	var player: Node = heavy.player
	var center: Vector3 = player.global_position + heavy.direction * param("distance", 3.0)
	player.rules.spawn_zone(center, param("radius", 2.6), param("time", 3.0), 0.0, param("bleed", 6.0), Color(0.85, 0.1, 0.2, 0.4), "crimson_rain")
