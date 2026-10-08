extends RuleBehavior
## Kills sometimes leave a flame on the floor that makes the enemies standing in it bleed.


func on_kill(info: Dictionary) -> void:
	var dead: Node3D = info.get("target") as Node3D
	if is_instance_valid(dead) and randf() < p("chance", 0.2):
		host.spawn_zone(dead.global_position, p("radius", 1.6), p("time", 8.0), 0.0, p("bleed", 6.0), Color(0.3, 0.4, 1.0, 0.4))
