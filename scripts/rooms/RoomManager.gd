extends Node
## Loads a room scene into the run, places the player and reports when the room is cleared.

signal room_loaded(room: Node)
signal room_cleared

@export var starting_room: Resource # a RoomData

@onready var room_container: Node3D = $"../CurrentRoom"

var current_room: Node3D


func _ready() -> void:
	add_to_group("room_manager")
	if starting_room:
		load_room.call_deferred(starting_room)


func load_room(room_data: Resource) -> void:
	if current_room:
		room_container.remove_child(current_room)
		current_room.queue_free()
	current_room = room_data.scene.instantiate()
	room_container.add_child(current_room)

	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		player.global_position = current_room.get_player_spawn_position()
		player.velocity = Vector3.ZERO

	current_room.room_cleared.connect(_on_room_cleared)
	current_room.start_room()
	room_loaded.emit(current_room)


func _on_room_cleared() -> void:
	room_cleared.emit()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("ROOM CLEARED")
