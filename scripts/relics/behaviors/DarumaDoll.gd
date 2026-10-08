extends RuleBehavior
## Once per biome, a deadly hit leaves you with 1 HP.

var used: bool = false


func on_biome_started(_index: int) -> void:
	used = false


func prevent_lethal(_damage: float) -> bool:
	if used:
		return false
	used = true
	host.player.health.set_current(1.0)
	host.show_text("DARUMA", Color(1.0, 0.4, 0.3))
	return true
