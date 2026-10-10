extends SceneTree
## Headless integration test: plays a whole run (all biomes) by itself. Usage: -- standard|quick

var rm: Node
var rman: Node
var player: CharacterBody3D
var failures: Array[String] = []
var completed: bool = false
var scale_checked: Dictionary = {}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "standard"
	var game_manager: Node = root.get_node("GameManager")
	game_manager.run_mode = game_manager.QUICK_MODE if which == "quick" else game_manager.STANDARD_MODE
	print("MODE: ", game_manager.run_mode.display_name)
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		print("  FAIL ", message)
		failures.append(message)
	else:
		print("  ok   ", message)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout



var techniques_taken: int = 0

func auto_technique() -> void:
	while true:
		await create_timer(0.1, true, false, true).timeout
		var tc: Node = root.find_child("TechniqueChoice", true, false)
		if tc and tc.visible and not tc.current_choices.is_empty():
			techniques_taken += 1
			tc.technique_chosen.emit(tc.current_choices[0])
		var oc: Node = root.find_child("OmenChoice", true, false)
		if oc and oc.visible and not oc.current_choices.is_empty():
			oc.omen_chosen.emit(oc.current_choices[0])
		var uc: Node = root.find_child("UpgradeChoice", true, false)
		if uc and uc.visible and not uc.current_choices.is_empty():
			uc.upgrade_chosen.emit(uc.current_choices[0])

func _run() -> void:
	auto_technique()
	await frames(20)
	rm = get_first_node_in_group("room_manager")
	rman = get_first_node_in_group("run_manager")
	player = get_first_node_in_group("player")
	rm.run_completed.connect(func(): completed = true)
	var biome_count: int = rm.biomes.size()
	check(rman.mode_name == root.get_node("GameManager").run_mode.display_name, "run manager knows the mode (%s)" % rman.mode_name)
	for b in biome_count:
		check(rm.biome_index == b, "now in biome %d (%s)" % [b + 1, rm.biome.display_name])
		check(is_equal_approx(rman.enemy_health_multiplier, rm.biome.enemy_health_multiplier), "health multiplier x%.2f set" % rman.enemy_health_multiplier)
		var cells: Dictionary = rm.dungeon.cells
		print("DUNGEON %d: %d rooms, boss %s" % [b + 1, cells.size(), rm.dungeon.boss])
		var expected_rooms: int = 1 + rm.biome.combat_rooms + rm.biome.elite_rooms + rm.biome.treasure_rooms + rm.biome.shop_rooms + rm.biome.miniboss_rooms + rm.biome.duel_rooms + rm.biome.arena_rooms + 1
		check(cells.size() == expected_rooms, "dungeon has %d rooms as the biome says" % expected_rooms)
		var seen: Dictionary = {}
		await explore(rm.dungeon.start, seen)
		check(rm.boss_unlocked and rm.rooms_done == rm.rooms_total, "boss unlocked after all %d rooms" % rm.rooms_total)
		for step in find_path(rm.current_cell, rm.dungeon.boss_parent):
			await go(step)
		await go(rm.dungeon.boss_door)
		check(rm.current_cell == rm.dungeon.boss, "entered the boss room")
		var gold_before: int = rman.gold
		var tag_text: String = ""
		for d in rm.current_room.doors.values():
			if d.exists:
				tag_text = d.tag.text
		var is_final: bool = rm.is_final_biome()
		check((tag_text == "") == is_final, "boss room door tag is '%s' (final biome: %s)" % [tag_text, is_final])
		await clear_current_room()
		check(rm.current_room.cleared, "boss killed")
		if not is_final:
			check(rman.gold >= gold_before + 30, "boss reward: +30 gold (%d -> %d)" % [gold_before, rman.gold])
		check(rman.bosses_defeated == b + 1, "bosses_defeated = %d" % rman.bosses_defeated)
		await wait_seconds(1.6)
		await pick_upgrade_if_open() # the boss reward choice
		var back_dir: String = rm.current_room.doors.keys().filter(func(d): return rm.current_room.doors[d].exists)[0]
		await use_door(back_dir)
		await wait_seconds(1.2)
		if b + 1 < biome_count:
			check(rm.biome_index == b + 1 and not completed, "moved on to biome %d, run not completed" % (b + 2))
		else:
			check(completed, "run_completed after the last boss")
	var shards: int = root.get_node("MetaProgression").calculate_shards(rman.rooms_cleared, rman.enemies_defeated, rman.bosses_defeated)
	print("shards (before multiplier): ", shards, " x ", rman.shard_multiplier, " = ", roundi(shards * rman.shard_multiplier))
	check(rman.bosses_defeated == biome_count, "every boss counted")
	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


func explore(cell: Vector2i, seen: Dictionary) -> void:
	seen[cell] = true
	await clear_current_room()
	var doors: Dictionary = rm.dungeon.cells[cell].doors
	for direction in doors:
		var neighbour: Vector2i = doors[direction]
		if seen.has(neighbour) or neighbour == rm.dungeon.boss:
			continue
		await go(direction)
		await explore(neighbour, seen)
		await go(DungeonGenerator.OPPOSITE[direction])


func clear_current_room() -> void:
	var room: Node = rm.current_room
	await wait_seconds(0.3)
	var enemies: Array = get_nodes_in_group("enemy").filter(func(e): return room.is_ancestor_of(e) and not e.health.is_dead())
	enemies = enemies.filter(func(e): return not e.scene_file_path.ends_with("MiniBoss.tscn") and not e.scene_file_path.ends_with("Duelist.tscn")) if false else enemies
	var plain: Array = enemies.filter(func(e): return not e.scene_file_path.ends_with("MiniBoss.tscn") and not e.scene_file_path.ends_with("Duelist.tscn"))
	if not plain.is_empty() and not scale_checked.has(rm.biome_index):
		var enemy: Node = plain[0]
		var reference: Node = load(enemy.scene_file_path).instantiate()
		var expected: float = reference.max_health * rman.enemy_health_multiplier
		reference.free()
		check(absf(enemy.health.max_health - expected) < 0.01, "enemy health scaled: %s %.1f (expected %.1f)" % [enemy.name, enemy.health.max_health, expected])
		scale_checked[rm.biome_index] = true
	for round in 10: # an Arena brings its enemies in waves
		enemies = get_nodes_in_group("enemy").filter(func(e): return room.is_ancestor_of(e) and not e.health.is_dead())
		for enemy in enemies:
			enemy.health.take_damage(1.0e9)
		player.health.heal(1000.0)
		await wait_seconds(1.8 if room.has_method("_next_wave") else 0.7)
		if room.cleared:
			break
	await pick_upgrade_if_open()


func pick_upgrade_if_open() -> void:
	await wait_seconds(0.3) # auto_technique() picks any open choice

func go(direction: String) -> void:
	var before: Vector2i = rm.current_cell
	await use_door(direction)
	for i in 80:
		if rm.current_cell != before and not rm.is_transitioning:
			break
		await wait_seconds(0.05)
	await wait_seconds(0.1)


func use_door(direction: String) -> void:
	var door: Node3D = rm.current_room.doors[direction]
	player.global_position = Vector3(door.global_position.x, 0.0, door.global_position.z)
	player.velocity = Vector3.ZERO
	await frames(8)
	player.get_node("HealthComponent").heal(9999.0)


func find_path(from: Vector2i, to: Vector2i) -> Array:
	var previous: Dictionary = {from: null}
	var queue: Array = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == to:
			break
		var doors: Dictionary = rm.dungeon.cells[cell].doors
		for direction in doors:
			var other: Vector2i = doors[direction]
			if not previous.has(other):
				previous[other] = [cell, direction]
				queue.append(other)
	var steps: Array = []
	var cursor: Vector2i = to
	while previous[cursor] != null:
		steps.push_front(previous[cursor][1])
		cursor = previous[cursor][0]
	return steps
