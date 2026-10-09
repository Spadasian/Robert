extends "res://scripts/player/kata/techniques/FinisherBase.gd"
## Finisher: the slash also sends a wave that pierces 12 m forward.


func on_finisher_strike(_kata: Node, heavy: Node, context: Dictionary) -> void:
	var direction: Vector3 = heavy.direction
	var ratio: float = param("wave_ratio", 0.7)
	heavy.player.rules.fire_wave(direction, heavy.strike_damage(context) * ratio, 20.0, 0.6, true)
