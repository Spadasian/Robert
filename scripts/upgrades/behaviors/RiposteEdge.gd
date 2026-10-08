extends RuleBehavior
## After a Perfect Dodge the next hit does more damage (a timed bonus that ends with the first hit).

var effect: Resource


func on_perfect_dodge(_source: Node) -> void:
	_clear()
	effect = host.player.stats.add_timed_modifier("attack_damage", UpgradeEffect.Operation.PERCENT, p("bonus", 0.5), p("time", 3.0))


func on_hit_dealt(info: Dictionary) -> void:
	if effect != null and info.get("kind", "") in ["light", "heavy", "skill"]:
		_clear()


func _clear() -> void:
	if effect != null:
		host.player.stats.remove_modifier(effect)
		effect = null
