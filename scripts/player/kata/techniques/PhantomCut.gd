extends TechniqueBehavior
## Master: every 4th light hit leaves a phantom slash that strikes forward half a second later.

var hits: int = 0


func on_event(kata: Node, event: String, payload: Dictionary) -> void:
	if event != "hit_dealt" or payload.get("kind", "") != "light" or payload.get("hit_count", 1) > 1:
		return
	hits += 1
	if hits % param("every", 4) != 0:
		return
	var player: Node = kata.get_parent()
	var direction: Vector3 = player.aim.aim_direction
	var damage: float = player.rules.attack_damage() * param("ratio", 1.0)
	var timer: SceneTreeTimer = kata.get_tree().create_timer(param("delay", 0.5), false)
	timer.timeout.connect(func():
		if is_instance_valid(player) and not player.health.is_dead():
			player.rules.fire_wave(direction, damage, 18.0, 0.35, true))
