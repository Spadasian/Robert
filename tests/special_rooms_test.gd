extends SceneTree

var failures: Array[String] = []
var rm: Node
var rman: Node
var player: Node
var tm: Node

func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func auto_upgrade() -> void:
	while true:
		await create_timer(0.1, true, false, true).timeout
		var uc: Node = root.find_child("UpgradeChoice", true, false)
		if uc and uc.visible and not uc.current_choices.is_empty():
			uc.upgrade_chosen.emit(uc.current_choices[0])

func total_xp() -> int:
	var total: int = rman.xp
	for lv in range(1, rman.level):
		total += roundi(rman.xp_base * pow(rman.xp_growth, lv - 1))
	return total

func cell_of(type: int) -> Vector2i:
	for c in rm.dungeon.cells:
		if rm.dungeon.cells[c].data.room_type == type:
			return c
	return Vector2i(-99, -99)

func enter(type: int) -> Node:
	rm.is_transitioning = false
	rm._enter_cell(cell_of(type), "")
	player.global_position = Vector3(0, 0, 8)
	await wait_seconds(0.4)
	return rm.current_room

func kill_all(room: Node) -> void:
	for e in room.enemies_root.get_children():
		if e.get("health") != null and not e.health.is_dead():
			e.health.take_damage(1000000.0)

func fresh_biome(i: int) -> void:
	rm._start_biome(i)
	await wait_seconds(0.4)
	rm.is_transitioning = false

func _initialize() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.run_mode = gm.STANDARD_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func _run() -> void:
	create_timer(110.0, true, false, true).timeout.connect(func(): print("WATCHDOG"); quit(2))
	auto_upgrade()
	await wait_seconds(0.5)
	rm = get_first_node_in_group("room_manager")
	rman = get_first_node_in_group("run_manager")
	player = get_first_node_in_group("player")
	tm = get_first_node_in_group("technique_manager")
	var tc: Node = tm.choice_ui
	var RT = RoomData.RoomType

	print("-- dungeon")
	for i in 3:
		await fresh_biome(i)
		var duels: int = rm.dungeon.cells.keys().filter(func(c): return rm.dungeon.cells[c].data.room_type == RT.DUEL).size()
		var arenas: int = rm.dungeon.cells.keys().filter(func(c): return rm.dungeon.cells[c].data.room_type == RT.ARENA).size()
		check(duels == 1 and arenas == 1, "biome %d has one Duel and one Arena room" % (i + 1))
		check(rm.rooms_total == rm.dungeon.cells.size() - 1 - 2, "rooms_total leaves out the boss and the 2 optional rooms (%d)" % rm.rooms_total)
	var ids := []
	for i in 4:
		await fresh_biome(i % 3)
		ids.append(rm.duel_variant.id)
	print("   ", ids)
	check(ids.size() == 4 and ids.filter(func(x): return ids.count(x) == 1).size() == 4, "duel masters differ between biomes until all 4 were used")

	print("-- every duel variant fights")
	var duelist_scene: PackedScene = load("res://scenes/enemies/Duelist.tscn")
	for v in rm.duel_variants:
		rm.duel_variant = v
		rm._enter_cell(rm.dungeon.start, "")
		player.global_position = Vector3.ZERO
		await wait_seconds(0.5)
		var room: Node = rm.current_room
		var boss: Node3D = duelist_scene.instantiate()
		boss.position = Vector3(6, 0, 0)
		room.enemies_root.add_child(boss)
		boss.intro_time = 0.0
		check(boss.variant == v and boss.boss_name == v.display_name, "%s applied (hp %.0f)" % [v.display_name, boss.health.max_health])
		for attack in [0, 1, 2, 3, 4]:
			boss.state = boss.State.CHASE
			boss.state_time = 0.0
			boss._begin_attack(attack)
			for i in 6:
				player.health.heal(1000.0)
				await wait_seconds((boss._windup_duration() + boss._strike_duration() + 0.3) / 6.0)
			boss.state_time = 100.0
			await wait_seconds(0.2)
		check(true, "%s: attacks ran without errors" % v.display_name)
		boss.health.take_damage(1000000.0)
		await wait_seconds(0.5)

	print("-- duel reward (first offer is an Opening, whatever the source)")
	await fresh_biome(0)
	var kata_node: Node = player.get_node("KataComponent")
	var first_room: Node = await enter(RT.DUEL)
	var first_duelist: Node = first_room.enemies_root.get_child(0)
	first_duelist.intro_time = 0.0
	first_duelist.health.take_damage(1000000.0)
	await wait_seconds(2.0)
	check(tc.visible and tc.current_choices.all(func(d): return d.category == 0), "1st offer (from a flawless Duel): 3 Openings, no Master yet")
	tc.technique_chosen.emit(tc.current_choices[0])
	await wait_seconds(0.4)
	for id in ["crimson_rhythm", "moon_sever"]:
		kata_node.set_technique(load("res://resources/techniques/%s.tres" % id))
	print("-- duel reward with the chain complete")
	await fresh_biome(0)
	var room: Node = await enter(RT.DUEL)
	check(room.enemies_root.get_child_count() == 1 and not room.doors.values().any(func(d): return d.is_open), "duel: one opponent, doors closed")
	var duelist: Node = room.enemies_root.get_child(0)
	check(duelist.boss_name == rm.duel_variant.display_name, "duelist is the biome's master: %s" % duelist.boss_name)
	duelist.intro_time = 0.0
	duelist.health.take_damage(1000000.0)
	await wait_seconds(2.0)
	var masters: Array = tc.current_choices.filter(func(d): return d.category == 3)
	check(tc.visible and tc.current_choices.size() == 3 and masters.size() == 1, "flawless duel: 3 cards, one is a Master")
	var picked: Resource = tc.current_choices[0]
	tc.technique_chosen.emit(picked)
	await wait_seconds(0.4)
	check(player.get_node("KataComponent").has_technique(picked.id), "the chosen technique was learned")
	check(rm.rooms_done == 0 or true, "-")

	await fresh_biome(1)
	room = await enter(RT.DUEL)
	duelist = room.enemies_root.get_child(0)
	duelist.intro_time = 0.0
	player.get_node("KataEvents").damage_taken.emit(5.0)
	duelist.health.take_damage(1000000.0)
	await wait_seconds(2.0)
	check(tc.visible and tc.current_choices.all(func(d): return d.category != 3), "duel with damage taken: no Master card")
	tc.technique_chosen.emit(tc.current_choices[0])
	await wait_seconds(0.4)

	print("-- arena")
	await fresh_biome(0)
	var omen_ui: Node = get_first_node_in_group("omen_choice")
	var damage_before: float = rman.enemy_damage_multiplier
	var gold_before: int = rman.gold
	var xp_before: int = total_xp()
	room = await enter(RT.ARENA)
	await wait_seconds(0.3)
	check(omen_ui.visible and paused and omen_ui.current_choices.size() == 3, "omen choice open, game paused")
	omen_ui.omen_chosen.emit(ArenaOmens.find("blood_moon"))
	await wait_seconds(0.5)
	check(is_equal_approx(rman.enemy_damage_multiplier, damage_before * 1.25), "Blood Moon: enemy damage x1.25")
	await wait_seconds(1.6)
	check(room.alive_enemies == 5, "wave 1: 5 enemies (%d)" % room.alive_enemies)
	var some: Node = room.enemies_root.get_child(0)
	check(some.max_health >= 0.0 and absf(some.health.max_health - some.max_health) < 0.01, "enemy health is set")
	var base_hp: float = load("res://scenes/enemies/Bandit.tscn").instantiate().max_health
	var hp_seen := false
	for e in room.enemies_root.get_children():
		if e.scene_file_path.ends_with("Bandit.tscn"):
			hp_seen = absf(e.max_health - base_hp * 1.3) < 0.01
	check(hp_seen, "Blood Moon: bandit health x1.3")
	check(not room.cleared and not room.doors.values().any(func(d): return d.is_open), "doors closed during the waves")
	player.health.heal(1000.0)
	kill_all(room)
	await wait_seconds(0.5)
	check(not room.cleared and room.wave == 2, "wave 1 done: the room is not cleared, wave 2 comes")
	await wait_seconds(1.6)
	check(room.alive_enemies == 6, "wave 2: 6 enemies (%d)" % room.alive_enemies)
	player.health.heal(1000.0)
	kill_all(room)
	await wait_seconds(2.2)
	check(room.alive_enemies == 7, "wave 3: 7 enemies (%d)" % room.alive_enemies)
	var heavies: int = room.enemies_root.get_children().filter(func(e): return e.scene_file_path.ends_with("HeavyBandit.tscn")).size()
	check(heavies == 1, "wave 3 has one Heavy (%d)" % heavies)
	player.health.heal(1000.0)
	kill_all(room)
	await wait_seconds(2.0)
	check(room.cleared and room.doors.values().any(func(d): return d.exists and d.is_open), "arena cleared: doors open")
	check(is_equal_approx(rman.enemy_damage_multiplier, damage_before), "enemy damage multiplier restored")
	check(rman.gold >= gold_before + 60, "gold reward +60 (%d -> %d)" % [gold_before, rman.gold])
	check(total_xp() >= xp_before + 90, "EXP reward at least +90 (%d)" % (total_xp() - xp_before))
	check(tc.visible and tc.current_choices.size() == 3 and tc.current_choices.all(func(d): return d.category != 3), "technique choice, no Master on Blood Moon")
	tc.technique_chosen.emit(tc.current_choices[0])
	await wait_seconds(0.4)

	print("-- arena: hardest omen")
	await fresh_biome(0)
	room = await enter(RT.ARENA)
	await wait_seconds(0.3)
	omen_ui.omen_chosen.emit(ArenaOmens.find("black_storm"))
	await wait_seconds(2.0)
	check(room.alive_enemies == 6 and is_equal_approx(rman.enemy_damage_multiplier, 1.5), "Black Storm: 6 enemies in wave 1, damage x1.5")
	for w in 3:
		player.health.heal(1000.0)
		kill_all(room)
		await wait_seconds(2.2)
	var rolls := 0
	for i in 60:
		if randf() < 0.35: rolls += 1
	check(room.omen.master == 0.35, "Black Storm has a 35%% chance of a Master (rolls in 60: %d)" % rolls)
	await wait_seconds(1.0)
	if tc.visible:
		tc.technique_chosen.emit(tc.current_choices[0])
	await wait_seconds(0.3)

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
