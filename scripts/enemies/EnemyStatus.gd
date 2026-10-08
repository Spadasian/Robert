class_name EnemyStatus
extends RefCounted
## Effects on one enemy: bleed (damage over time, stacks), stun (it stands still), slow, and a mark (it takes more damage).
## Enemy.gd owns one and ticks it from _process. Bleed damage is credited to the player, so kills by bleed count.

const BLEED_TICK: float = 0.5
const MAX_BLEED_STACKS: int = 3

var enemy: Node
var bleeds: Array = [] # { "dps": float, "left": float }
var bleed_timer: float = 0.0
var stun_left: float = 0.0
var slow_factor: float = 1.0
var slow_left: float = 0.0
var mark_bonus: float = 0.0
var mark_left: float = 0.0


func _init(owner_enemy: Node) -> void:
	enemy = owner_enemy


func is_bleeding() -> bool:
	return not bleeds.is_empty()


## Adds a bleed stack. At the maximum, the weakest stack is replaced if the new one is stronger.
## `key` (optional): one stack per source, refreshed instead of added (a zone on the floor uses its own id).
func apply_bleed(dps: float, duration: float, key: String = "") -> void:
	if key != "":
		for stack in bleeds:
			if stack.get("key", "") == key:
				stack.dps = dps
				stack.left = duration
				return
	if bleeds.size() < MAX_BLEED_STACKS:
		bleeds.append({"dps": dps, "left": duration, "key": key})
		return
	var weakest: Dictionary = bleeds[0]
	for stack in bleeds:
		if stack.dps < weakest.dps:
			weakest = stack
	if dps >= weakest.dps:
		weakest.dps = dps
	weakest.left = duration


func apply_stun(duration: float) -> void:
	if enemy.has_method("can_be_stunned") and not enemy.can_be_stunned():
		return
	stun_left = maxf(stun_left, duration)


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, factor) if slow_left > 0.0 else factor
	slow_left = maxf(slow_left, duration)


func apply_mark(bonus: float, duration: float) -> void:
	mark_bonus = maxf(mark_bonus, bonus) if mark_left > 0.0 else bonus
	mark_left = maxf(mark_left, duration)


## 0 = stands still, 1 = normal speed.
func speed_factor() -> float:
	if stun_left > 0.0:
		return 0.0
	return slow_factor if slow_left > 0.0 else 1.0


## Multiplier of the damage this enemy receives.
func damage_taken_factor() -> float:
	return 1.0 + (mark_bonus if mark_left > 0.0 else 0.0)


func tick(delta: float) -> void:
	stun_left = maxf(stun_left - delta, 0.0)
	slow_left = maxf(slow_left - delta, 0.0)
	mark_left = maxf(mark_left - delta, 0.0)
	if bleeds.is_empty() or enemy.health.is_dead():
		bleeds.clear()
		return
	bleed_timer += delta
	var total_dps: float = 0.0
	for stack in bleeds:
		stack.left -= delta
		total_dps += stack.dps
	bleeds = bleeds.filter(func(stack): return stack.left > 0.0)
	if bleed_timer < BLEED_TICK:
		return
	bleed_timer = 0.0
	var damage: float = total_dps * BLEED_TICK
	enemy.health.take_damage(damage)
	var player: Node = enemy.get_tree().get_first_node_in_group("player")
	if player and player.has_method("on_bleed_tick"):
		player.on_bleed_tick(enemy, damage, enemy.health.is_dead())
