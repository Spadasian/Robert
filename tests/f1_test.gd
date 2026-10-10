extends SceneTree

var failures: Array[String] = []
var player: CharacterBody3D
var stats: Node
var rules: Node
var um: Node
var events: Node
var rman: Node
var rm: Node
var kata: Node

func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func U(id: String) -> Resource:
	return load("res://resources/upgrades/%s.tres" % id)

func take(id: String) -> void:
	um.apply_upgrade(U(id))

func reset() -> void:
	stats.upgrades.clear(); stats.modifiers.clear(); rules.behaviors.clear()
	stats._recalculate(); stats.stats_changed.emit()
	rules.shield = 0.0
	player.health.set_current(player.health.max_health)
	kata.close("test"); kata.slots.clear(); kata.behaviors.clear(); kata.is_awake = false
	rman.rerolls_used = 0
	player.dash.charges = player.dash.max_charges
	EnemyTime.reset()

func dummy_at(pos: Vector3, hp: float = 1000.0) -> Node:
	var d: Node3D = load("res://scenes/enemies/TrainingDummy.tscn").instantiate()
	d.position = pos
	rm.current_room.enemies_root.add_child(d)
	d.health.set_max_health(hp)
	return d

func _initialize() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.run_mode = gm.QUICK_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func _run() -> void:
	create_timer(100.0, true, false, true).timeout.connect(func(): print("WATCHDOG"); quit(2))
	await wait_seconds(0.6)
	player = get_first_node_in_group("player")
	stats = player.get_node("StatsComponent"); rules = player.get_node("RuleHost"); events = player.get_node("KataEvents")
	kata = player.get_node("KataComponent")
	um = get_first_node_in_group("upgrade_manager"); rman = get_first_node_in_group("run_manager"); rm = get_first_node_in_group("room_manager")
	var light := {"kind": "light", "hit_count": 1, "crit": false}

	print("-- pool")
	check(um.upgrade_pool.size() == 75, "71 upgrades in the pool (%d)" % um.upgrade_pool.size())
	var ids := {}
	var bad := 0
	for u in um.upgrade_pool:
		ids[u.id] = true
		if u.effects.is_empty() and u.behavior == null: bad += 1
	check(ids.size() == um.upgrade_pool.size() and bad == 0, "ids are unique and every upgrade does something")
	for removed in ["afterimage", "cutting_wind", "ultimate_charge"]:
		check(not ids.has(removed), "%s (rejected) is not in the pool" % removed)
	check(U("blood_edge").description == "+15% attack damage" and U("vital_spirit").effects[0].value == 20.0, "the first ten have the reviewed values")

	print("-- stats: dash, perfect dodge")
	reset()
	var cd0: float = player.dash.dash_cooldown; var sp0: float = player.dash.dash_speed
	take("ghost_sandals"); take("long_stride")
	check(is_equal_approx(player.dash.dash_cooldown, cd0 / 1.15) and is_equal_approx(player.dash.dash_speed, sp0 * 1.25), "dash recharge x1.15 and distance x1.25")
	reset()
	check(is_equal_approx(player.dash.dash_speed, sp0), "reset restores the dash")
	var perfect := []
	events.perfect_dodge.connect(func(_s): perfect.append(1))
	player.dash.is_dashing = true; player.dash.elapsed = 0.16
	player._on_hit_received(1.0, null)
	check(perfect.size() == 0, "0.16 s after the dash is NOT a Perfect Dodge")
	take("phantom_window")
	player._on_hit_received(1.0, null)
	check(perfect.size() == 1, "Phantom Window: 0.16 s is a Perfect Dodge now")
	check(is_equal_approx(EnemyTime.scale, 0.2) and EnemyTime.time_left > 0.65 and EnemyTime.time_left <= 0.7, "a Perfect Dodge slows the enemies to 20%% for 0.7 s (%.2f)" % EnemyTime.time_left)
	EnemyTime.reset()
	player.perfect_cooldown_left = 0.0; player.perfect_guard_left = 0.0
	take("time_slip")
	player._on_hit_received(1.0, null)
	check(EnemyTime.time_left > 1.15 and EnemyTime.time_left <= 1.2, "Time Slip: 1.2 s (%.2f)" % EnemyTime.time_left)
	var bandit: Node3D = load("res://scenes/enemies/Bandit.tscn").instantiate()
	bandit.position = Vector3(10, 0, 10)
	rm.current_room.enemies_root.add_child(bandit)
	check(is_equal_approx(bandit.time_scale(), 0.2), "enemies run at 20%% of their time during the slow")
	check(is_equal_approx(player.dash.dash_speed, sp0), "the player is not slowed")
	await wait_seconds(1.4)
	check(is_equal_approx(EnemyTime.scale, 1.0) and is_equal_approx(bandit.time_scale(), 1.0), "the slow ends by itself")
	bandit.queue_free()
	player.dash.is_dashing = false

	print("-- stats: damage")
	reset()
	var d1: Node = dummy_at(Vector3(10, 0, 8))
	take("sharp_focus")  # +5% crit, not enough to test; force crit chance
	stats.add_modifier(load("res://scripts/upgrades/UpgradeEffect.gd").new())
	var eff := UpgradeEffect.new(); eff.stat = "crit_chance"; eff.value = 1.0; stats.add_modifier(eff)
	var dmg: float = CombatManager.calculate_damage(10.0, player, d1.health, "light")
	check(is_equal_approx(dmg, 15.0) and CombatManager.last_hit_was_crit, "crit x1.5 (%.2f)" % dmg)
	take("heavy_hands")
	dmg = CombatManager.calculate_damage(10.0, player, d1.health, "light")
	check(is_equal_approx(dmg, 17.5), "Heavy Hands: crit x1.75 (%.2f)" % dmg)
	reset()
	d1.health.current_health = 350.0  # 35% of 1000
	dmg = CombatManager.calculate_damage(10.0, player, d1.health, "light")
	check(is_equal_approx(dmg, 10.0), "35%% HP enemy: no execute bonus yet (%.2f)" % dmg)
	take("killing_intent")
	dmg = CombatManager.calculate_damage(10.0, player, d1.health, "light")
	check(is_equal_approx(dmg, 12.5), "Killing Intent: enemies below 40%% take +25%% (%.2f)" % dmg)
	take("executioner")
	d1.health.current_health = 250.0
	dmg = CombatManager.calculate_damage(10.0, player, d1.health, "light")
	check(is_equal_approx(dmg, 10.0 * (1.0 + 0.75)), "stacks with Executioner (%.2f)" % dmg)

	print("-- stats: Kata, Heavy, skills, xp, choices")
	reset()
	kata.set_technique(load("res://resources/techniques/quick_draw.tres")); kata.set_technique(load("res://resources/techniques/crimson_rhythm.tres"))
	events.dodge.emit()
	kata.flow_value = 0.0
	take("flow_seeker"); take("rhythm_keeper"); take("lingering_mist")
	kata.add_flow(0.5)
	check(is_equal_approx(kata.flow_value, 0.6), "Flow Seeker: +20%% Flow (%.2f)" % kata.flow_value)
	kata.add_flow(-0.4)
	check(is_equal_approx(kata.flow_value, 0.4), "Rhythm Keeper: lose half (%.2f)" % kata.flow_value)
	check(is_equal_approx(kata.get_open_timeout(), 4.0), "Lingering Mist: Kata timeout 4 s")
	reset()
	var heavy: Node = player.get_node("HeavySkill")
	take("finisher_edge")
	heavy.try_activate()
	check(is_equal_approx(heavy.cooldown_left, 0.9 * 0.8), "Finisher Edge: Heavy cooldown 0.72 (%.2f)" % heavy.cooldown_left)
	heavy.cancel(); heavy.cooldown_left = 0.0
	take("whirl_training")
	heavy.try_activate()
	check(is_equal_approx(heavy.telegraph.scale.x, 1.15), "Whirl Training: Heavy reach x1.15")
	heavy.cancel(); heavy.cooldown_left = 0.0
	reset()
	var iai: Node = player.get_node_or_null("IaijutsuSkill")
	var base_cd: float = iai.cooldown
	take("skill_haste")
	iai.try_activate()
	check(is_equal_approx(iai.cooldown_left, base_cd * 0.85), "Skill Haste: Iaijutsu cooldown x0.85")
	iai.cancel(); iai.cooldown_left = 0.0
	reset()
	rman.xp = 0; rman.level = 1
	take("scholars_brush")
	rman.add_xp(10)
	check(rman.xp == 11, "Scholar's Brush: 10 EXP -> 11 (%d)" % rman.xp)
	rman.xp = 0
	reset()
	check(um.get_random_choices(int(stats.get_stat("choice_count"))).size() == 3, "3 cards by default")
	take("wide_view")
	check(um.get_random_choices(int(stats.get_stat("choice_count"))).size() == 4, "Wide View: 4 cards")
	check(um.rerolls_left() == 0 and um.reroll(3).is_empty(), "no reroll without Reroll Token")
	take("reroll_token")
	check(um.rerolls_left() == 1 and um.reroll(3).size() == 3 and um.rerolls_left() == 0, "Reroll Token: one reroll, then none")
	reset()
	var hp0: float = player.health.current_health
	var ev := UpgradeEffect.new(); ev.stat = "evade_chance"; ev.value = 1.0; stats.add_modifier(ev)
	player._on_hit_received(30.0, null)
	check(player.health.current_health == hp0, "Lucky Thread effect: the hit did nothing")

	print("-- behaviors")
	reset()
	take("riposte_edge")
	events.perfect_dodge.emit(null)
	check(is_equal_approx(stats.get_stat("attack_damage"), 15.0), "Riposte Edge: +50%% damage after a Perfect Dodge")
	events.hit_dealt.emit(light)
	check(is_equal_approx(stats.get_stat("attack_damage"), 10.0), "...ends with the first hit")
	reset()
	take("slipstream"); events.dodge.emit()
	check(is_equal_approx(stats.get_stat("move_speed"), 7.2), "Slipstream: +20%% speed after a dash")
	await wait_seconds(2.4)
	check(is_equal_approx(stats.get_stat("move_speed"), 6.0), "...and it ends by itself")
	reset()
	take("mirror_step"); player.dash.charges = 0
	events.perfect_dodge.emit(null)
	check(player.dash.charges == 1, "Mirror Step: the charge is back")
	reset()
	take("quick_recovery"); player.dash.charges = 0; player.dash.recharge_left = 0.7
	events.hit_dealt.emit(light)
	check(is_equal_approx(player.dash.recharge_left, 0.5), "Quick Recovery: -0.2 s")
	reset()
	take("soul_reaper")
	var ult: Node = player.get_node("UltimateSkill"); ult.charge = 0.0
	events.kill.emit({"target": d1})
	check(is_equal_approx(ult.charge, 5.0), "Soul Reaper: +5%% Ultimate (%.1f)" % ult.charge)
	reset()
	take("bleeding_cut")
	d1.health.current_health = 1000.0
	events.critical_hit.emit({"target": d1})
	check(d1.status.is_bleeding(), "Bleeding Cut: a critical hit makes it bleed")
	var hp_b: float = d1.health.current_health
	await wait_seconds(1.1)
	check(d1.health.current_health < hp_b, "...and the bleed hurts (%.1f -> %.1f)" % [hp_b, d1.health.current_health])
	d1.status.apply_bleed(3.0, 3.0); d1.status.apply_bleed(3.0, 3.0); d1.status.apply_bleed(3.0, 3.0); d1.status.apply_bleed(9.0, 3.0)
	check(d1.status.bleeds.size() == 3, "bleed stacks up to 3")
	d1.status.bleeds.clear()
	reset()
	take("finish_them")
	d1.health.current_health = 300.0
	dmg = CombatManager.calculate_damage(10.0, player, d1.health, "heavy")
	check(is_equal_approx(dmg, 13.0), "Finish Them: Heavy x1.3 on a wounded enemy")
	d1.health.current_health = 900.0
	check(is_equal_approx(CombatManager.calculate_damage(10.0, player, d1.health, "heavy"), 10.0), "...not on a healthy one")
	reset()
	take("deadeye")
	check(is_equal_approx(rules.crit_chance_bonus("light", d1), 0.15), "Deadeye: +15%% crit on a new enemy")
	events.hit_dealt.emit({"kind": "light", "hit_count": 1, "target": d1})
	check(is_equal_approx(rules.crit_chance_bonus("light", d1), 0.0), "...only the first hit")
	reset()
	take("overkill_wave")
	var d2: Node = dummy_at(Vector3(12, 0, 8)); var hp2: float = d2.health.current_health
	events.kill.emit({"target": d1, "overkill": 100.0})
	check(is_equal_approx(hp2 - d2.health.current_health, 50.0), "Overkill Wave: the neighbour takes 50")
	reset()
	take("death_mark")
	d1.health.current_health = 90.0
	check(CombatManager.calculate_damage(10.0, player, d1.health, "light") >= 90.0, "Death Mark: a light hit kills an enemy below 10%%")
	check(CombatManager.calculate_damage(10.0, player, d1.health, "heavy") < 90.0, "...a Heavy does not use it")
	d1.health.current_health = 110.0
	check(CombatManager.calculate_damage(10.0, player, d1.health, "light") < 110.0, "...above 10%% it does nothing")
	d1.health.current_health = 1000.0
	reset()
	take("lethal_rhythm")
	for i in 4: events.hit_dealt.emit(light)
	check(rules.forced_crit("light", d1), "Lethal Rhythm: the 5th hit is a guaranteed critical")
	events.hit_dealt.emit({"kind": "light", "hit_count": 1, "crit": true})
	check(not rules.forced_crit("light", d1), "...then it starts again")
	for i in 3: events.hit_dealt.emit(light)
	events.damage_taken.emit(1.0)
	events.hit_dealt.emit(light)
	check(not rules.forced_crit("light", d1), "...and taking damage resets it")
	reset()
	take("opening_strike")
	check(is_equal_approx(rules.damage_multiplier("light", d1.health), 1.0), "Opening Strike: nothing before the Kata opens")
	kata.opened.emit()
	check(is_equal_approx(rules.damage_multiplier("light", d1.health), 1.4), "...+40%% on the first hit after")
	events.hit_dealt.emit(light)
	check(is_equal_approx(rules.damage_multiplier("light", d1.health), 1.0), "...only once")
	reset()
	take("combo_spark")
	kata.is_awake = true; kata.is_open = true
	var waves_before: int = rm.current_room.get_children().filter(func(n): return n.get("kind") == "wave").size()
	for i in 3: events.hit_dealt.emit(light)
	var waves: Array = rm.current_room.get_children().filter(func(n): return n.get("kind") == "wave")
	check(waves.size() == waves_before + 1 and waves[-1].pierce and is_equal_approx(waves[-1].damage, 6.0), "Combo Spark: a wave on the 3rd hit (6 damage, piercing)")
	for w in waves: w.queue_free()
	kata.is_open = false
	reset()
	take("second_wind")
	kata.set_technique(load("res://resources/techniques/quick_draw.tres"))
	kata.finisher_performed.emit({})
	await wait_seconds(0.3)
	check(kata.is_open, "Second Wind: the Kata is open again after a Finisher")
	reset()
	take("bamboo_heart")
	player.health.set_current(50.0)
	rm.fight_room_cleared.emit(0)
	check(is_equal_approx(player.health.current_health, 60.0), "Bamboo Heart: +10%% HP when a fight room is cleared")
	reset()
	take("second_chance")
	check(rules.process_incoming(1000.0, null) == 0.0 and is_equal_approx(player.health.current_health, 30.0), "Second Chance: survives with 30%%")
	check(rules.process_incoming(1000.0, null) == 1000.0, "...only once")
	reset()
	take("armor_plate")
	check(is_equal_approx(rules.shield, 15.0), "Armor Plate: 15 shield")
	check(rules.process_incoming(10.0, null) == 0.0 and is_equal_approx(rules.shield, 5.0), "the shield takes the hit")
	check(is_equal_approx(rules.process_incoming(10.0, null), 5.0), "...and what is left passes through")
	rules._each("on_room_entered", [RoomData.RoomType.COMBAT])
	check(is_equal_approx(rules.shield, 15.0), "...and it is back in the next room")
	reset()
	take("warm_tea")
	player.health.set_current(50.0)
	rules._each("on_room_entered", [RoomData.RoomType.COMBAT])
	check(player.health.current_health == 50.0, "Warm Tea: no heal in a combat room")
	rules._each("on_room_entered", [RoomData.RoomType.SHOP])
	check(is_equal_approx(player.health.current_health, 65.0), "Warm Tea: +15%% in a Shop")
	rules._each("on_room_entered", [RoomData.RoomType.TREASURE])
	check(is_equal_approx(player.health.current_health, 65.0), "Warm Tea: nothing in a Treasure room any more")
	player.health.set_current(50.0)
	rules._each("on_room_entered", [RoomData.RoomType.SHOP])
	check(player.health.current_health == 50.0, "Warm Tea: only once per biome (the second Shop gives nothing)")
	rules._each("on_biome_started", [1])
	rules._each("on_room_entered", [RoomData.RoomType.SHOP])
	check(is_equal_approx(player.health.current_health, 65.0), "Warm Tea: works again in the next biome")
	reset()
	take("last_stand")
	check(is_equal_approx(rules.damage_multiplier("light", d1.health), 1.0), "Last Stand: nothing at full health")
	player.health.set_current(20.0)
	check(is_equal_approx(rules.damage_multiplier("light", d1.health), 1.25) and is_equal_approx(rules.process_incoming(10.0, null), 8.0), "Last Stand: +25%% damage and -20%% taken below 30%%")
	reset()
	take("spiked_armor")
	var hp3: float = d1.health.current_health
	rules.process_incoming(10.0, d1)
	check(is_equal_approx(hp3 - d1.health.current_health, 8.0), "Spiked Armor: the attacker takes 8")
	reset()
	take("lifebloom")
	check(is_equal_approx(stats.get_stat("max_health"), 115.0), "Lifebloom: +15 max HP")
	player.health.set_current(50.0)
	events_level_up()
	check(is_equal_approx(player.health.current_health, 70.0), "Lifebloom: +20 HP on a level up")
	reset()
	take("guardian_spirit"); events.perfect_dodge.emit(null)
	check(is_equal_approx(rules.shield, 20.0), "Guardian Spirit: 20 shield after a Perfect Dodge")
	reset()
	take("adrenaline"); events.damage_taken.emit(5.0)
	check(is_equal_approx(stats.get_stat("attack_speed"), 1.3), "Adrenaline: +30%% attack speed")
	await wait_seconds(3.2)
	check(is_equal_approx(stats.get_stat("attack_speed"), 1.0), "...for 3 s")

	print("-- enemy status")
	reset()
	var d3: Node = dummy_at(Vector3(14, 0, 8), 30.0)
	var killed := []
	events.kill.connect(func(info): killed.append(info))
	d3.status.apply_bleed(100.0, 3.0)
	await wait_seconds(0.8)
	check(killed.size() == 1 and killed[0].kind == "bleed", "a bleed kill counts as a kill")
	var d4: Node = dummy_at(Vector3(16, 0, 8))
	d4.status.apply_stun(1.0)
	check(is_equal_approx(d4.time_scale(), 0.0), "a stunned enemy does not move")
	d4.status.apply_mark(0.25, 2.0)
	var hp4: float = d4.health.current_health
	d4._on_hit_received(100.0, null)
	check(is_equal_approx(hp4 - d4.health.current_health, 125.0), "a marked enemy takes +25%%")
	var boss: Node = load("res://scenes/enemies/Boss.tscn").instantiate()
	boss.position = Vector3(-10, 0, 10)
	rm.current_room.enemies_root.add_child(boss)
	boss.status.apply_stun(2.0)
	check(is_equal_approx(boss.time_scale(), 1.0), "a boss cannot be stunned")
	boss.queue_free()

	print("-- new crit chance upgrades")
	reset()
	var crit0: float = stats.get_stat("crit_chance")
	take("falcon_eye")
	check(is_equal_approx(stats.get_stat("crit_chance"), crit0 + 0.07), "Falcon Eye: +7%% crit chance")
	reset()
	take("backstab_instinct")
	d1.rotation.y = 0.0
	player.global_position = d1.global_position + Vector3(0, 0, 3)
	check(is_equal_approx(rules.crit_chance_bonus("light", d1), 0.0), "Backstab Instinct: nothing from the front")
	d1.rotation.y = PI
	check(is_equal_approx(rules.crit_chance_bonus("light", d1), 0.30), "Backstab Instinct: +30%% from behind")
	d1.rotation.y = 0.0
	reset()
	take("perfect_aim")
	events.perfect_dodge.emit(null)
	check(is_equal_approx(stats.get_stat("crit_chance"), crit0 + 0.40), "Perfect Aim: +40%% crit chance after a Perfect Dodge")
	events.perfect_dodge.emit(null)
	check(is_equal_approx(stats.get_stat("crit_chance"), crit0 + 0.40), "Perfect Aim: renewed, not stacked")
	await wait_seconds(3.3)
	check(is_equal_approx(stats.get_stat("crit_chance"), crit0), "Perfect Aim: ends after 3 s")
	reset()
	take("crit_momentum")
	for i in 3: events.critical_hit.emit({"target": d1, "kind": "light"})
	check(is_equal_approx(stats.get_stat("crit_chance"), crit0 + 0.12), "Crit Momentum: 3 crits = +12%%")
	for i in 5: events.critical_hit.emit({"target": d1, "kind": "light"})
	check(is_equal_approx(stats.get_stat("crit_chance"), crit0 + 0.20), "Crit Momentum: capped at 5 stacks (+20%%)")
	await wait_seconds(4.3)
	check(is_equal_approx(stats.get_stat("crit_chance"), crit0), "Crit Momentum: stacks expire after 4 s")
	events.critical_hit.emit({"target": d1, "kind": "light"})
	check(is_equal_approx(stats.get_stat("crit_chance"), crit0 + 0.04), "Crit Momentum: starts again after they ended")

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)

func events_level_up() -> void:
	rman.level_up.emit(2)
