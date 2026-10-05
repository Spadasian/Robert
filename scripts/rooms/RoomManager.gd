extends Node
## Loads room scenes into the run, places the player and moves on when the exit is reached.
## For now rooms come from a fixed list; the procedural generator (Phase 12) will replace it.

const GOLD_PICKUP_SCENE: PackedScene = preload("res://scenes/world/GoldPickup.tscn")

signal room_loaded(room: Node)
signal room_cleared

@export var room_sequence: Array[Resource] = [] # RoomData resources

@onready var room_container: Node3D = $"../CurrentRoom"

var current_room: Node3D
var current_room_data: Resource
var room_index: int = -1
var is_transitioning: bool = false


func _ready() -> void:
	add_to_group("room_manager")
	if not room_sequence.is_empty():
		_load_next_room.call_deferred()


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


func _load_next_room() -> void:
	room_index = (room_index + 1) % room_sequence.size()
	load_room(room_sequence[room_index])


func _on_room_cleared() -> void:
	room_cleared.emit()
	_spawn_reward()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("ROOM CLEARED")


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
	_load_next_room()
	if hud:
		await hud.fade_in()
	is_transitioning = false


func _spawn_reward() -> void:
	var pickup: Node3D = GOLD_PICKUP_SCENE.instantiate()
	pickup.amount = current_room_data.reward_gold
	current_room.add_child(pickup)
	pickup.global_position = current_room.get_reward_position()
