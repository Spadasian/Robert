extends Node3D
## Root script of every room scene.
## Required child nodes: PlayerSpawn (Marker3D), EnemySpawns (Node3D with EnemySpawnPoint children), Enemies (Node3D).

signal room_cleared

@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var enemy_spawns: Node3D = $EnemySpawns
@onready var enemies_root: Node3D = $Enemies

var alive_enemies: int = 0


func get_player_spawn_position() -> Vector3:
	return player_spawn.global_position


func start_room() -> void:
	for point in enemy_spawns.get_children():
		var scene: PackedScene = point.get("enemy_scene")
		if scene == null:
			continue
		var enemy: Node3D = scene.instantiate()
		enemies_root.add_child(enemy)
		enemy.global_position = point.global_position
		enemy.defeated.connect(_on_enemy_defeated)
		alive_enemies += 1
	if alive_enemies == 0:
		room_cleared.emit.call_deferred()


func _on_enemy_defeated(_enemy: Node) -> void:
	alive_enemies -= 1
	if alive_enemies <= 0:
		room_cleared.emit()
