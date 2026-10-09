extends "res://scripts/player/kata/techniques/FinisherBase.gd"
## Finisher: you cannot be hurt from the strike until the end of its recovery.


func on_finisher_strike(_kata: Node, _heavy: Node, context: Dictionary) -> void:
	context["invulnerable"] = true
