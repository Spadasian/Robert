extends RuleBehavior
## While the Kata is open, every Nth light hit sends a slash wave forward.

var count: int = 0


func on_kata_opened() -> void:
	count = 0


func on_kata_closed(_reason: String) -> void:
	count = 0


func on_hit_dealt(info: Dictionary) -> void:
	if info.get("kind", "") != "light" or info.get("hit_count", 1) > 1 or not host.player.kata.is_open:
		return
	count += 1
	if count % int(p("every", 3)) == 0:
		host.fire_wave(host.player.aim.aim_direction, host.attack_damage() * p("ratio", 0.6), 16.0, 0.5, true)
