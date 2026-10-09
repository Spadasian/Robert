extends "res://scripts/player/kata/techniques/FinisherBase.gd"
## Finisher: the enemies it hits are stunned and take more damage for a while.


func on_finisher_strike(_kata: Node, _heavy: Node, context: Dictionary) -> void:
	context["on_hit"] = context.get("on_hit", []) + [_shatter]


func _shatter(info: Dictionary) -> void:
	var target: Node = info.get("target")
	if is_instance_valid(target) and target.get("status") != null:
		target.status.apply_stun(param("stun", 1.5))
		target.status.apply_mark(param("mark_bonus", 0.25), param("mark_time", 4.0))
