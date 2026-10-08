extends RuleBehavior
## The first hit on every enemy has extra critical chance.

var seen: Dictionary = {}


func crit_chance_bonus(_kind: String, target: Node) -> float:
	if target != null and not seen.has(target.get_instance_id()):
		return p("bonus", 0.15)
	return 0.0


func on_hit_dealt(info: Dictionary) -> void:
	var target: Node = info.get("target")
	if target != null:
		seen[target.get_instance_id()] = true
