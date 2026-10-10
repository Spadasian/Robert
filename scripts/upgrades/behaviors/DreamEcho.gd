extends RuleBehavior
## Yume: every dash leaves a clone behind that cuts the spot a moment later.

const PhantomClone = preload("res://scripts/player/skills/yume/PhantomClone.gd")

var cooldown_left: float = 0.0


func on_tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func on_dodge() -> void:
	if cooldown_left > 0.0:
		return
	cooldown_left = p("cooldown", 1.0)
	var clone := PhantomClone.new()
	clone.player = host.player
	clone.damage = host.attack_damage() * p("damage_ratio", 0.8)
	clone.radius = p("radius", 2.2)
	clone.delay = p("delay", 0.3)
	host.player.get_parent().add_child(clone)
	clone.global_position = host.player.dash.start_position
	clone.global_position.y = 0.0
