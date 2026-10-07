extends Node
## Builds the run plan with RunGenerator, loads rooms one by one, places the player
## and moves on when the exit is reached.

const GOLD_PICKUP_SCENE: PackedScene = preload("res://scenes/world/GoldPickup.tscn")

signal room_loaded(room: Node)
signal room_changed(index: int, total: int)
signal room_cleared

@export var room_pool: Array[Resource] = [] # every RoomData that can appear in a run
## Room types in order: 0 COMBAT, 1 ELITE, 2 TREASURE, 3 SHOP, 4 EVENT, 5 SHRINE, 6 BOSS
@export var layout: PackedInt32Array = PackedInt32Array([0, 0, 0, 1, 3, 0, 6])
## 0 = new random run every time. Put a number here to replay the same run.
@export var run_seed: int = 0

@onready var room_container: Node3D = $"../CurrentRoom"

var room_plan: Array = []
var current_room: Node3D
var current_room_data: Resource
var room_index: int = -1
var is_transitioning: bool = false


func _enter_tree() -> void:
	add_to_group("room_manager")


func _ready() -> void:
	if room_pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	if run_seed == 0:
		rng.randomize()
	else:
		rng.seed = run_seed
	print("Run seed: ", rng.seed)
	room_plan = RunGenerator.generate(room_pool, layout, rng)
	print("Run plan: ", room_plan.map(func(room): return room.display_name))
	_load_room_at.call_deferred(0)


func load_room(room_data: Resource) -> void:
	if current_room:
		room_container.remove_child(current_room)
		current_room.queue_free()
	current_room_data = room_data
	current_room = room_data.scene.instantiate()
	room_container.add_child(current_room)

	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		player.global_position = current_room.get_player_spawn_position()
		player.velocity = Vector3.ZERO
	var camera_rig := get_tree().get_first_node_in_group("camera_rig")
	if camera_rig:
		camera_rig.snap_to_target()

	current_room.room_cleared.connect(_on_room_cleared)
	current_room.exit_reached.connect(_on_exit_reached)
	current_room.start_room()
	room_loaded.emit(current_room)


func _load_room_at(index: int) -> void:
	room_index = index
	load_room(room_plan[index])
	room_changed.emit(room_index, room_plan.size())


func _on_room_cleared() -> void:
	_spawn_reward()
	var hud := get_tree().get_first_node_in_group("hud")
	var is_fight: bool = current_room_data.room_type in [RoomData.RoomType.COMBAT, RoomData.RoomType.ELITE, RoomData.RoomType.BOSS]
	if hud and is_fight:
		hud.show_message("ROOM CLEARED")
	room_cleared.emit()


func _on_exit_reached() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	# Anything left on the floor is collected automatically when you leave.
	for pickup in get_tree().get_nodes_in_group("pickup"):
		pickup.collect()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		await hud.fade_out()

	if room_index + 1 >= room_plan.size():
		# Placeholder until Phase 16 (victory screen): start a brand new run.
		print("Run complete")
		get_tree().reload_current_scene()
		return

	_load_room_at(room_index + 1)
	if hud:
		await hud.fade_in()
	is_transitioning = false


func _spawn_reward() -> void:
	if current_room_data.reward_gold <= 0:
		return
	var pickup: Node3D = GOLD_PICKUP_SCENE.instantiate()
	pickup.amount = current_room_data.reward_gold
	current_room.add_child(pickup)
	pickup.global_position = current_room.get_reward_position()
