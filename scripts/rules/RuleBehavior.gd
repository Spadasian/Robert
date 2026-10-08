class_name RuleBehavior
extends RefCounted
## Base class of what an upgrade or a relic DOES beyond changing a number. Override only the hooks you need.
## The behavior lives as long as the run; RuleHost (a node of the Player) calls the hooks. `host` gives helpers
## (heal, shield, waves...), `p()` reads the numbers from the `params` of the .tres, so one script can serve
## several items. Same idea as TechniqueBehavior for the Kata.

var data: Resource # the UpgradeData / RelicData
var host: Node # the RuleHost


func p(key: String, default: Variant) -> Variant:
	if data == null:
		return default
	return data.params.get(key, default)


## Called once, when the item is obtained.
func setup() -> void:
	pass


# ---- events

func on_dodge() -> void: # a dash started
	pass


func on_perfect_dodge(_source: Node) -> void:
	pass


func on_light_attack() -> void:
	pass


func on_heavy_attack() -> void:
	pass


## info: { target, damage, crit, kind, hit_count, killed, from_behind, overkill }
func on_hit_dealt(_info: Dictionary) -> void:
	pass


func on_critical_hit(_info: Dictionary) -> void:
	pass


func on_kill(_info: Dictionary) -> void:
	pass


func on_damage_taken(_amount: float) -> void:
	pass


func on_skill_used(_skill: Node) -> void:
	pass


func on_bleed_tick(_enemy: Node, _damage: float) -> void:
	pass


func on_kata_opened() -> void:
	pass


func on_kata_closed(_reason: String) -> void:
	pass


func on_finisher(_context: Dictionary) -> void:
	pass


## room_type: RoomData.RoomType of the room that was entered / cleared.
func on_room_entered(_room_type: int) -> void:
	pass


func on_room_cleared(_room_type: int) -> void:
	pass


func on_level_up(_level: int) -> void:
	pass


func on_tick(_delta: float) -> void:
	pass


# ---- questions the combat asks before a hit is dealt or taken

## Multiplies the damage of a hit the player deals. kind: "light" / "heavy" / "skill" / "wave".
func damage_multiplier(_kind: String, _target_health: Node) -> float:
	return 1.0


func crit_chance_bonus(_kind: String, _target: Node) -> float:
	return 0.0


func forced_crit(_kind: String, _target: Node) -> bool:
	return false


## True when this hit kills the target outright.
func executes(_kind: String, _target_health: Node) -> bool:
	return false


## Changes the damage the player is about to take (before the shield). `source` may be null.
func modify_incoming(damage: float, _source: Node) -> float:
	return damage


## Called when a hit would kill the player. Return true if the item saved him (it must restore the health itself).
func prevent_lethal(_damage: float) -> bool:
	return false
