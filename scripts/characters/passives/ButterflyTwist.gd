extends RuleBehavior
## Yume's passive: every dash (the normal one and Phantom Step) throws 3 shuriken in a fan, opposite to the direction of
## the dash (dash backwards and they fly forward). At most one volley per second. The damage grows with her damage
## upgrades, and the shuriken are real hits: they can crit, bleed, charge the Ultimate and feed the Flow.

var cooldown_left: float = 0.0


func on_tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func on_dodge() -> void:
	throw(host.player.dash.direction)


## A skill that moves the player like a dash (Phantom Step) tells where it went with get_twist_direction().
func on_skill_resolved(skill: Node) -> void:
	if skill.has_method("get_twist_direction"):
		throw(skill.get_twist_direction())


func throw(dash_direction: Vector3) -> void:
	if cooldown_left > 0.0 or dash_direction.length() < 0.01:
		return
	cooldown_left = p("cooldown", 1.0)
	var back: Vector3 = -Vector3(dash_direction.x, 0.0, dash_direction.z).normalized()
	var damage: float = p("damage", 5.0) * host.attack_damage() / p("base_attack", 9.0)
	var spread: float = deg_to_rad(p("spread", 18.0))
	for angle in [-spread, 0.0, spread]:
		host.fire_shuriken(back.rotated(Vector3.UP, angle), damage)
