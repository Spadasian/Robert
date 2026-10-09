extends Node
## Builds the dungeon of the current biome with DungeonGenerator, moves the player from room to room through doors
## and keeps the rooms the player has visited alive (out of the scene tree), so they remember what happened in them.
## The door to the boss stays locked until every other room is entered and cleared. The boss door of a biome leads to
## the next biome; after the last one the run is won. The run mode (RunModeData) says which biomes a run has.

const GOLD_PICKUP_SCENE: PackedScene = preload("res://scenes/world/GoldPickup.tscn")
const BOSS_GOLD_REWARD: int = 30
const BOSS_HEAL_RATIO: float = 0.5

signal biome_started(index: int)
signal room_loaded(room: Node)
signal room_changed(index: int, total: int) # a room was entered: index = rooms cleared, total = rooms before the boss
signal map_changed # something the minimap shows changed (a room entered or cleared, a new biome)
signal room_cleared
signal fight_room_cleared(room_type: int) # any fight room was cleared (also mini-boss, boss, Duel, Arena)
signal miniboss_defeated # the mini-boss of the biome fell (TechniqueManager reacts: it teaches an Opening or Flow)
signal boss_defeated(is_final: bool) # the boss of a biome fell; is_final = it was the last biome
signal run_completed # the boss door was used after the last boss died; EndScreen shows the victory

@export var room_pool: Array[Resource] = [] # every RoomData that can appear in a run (including START and BOSS)
## Used when the Run scene is started on its own (F6 in the editor); normally GameManager.run_mode is used.
@export var default_mode: Resource
## The kinds of mini-boss (MiniBossVariant). Each biome of a run gets a different one while there are enough.
@export var miniboss_variants: Array[Resource] = []
## The kinds of master met in Duel rooms (also MiniBossVariant resources); picked like the mini-boss variants.
@export var duel_variants: Array[Resource] = []
## 0 = new random run every time. Put a number here to replay the same run.
@export var run_seed: int = 0

@onready var room_container: Node3D = $"../CurrentRoom"

var mode: Resource
var biomes: Array = []
var biome_index: int = -1
var biome: Resource
var dungeon: Dictionary = {}
var rooms: Dictionary = {} # Vector2i -> Room instance, created when the player first enters the cell
var visited: Dictionary = {} # Vector2i -> true
var current_cell: Vector2i = Vector2i.ZERO
var current_room: Node3D
var current_room_data: Resource
var boss_unlocked: bool = false
var is_transitioning: bool = false
var rooms_done: int = 0
var rooms_total: int = 0 # every required room of this biome (not the boss room, not the optional special rooms)
var miniboss_variant: Resource # the variant of the mini-boss of the current biome
var variant_bag: Array = [] # variants not used yet in this run
var duel_variant: Resource # the master of the Duel room of the current biome
var duel_bag: Array = []

# Rooms the boss door does not wait for.
const OPTIONAL_TYPES: Array = [RoomData.RoomType.DUEL, RoomData.RoomType.ARENA]
# Special rooms: the door that leads to one has a coloured label, visible before entering.
const DOOR_LABELS: Dictionary = {
	RoomData.RoomType.MINIBOSS: ["MINI-BOSS", Color(1.0, 0.35, 0.3)],
	RoomData.RoomType.DUEL: ["DUEL", Color(0.4, 0.85, 1.0)],
	RoomData.RoomType.ARENA: ["ARENA", Color(1.0, 0.6, 0.2)],
	RoomData.RoomType.TREASURE: ["TREASURE", Color(1.0, 0.85, 0.3)],
	RoomData.RoomType.SHOP: ["SHOP", Color(0.4, 0.9, 0.5)],
}


func _enter_tree() -> void:
	add_to_group("room_manager")


func _ready() -> void:
	if room_pool.is_empty():
		return
	mode = GameManager.run_mode if GameManager.run_mode != null else default_mode
	biomes = mode.biomes
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.mode_name = mode.display_name
		run_manager.biome_count = biomes.size()
		run_manager.shard_multiplier = mode.shard_multiplier
	_start_biome.call_deferred(0)


func _exit_tree() -> void:
	# Rooms that are not in the tree are not freed with the scene, so free them here.
	_free_kept_rooms()


func is_final_biome() -> bool:
	return biome_index + 1 >= biomes.size()


func get_cell_data(cell: Vector2i) -> Dictionary:
	return dungeon.cells.get(cell, {})


func is_cell_cleared(cell: Vector2i) -> bool:
	return rooms.has(cell) and rooms[cell].cleared


func _free_kept_rooms() -> void:
	for cell in rooms:
		var room: Node = rooms[cell]
		if is_instance_valid(room):
			if room.get_parent():
				room.get_parent().remove_child(room)
			room.queue_free()
	rooms.clear()
	current_room = null


## Builds and enters the dungeon of biome number `index` of the run mode.
func _start_biome(index: int) -> void:
	biome_index = index
	biome = biomes[index]
	_free_kept_rooms()
	visited.clear()
	boss_unlocked = false
	rooms_done = 0

	var rng := RandomNumberGenerator.new()
	if run_seed == 0:
		rng.randomize()
	else:
		rng.seed = run_seed + index
	print("Biome %d (%s), seed: %d" % [index + 1, biome.display_name, rng.seed])
	dungeon = DungeonGenerator.generate(room_pool, biome.get_room_counts(), biome.grid_size, rng)
	rooms_total = 0
	for cell in dungeon.cells:
		var type: int = dungeon.cells[cell].data.room_type
		if cell != dungeon.boss and not OPTIONAL_TYPES.has(type):
			rooms_total += 1
	_pick_miniboss_variant(rng)
	_pick_duel_variant(rng)

	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.biome_index = index
		run_manager.enemy_health_multiplier = biome.enemy_health_multiplier
		run_manager.enemy_damage_multiplier = biome.enemy_damage_multiplier
	_apply_biome_look()
	biome_started.emit(index)
	_enter_cell(dungeon.start, "")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and biomes.size() > 1:
		hud.show_message("Biome %d: %s" % [index + 1, biome.display_name], 3.0)


## A different mini-boss variant for every biome while the variants last (then the bag is refilled).
func _pick_miniboss_variant(rng: RandomNumberGenerator) -> void:
	miniboss_variant = null
	if miniboss_variants.is_empty():
		return
	if variant_bag.is_empty():
		variant_bag = miniboss_variants.duplicate()
	miniboss_variant = variant_bag[rng.randi() % variant_bag.size()]
	variant_bag.erase(miniboss_variant)
	print("Mini-boss of this biome: %s" % miniboss_variant.display_name)


func _pick_duel_variant(rng: RandomNumberGenerator) -> void:
	duel_variant = null
	if duel_variants.is_empty():
		return
	if duel_bag.is_empty():
		duel_bag = duel_variants.duplicate()
	duel_variant = duel_bag[rng.randi() % duel_bag.size()]
	duel_bag.erase(duel_variant)


func _apply_biome_look() -> void:
	var world_environment := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if world_environment and world_environment.environment:
		world_environment.environment.background_color = biome.background_color
		world_environment.environment.ambient_light_color = biome.ambient_color
	var sun := get_node_or_null("../Sun") as DirectionalLight3D
	if sun:
		sun.light_color = biome.sun_color


func _enter_cell(cell: Vector2i, entry_side: String) -> void:
	if current_room and current_room.get_parent():
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
		if cell == dungeon.boss and not is_final_biome():
			current_room.set_exit_tag("NEXT BIOME")
		for direction in cell_data.doors:
			if direction == boss_side or cell == dungeon.boss:
				continue # the boss door and the way out of the boss room keep their own text
			var neighbour_type: int = dungeon.cells[cell_data.doors[direction]].data.room_type
			if DOOR_LABELS.has(neighbour_type):
				current_room.doors[direction].set_destination(DOOR_LABELS[neighbour_type][0], DOOR_LABELS[neighbour_type][1])

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
	if is_transitioning or (current_cell != dungeon.boss and not dungeon.cells[current_cell].doors.has(direction)):
		return
	is_transitioning = true
	# Anything left on the floor is collected automatically when you leave.
	for pickup in get_tree().get_nodes_in_group("pickup"):
		pickup.collect()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		await hud.fade_out()

	if current_cell == dungeon.boss:
		if is_final_biome():
			# The run is won. is_transitioning stays true so a door cannot fire twice.
			print("Run complete")
			if hud:
				await hud.fade_in()
			run_completed.emit()
			return
		_start_biome(biome_index + 1)
		if hud:
			await hud.fade_in()
		is_transitioning = false
		return

	if not dungeon.cells[current_cell].doors.has(direction):
		is_transitioning = false # the room changed during the fade (should not happen in play)
		if hud:
			await hud.fade_in()
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
	if type != RoomData.RoomType.BOSS and not OPTIONAL_TYPES.has(type):
		rooms_done += 1
		_update_boss_lock()
	map_changed.emit()
	# Rooms without a fight give no gold and no free upgrade choice (not emitting room_cleared silences UpgradeManager).
	var is_fight: bool = [RoomData.RoomType.COMBAT, RoomData.RoomType.ELITE, RoomData.RoomType.BOSS, RoomData.RoomType.MINIBOSS, RoomData.RoomType.DUEL, RoomData.RoomType.ARENA].has(type)
	if not is_fight:
		return
	_spawn_reward(data)
	fight_room_cleared.emit(type)
	AudioManager.play_sfx("room_clear")
	var is_boss: bool = type == RoomData.RoomType.BOSS
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.rooms_cleared += 1
		if is_boss:
			run_manager.boss_defeated = true
			run_manager.bosses_defeated += 1
	var hud := get_tree().get_first_node_in_group("hud")
	if is_boss:
		var final: bool = is_final_biome()
		if not final:
			_give_boss_reward()
		if hud:
			hud.show_message("BOSS DEFEATED" if final else "BOSS DEFEATED   +%d gold, healed" % BOSS_GOLD_REWARD, 3.0)
		boss_defeated.emit(final)
		return # no regular upgrade choice for a boss (UpgradeManager reacts to boss_defeated instead)
	if type == RoomData.RoomType.MINIBOSS:
		if hud:
			hud.show_message("MINI-BOSS DEFEATED", 3.0)
		miniboss_defeated.emit() # its reward is a Kata technique, not the usual upgrade
		return
	if hud:
		hud.show_message("ROOM CLEARED", 2.0)
	room_cleared.emit()


## Gold and a partial heal for beating the boss of a biome that is not the last one.
func _give_boss_reward() -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.add_gold(BOSS_GOLD_REWARD)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var health: Node = player.get_node("HealthComponent")
		health.heal(health.max_health * BOSS_HEAL_RATIO)


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
