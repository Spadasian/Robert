extends "res://scripts/player/kata/techniques/FinisherBase.gd"
## Finisher: every enemy the slash hits heals you.

var rules: Node


func on_finisher_strike(_kata: Node, heavy: Node, context: Dictionary) -> void:
	rules = heavy.player.rules
	context["on_hit"] = context.get("on_hit", []) + [_harvest]


func _harvest(_info: Dictionary) -> void:
	if is_instance_valid(rules):
		rules.heal(param("heal", 3.0))
