extends RuleBehavior
## Yume: every 3rd connecting light hit makes your attacks faster for a moment (renewed, not stacked).

var hits: int = 0
var effect: Resource


func on_hit_dealt(info: Dictionary) -> void:
	if info.get("kind", "") != "light" or info.get("hit_count", 1) > 1:
		return
	hits += 1
	if hits % int(p("every", 3)) != 0:
		return
	if effect != null:
		host.player.stats.remove_modifier(effect)
	effect = host.player.stats.add_timed_modifier("attack_speed", UpgradeEffect.Operation.PERCENT, p("bonus", 0.15), p("time", 2.0))
