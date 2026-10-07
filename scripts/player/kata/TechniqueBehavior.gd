class_name TechniqueBehavior
extends RefCounted
## Base class of what a technique DOES. Override only the hooks you need. `kata` is the KataComponent.
##
## Events (event: String, payload: Dictionary) are the signals of KataEvents:
##   "light_attack", "heavy_attack", "hit_dealt", "critical_hit", "kill", "dodge", "perfect_dodge",
##   "damage_taken", "skill_used". For the hit events payload is the info dictionary (see KataEvents).

var data: Resource # the TechniqueData; numbers are read with param()


func param(key: String, default: Variant) -> Variant:
	if data == null:
		return default
	return data.params.get(key, default)


# ---- Opening: when does the Kata start?

## Called while the Kata is NOT running. Return true to start it.
func opening_matches(_kata: Node, _event: String, _payload: Dictionary) -> bool:
	return false


## The Kata just started (called for the Opening and for every other active technique).
func on_open(_kata: Node) -> void:
	pass


# ---- Flow (and any technique): what happens while the Kata runs?

func on_event(_kata: Node, _event: String, _payload: Dictionary) -> void:
	pass


func on_tick(_kata: Node, _delta: float) -> void:
	pass


## The Kata ended (finisher, timeout or a new room).
func on_close(_kata: Node, _reason: String) -> void:
	pass


# ---- Finisher

## Multiplies the damage of the heavy attack that ends the Kata.
func finisher_multiplier(_kata: Node) -> float:
	return 1.0


## Called when the heavy attack starts its strike as the Finisher. `context` is shared with the other techniques
## (damage_multiplier, flow, ...); `heavy` is the HeavyAttack node (its position and direction can be used).
func on_finisher_strike(_kata: Node, _heavy: Node, _context: Dictionary) -> void:
	pass
