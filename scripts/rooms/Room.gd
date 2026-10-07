extends Node3D
## Root script of every room scene.
## Required child nodes: PlayerSpawn (Marker3D), EnemySpawns (Node3D with EnemySpawnPoint children),
## Enemies (Node3D), RewardSpawn (Marker3D), Doors (Node3D with four Door children: North, East, South, West).
## RoomManager keeps visited rooms alive (out of the scene tree), so a room remembers what happened in it.

signal room_cleared
signal door_used(direction: String)
signal locked_door_touched(direction: String)

const DOOR_INWARD: Dictionary = {
	"north": Vector3(0.0, 0.0, 1.0), "south": Vector3(0.0, 0.0, -1.0),
	"east": Vector3(-1.0, 0.0, 0.0), "west": Vector3(1.0, 0.0, 0.0),
}
const ENTRY_DISTANCE: float = 2.4 # how far inside the room the player appears when coming through a door

# Enemies never spawn closer than this to where the player enters: two bodies placed on the same spot are pushed
# apart by the physics engine in a random direction (this once lifted the player into the air).
const MIN_ENEMY_SPAWN_DISTANCE: float = 3.5

@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var enemy_spawns: Node3D = $EnemySpawns
@onready var enemies_root: Node3D = $Enemies
@onready var reward_spawn: Marker3D = $RewardSpawn
@onready var doors_root: Node3D = $Doors

var doors: Dictionary = {} # "north" / "east" / "south" / "west" -> Door
var alive_enemies: int = 0
var entry_position: Vector3 = Vector3.ZERO # set by RoomManager before start_room()
var started_empty: bool = false # a shop or treasure room: no enemies, the doors are open from the start
var entered_before: bool = false
var cleared: bool = false


func _ready() -> void:
	entry_position = player_spawn.position
	for door in doors_root.get_children():
		doors[door.direction] = door
		door.entered.connect(func(direction: String): door_used.emit(direction))
		door.locked_touched.connect(func(direction: String): locked_door_touched.emit(direction))


func get_player_spawn_position() -> Vector3:
	return player_spawn.global_position


func get_reward_position() -> Vector3:
	return reward_spawn.global_position


## Where the player appears when entering through the door on side `direction` ("" = the room's own spawn point).
func get_entry_position(direction: String) -> Vector3:
	if direction == "" or not doors.has(direction):
		return player_spawn.global_position
	var door: Node3D = doors[direction]
	var spot: Vector3 = door.global_position + DOOR_INWARD[direction] * ENTRY_DISTANCE
	return Vector3(spot.x, 0.0, spot.z)


## neighbours: the sides that have a door ("east": true ...). boss_direction: the side of the door that leads to the boss.
func configure_doors(neighbours: Dictionary, boss_direction: String) -> void:
	for direction in doors:
		doors[direction].setup(neighbours.has(direction), direction == boss_direction)
	_update_doors()


## Text above every door of this room (the boss room says "NEXT BIOME").
func set_exit_tag(text: String) -> void:
	for direction in doors:
		if doors[direction].exists:
			doors[direction].tag.text = text


func set_door_locked(direction: String, locked: bool) -> void:
	if doors.has(direction):
		doors[direction].set_locked(locked)
		_update_doors()


func start_room() -> void:
	entered_before = true
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	for point in enemy_spawns.get_children():
		var scene: PackedScene = point.get("enemy_scene")
		if scene == null:
			continue
		var enemy: Node3D = scene.instantiate()
		if run_manager:
			enemy.max_health *= run_manager.enemy_health_multiplier # read by Enemy._ready, so the boss bar is right too
		enemies_root.add_child(enemy)
		enemy.global_position = _safe_enemy_position(point.global_position)
		enemy.defeated.connect(_on_enemy_defeated)
		alive_enemies += 1
	started_empty = alive_enemies == 0
	if started_empty:
		_clear_room.call_deferred()


## An enemy that was created during the fight (a summon): the room waits for it too.
func register_enemy(enemy: Node) -> void:
	enemy.defeated.connect(_on_enemy_defeated)
	alive_enemies += 1


func _safe_enemy_position(wanted: Vector3) -> Vector3:
	var spawn: Vector3 = entry_position
	var offset: Vector3 = wanted - spawn
	offset.y = 0.0
	if offset.length() >= MIN_ENEMY_SPAWN_DISTANCE:
		return wanted
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
	if cleared:
		return
	cleared = true
	if not started_empty:
		AudioManager.play_sfx("door") # the doors open after a fight
	_update_doors()
	room_cleared.emit()


## Doors are open once the room is cleared; a locked door (boss) stays shut.
func _update_doors() -> void:
	for direction in doors:
		doors[direction].set_open(cleared)
