extends SceneTree

var failures: Array[String] = []
var gm: Node

func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func start_run_scene(character: Resource) -> Node:
	gm.selected_character = character
	gm.run_mode = gm.QUICK_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await wait_seconds(0.6)
	return scene

func end_run_scene(scene: Node) -> void:
	scene.queue_free()
	await wait_seconds(0.2)

func _initialize() -> void:
	gm = root.get_node("GameManager")
	_run.call_deferred()

func _run() -> void:
	create_timer(110.0, true, false, true).timeout.connect(func(): print("WATCHDOG"); quit(2))

	print("-- character data")
	var characters: Array = gm.get_characters()
	check(characters.size() == 4, "4 characters")
	var ids: Array = characters.map(func(c): return c.id)
	check(ids == ["kazuma", "yume", "takeda", "kurotsuki"], "kazuma, yume, takeda, kurotsuki %s" % str(ids))
	var kazuma: Resource = characters[0]
	check(kazuma.implemented and characters[1].implemented and not characters[2].implemented and not characters[3].implemented, "Kazuma and Yume can be chosen for now")
	check(kazuma.stats.get("max_health") == 110.0 and kazuma.stats.get("attack_damage") == 11.0, "Kazuma: 110 HP, 11 damage (from the Excel)")
	check(characters[1].stats.get("move_speed") == 7.0 and characters[2].stats.get("max_health") == 130.0 and characters[3].stats.get("starting_corruption") == 15.0, "Yume speed 7, Takeda 130 HP, Kurotsuki 15 Corruption")
	check(characters.all(func(c): return c.skill_names.size() == 5 and c.passive_name != "" and c.weapon != ""), "every character has 5 skills, a passive and a weapon")

	print("-- a run without a character keeps the base stats")
	var scene: Node = await start_run_scene(null)
	var player: Node = get_first_node_in_group("player")
	check(player.stats.get_stat("max_health") == 100.0 and player.stats.get_stat("attack_damage") == 10.0 and player.stats.get_stat("crit_chance") == 0.0, "100 HP, 10 damage, no crit")
	check(player.skills.size() == 4 and player.skills.map(func(s): return s.get_slot()) == ["rmb", "shift", "q", "e"], "4 skills in the slots rmb, shift, q, e")
	await end_run_scene(scene)

	print("-- Kazuma")
	scene = await start_run_scene(kazuma)
	player = get_first_node_in_group("player")
	check(player.stats.get_stat("max_health") == 110.0 and player.health.max_health == 110.0 and player.health.current_health == 110.0, "110 HP at the start")
	check(player.stats.get_stat("attack_damage") == 11.0, "11 damage")
	check(is_equal_approx(player.stats.get_stat("crit_chance"), 0.08), "Keen Eye: +8%% critical chance (%.2f)" % player.stats.get_stat("crit_chance"))
	var body_material := player.body_mesh.get_active_material(0) as StandardMaterial3D
	check(body_material != null and body_material.albedo_color.is_equal_approx(kazuma.color), "the body has Kazuma's red")
	var ult: Node = player.skills[3]
	var rules: Node = player.get_node("RuleHost")
	var kata: Node = player.get_node("KataComponent")
	var rm: Node = get_first_node_in_group("room_manager")
	for e in get_nodes_in_group("enemy"): e.set_physics_process(false)

	print("-- new damage rules")
	var heavy: Node = player.skills[0]
	check(is_equal_approx(heavy.strike_damage({}), 15.0), "Heavy = damage + 4 = 15 (%.1f)" % heavy.strike_damage({}))
	var iaijutsu: Node = player.skills[1]
	iaijutsu._begin_strike()
	check(is_equal_approx(iaijutsu.hitbox.damage, 11.0), "Iaijutsu = 1.0 x damage = 11 (%.1f)" % iaijutsu.hitbox.damage)
	iaijutsu._cancel()

	print("-- lifesteal")
	var dummy: Node3D = load("res://scenes/enemies/TrainingDummy.tscn").instantiate()
	dummy.position = Vector3(9, 0, 9)
	rm.current_room.enemies_root.add_child(dummy)
	var effect := UpgradeEffect.new(); effect.stat = "lifesteal"; effect.operation = UpgradeEffect.Operation.ADD; effect.value = 0.1
	player.stats.add_modifier(effect)
	player.health.set_current(50.0)
	CombatManager.after_hit(player, dummy.health, {"damage": 20.0, "overkill": 0.0})
	check(is_equal_approx(player.health.current_health, 52.0), "10%% of 20 damage = 2 HP (%.1f)" % player.health.current_health)
	CombatManager.after_hit(player, dummy.health, {"damage": 20.0, "overkill": 10.0})
	check(is_equal_approx(player.health.current_health, 53.0), "overkill does not heal: 10%% of 10 = 1 (%.1f)" % player.health.current_health)
	player.on_bleed_tick(dummy, 10.0, false)
	check(is_equal_approx(player.health.current_health, 54.0), "bleeding heals too")
	player.stats.remove_modifier(effect)
	var meal: Resource = load("res://resources/upgrades/crimson_meal.tres")
	check(meal.effects[0].stat == "lifesteal" and is_equal_approx(meal.effects[0].value, 0.06), "Crimson Meal: 6%% lifesteal")
	check(not player.stats.base_stats.has("life_on_kill"), "life_on_kill is gone")

	print("-- attack range")
	var attack: Node = player.get_node("WeaponPivot")
	var range_effect := UpgradeEffect.new(); range_effect.stat = "attack_range"; range_effect.operation = UpgradeEffect.Operation.PERCENT; range_effect.value = 0.15
	player.stats.add_modifier(range_effect)
	attack.cooldown_left = 0.0
	attack.start_attack()
	check(is_equal_approx(attack.hitbox.scale.x, 1.15), "Weapon Master: the basic attack reaches 15%% farther (%.2f)" % attack.hitbox.scale.x)
	attack.end_attack()
	player.stats.remove_modifier(range_effect)

	print("-- Kata skills are bound to slots")
	check(player.skills.map(func(s): return s.get_slot()) == ["rmb", "shift", "q", "e"], "slots rmb, shift, q, e")
	var opening := load("res://resources/techniques/crescent_entry.tres")
	check(opening.params.get("slot") == "shift" and load("res://resources/techniques/shadow_vault.tres").params.get("slot") == "q", "Crescent Entry = Shift, Shadow Vault = Q")

	print("-- style upgrades come up 3 times more often for their character")
	var um: Node = get_first_node_in_group("upgrade_manager")
	var style_upgrade: Resource = load("res://resources/upgrades/falcon_eye.tres").duplicate()
	style_upgrade.character = "kazuma"
	var other_upgrade: Resource = load("res://resources/upgrades/falcon_eye.tres").duplicate()
	other_upgrade.character = "yume"
	var plain: Resource = load("res://resources/upgrades/falcon_eye.tres")
	check(is_equal_approx(um.weight_of(style_upgrade), 3.0 * plain.get_weight()), "Kazuma's own style upgrade: x3 (%.0f)" % um.weight_of(style_upgrade))
	check(is_equal_approx(um.weight_of(other_upgrade), plain.get_weight()) and is_equal_approx(um.weight_of(plain), plain.get_weight()), "another character's and plain upgrades: x1")
	var shown := {"style": 0, "plain": 0}
	var saved_pool: Array[Resource] = um.upgrade_pool
	var plain_copy: Resource = plain.duplicate()
	plain_copy.id = "plain_copy"
	var test_pool: Array[Resource] = [style_upgrade, plain_copy]
	um.upgrade_pool = test_pool
	for i in 600:
		var pick: Array = um.get_random_choices(1)
		if pick[0] == style_upgrade: shown["style"] += 1
		else: shown["plain"] += 1
	um.upgrade_pool = saved_pool
	check(shown.style > shown.plain * 2.0 and shown.style < shown.plain * 4.5, "in 600 offers the style upgrade wins ~3:1 (%d : %d)" % [shown.style, shown.plain])
	check(load("res://resources/upgrades/weapon_master.tres").character == "", "Weapon Master is for everybody")

	await end_run_scene(scene)

	print("-- Kurotsuki starts with Corruption and the Cursed")
	scene = await start_run_scene(characters[3])
	player = get_first_node_in_group("player")
	var corruption: Node = player.get_node("CorruptionComponent")
	check(is_equal_approx(corruption.value, 15.0) and corruption.level == 0, "15%% Corruption at the start (%.0f)" % corruption.value)
	check(corruption.cursed_unlocked, "the Cursed are unlocked from the start")
	check(player.stats.get_stat("max_health") == 95.0 and is_equal_approx(player.stats.get_stat("bleed_power"), 1.2), "95 HP, bleed x1.2")
	await end_run_scene(scene)

	print("-- a character can bring its own skills")
	var custom := CharacterData.new()
	custom.id = "test"
	custom.skill_scenes = {"shift": load("res://scenes/player/skills/Kaeshi.tscn")}
	scene = await start_run_scene(custom)
	player = get_first_node_in_group("player")
	check(player.skills.size() == 4 and player.skills[1].display_name == "Kaeshi", "the Shift skill was replaced and stays in its place")
	await end_run_scene(scene)

	print("-- menu -> character select -> run")
	gm.selected_character = null
	var menu: Node = load("res://scenes/ui/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await wait_seconds(0.3)
	menu.quick_button.pressed.emit()
	await wait_seconds(0.5)
	var select: Node = current_scene
	check(select != null and select.scene_file_path.ends_with("CharacterSelect.tscn"), "the mode button opens the character select")
	check(gm.run_mode == gm.QUICK_MODE, "the mode is remembered")
	check(select.cards.size() == 4 and not select.cards[0].disabled and not select.cards[1].disabled and select.cards[2].disabled and select.cards[3].disabled, "4 cards, Kazuma's and Yume's are enabled")
	select.cards[0].pressed.emit()
	await wait_seconds(0.8)
	check(gm.selected_character == kazuma, "choosing a card sets the character")
	check(current_scene != null and current_scene.scene_file_path.ends_with("Run.tscn"), "the run starts")
	var run_player: Node = get_first_node_in_group("player")
	check(run_player != null and run_player.stats.get_stat("max_health") == 110.0, "and the player is Kazuma (110 HP)")

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
