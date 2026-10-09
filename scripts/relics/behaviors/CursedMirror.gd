extends RuleBehavior
## Cursed relic: a Perfect Dodge freezes the enemies until you land a hit on one (at most `max_freeze` s),
## and Finishers deal double damage, but every hit you take hurts 30% more.

var freezing: bool = false


func on_perfect_dodge(_source: Node) -> void:
	freezing = true
	EnemyTime.slow(0.0, p("max_freeze", 8.0))


func on_hit_dealt(info: Dictionary) -> void:
	if freezing and info.get("kind", "") != "bleed":
		freezing = false
		EnemyTime.reset() # time starts again with the first hit


func on_finisher(context: Dictionary) -> void:
	context["damage_multiplier"] = context.get("damage_multiplier", 1.0) * p("finisher", 2.0)


func modify_incoming(damage: float, _source: Node) -> float:
	return damage * (1.0 + p("damage_taken", 0.3))
