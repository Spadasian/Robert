extends RuleBehavior
## The first hit after the Kata opens does more damage.

var fresh: bool = false


func on_kata_opened() -> void:
	fresh = true


func on_kata_closed(_reason: String) -> void:
	fresh = false


func damage_multiplier(kind: String, _target_health: Node) -> float:
	if fresh and kind in ["light", "heavy", "skill"]:
		return 1.0 + p("bonus", 0.4)
	return 1.0


func on_hit_dealt(info: Dictionary) -> void:
	if info.get("kind", "") in ["light", "heavy", "skill"]:
		fresh = false
