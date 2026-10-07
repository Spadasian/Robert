extends Node
## Builds the dungeon map with DungeonGenerator, moves the player from room to room through doors and keeps
## the rooms the player has visited alive (out of the scene tree), so they remember what happened in them.
## The door to the boss stays locked until every other room is entered and cleared.

const GOLD_PICKUP_SCENE: PackedScene = preload("res://scenes/world/GoldPickup.tscn")

signal room_loaded(room: Node)
signal room_changed(index: int, total: int) # a room was entered: index = rooms cleared, total = rooms before the boss
signal map_changed # something the minimap shows changed (a room entered or cleared)
signal room_cleared
signal run_completed # a door of the boss room was used after the boss died; EndScreen shows the victory

@export var room_pool: Array[Resource] = [] # every RoomData that can appear in a run (including START and BOSS)
@export var combat_rooms: int = 4
@export var elite_rooms: int = 1
@export var treasure_rooms: int = 1
@export var shop_rooms: int = 1
@export var event_rooms: int = 0
@export var shrine_rooms: int = 0
@export var grid_size: Vector2i = Vector2i(5, 4)
## 0 = new random run every time. Put a number here to replay the same run.
@export var run_seed: int = 0

@onready var room_container: Node3D = $"../CurrentRoom"

var dungeon: Dictionary = {}
var rooms: Dictionary = {} # Vector2i -> Room instance, created when the player first enters the cell
var visited: Dictionary = {} # Vector2i -> true
var current_cell: Vector2i = Vector2i.ZERO
var current_room: Node3D
var current_room_data: Resource
var boss_unlocked: bool = false
var is_transitioning: bool = false
var rooms_done: int = 0
var rooms_total: int = 0 # every room except the boss room


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
	var counts: Dictionary = {
		RoomData.RoomType.COMBAT: combat_rooms, RoomData.RoomType.ELITE: elite_rooms,
		RoomData.RoomType.TREASURE: treasure_rooms, RoomData.RoomType.SHOP: shop_rooms,
		RoomData.RoomType.EVENT: event_rooms, RoomData.RoomType.SHRINE: shrine_rooms,
	}
	dungeon = DungeonGenerator.generate(room_pool, counts, grid_size, rng)
	rooms_total = dungeon.cells.size() - 1
	_enter_cell.call_deferred(dungeon.start, "")


func _exit_tree() -> void:
	# Rooms that are not in the tree are not freed with the scene, so free them here.
	for cell in rooms:
		var room: Node = rooms[cell]
		if is_instance_valid(room) and not room.is_inside_tree():
			room.queue_free()


## Cell of the dungeon where the player is.
func get_cell_data(cell: Vector2i) -> Dictionary:
	return dungeon.cells.get(cell, {})


func is_cell_cleared(cell: Vector2i) -> bool:
	return rooms.has(cell) and rooms[cell].cleared


func _enter_cell(cell: Vector2i, entry_side: String) -> void:
	if current_room:
		room_container.remove_child(current_room) # kept alive: it remembers its state

	current_cell = cell
	var cell_data: Dictionary = dungeon.cells[cell]
	current_room_data = cell_data.data
	var is_new: bool = not rooms.has(cell)
	if is_new:
		var room: Node3D = current_room_data.scene.instantiate()
		rooms[cell] = room
		room.room_cleared.connect(_on_room_cleared.bind(cell))
		room.door_used.connect(_on_door_used)
		room.locked_door_touched.connect(_on_locked_door_touched)
	current_room = rooms[cell]
	room_container.add_child(current_room)
	if is_new:
		var boss_side: String = dungeon.boss_door if cell == dungeon.boss_parent else ""
		current_room.configure_doors(cell_data.doors, boss_side)
		if boss_side != "":
			current_room.set_door_locked(boss_side, not boss_unlocked)

	var entry: Vector3 = current_room.get_entry_position(entry_side)
	current_room.entry_position = entry
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		player.global_position = entry
		player.velocity = Vector3.ZERO
	var camera_rig := get_tree().get_first_node_in_group("camera_rig")
	if camera_rig:
		camera_rig.snap_to_target()

	var is_boss_room: bool = current_room_data.room_type == RoomData.RoomType.BOSS
	AudioManager.play_music("music_boss" if is_boss_room else "music_run")
	AudioManager.play_ambience("ambience_night")
	visited[cell] = true
	if not current_room.entered_before:
		current_room.start_room()
	room_loaded.emit(current_room)
	room_changed.emit(rooms_done, rooms_total)
	map_changed.emit()


func _on_door_used(direction: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	# Anything left on the floor is collected automatically when you leave.
	for pickup in get_tree().get_nodes_in_group("pickup"):
		pickup.collect()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		await hud.fade_out()

	if current_cell == dungeon.boss:
		# The run is won. is_transitioning stays true so a door cannot fire twice.
		print("Run complete")
		if hud:
			await hud.fade_in()
		run_completed.emit()
		return

	var next_cell: Vector2i = dungeon.cells[current_cell].doors[direction]
	_enter_cell(next_cell, DungeonGenerator.OPPOSITE[direction])
	if hud:
		await hud.fade_in()
	is_transitioning = false


func _on_locked_door_touched(_direction: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("The boss door is sealed: %d / %d rooms cleared" % [rooms_done, rooms_total], 2.0)


func _on_room_cleared(cell: Vector2i) -> void:
	var data: Resource = dungeon.cells[cell].data
	var type: int = data.room_type
	if type != RoomData.RoomType.BOSS:
		rooms_done += 1
		_update_boss_lock()
	map_changed.emit()
	# Rooms without a fight give no gold and no free upgrade choice (not emitting room_cleared silences UpgradeManager).
	var is_fight: bool = type == RoomData.RoomType.COMBAT or type == RoomData.RoomType.ELITE or type == RoomData.RoomType.BOSS
	if not is_fight:
		return
	_spawn_reward(data)
	AudioManager.play_sfx("room_clear")
	var is_boss: bool = type == RoomData.RoomType.BOSS
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.rooms_cleared += 1
		if is_boss:
			run_manager.boss_defeated = true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("BOSS DEFEATED" if is_boss else "ROOM CLEARED", 3.0 if is_boss else 2.0)
	if is_boss:
		return # the run ends when the player uses the door, so no upgrade choice (not emitting also silences UpgradeManager)
	room_cleared.emit()


## When every room before the boss is cleared the boss door opens.
func _update_boss_lock() -> void:
	if boss_unlocked or rooms_done < rooms_total:
		return
	boss_unlocked = true
	var parent_room: Node = rooms.get(dungeon.boss_parent)
	if parent_room:
		parent_room.set_door_locked(dungeon.boss_door, false)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("The boss door is open", 3.0)


func _spawn_reward(data: Resource) -> void:
	var pickup: Node3D = GOLD_PICKUP_SCENE.instantiate()
	pickup.amount = data.reward_gold
	current_room.add_child(pickup)
	pickup.global_position = current_room.get_reward_position()
