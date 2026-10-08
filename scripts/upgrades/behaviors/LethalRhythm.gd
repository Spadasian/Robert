extends RuleBehavior
## Every Nth light hit in a row is a guaranteed critical hit. Taking damage breaks the rhythm.

var streak: int = 0


func forced_crit(kind: String, _target: Node) -> bool:
	return kind == "light" and streak >= p("every", 5) - 1


func on_hit_dealt(info: Dictionary) -> void:
	if info.get("kind", "") != "light" or info.get("hit_count", 1) > 1:
		return
	streak = 0 if streak >= p("every", 5) - 1 else streak + 1


func on_damage_taken(_amount: float) -> void:
	streak = 0
