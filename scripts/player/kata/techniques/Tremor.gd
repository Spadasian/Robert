extends "res://scripts/player/kata/techniques/FinisherBase.gd"
## Finisher: the ground in front of you shakes and hurts everything on it for 3 s.


func on_finisher_strike(_kata: Node, heavy: Node, _context: Dictionary) -> void:
	var player: Node = heavy.player
	var center: Vector3 = player.global_position + heavy.direction * param("distance", 3.0)
	var dps: float = player.rules.attack_damage() * param("damage_ratio", 1.2)
	player.rules.spawn_zone(center, param("radius", 2.8), param("time", 3.0), dps, 0.0, Color(0.7, 0.55, 0.3, 0.4))
	VFX.shake(0.15, 0.3)
