extends SceneTree

var failures: Array[String] = []
var rm: Node
var rman: Node
var player: Node
var tm: Node
var tc: Node
var omen_ui: Node
var RT = RoomData.RoomType

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

func environment() -> Environment:
	return root.find_child("WorldEnvironment", true, false).environment

func sun() -> DirectionalLight3D:
	return root.find_child("Sun", true, false) as DirectionalLight3D

func start_arena(omen_id: String) -> Node:
	await fresh_biome(0)
	player.health.set_max_health(player.health.max_health)
	var room: Node = await enter(RT.ARENA)
	await wait_seconds(0.3)
	omen_ui.omen_chosen.emit(ArenaOmens.find(omen_id))
	await wait_seconds(0.3)
	return room

## The test picks upgrades by itself at every level up: one may be a shield, an evade chance or more HP, which would
## change the numbers below. Before a check that depends on damage taken the upgrades are taken away.
func strip_upgrades() -> void:
	var rules: Node = player.get_node("RuleHost")
	player.stats.upgrades.clear(); player.stats.modifiers.clear(); rules.behaviors.clear(); rules.shield = 0.0
	player.stats._recalculate(); player.stats.stats_changed.emit()
	player.free_hits_left = 0

func finish_arena(room: Node) -> void:
	var waves: int = room.omen.waves.size()
	for w in waves:
		await wait_seconds(2.0)
		player.health.heal(1000.0)
		kill_all(room)
	await wait_seconds(1.8)

func take_card() -> void:
	await wait_seconds(1.0)
	if tc.visible:
		tc.technique_chosen.emit(tc.current_choices[0])
	await wait_seconds(0.3)

func _initialize() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.run_mode = gm.STANDARD_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func _run() -> void:
	create_timer(175.0, true, false, true).timeout.connect(func(): print("WATCHDOG"); quit(2))
	auto_upgrade()
	await wait_seconds(0.5)
	rm = get_first_node_in_group("room_manager")
	rman = get_first_node_in_group("run_manager")
	player = get_first_node_in_group("player")
	tm = get_first_node_in_group("technique_manager")
	tc = tm.choice_ui
	omen_ui = get_first_node_in_group("omen_choice")
	var ult: Node = null
	for s in player.skills:
		if s.display_name == "Moonlit Storm": ult = s

	print("-- Ultimate charges from kills only")
	ult.charge = 0.0
	ult.on_player_hit_dealt(false)
	check(ult.charge == 0.0, "a hit that does not kill gives no charge")
	ult.on_player_hit_dealt(true)
	check(is_equal_approx(ult.charge, 6.0), "a kill gives 6 (%.1f)" % ult.charge)
	var effect := UpgradeEffect.new()
	effect.stat = "ultimate_hit_charge"; effect.operation = UpgradeEffect.Operation.ADD; effect.value = 2.0
	player.stats.add_modifier(effect)
	ult.on_player_hit_dealt(false)
	check(is_equal_approx(ult.charge, 8.0), "with the stat ultimate_hit_charge a hit charges too (%.1f)" % ult.charge)
	player.stats.remove_modifier(effect)
	var dummy: Node3D = load("res://scenes/enemies/TrainingDummy.tscn").instantiate()
	rm.current_room.enemies_root.add_child(dummy)
	dummy.global_position = player.global_position + Vector3(5, 0, 0)
	ult.charge = 0.0
	player.on_bleed_tick(dummy, 5.0, true)
	check(is_equal_approx(ult.charge, 6.0), "a kill by bleeding charges the Ultimate")
	ult.charge_locked = true; ult.charge = 0.0
	ult.on_player_hit_dealt(true)
	check(ult.charge == 0.0, "charge_locked: no charge")
	ult.charge_locked = false
	dummy.queue_free()

	print("-- the omen list")
	var all: Array = ArenaOmens.all()
	var ids := {}
	for o in all: ids[o.id] = true
	check(all.size() == 10 and ids.size() == 10, "10 unique omens")
	check(all[0].id == "pale_moon" and all[1].id == "blood_moon" and all[2].id == "black_storm", "the first three are the old ones")
	check(all.all(func(o): return o.name != "" and o.text != "" and o.reward != "" and o.difficulty != "" and o.waves.size() >= 2), "every omen has name, text, reward, difficulty, waves")
	var tier := {"Easy": 40, "Medium": 80, "Hard": 150, "Very hard": 200}
	check(all.all(func(o): return o.gold == tier[o.difficulty]), "arena gold grows with the difficulty (40 / 80 / 150 / 200)")
	var seen := {}
	var always_three := true
	for i in 30:
		var three: Array = ArenaOmens.pick(3)
		var distinct := {}
		for o in three: distinct[o.id] = true; seen[o.id] = true
		always_three = always_three and three.size() == 3 and distinct.size() == 3
	check(always_three, "pick(3) gives 3 different omens")
	check(seen.size() >= 8, "over 30 picks most omens show up (%d of 10)" % seen.size())

	print("-- arena offers 3 of 10")
	await fresh_biome(0)
	var room: Node = await enter(RT.ARENA)
	await wait_seconds(0.3)
	check(omen_ui.visible and omen_ui.current_choices.size() == 3, "the omen card choice shows 3")
	omen_ui.omen_chosen.emit(ArenaOmens.find("pale_moon"))
	await finish_arena(room)
	await take_card()

	print("-- Fog of Ghosts")
	var env: Environment = environment()
	var fog_before: bool = env.volumetric_fog_enabled
	var ambient_before: Color = env.ambient_light_color
	var xp_before: int = total_xp()
	room = await start_arena("fog_of_ghosts")
	check(env.volumetric_fog_enabled and env.volumetric_fog_density > 0.0, "volumetric fog is on")
	await wait_seconds(1.8)
	var near_enemy: Node3D = room.enemies_root.get_child(0)
	var far_enemy: Node3D = room.enemies_root.get_child(1)
	near_enemy.global_position = player.global_position + Vector3(2, 0, 0)
	far_enemy.global_position = player.global_position + Vector3(11, 0, 0)
	await wait_seconds(0.3)
	var near_mesh: MeshInstance3D = near_enemy.find_children("*", "MeshInstance3D", true, false)[0]
	var far_mesh: MeshInstance3D = far_enemy.find_children("*", "MeshInstance3D", true, false)[0]
	check(near_mesh.transparency < 0.1 and far_mesh.transparency > 0.6, "near enemy visible (%.2f), far enemy fades in the fog (%.2f)" % [near_mesh.transparency, far_mesh.transparency])
	await finish_arena(room)
	check(env.volumetric_fog_enabled == fog_before and env.ambient_light_color == ambient_before, "fog and ambient restored after the arena")
	check(total_xp() >= xp_before + 100, "reward: +100 EXP")
	await take_card()

	print("-- Iron Rain")
	var gold_before: int = rman.gold
	room = await start_arena("iron_rain")
	strip_upgrades()
	player.health.set_current(player.health.max_health)
	var hp0: float = player.health.current_health
	room._strike_at(player.global_position + Vector3(9, 0, 0), 1.6, 0.3, 10.0, Color(1, 0, 0, 0.4), true)
	var near_strike: Node = room._strike_at(player.global_position, 1.6, 0.3, 10.0, Color(1, 0, 0, 0.4), true)
	await wait_seconds(0.2)
	check(player.health.current_health == hp0, "the warning does no damage")
	await wait_seconds(0.3)
	check(player.health.current_health < hp0, "the strike on the player hurts (%.1f -> %.1f)" % [hp0, player.health.current_health])
	var hp1: float = player.health.current_health
	player.dash.is_dashing = true; player.dash.elapsed = 0.02
	var dodged: Node = room._strike_at(player.global_position, 1.6, 100.0, 10.0, Color(1, 0, 0, 0.4), true)
	dodged._strike()
	await wait_seconds(0.1)
	check(player.health.current_health == hp1, "dashing through the strike: no damage")
	player.dash.is_dashing = false
	await wait_seconds(2.2)
	var volleys: int = get_nodes_in_group("arrow_strike").size()
	check(room.alive_enemies > 0 and (volleys > 0 or room.rain_timer > 0.0), "volleys of arrows come during the fight (%d active)" % volleys)
	await finish_arena(room)
	check(rman.gold >= gold_before + 80, "reward: +80 gold")
	await take_card()

	print("-- Eclipse")
	var sun_before: float = sun().light_energy
	room = await start_arena("eclipse")
	check(sun().light_energy < sun_before, "the light is dimmer (%.2f -> %.2f)" % [sun_before, sun().light_energy])
	await wait_seconds(1.8)
	var bandit: Node = null
	for e in room.enemies_root.get_children():
		if e.scene_file_path.ends_with("Bandit.tscn") and not e.scene_file_path.ends_with("HeavyBandit.tscn"): bandit = e
	if bandit:
		var base_speed: float = load("res://scenes/enemies/Bandit.tscn").instantiate().move_speed
		check(is_equal_approx(bandit.move_speed, base_speed * 1.3), "enemies are 30%% faster (%.2f)" % bandit.move_speed)
		check(bandit.hide_next_telegraph or bandit.state != 0, "the first attack has no warning")
		bandit.hide_next_telegraph = true
		check(not bandit.telegraph_visible() and bandit.telegraph_visible(), "the warning is hidden once, then shown again")
	gold_before = rman.gold
	await finish_arena(room)
	check(is_equal_approx(sun().light_energy, sun_before), "light restored")
	check(rman.gold >= gold_before + 150, "reward: +150 gold")
	await take_card()

	print("-- Hunger Moon")
	room = await start_arena("hunger_moon")
	check(player.health.heal_blocked, "healing is blocked")
	player.health.set_current(50.0)
	player.health.heal(20.0)
	check(player.health.current_health == 50.0, "heal() does nothing in the arena")
	await finish_arena(room)
	check(not player.health.heal_blocked, "healing works again after the arena")
	await wait_seconds(1.6)
	check(tc.visible and tc.rerolls_left == 1 and tc.reroll_button.visible, "the technique offer has one reroll")
	var before_ids: Array = tc.current_choices.map(func(d): return d.id)
	tc._reroll()
	var after_ids: Array = tc.current_choices.map(func(d): return d.id)
	check(tc.rerolls_left == 0 and after_ids != before_ids and not tc.reroll_button.visible, "reroll gives other cards and is used up")
	tc._reroll()
	check(tc.current_choices.map(func(d): return d.id) == after_ids, "no second reroll")
	tc.technique_chosen.emit(tc.current_choices[0])
	await wait_seconds(0.4)

	print("-- Silent Night")
	room = await start_arena("silent_night")
	check(ult.charge_locked, "the Ultimate is locked")
	ult.charge = 0.0; ult.on_player_hit_dealt(true)
	check(ult.charge == 0.0, "no charge from kills")
	await wait_seconds(1.8)
	var hp_ok := true
	for e in room.enemies_root.get_children():
		var base_hp: float = load(e.scene_file_path).instantiate().max_health
		hp_ok = hp_ok and absf(e.max_health - base_hp * 1.4 * rman.enemy_health_multiplier) < 0.01
	check(hp_ok, "enemies have +40%% health")
	check(room.omen.master == 0.5, "50%% chance of a Master")
	await finish_arena(room)
	check(not ult.charge_locked, "the Ultimate works again after the arena")
	await take_card()

	print("-- Crimson Tide")
	room = await start_arena("crimson_tide")
	await wait_seconds(1.8)
	strip_upgrades()
	player.health.set_current(player.health.max_health)
	for e in room.enemies_root.get_children(): e.set_physics_process(false) # only the explosions may hurt now
	var victim: Node3D = room.enemies_root.get_child(0)
	victim.global_position = player.global_position + Vector3(1.0, 0, 0)
	var hp_t: float = player.health.current_health
	victim.health.take_damage(1000000.0)
	await wait_seconds(0.3)
	check(player.health.current_health == hp_t, "the explosion is announced first")
	await wait_seconds(0.6)
	check(player.health.current_health < hp_t, "the explosion hurts when you stay near the dead enemy (%.1f -> %.1f)" % [hp_t, player.health.current_health])
	player.health.set_current(player.health.max_health)
	hp_t = player.health.current_health
	var far_victim: Node3D = room.enemies_root.get_child(1)
	far_victim.global_position = player.global_position + Vector3(9.0, 0, 0)
	far_victim.health.take_damage(1000000.0)
	await wait_seconds(1.0)
	check(player.health.current_health == hp_t, "far from it nothing happens")
	await finish_arena(room)
	await take_card()

	print("-- Twin Suns")
	room = await start_arena("twin_suns")
	check(room.extra_lights.size() == 2, "two suns (lights)")
	await wait_seconds(1.8)
	var left := 0
	var right := 0
	for e in room.enemies_root.get_children():
		if e.position.x < -3.0: left += 1
		elif e.position.x > 3.0: right += 1
	check(room.alive_enemies == 10 and left >= 3 and right >= 3, "wave 1: 10 enemies in two groups on opposite sides (%d left / %d right)" % [left, right])
	player.health.heal(1000.0); kill_all(room)
	await wait_seconds(2.0)
	check(room.wave == 2 and room.alive_enemies == 12, "wave 2: two groups of 6 (%d)" % room.alive_enemies)
	player.health.heal(1000.0); kill_all(room)
	await wait_seconds(1.5)
	check(room.cleared, "only 2 waves, then the arena is cleared")
	check(room.extra_lights.is_empty(), "the suns are gone")
	await take_card()

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
