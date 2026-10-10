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
	gm.run_mode = gm.QUICK_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func _run() -> void:
	create_timer(80.0, true, false, true).timeout.connect(func(): print("WATCHDOG"); quit(2))
	await wait_seconds(0.5)
	var rman: Node = get_first_node_in_group("run_manager")
	var rm: Node = get_first_node_in_group("room_manager")
	var um: Node = get_first_node_in_group("upgrade_manager")
	var tm: Node = get_first_node_in_group("technique_manager")
	var player: Node = get_first_node_in_group("player")
	var uc: Node = um.choice_ui

	print("-- curve")
	check(rman.level == 1 and rman.xp == 0 and rman.xp_to_next() == 60, "start: level 1, 60 EXP needed")
	rman.level = 2; check(rman.xp_to_next() == 90, "level 2 needs 90")
	rman.level = 3; check(rman.xp_to_next() == 135, "level 3 needs 135")
	rman.level = 4; check(rman.xp_to_next() == 202 or rman.xp_to_next() == 203, "level 4 needs ~202")
	rman.level = 1

	print("-- kills give EXP")
	var start_room: Node = rm.current_room
	var room_alive_before: int = start_room.alive_enemies
	var dummy: Node3D = load("res://scenes/enemies/Bandit.tscn").instantiate()
	dummy.position = Vector3(8, 0, 8)
	start_room.enemies_root.add_child(dummy)
	start_room.register_enemy(dummy)
	await wait_seconds(0.2)
	check(dummy.xp_value == 6, "bandit is worth 6 EXP")
	dummy.health.take_damage(10000.0)
	await wait_seconds(0.3)
	check(rman.xp == 6, "EXP after the kill: %d" % rman.xp)
	var xp_bar = get_first_node_in_group("hud").xp_bar
	check(xp_bar.value == 6 and xp_bar.max_value == 60 and get_first_node_in_group("hud").xp_label.text == "Lv 1", "HUD bar shows 6 / 60, Lv 1")

	print("-- level ups are queued during a fight")
	var fighter: Node3D = load("res://scenes/enemies/Bandit.tscn").instantiate()
	fighter.position = Vector3(9, 0, 9)
	start_room.enemies_root.add_child(fighter)
	start_room.register_enemy(fighter)
	await wait_seconds(0.2)
	rman.add_xp(60 + 90 + 20) # level 1 -> 3
	check(rman.level == 3 and rman.pending_levels == 2, "level 3 reached, 2 choices pending")
	await wait_seconds(1.5)
	check(not uc.visible, "no choice while an enemy is alive")
	fighter.health.take_damage(10000.0)
	await wait_seconds(0.3)
	rm.room_cleared.emit() # the start room was already clear, so it does not signal again; a fight room does
	await wait_seconds(1.5)
	check(uc.visible and uc.current_choices.size() == 3, "choice appears once the room is clear (3 cards)")
	var upgrades_before: int = player.get_node("StatsComponent").upgrades.size()
	uc.upgrade_chosen.emit(uc.current_choices[0])
	await wait_seconds(1.5)
	check(uc.visible, "second queued level up shows another choice")
	uc.upgrade_chosen.emit(uc.current_choices[0])
	await wait_seconds(0.5)
	check(player.get_node("StatsComponent").upgrades.size() == upgrades_before + 2 and rman.pending_levels == 0, "two upgrades applied, queue empty")

	print("-- clearing a room alone gives no upgrade")
	rm.room_cleared.emit()
	await wait_seconds(1.5)
	check(not uc.visible, "room cleared with nothing pending: no choice")

	print("-- technique reward goes first")
	rman.add_xp(10000)  # many levels at once
	await wait_seconds(0.2)
	tm.offer_pending = true
	rm.miniboss_defeated.emit()
	await wait_seconds(0.3)
	var tc: Node = tm.choice_ui
	check(not uc.visible, "upgrade choice waits for the technique reward")
	await wait_seconds(1.6)
	check(tc.visible and not uc.visible, "technique choice is shown first")
	tc.technique_chosen.emit(tc.current_choices[0])
	await wait_seconds(1.2)
	check(uc.visible, "then the level up choices")
	for i in 12:
		if uc.visible: uc.upgrade_chosen.emit(uc.current_choices[0])
		await wait_seconds(0.9)
	check(rman.pending_levels == 0 and not uc.visible, "all queued level ups were consumed; empty pool does not hang")

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
