extends Node3D
## Root script of every room scene.
## Required child nodes: PlayerSpawn (Marker3D), EnemySpawns (Node3D with EnemySpawnPoint children),
## Enemies (Node3D), RewardSpawn (Marker3D), Exit (Area3D) with a DoorVisual (MeshInstance3D) inside it.

signal room_cleared
signal exit_reached

@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var enemy_spawns: Node3D = $EnemySpawns
@onready var enemies_root: Node3D = $Enemies
@onready var reward_spawn: Marker3D = $RewardSpawn
@onready var exit_area: Area3D = $Exit
@onready var door_visual: MeshInstance3D = $Exit/DoorVisual

var alive_enemies: int = 0
var door_material: StandardMaterial3D


func _ready() -> void:
	door_material = door_visual.get_active_material(0).duplicate() as StandardMaterial3D
	door_visual.material_override = door_material
	exit_area.body_entered.connect(_on_exit_body_entered)
	_set_door_open(false)


func get_player_spawn_position() -> Vector3:
	return player_spawn.global_position


func get_reward_position() -> Vector3:
	return reward_spawn.global_position


# Enemies never spawn closer than this to the player spawn: two bodies placed on the same spot are pushed apart
# by the physics engine in a random direction (this once lifted the player into the air).
const MIN_ENEMY_SPAWN_DISTANCE: float = 3.5

var started_empty: bool = false # a shop or treasure room: no enemies, the exit is open from the start


func start_room() -> void:
	for point in enemy_spawns.get_children():
		var scene: PackedScene = point.get("enemy_scene")
		if scene == null:
			continue
		var enemy: Node3D = scene.instantiate()
		enemies_root.add_child(enemy)
		enemy.global_position = _safe_enemy_position(point.global_position)
		enemy.defeated.connect(_on_enemy_defeated)
		alive_enemies += 1
	started_empty = alive_enemies == 0
	if started_empty:
		_clear_room.call_deferred()


func _safe_enemy_position(wanted: Vector3) -> Vector3:
	var spawn: Vector3 = player_spawn.global_position
	var offset: Vector3 = wanted - spawn
	offset.y = 0.0
	if offset.length() >= MIN_ENEMY_SPAWN_DISTANCE:
		return wanted
	push_warning("%s: an enemy spawn point is too close to the player spawn, moved it away" % name)
	var away: Vector3 = offset.normalized() if offset.length() > 0.01 else Vector3.RIGHT
	return Vector3(spawn.x + away.x * MIN_ENEMY_SPAWN_DISTANCE, wanted.y, spawn.z + away.z * MIN_ENEMY_SPAWN_DISTANCE)


func _on_enemy_defeated(_enemy: Node) -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.register_kill()
	alive_enemies -= 1
	if alive_enemies <= 0:
		_clear_room()


func _clear_room() -> void:
	if not started_empty:
		AudioManager.play_sfx("door") # the exit opens after a fight
	_set_door_open(true)
	room_cleared.emit()


func _set_door_open(open: bool) -> void:
	exit_area.set_deferred("monitoring", open)
	door_material.albedo_color = Color(0.2, 0.9, 0.8) if open else Color(0.3, 0.05, 0.05)
	door_material.emission_enabled = open
	door_material.emission = Color(0.2, 0.9, 0.8)


func _on_exit_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		exit_reached.emit()
