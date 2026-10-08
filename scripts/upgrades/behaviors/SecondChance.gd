extends RuleBehavior
## Once per run a deadly hit leaves the player alive.

var used: bool = false


func prevent_lethal(_damage: float) -> bool:
	if used:
		return false
	used = true
	host.player.health.set_current(host.player.health.max_health * p("ratio", 0.3))
	host.show_text("SECOND CHANCE", Color(1.0, 0.85, 0.4))
	return true
