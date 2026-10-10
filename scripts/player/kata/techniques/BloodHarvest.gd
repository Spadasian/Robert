extends "res://scripts/player/kata/techniques/FinisherBase.gd"
## Finisher: every enemy the slash hits heals you for a share of the damage dealt to it.

var rules: Node


func on_finisher_strike(_kata: Node, heavy: Node, context: Dictionary) -> void:
	rules = heavy.player.rules
	context["on_hit"] = context.get("on_hit", []) + [_harvest]


func _harvest(info: Dictionary) -> void:
	if is_instance_valid(rules):
		rules.heal(info.get("damage", 0.0) * param("lifesteal", 0.10))
