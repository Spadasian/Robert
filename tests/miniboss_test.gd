extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _initialize() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.run_mode = gm.STANDARD_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func auto_pick() -> void:
	while true:
		await create_timer(0.1, true, false, true).timeout
		var oc: Node = root.find_child("OmenChoice", true, false)
		if oc and oc.visible and not oc.current_choices.is_empty():
			oc.omen_chosen.emit(oc.current_choices[0])
		var uc: Node = root.find_child("UpgradeChoice", true, false)
		if uc and uc.visible and not uc.current_choices.is_empty():
			uc.upgrade_chosen.emit(uc.current_choices[0])

func _run() -> void:
	auto_pick()
	create_timer(100.0, true, false, true).timeout.connect(func(): print("WATCHDOG"); quit(2))
	await wait_seconds(0.5)
	var rm: Node = get_first_node_in_group("room_manager")
	var player: Node = get_first_node_in_group("player")
	var tm: Node = get_first_node_in_group("technique_manager")

	print("-- dungeon")
	var mini_cells: Array = rm.dungeon.cells.keys().filter(func(c): return rm.dungeon.cells[c].data.room_type == RoomData.RoomType.MINIBOSS)
	check(mini_cells.size() == 1, "exactly one mini-boss room in the biome")
	check(rm.miniboss_variant != null, "biome has a mini-boss variant: %s" % rm.miniboss_variant.display_name)
	var required := 0
	for c in rm.dungeon.cells:
		if c != rm.dungeon.boss and not rm.OPTIONAL_TYPES.has(rm.dungeon.cells[c].data.room_type): required += 1
	check(rm.rooms_total == required, "rooms_total counts the mini-boss (%d)" % rm.rooms_total)

	print("-- variants differ between biomes")
	var seen: Array = [rm.miniboss_variant.id]
	for i in 3:
		rm._start_biome(i % 3)
		await wait_seconds(0.2)
		seen.append(rm.miniboss_variant.id)
	print("   ", seen)
	check(seen[0] != seen[1] and seen[1] != seen[2] and seen[2] != seen[3], "consecutive biomes get different variants")
	check(seen.slice(0, 4).size() == 4 and seen[0] != seen[2] and seen[1] != seen[3] and seen[0] != seen[3], "all four variants used before a repeat")

	print("-- door labels")
	rm._start_biome(0)
	await wait_seconds(0.2)
	var found_label := false
	for cell in rm.dungeon.cells:
		if cell == rm.dungeon.boss:
			continue
		var data: Dictionary = rm.dungeon.cells[cell]
		for dir in data.doors:
			var type: int = rm.dungeon.cells[data.doors[dir]].data.room_type
			if rm.DOOR_LABELS.has(type):
				# enter the cell to create it, then look at the door
				rm._enter_cell(cell, "")
				await wait_seconds(0.1)
				var door = rm.current_room.doors[dir]
				var expected: String = rm.DOOR_LABELS[type][0]
				if door.tag.text != expected:
					check(false, "door %s of %s should say %s but says '%s'" % [dir, cell, expected, door.tag.text])
				else:
					found_label = true
	check(found_label, "doors to special rooms carry their label")

	print("-- every variant, every attack")
	await wait_seconds(1.5)
	rm.is_transitioning = false
	var variants: Array = rm.miniboss_variants
	var scene: PackedScene = load("res://scenes/enemies/MiniBoss.tscn")
	for v in variants:
		rm.miniboss_variant = v
		rm._enter_cell(rm.dungeon.start, "")
		player.global_position = Vector3.ZERO
		await wait_seconds(0.5)
		var room: Node = rm.current_room
		var boss: Node3D = scene.instantiate()
		boss.position = player.global_position + Vector3(6, 0, 0)
		room.enemies_root.add_child(boss)
		boss.defeated.connect(room._on_enemy_defeated)
		room.alive_enemies += 1
		player.health.heal(10000.0)
		check(boss.boss_name == v.display_name and boss.variant == v, "%s applied (hp %.0f)" % [v.display_name, boss.health.max_health])
		print("   paused ", paused, " player ", player.global_position, " boss ", boss.global_position, " state ", boss.state)
		boss.intro_time = 0.0
		await wait_seconds(0.3)
		var used := {}
		for attack in [0, 1, 2, 3, 4, 5]:
			if not is_instance_valid(boss): break
			boss.state = boss.State.CHASE
			boss.state_time = 0.0
			boss.velocity = Vector3.ZERO
			var hp_before: float = player.health.current_health
			boss._begin_attack(attack)
			await wait_seconds(0.2)
			var alive_before: int = room.alive_enemies
			for i in 8:
				player.health.heal(1000.0)
				await wait_seconds((boss._windup_duration() + boss._strike_duration() + 0.3) / 8.0)
			used[attack] = true
			print("   a", attack, " state ", boss.state, " pos ", boss.global_position, " lt ", boss.state_time, " paused ", paused)
			#print("   attack ", attack, " boss in tree ", boss.is_inside_tree(), " room in tree ", room.is_inside_tree(), " cell ", rm.current_cell, " pos ", boss.global_position if boss.is_inside_tree() else "-")
			if attack == 5 and v.id == "iron_warden":
				check(room.alive_enemies > alive_before, "Summon created minions (%d -> %d)" % [alive_before, room.alive_enemies])
			if attack == 4:
				print("   leap debug: landed ", boss.leap_landed, " from ", boss.leap_from, " to ", boss.leap_to, " attack ", boss.attack, " windup ", boss._windup_duration(), " marker ", boss.leap_marker)
				check(boss.leap_landed, "%s: leap landed" % v.display_name)
			boss.state_time = 100.0
			await wait_seconds(0.2)
		check(used.size() == 6, "%s: all six attacks ran without errors" % v.display_name)
		if is_instance_valid(boss):
			boss.health.take_damage(100000.0)
		await wait_seconds(0.5)
		for e in get_nodes_in_group("enemy"):
			if is_instance_valid(e) and not e.health.is_dead(): e.health.take_damage(100000.0)
		await wait_seconds(0.4)

	print("-- reward")
	var tech_ui: Node = tm.choice_ui
	rm.miniboss_defeated.emit()
	await wait_seconds(1.6)
	check(tech_ui.visible and tech_ui.current_choices.all(func(d): return d.category in [0, 1]), "mini-boss reward: Opening/Flow choice")
	tech_ui.technique_chosen.emit(tech_ui.current_choices[0])
	await wait_seconds(0.3)
	check(get_first_node_in_group("player").get_node("KataComponent").is_awake, "the Kata is awake")

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
