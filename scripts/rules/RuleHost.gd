extends Node
## The place where upgrades and relics with a special rule (RuleBehavior) live. A child of the Player.
## It listens to everything that happens in the fight and tells every behavior; combat asks it the "filter" questions
## (damage multipliers, extra crit chance, incoming damage...). It also keeps the shield and has small helpers.

signal shield_changed(value: float)

const WAVE_SCENE: PackedScene = preload("res://scenes/player/Wave.tscn")
const SHURIKEN_SCENE: PackedScene = preload("res://scenes/player/Shuriken.tscn")

var behaviors: Array = []
var shield: float = 0.0
var hidden_left: float = 0.0 # while > 0 the enemies cannot see the player (they start no new attacks)
var player: CharacterBody3D
var events: Node


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	events = player.get_node("KataEvents")
	events.dodge.connect(func(): _each("on_dodge", []))
	events.perfect_dodge.connect(func(source): _each("on_perfect_dodge", [source]))
	events.light_attack.connect(func(): _each("on_light_attack", []))
	events.heavy_attack.connect(func(): _each("on_heavy_attack", []))
	events.hit_dealt.connect(func(info): _each("on_hit_dealt", [info]))
	events.critical_hit.connect(func(info): _each("on_critical_hit", [info]))
	events.kill.connect(func(info): _each("on_kill", [info]))
	events.damage_taken.connect(func(amount): _each("on_damage_taken", [amount]))
	events.skill_used.connect(func(skill): _each("on_skill_used", [skill]))
	events.skill_resolved.connect(func(skill): _each("on_skill_resolved", [skill]))
	events.bleed_tick.connect(func(enemy, damage): _each("on_bleed_tick", [enemy, damage]))
	var kata: Node = player.get_node("KataComponent")
	kata.opened.connect(func(): _each("on_kata_opened", []))
	kata.closed.connect(func(reason): _each("on_kata_closed", [reason]))
	kata.finisher_performed.connect(func(context): _each("on_finisher", [context]))
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.level_up.connect(func(level): _each("on_level_up", [level]))
		run_manager.gold_collected.connect(func(amount): _each("on_gold_collected", [amount]))
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager:
		room_manager.room_loaded.connect(_on_room_loaded)
		room_manager.biome_started.connect(func(index): _each("on_biome_started", [index]))
		room_manager.fight_room_cleared.connect(func(room_type): _each("on_room_cleared", [room_type]))


func _physics_process(delta: float) -> void:
	hidden_left = maxf(hidden_left - delta, 0.0)
	if not behaviors.is_empty() and not player.health.is_dead():
		_each("on_tick", [delta])


## Creates the behavior of an UpgradeData / RelicData (if it has one) and starts listening for it.
func add_behavior(item: Resource) -> RuleBehavior:
	if item == null or item.get("behavior") == null:
		return null
	var behavior: RuleBehavior = item.behavior.new()
	behavior.data = item
	behavior.host = self
	behaviors.append(behavior)
	behavior.setup()
	return behavior


func has_behavior(item_id: String) -> bool:
	return behaviors.any(func(behavior): return behavior.data.id == item_id)


func _each(method: String, args: Array) -> void:
	for behavior in behaviors.duplicate():
		behavior.callv(method, args)


func _on_room_loaded(_room: Node) -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var room_type: int = room_manager.current_room_data.room_type if room_manager and room_manager.current_room_data else -1
	_each("on_room_entered", [room_type])


# ---- questions from combat

func damage_multiplier(kind: String, target_health: Node) -> float:
	var multiplier: float = 1.0
	for behavior in behaviors:
		multiplier *= behavior.damage_multiplier(kind, target_health)
	return multiplier


func crit_chance_bonus(kind: String, target: Node) -> float:
	var bonus: float = 0.0
	for behavior in behaviors:
		bonus += behavior.crit_chance_bonus(kind, target)
	return bonus


func forced_crit(kind: String, target: Node) -> bool:
	return behaviors.any(func(behavior): return behavior.forced_crit(kind, target))


func executes(kind: String, target_health: Node) -> bool:
	return behaviors.any(func(behavior): return behavior.executes(kind, target_health))


## The damage the player takes after the rules, the shield and (as a last chance) a life saver.
## Returns the damage that really reaches the health (0 = nothing).
func process_incoming(damage: float, source: Node) -> float:
	for behavior in behaviors:
		damage = behavior.modify_incoming(damage, source)
	if shield > 0.0 and damage > 0.0:
		var absorbed: float = minf(shield, damage)
		set_shield(shield - absorbed)
		damage -= absorbed
	if damage <= 0.0:
		return 0.0
	if damage >= player.health.current_health:
		for behavior in behaviors:
			if behavior.prevent_lethal(damage):
				return 0.0
	return damage


# ---- helpers for the behaviors

## Enemies lose sight of the player for a while (Vanish, Kitsune Tail).
func hide_player(seconds: float) -> void:
	hidden_left = maxf(hidden_left, seconds)


## A zone on the floor that hurts (or makes bleed) the enemies inside it for a while.
func spawn_zone(position: Vector3, radius: float, duration: float, damage_per_second: float, bleed_per_second: float, color: Color = Color(0.9, 0.2, 0.3, 0.35), bleed_key: String = "") -> Node:
	var zone := HazardZone.new()
	zone.radius = radius
	zone.duration = duration
	zone.damage_per_second = damage_per_second
	zone.bleed_per_second = bleed_per_second
	zone.color = color
	zone.bleed_key = bleed_key
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var parent: Node = room_manager.current_room if room_manager and room_manager.current_room else get_tree().current_scene
	parent.add_child(zone)
	zone.global_position = Vector3(position.x, 0.05, position.z)
	return zone


func set_shield(value: float) -> void:
	shield = maxf(value, 0.0)
	shield_changed.emit(shield)


func add_shield(amount: float) -> void:
	set_shield(shield + amount)


func heal(amount: float) -> void:
	player.health.heal(amount)


func heal_percent(ratio: float) -> void:
	player.health.heal(player.health.max_health * ratio)


func show_text(text: String, color: Color = Color.WHITE) -> void:
	player._show_floating_text(text, color)


func attack_damage() -> float:
	return player.stats.get_stat("attack_damage")


func enemies_near(center: Vector3, radius: float, except: Node = null) -> Array:
	var found: Array = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == except or enemy.health.is_dead():
			continue
		var offset: Vector3 = enemy.global_position - center
		offset.y = 0.0
		if offset.length() <= radius:
			found.append(enemy)
	return found


func nearest_enemy(center: Vector3, radius: float, except: Node = null) -> Node:
	var best: Node = null
	var best_distance: float = radius
	for enemy in enemies_near(center, radius, except):
		var distance: float = (enemy.global_position - center).length()
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## A slash wave that flies forward (Combo Spark, Broken Katana Hilt, Gale Slash).
func fire_wave(direction: Vector3, damage: float, speed: float = 16.0, lifetime: float = 0.5, pierce: bool = true) -> void:
	_fire(WAVE_SCENE, direction, damage, speed, lifetime, pierce)


## A shuriken (Yume): small, stops at the first enemy it hits.
func fire_shuriken(direction: Vector3, damage: float, speed: float = 15.0, lifetime: float = 0.7) -> void:
	_fire(SHURIKEN_SCENE, direction, damage, speed, lifetime, false)


func _fire(scene: PackedScene, direction: Vector3, damage: float, speed: float, lifetime: float, pierce: bool) -> void:
	var projectile = scene.instantiate()
	projectile.damage = damage
	projectile.speed = speed
	projectile.lifetime = lifetime
	projectile.pierce = pierce
	projectile.source = player
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	var parent: Node = room_manager.current_room if room_manager and room_manager.current_room else get_tree().current_scene
	parent.add_child(projectile)
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
	projectile.launch(player.global_position + Vector3(0.0, 0.9, 0.0) + flat * 0.8, flat)
