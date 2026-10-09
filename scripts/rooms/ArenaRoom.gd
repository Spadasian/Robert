extends "res://scripts/rooms/Room.gd"
## An Arena: before the fight the player picks an omen (the harder, the better the reward), then 3 waves of enemies
## come. After the third wave: EXP, gold and a Kata technique (1 of 3); the hardest omen may add a Master technique.
## Optional room: the boss door does not wait for it.

const BANDIT: PackedScene = preload("res://scenes/enemies/Bandit.tscn")
const ARCHER: PackedScene = preload("res://scenes/enemies/Archer.tscn")
const NINJA: PackedScene = preload("res://scenes/enemies/Ninja.tscn")
const HEAVY: PackedScene = preload("res://scenes/enemies/HeavyBandit.tscn")

const ArrowStrike = preload("res://scripts/combat/ArrowStrike.gd")
const WAVE_PAUSE: float = 1.2
# Spots along the walls where enemies appear; the ones farthest from the player are used first.
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(-8, 0, -8), Vector3(0, 0, -9), Vector3(8, 0, -8), Vector3(9, 0, 0),
	Vector3(8, 0, 8), Vector3(0, 0, 9), Vector3(-8, 0, 8), Vector3(-9, 0, 0),
]
const OMENS: Array[Dictionary] = ArenaOmens.LIST # kept for the tests; the full numbers come from ArenaOmens.all()
const FOG_FADE_START: float = 5.0 # Fog of Ghosts: enemies start to fade at this distance (m)
const FOG_FADE_RANGE: float = 4.0
const RAIN_INTERVAL: float = 1.5 # Iron Rain: seconds between volleys

var omen: Dictionary = {}
var wave: int = 0
var original_damage_multiplier: float = 1.0
var spawn_cycle: int = 0
var sky_backup: Dictionary = {} # the atmosphere before the omen (restored when the arena ends)
var extra_lights: Array[Node] = []
var rain_timer: float = 0.0
var heal_was_blocked: bool = false
var ultimate: Node # locked by Silent Night


## Instead of fixed enemies: the player chooses the omen, then the waves start.
func start_room() -> void:
	entered_before = true
	started_empty = false
	_begin.call_deferred()


func _begin() -> void:
	var picker := get_tree().get_first_node_in_group("omen_choice")
	var offered: Array = ArenaOmens.pick(3)
	omen = offered[0] if picker == null else await picker.choose(offered)
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		original_damage_multiplier = run_manager.enemy_damage_multiplier
		run_manager.enemy_damage_multiplier *= omen.damage
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message(omen.name.to_upper(), 2.0)
	_apply_omen_effects()
	_next_wave()


# ---------------------------------------------------------------- special omens

func _apply_omen_effects() -> void:
	_apply_atmosphere()
	var player := get_tree().get_first_node_in_group("player")
	match omen.id:
		"hunger_moon":
			if player:
				heal_was_blocked = player.health.heal_blocked
				player.health.heal_blocked = true
		"silent_night":
			if player:
				for skill in player.skills:
					if skill.has_method("add_charge"):
						ultimate = skill
				if ultimate:
					ultimate.charge_locked = true
		"twin_suns":
			for side in [-1.0, 1.0]:
				var sun := OmniLight3D.new()
				sun.light_color = Color(1.0, 0.85, 0.45)
				sun.light_energy = 3.0
				sun.omni_range = 20.0
				sun.position = Vector3(9.0 * side, 4.0, 0.0)
				add_child(sun)
				extra_lights.append(sun)
	set_process(omen.id == "fog_of_ghosts" or omen.id == "iron_rain")


## Forward+ atmosphere: volumetric fog, ambient and sun colours (the WorldEnvironment and the Sun of the Run scene).
func _apply_atmosphere() -> void:
	var sky: Dictionary = omen.sky
	if sky.is_empty():
		return
	var environment: Environment = _world_environment()
	var sun: DirectionalLight3D = _sun()
	if environment:
		sky_backup["ambient_color"] = environment.ambient_light_color
		sky_backup["ambient_energy"] = environment.ambient_light_energy
		sky_backup["fog"] = environment.volumetric_fog_enabled
		sky_backup["fog_density"] = environment.volumetric_fog_density
		sky_backup["fog_color"] = environment.volumetric_fog_albedo
		if sky.has("ambient_color"):
			environment.ambient_light_color = sky.ambient_color
		if sky.has("ambient_energy"):
			environment.ambient_light_energy = sky.ambient_energy
		if sky.has("fog_density"):
			environment.volumetric_fog_enabled = true
			environment.volumetric_fog_density = sky.fog_density
			environment.volumetric_fog_albedo = sky.get("fog_color", Color(0.6, 0.65, 0.75))
			environment.volumetric_fog_emission = Color(0.05, 0.06, 0.09)
	if sun:
		sky_backup["sun_color"] = sun.light_color
		sky_backup["sun_energy"] = sun.light_energy
		if sky.has("sun_color"):
			sun.light_color = sky.sun_color
		if sky.has("sun_energy"):
			sun.light_energy = sky.sun_energy


func _restore_omen_effects() -> void:
	var environment: Environment = _world_environment()
	var sun: DirectionalLight3D = _sun()
	if environment and sky_backup.has("ambient_color"):
		environment.ambient_light_color = sky_backup.ambient_color
		environment.ambient_light_energy = sky_backup.ambient_energy
		environment.volumetric_fog_enabled = sky_backup.fog
		environment.volumetric_fog_density = sky_backup.fog_density
		environment.volumetric_fog_albedo = sky_backup.fog_color
	if sun and sky_backup.has("sun_color"):
		sun.light_color = sky_backup.sun_color
		sun.light_energy = sky_backup.sun_energy
	sky_backup.clear()
	for light in extra_lights:
		if is_instance_valid(light):
			light.queue_free()
	extra_lights.clear()
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if omen.get("id", "") == "hunger_moon" and player:
		player.health.heal_blocked = heal_was_blocked
	if is_instance_valid(ultimate):
		ultimate.charge_locked = false
		ultimate = null
	set_process(false)
	_unfade_enemies()


func _world_environment() -> Environment:
	var node: Node = get_tree().root.find_child("WorldEnvironment", true, false) if is_inside_tree() else null
	return node.environment if node else null


func _sun() -> DirectionalLight3D:
	return get_tree().root.find_child("Sun", true, false) as DirectionalLight3D if is_inside_tree() else null


func _exit_tree() -> void:
	if not sky_backup.is_empty() or is_instance_valid(ultimate) or not extra_lights.is_empty() or omen.get("id", "") == "hunger_moon":
		_restore_omen_effects()


func _process(delta: float) -> void:
	if omen.is_empty() or cleared:
		return
	if omen.id == "fog_of_ghosts":
		_fade_enemies_in_fog()
	elif omen.id == "iron_rain" and wave > 0 and alive_enemies > 0:
		rain_timer -= delta
		if rain_timer <= 0.0:
			rain_timer = RAIN_INTERVAL
			_arrow_volley()


## Fog of Ghosts: the farther an enemy is from the player, the more it vanishes into the fog.
func _fade_enemies_in_fog() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	for enemy in enemies_root.get_children():
		var distance: float = (enemy.global_position - player.global_position).length()
		var fade: float = clampf((distance - FOG_FADE_START) / FOG_FADE_RANGE, 0.0, 0.92)
		for mesh in enemy.find_children("*", "MeshInstance3D", true, false):
			mesh.transparency = fade


func _unfade_enemies() -> void:
	for enemy in enemies_root.get_children():
		for mesh in enemy.find_children("*", "MeshInstance3D", true, false):
			mesh.transparency = 0.0


## Iron Rain: one volley of arrows on the player and one or two random spots.
func _arrow_volley() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var spots: Array = [player.global_position]
	for index in randi_range(1, 2):
		spots.append(Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0)))
	for spot in spots:
		_strike_at(spot, 1.6, 1.2, 10.0, Color(1.0, 0.25, 0.2, 0.45), true)


func _strike_at(spot: Vector3, radius: float, delay: float, damage: float, color: Color, arrows: bool) -> Node:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var strike := ArrowStrike.new()
	strike.radius = radius
	strike.delay = delay
	strike.damage = damage * (run_manager.enemy_damage_multiplier if run_manager else 1.0)
	strike.color = color
	strike.arrows = arrows
	add_child(strike)
	strike.global_position = Vector3(spot.x, 0.05, spot.z)
	return strike


func _next_wave() -> void:
	wave += 1
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("WAVE %d / %d" % [wave, omen.waves.size()], WAVE_PAUSE)
	await get_tree().create_timer(WAVE_PAUSE, false).timeout
	_spawn_wave()


func _spawn_wave() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_position: Vector3 = player.global_position if player else Vector3.ZERO
	var heavies: int = omen.heavy if wave == omen.waves.size() else 0
	var count: int = omen.waves[wave - 1] + omen.extra
	for group in omen.groups:
		var spots: Array = _group_spots(group, player_position)
		for index in count:
			var scene: PackedScene = HEAVY if (group == 0 and index < heavies) else [BANDIT, BANDIT, ARCHER, NINJA].pick_random()
			_spawn_enemy(scene, spots[spawn_cycle % spots.size()])
			spawn_cycle += 1


## The spots a group uses: all of them (farthest from the player first), or one side of the arena for Twin Suns.
func _group_spots(group: int, player_position: Vector3) -> Array:
	var spots: Array = SPAWN_POINTS.duplicate()
	if omen.groups > 1:
		spots = spots.filter(func(spot): return (spot.x <= 0.0) == (group == 0))
	spots.sort_custom(func(a, b): return a.distance_to(player_position) > b.distance_to(player_position))
	return spots


func _spawn_enemy(scene: PackedScene, spot: Vector3) -> Node:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var enemy: Node3D = scene.instantiate()
	var health_scale: float = omen.hp * (run_manager.enemy_health_multiplier if run_manager else 1.0)
	enemy.max_health *= health_scale
	if omen.speed != 1.0 and "move_speed" in enemy:
		enemy.move_speed *= omen.speed # Eclipse
	if omen.id == "eclipse":
		enemy.hide_next_telegraph = true
	enemy.position = spot + Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))
	enemies_root.add_child(enemy)
	register_enemy(enemy)
	return enemy


## A wave ended: the next one comes; after the last one the room is cleared.
func _on_enemy_defeated(enemy: Node) -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.register_kill(enemy)
	alive_enemies -= 1
	if omen.id == "crimson_tide" and is_instance_valid(enemy):
		_strike_at(enemy.global_position, 2.2, 0.6, 8.0, Color(1.0, 0.35, 0.2, 0.5), false)
	if alive_enemies > 0 or cleared:
		return
	if wave < omen.waves.size():
		_next_wave()
	else:
		_clear_room()


func _clear_room() -> void:
	if cleared:
		return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.enemy_damage_multiplier = original_damage_multiplier
	_restore_omen_effects()
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
		var stats: Node = player.get_node("StatsComponent") if player else null
		var extra_cards: int = int(stats.get_stat("reward_cards")) if stats else 0
		var master_chance: float = omen.master + (stats.get_stat("master_chance") if stats else 0.0)
		techniques.offer([TechniqueData.Category.OPENING, TechniqueData.Category.FLOW, TechniqueData.Category.FINISHER], 3 + extra_cards, randf() < master_chance, omen.rerolls)
