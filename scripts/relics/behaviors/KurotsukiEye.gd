extends RuleBehavior
## A kill marks the nearest enemy: it takes more damage for a few seconds. The next kill moves the mark.

var marked: Node


func on_kill(info: Dictionary) -> void:
	var dead: Node3D = info.get("target") as Node3D
	var center: Vector3 = dead.global_position if is_instance_valid(dead) else host.player.global_position
	if is_instance_valid(marked) and marked.get("status") != null:
		marked.status.mark_left = 0.0
	marked = host.nearest_enemy(center, 30.0, dead)
	if marked != null:
		marked.status.apply_mark(p("bonus", 0.25), p("time", 6.0))
