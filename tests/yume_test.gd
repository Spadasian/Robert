extends SceneTree

var failures: Array[String] = []
var gm: Node
var player: CharacterBody3D
var rm: Node
var events: Node

func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func dummy_at(offset: Vector3, hp: float = 1000.0) -> Node:
	var d: Node3D = load("res://scenes/enemies/TrainingDummy.tscn").instantiate()
	d.position = player.global_position + offset
	rm.current_room.enemies_root.add_child(d)
	d.health.set_max_health(hp)
	return d

func clear_dummies() -> void:
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	await wait_seconds(0.1)

func press(action: String, seconds: float = 0.08) -> void:
	Input.action_press(action)
	await wait_seconds(seconds)
	Input.action_release(action)

func shurikens() -> Array:
	return get_nodes_in_group("projectile").filter(func(n): return n.kind == "shuriken")

func reset_player() -> void:
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.health.set_current(player.health.max_health)
	EnemyTime.reset()

func _initialize() -> void:
	gm = root.get_node("GameManager")
	gm.run_mode = gm.QUICK_MODE
	gm.selected_character = load("res://resources/characters/yume.tres")
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func _run() -> void:
	create_timer(150.0, true, false, true).timeout.connect(func(): print("WATCHDOG"); quit(2))
	await wait_seconds(0.7)
	player = get_first_node_in_group("player")
	rm = get_first_node_in_group("room_manager")
	events = player.get_node("KataEvents")
	for e in get_nodes_in_group("enemy"): e.set_physics_process(false)
	var stats: Node = player.stats
	stats.base_stats["crit_chance"] = 0.0 # no random crits in the numbers below
	stats._recalculate()
	var dir: Vector3 = player.aim.aim_direction

	print("-- Yume is ready")
	check(gm.selected_character.implemented, "Yume can be chosen")
	check(stats.get_stat("max_health") == 85.0 and stats.get_stat("attack_damage") == 9.0 and is_equal_approx(stats.get_stat("attack_speed"), 1.2) and stats.get_stat("move_speed") == 7.0, "85 HP, 9 damage, attack speed 1.2, speed 7")
	check(player.skills.map(func(s): return s.display_name) == ["Leaping Cut", "Phantom Step", "Mirror Dream", "Dream Clones"], "her own skills: Leaping Cut, Phantom Step, Mirror Dream, Dream Clones")
	check(player.skills.map(func(s): return s.get_slot()) == ["rmb", "shift", "q", "e"], "in the slots rmb, shift, q, e")
	check(player.get_node("RuleHost").behaviors.any(func(b): return b.data.id == "yume"), "the passive Butterfly Twist is on")
	var weapon: Node = player.get_node("WeaponPivot")
	check(weapon.weapon_model != null and weapon.weapon_model.get_child_count() >= 5, "the tessen model is in her hand")
	check(weapon.blade == null, "the plain box blade is gone")

	print("-- Twin Cuts")
	var target: Node = dummy_at(dir * 1.8)
	await wait_seconds(0.2)
	var hp0: float = target.health.current_health
	await press("attack", 0.08)
	await wait_seconds(0.4)
	var dealt: float = hp0 - target.health.current_health
	check(is_equal_approx(dealt, 2.0 * 9.0 * 0.6), "two cuts of 60%% of 9 = 10.8 (%.2f)" % dealt)
	await wait_seconds(0.5)
	check(weapon.params.get("hits") == 2 and is_equal_approx(weapon.params.get("swing_time"), 0.09), "short swings (0.09 s), 2 cuts")
	await clear_dummies()

	print("-- Butterfly Twist: 3 shuriken opposite to the dash")
	reset_player()
	var rules: Node = player.get_node("RuleHost")
	var passive = rules.behaviors.filter(func(b): return b.data.id == "yume")[0]
	passive.cooldown_left = 0.0
	player.dash.direction = Vector3(1, 0, 0)
	events.dodge.emit()
	var thrown: Array = shurikens()
	check(thrown.size() == 3, "3 shuriken (%d)" % thrown.size())
	check(thrown.all(func(s): return s.direction.x < -0.9), "they fly opposite to the dash (towards -X)")
	check(thrown.all(func(s): return is_equal_approx(s.damage, 5.0)), "5 damage each")
	events.dodge.emit()
	check(shurikens().size() == 3, "a second dash right away throws nothing (1 s limit)")
	await wait_seconds(0.9)
	passive.cooldown_left = 0.0
	stats.base_stats["attack_damage"] = 18.0
	stats._recalculate()
	events.dodge.emit()
	var scaled: Array = shurikens().filter(func(s): return is_equal_approx(s.damage, 10.0))
	check(scaled.size() == 3, "the damage grows with her damage upgrades (x2 damage = 10)")
	stats.base_stats["attack_damage"] = 9.0
	stats._recalculate()
	await wait_seconds(1.0)

	print("-- shuriken hit like real attacks")
	reset_player()
	passive.cooldown_left = 0.0
	var wall_dummy: Node = dummy_at(Vector3(-4.0, 0, 0))
	await wait_seconds(0.2)
	var seen := {"hit": 0, "kind": ""}
	events.hit_dealt.connect(func(info): seen.hit += 1; seen.kind = info.get("kind", ""))
	var hp_s: float = wall_dummy.health.current_health
	player.dash.direction = Vector3(1, 0, 0)
	events.dodge.emit()
	await wait_seconds(0.8)
	check(wall_dummy.health.current_health < hp_s and seen.kind == "shuriken", "a shuriken hit the dummy and the Kata heard 'shuriken' (%.0f)" % (hp_s - wall_dummy.health.current_health))
	var kata: Node = player.get_node("KataComponent")
	kata.close("test"); kata.slots.clear(); kata.behaviors.clear(); kata.is_awake = false
	kata.set_technique(load("res://resources/techniques/quick_draw.tres")); kata.set_technique(load("res://resources/techniques/crimson_rhythm.tres"))
	events.dodge.emit(); kata.set_flow(0.0)
	events.hit_dealt.emit({"kind": "shuriken", "hit_count": 1})
	check(kata.flow_value > 0.0, "a shuriken hit feeds the Flow like a light hit")
	kata.close("test"); kata.slots.clear(); kata.behaviors.clear(); kata.is_awake = false
	await clear_dummies()

	print("-- Leaping Cut")
	reset_player()
	var heavy: Node = player.skills[0]
	heavy.cooldown_left = 0.0
	var ahead: Node = dummy_at(dir * 2.0)
	await wait_seconds(0.2)
	var hp_h: float = ahead.health.current_health
	var start: Vector3 = player.global_position
	Input.action_press("heavy")
	await wait_seconds(0.08)
	Input.action_release("heavy")
	await wait_seconds(0.3)
	check(heavy.is_invulnerable(), "invulnerable while she jumps")
	await wait_seconds(0.5)
	var jumped: float = (player.global_position - start).dot(dir)
	check(jumped > 4.0, "she jumped over the dummy (%.1f m forward)" % jumped)
	check(is_equal_approx(hp_h - ahead.health.current_health, 13.0), "the cut behind her hit it: 9 + 4 = 13 (%.1f)" % (hp_h - ahead.health.current_health))
	check(not heavy.is_active and not heavy.is_invulnerable(), "the skill ended")
	await wait_seconds(1.0)
	await clear_dummies()

	print("-- Phantom Step")
	reset_player()
	var step: Node = player.skills[1]
	step.cooldown_left = 0.0
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	var by_start: Node = dummy_at(side * 1.6)
	await wait_seconds(0.2)
	var hp_p: float = by_start.health.current_health
	passive.cooldown_left = 0.0
	var start2: Vector3 = player.global_position
	await press("skill", 0.08)
	check(step.is_invulnerable() or not step.is_active, "invulnerable during the step")
	check(hp_p == by_start.health.current_health, "the clone has not cut yet")
	check(shurikens().size() >= 3, "Butterfly Twist counts the step as a dash (%d shuriken)" % shurikens().size())
	await wait_seconds(0.2)
	var moved: float = (player.global_position - start2).dot(dir)
	check(moved > 3.2 and moved < 4.8, "about 4 m forward (%.1f)" % moved)
	await wait_seconds(0.4)
	check(is_equal_approx(hp_p - by_start.health.current_health, 9.0), "the clone cuts where she stood: 9 (%.1f)" % (hp_p - by_start.health.current_health))
	await clear_dummies()

	print("-- Mirror Dream")
	reset_player()
	var dream: Node = player.skills[2]
	dream.cooldown_left = 0.0
	var bandit: Node3D = load("res://scenes/enemies/Bandit.tscn").instantiate()
	bandit.position = Vector3(-6, 0, 0)
	rm.current_room.enemies_root.add_child(bandit)
	var near_decoy: Node = dummy_at(dir * 2.6 + Vector3(0.5, 0, 0))
	await wait_seconds(0.2)
	var hp_d: float = near_decoy.health.current_health
	await press("ability", 0.08)
	await wait_seconds(0.2)
	var decoys: Array = get_nodes_in_group("decoy")
	check(decoys.size() == 1 and not dream.is_active, "an illusion stands in front of her and she is free")
	check(bandit.target == decoys[0], "the enemies look at the illusion, not at her")
	var player_hp: float = player.health.current_health
	await wait_seconds(2.2)
	check(get_nodes_in_group("decoy").is_empty(), "the illusion burst after 2 s")
	check(is_equal_approx(hp_d - near_decoy.health.current_health, 18.0), "the burst hurt the enemy near it: 2 x 9 = 18 (%.1f)" % (hp_d - near_decoy.health.current_health))
	check(player.health.current_health == player_hp, "the burst does not hurt her")
	await wait_seconds(0.2)
	check(bandit.target == player, "after it the enemies look at her again")
	await clear_dummies()

	print("-- Dream Clones")
	reset_player()
	var clones_skill: Node = player.skills[3]
	var prey: Node = dummy_at(dir * 3.0)
	await wait_seconds(0.2)
	check(not clones_skill.is_available(), "the Ultimate needs charge first")
	clones_skill.charge = clones_skill.max_charge
	var hp_c: float = prey.health.current_health
	await press("ultimate", 0.08)
	check(clones_skill.charge == 0.0 and not clones_skill.is_active and not player.is_busy(), "the charge is spent and she can fight at once")
	var clones: Array = get_children_by_script("DreamClone.gd")
	check(clones.size() == 3, "3 clones (%d)" % clones.size())
	await wait_seconds(2.0)
	var cut: float = hp_c - prey.health.current_health
	check(cut >= 2.0 * 0.8 * 9.0 * 2.0, "the clones cut the enemy (%.0f damage in 2 s)" % cut)
	await wait_seconds(2.6)
	check(get_children_by_script("DreamClone.gd").is_empty(), "the clones are gone after 4 s")

	print("-- Yume's style upgrades")
	var um: Node = get_first_node_in_group("upgrade_manager")
	for id in ["dream_echo", "quick_hands", "silk_step"]:
		var u: Resource = load("res://resources/upgrades/%s.tres" % id)
		check(u.character == "yume" and is_equal_approx(um.weight_of(u), 3.0 * u.get_weight()), "%s is a Yume upgrade: 3x chance" % u.display_name)
	reset_player()
	await clear_dummies()
	var echo_target: Node = dummy_at(Vector3(0, 0, 1.0))
	um.apply_upgrade(load("res://resources/upgrades/dream_echo.tres"))
	var echo_hp: float = echo_target.health.current_health
	player.dash.direction = Vector3(1, 0, 0)
	player.dash.start_position = player.global_position
	events.dodge.emit()
	await wait_seconds(0.6)
	check(is_equal_approx(echo_hp - echo_target.health.current_health, 9.0 * 0.8), "Dream Echo: the clone of the dash cuts 0.8 x 9 (%.1f)" % (echo_hp - echo_target.health.current_health))
	um.apply_upgrade(load("res://resources/upgrades/quick_hands.tres"))
	var speed0: float = stats.get_stat("attack_speed")
	for i in 3: events.hit_dealt.emit({"kind": "light", "hit_count": 1})
	check(is_equal_approx(stats.get_stat("attack_speed"), speed0 * 1.15), "Quick Hands: 3 hits = +15%% attack speed")
	await wait_seconds(2.3)
	check(is_equal_approx(stats.get_stat("attack_speed"), speed0), "...for 2 s")
	um.apply_upgrade(load("res://resources/upgrades/silk_step.tres"))
	events.perfect_dodge.emit(null)
	check(player.is_hidden(), "Silk Step: invisible after a Perfect Dodge")

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)

func get_children_by_script(script_name: String) -> Array:
	return current_scene.find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with(script_name))
