extends "res://scripts/rooms/Room.gd"
## An Arena: before the fight the player picks an omen (the harder, the better the reward), then 3 waves of enemies
## come. After the third wave: EXP, gold and a Kata technique (1 of 3); the hardest omen may add a Master technique.
## Optional room: the boss door does not wait for it.

const BANDIT: PackedScene = preload("res://scenes/enemies/Bandit.tscn")
const ARCHER: PackedScene = preload("res://scenes/enemies/Archer.tscn")
const NINJA: PackedScene = preload("res://scenes/enemies/Ninja.tscn")
const HEAVY: PackedScene = preload("res://scenes/enemies/HeavyBandit.tscn")

const WAVE_SIZES: Array[int] = [4, 5, 6]
const WAVE_PAUSE: float = 1.2
# Spots along the walls where enemies appear; the ones farthest from the player are used first.
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(-8, 0, -8), Vector3(0, 0, -9), Vector3(8, 0, -8), Vector3(9, 0, 0),
	Vector3(8, 0, 8), Vector3(0, 0, 9), Vector3(-8, 0, 8), Vector3(-9, 0, 0),
]
const OMENS: Array[Dictionary] = [
	{"name": "Pale Moon", "color": Color(0.8, 0.85, 1.0), "hp": 1.0, "damage": 1.0, "extra": 0, "heavy": 0,
		"xp": 40, "gold": 30, "master": 0.0, "text": "Normal enemies.", "reward": "Technique + 40 EXP + 30 gold"},
	{"name": "Blood Moon", "color": Color(1.0, 0.55, 0.3), "hp": 1.3, "damage": 1.25, "extra": 1, "heavy": 1,
		"xp": 90, "gold": 60, "master": 0.0, "text": "Enemies +30% health, +25% damage, one more per wave, a Heavy in the last wave.", "reward": "Technique + 90 EXP + 60 gold"},
	{"name": "Black Storm", "color": Color(0.75, 0.35, 1.0), "hp": 1.6, "damage": 1.5, "extra": 2, "heavy": 2,
		"xp": 180, "gold": 120, "master": 0.35, "text": "Enemies +60% health, +50% damage, two more per wave, two Heavies in the last wave.", "reward": "Technique + 180 EXP + 120 gold, 35% chance of a Master technique"},
]

var omen: Dictionary = {}
var wave: int = 0
var original_damage_multiplier: float = 1.0
var spawn_cycle: int = 0


## Instead of fixed enemies: the player chooses the omen, then the waves start.
func start_room() -> void:
	entered_before = true
	started_empty = false
	_begin.call_deferred()


func _begin() -> void:
	var picker := get_tree().get_first_node_in_group("omen_choice")
	omen = OMENS[0] if picker == null else await picker.choose(OMENS)
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		original_damage_multiplier = run_manager.enemy_damage_multiplier
		run_manager.enemy_damage_multiplier *= omen.damage
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message(omen.name.to_upper(), 2.0)
	_next_wave()


func _next_wave() -> void:
	wave += 1
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("WAVE %d / %d" % [wave, WAVE_SIZES.size()], WAVE_PAUSE)
	await get_tree().create_timer(WAVE_PAUSE, false).timeout
	_spawn_wave()


func _spawn_wave() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_position: Vector3 = player.global_position if player else Vector3.ZERO
	var spots: Array = SPAWN_POINTS.duplicate()
	spots.sort_custom(func(a, b): return a.distance_to(player_position) > b.distance_to(player_position))
	var heavies: int = omen.heavy if wave == WAVE_SIZES.size() else 0
	var count: int = WAVE_SIZES[wave - 1] + omen.extra
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	for index in count:
		var scene: PackedScene = HEAVY if index < heavies else [BANDIT, BANDIT, ARCHER, NINJA].pick_random()
		var enemy: Node3D = scene.instantiate()
		var health_scale: float = omen.hp * (run_manager.enemy_health_multiplier if run_manager else 1.0)
		enemy.max_health *= health_scale
		enemy.position = spots[spawn_cycle % spots.size()] + Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))
		spawn_cycle += 1
		enemies_root.add_child(enemy)
		register_enemy(enemy)


## A wave ended: the next one comes; after the last one the room is cleared.
func _on_enemy_defeated(enemy: Node) -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.register_kill(enemy)
	alive_enemies -= 1
	if alive_enemies > 0 or cleared:
		return
	if wave < WAVE_SIZES.size():
		_next_wave()
	else:
		_clear_room()


func _clear_room() -> void:
	if cleared:
		return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.enemy_damage_multiplier = original_damage_multiplier
	var techniques := get_tree().get_first_node_in_group("technique_manager")
	if techniques:
		techniques.offer_pending = true
	super()
	_give_reward(techniques)


func _give_reward(techniques: Node) -> void:
	await get_tree().create_timer(1.2, false).timeout
	var player := get_tree().get_first_node_in_group("player")
	if player and player.get_node("HealthComponent").is_dead():
		if techniques:
			techniques.offer_pending = false
		return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.add_gold(omen.gold)
		run_manager.add_xp(omen.xp)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("ARENA CLEARED   +%d EXP  +%d gold" % [omen.xp, omen.gold], 2.5)
	if techniques:
		techniques.offer([TechniqueData.Category.OPENING, TechniqueData.Category.FLOW, TechniqueData.Category.FINISHER], 3, randf() < omen.master)
