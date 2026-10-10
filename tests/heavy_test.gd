extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _initialize() -> void:
	root.get_node("GameManager").run_mode = root.get_node("GameManager").QUICK_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func _run() -> void:
	await wait_seconds(0.5)
	var player: CharacterBody3D = get_first_node_in_group("player")
	var rm: Node = get_first_node_in_group("room_manager")
	var heavy: Node = null
	var iai: Node = null
	for skill in player.skills:
		if skill.display_name == "Heavy":
			heavy = skill
		if skill.display_name == "Iaijutsu":
			iai = skill
	check(heavy != null and iai != null, "player has Heavy and Iaijutsu skills (%d skills)" % player.skills.size())
	check(player.skills[0] == heavy, "Heavy is the first slot")
	check(heavy.input_action == "heavy" and iai.input_action == "skill" and iai.key_label == "SHIFT", "heavy=RMB action, Iaijutsu on SHIFT")
	var hud: Node = get_first_node_in_group("hud")
	check(hud.skill_slots.size() == 4, "HUD shows 4 skill slots")
	var map_heavy: Array = InputMap.action_get_events("heavy")
	var map_skill: Array = InputMap.action_get_events("skill")
	check(map_heavy.size() == 1 and map_heavy[0] is InputEventMouseButton and map_heavy[0].button_index == MOUSE_BUTTON_RIGHT, "InputMap heavy = right mouse button")
	check(map_skill.size() == 1 and map_skill[0] is InputEventKey and map_skill[0].physical_keycode == KEY_SHIFT, "InputMap skill = Shift")

	# a dummy right in front of the player
	var dummy: Node3D = load("res://scenes/enemies/TrainingDummy.tscn").instantiate()
	rm.current_room.enemies_root.add_child(dummy)
	var dir: Vector3 = player.aim.aim_direction
	dummy.global_position = player.global_position + dir * 2.4
	await wait_seconds(0.2)
	var before: float = dummy.health.current_health
	Input.action_press("heavy")
	await wait_seconds(0.1)
	Input.action_release("heavy")
	check(heavy.is_active, "heavy attack started on RMB")
	check(not iai.is_active, "RMB does not start Iaijutsu any more")
	check(player.is_busy(), "player is busy during the heavy attack")
	await wait_seconds(1.0)
	var dealt: float = before - dummy.health.current_health
	check(absf(dealt - 14.0) < 0.01, "heavy dealt %.1f damage (expected 14 = 10 + 4)" % dealt)
	check(not heavy.is_active, "heavy attack finished")
	check(heavy.cooldown_left >= 0.0, "cooldown running (%.2f)" % heavy.cooldown_left)

	await wait_seconds(0.8)
	Input.action_press("skill")
	await wait_seconds(0.1)
	Input.action_release("skill")
	check(iai.is_active, "Iaijutsu started on Shift")
	await wait_seconds(1.0)
	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
