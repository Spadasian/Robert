extends RuleBehavior
## For a moment after you hit something, being hit does not take Flow away.


func on_hit_dealt(_info: Dictionary) -> void:
	host.player.kata.flow_shield_left = p("time", 1.0)
