extends RuleBehavior
## Every swing that connects recharges the dash a little.


func on_hit_dealt(info: Dictionary) -> void:
	if info.get("hit_count", 1) <= 1 and info.get("kind", "") in ["light", "heavy", "skill"]:
		host.player.dash.reduce_recharge(p("seconds", 0.2))
