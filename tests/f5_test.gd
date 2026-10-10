extends SceneTree

var failures: Array[String] = []
var player: CharacterBody3D
var stats: Node
var rules: Node
var events: Node
var rman: Node
var rm: Node
var kata: Node
var corruption: Node
var um: Node

func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func reset() -> void:
	corruption.modifiers.clear()
	stats.upgrades.clear(); stats.modifiers.clear(); rules.behaviors.clear(); rman.relics.clear()
	stats._recalculate(); stats.stats_changed.emit()
	corruption.possessed = false; corruption.possessed_left = 0.0; corruption.cooldown_left = 0.0
	corruption.cursed_unlocked = false
	corruption.set_corruption(0.0); corruption.cursed_unlocked = false
	rules.shield = 0.0
	player.health.set_current(player.health.max_health)
	kata.close("test"); kata.slots.clear(); kata.behaviors.clear(); kata.is_awake = false
	EnemyTime.reset()
	player.perfect_cooldown_left = 0.0; player.perfect_guard_left = 0.0

func dummy_at(pos: Vector3) -> Node:
	var d: Node3D = load("res://scenes/enemies/TrainingDummy.tscn").instantiate()
	d.position = pos
	rm.current_room.enemies_root.add_child(d)
	d.health.set_max_health(1000.0)
	return d

func upgrade(id: String) -> Resource:
	return load("res://resources/upgrades/%s.tres" % id)

func _initialize() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.run_mode = gm.QUICK_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func _run() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func(): print("WATCHDOG"); quit(2))
	await wait_seconds(0.6)
	player = get_first_node_in_group("player")
	stats = player.get_node("StatsComponent"); rules = player.get_node("RuleHost"); events = player.get_node("KataEvents")
	kata = player.get_node("KataComponent"); corruption = player.get_node("CorruptionComponent")
	rman = get_first_node_in_group("run_manager"); rm = get_first_node_in_group("room_manager")
	um = get_first_node_in_group("upgrade_manager")
	var hud: Node = get_first_node_in_group("hud")
	for e in get_nodes_in_group("enemy"): e.set_physics_process(false)

	print("-- Corruption grows with kills")
	reset()
	events.kill.emit({"kind": "light"})
	check(is_equal_approx(corruption.value, 1.5), "a kill adds 1.5 (%.1f)" % corruption.value)
	var dummy: Node = dummy_at(Vector3(6, 0, 6))
	player.on_bleed_tick(dummy, 5.0, true)
	check(is_equal_approx(corruption.value, 3.0), "a kill by bleeding counts too (%.1f)" % corruption.value)
	reset()
	var breath := UpgradeEffect.new(); breath.stat = "corruption_on_hit"; breath.operation = UpgradeEffect.Operation.ADD; breath.value = 3.0
	stats.add_modifier(breath)
	events.kill.emit({"kind": "light"})
	check(is_equal_approx(corruption.value, 4.5), "Dark Breath: +3 more per kill (%.1f)" % corruption.value)
	events.hit_dealt.emit({"kind": "light", "damage": 10.0, "killed": false})
	check(is_equal_approx(corruption.value, 4.5), "a hit that does not kill adds nothing")

	print("-- thresholds")
	reset()
	var d2: Node = dummy_at(Vector3(7, 0, 7))
	check(is_equal_approx(CombatManager.calculate_damage(10.0, player, d2.health, "light"), 10.0), "below 25%%: x1")
	corruption.set_corruption(25.0)
	check(is_equal_approx(CombatManager.calculate_damage(10.0, player, d2.health, "light"), 10.5), "25%%: +5%% damage")
	corruption.set_corruption(50.0)
	check(is_equal_approx(CombatManager.calculate_damage(10.0, player, d2.health, "light"), 12.0), "50%%: +20%% damage")
	check(corruption.cursed_unlocked, "50%%: the Cursed are unlocked")
	corruption.set_corruption(75.0)
	check(is_equal_approx(CombatManager.calculate_damage(10.0, player, d2.health, "light"), 13.0), "75%%: +30%% damage")
	check(is_equal_approx(kata.get_open_timeout(), 2.0), "75%%: the Kata waits 1 s less (%.1f)" % kata.get_open_timeout())
	check(corruption.edge_strength() > 0.2, "75%%: purple edge of the screen (%.2f)" % corruption.edge_strength())
	await wait_seconds(0.2)
	check(hud.corruption_edge != null and hud.corruption_edge.modulate.a > 0.1, "the HUD shows the purple edge")
	corruption.set_corruption(60.0)
	check(is_equal_approx(kata.get_open_timeout(), 3.0) and corruption.edge_strength() == 0.0, "below 75%%: no penalty, no edge")

	print("-- Cursed offers wait for 50%")
	reset()
	var cursed_seen := false
	for i in 300:
		for u in um.get_random_choices(4):
			if u.rarity == UpgradeData.Rarity.CURSED: cursed_seen = true
	check(not cursed_seen, "no Cursed upgrade in 300 offers before Corruption reached 50%")
	check(rman.get_random_relics(40).all(func(r): return not r.cursed), "no Cursed relic before 50%")
	corruption.set_corruption(50.0)
	corruption.set_corruption(0.0)
	cursed_seen = false
	for i in 300:
		for u in um.get_random_choices(4):
			if u.rarity == UpgradeData.Rarity.CURSED: cursed_seen = true
	check(cursed_seen, "Cursed upgrades appear after 50%% was reached once (it stays, even when the bar is back to 0)")
	check(rman.get_random_relics(40).any(func(r): return r.id == "cursed_mirror"), "Cursed Mirror can be found now")

	print("-- Possessed")
	reset()
	var hp_max: float = player.health.max_health
	var speed0: float = stats.get_stat("move_speed"); var aspeed0: float = stats.get_stat("attack_speed")
	corruption.set_corruption(100.0)
	check(corruption.possessed and is_equal_approx(corruption.possessed_left, 15.0), "100%%: Possessed for 15 s")
	check(is_equal_approx(stats.get_stat("move_speed"), speed0 * 1.25), "+25%% movement speed")
	check(is_equal_approx(stats.get_stat("attack_speed"), aspeed0 * 1.3), "+30%% attack speed")
	check(is_equal_approx(CombatManager.calculate_damage(10.0, player, d2.health, "light"), 16.0), "+60%% damage")
	player.health.set_current(50.0)
	player._on_hit_received(10.0, null)
	check(is_equal_approx(player.health.current_health, 45.0), "takes half the damage (%.1f)" % player.health.current_health)
	events.hit_dealt.emit({"kind": "light", "damage": 20.0})
	check(is_equal_approx(player.health.current_health, 47.0), "heals 10%% of the damage dealt (%.1f)" % player.health.current_health)
	corruption.add_corruption(50.0)
	check(is_equal_approx(corruption.value, 100.0), "no Corruption is gained while Possessed")
	await wait_seconds(0.3)
	check(hud.corruption_label.text.begins_with("POSSESSED"), "the HUD says POSSESSED (%s)" % hud.corruption_label.text)
	var aura_on := false
	for child in player.get_children():
		if child.get_script() and child.get_script().resource_path.ends_with("CorruptionVfx.gd"): aura_on = child.aura.emitting
	check(aura_on, "the dark aura is on")
	for i in 7: corruption._physics_process(1.0)
	check(corruption.possessed and corruption.value < 60.0 and corruption.value > 40.0, "the bar drains while it lasts (%.0f)" % corruption.value)
	for i in 8: corruption._physics_process(1.0)
	check(not corruption.possessed and corruption.value == 0.0, "after 15 s he returns to normal and the bar is at 0")
	check(is_equal_approx(stats.get_stat("move_speed"), speed0) and is_equal_approx(stats.get_stat("attack_speed"), aspeed0), "the bonuses are gone")
	check(is_equal_approx(CombatManager.calculate_damage(10.0, player, d2.health, "light"), 10.0), "damage back to normal")
	check(corruption.cooldown_left > 19.0, "cooldown of 20 s")
	events.kill.emit({"kind": "light"})
	check(corruption.value == 0.0, "no Corruption during the cooldown")
	await wait_seconds(0.2)
	check(hud.corruption_label.text.contains("resting"), "the HUD says it is resting (%s)" % hud.corruption_label.text)
	for i in 21: corruption._physics_process(1.0)
	events.kill.emit({"kind": "light"})
	check(is_equal_approx(corruption.value, 1.5), "after the cooldown kills fill the bar again")
	check(corruption.cursed_unlocked, "the Cursed stay unlocked")

	print("-- Cursed upgrades")
	reset()
	var pool_cursed: Array = um.upgrade_pool.filter(func(u): return u.rarity == UpgradeData.Rarity.CURSED)
	check(pool_cursed.size() == 4, "4 Cursed upgrades in the pool (%d)" % pool_cursed.size())
	check(not um.upgrade_pool.any(func(u): return u.id in ["cursed_hunger", "kurotsuki_gift"]), "Cursed Hunger and Kurotsuki's Gift (rejected) are not there")
	var base_hp: float = stats.get_stat("max_health"); var base_dmg: float = stats.get_stat("attack_damage")
	um.apply_upgrade(upgrade("cursed_blade"))
	check(is_equal_approx(stats.get_stat("attack_damage"), base_dmg * 1.6) and is_equal_approx(stats.get_stat("max_health"), base_hp * 0.75), "Cursed Blade: +60%% damage, -25%% max HP")
	reset()
	um.apply_upgrade(upgrade("cursed_rhythm"))
	check(is_equal_approx(stats.get_stat("flow_gain"), 2.0) and is_equal_approx(kata.get_open_timeout(), 1.5), "Cursed Rhythm: Flow x2, Kata timeout 1.5 s")
	reset()
	var aspeed: float = stats.get_stat("attack_speed"); var recharge: float = stats.get_stat("dash_recharge")
	um.apply_upgrade(upgrade("cursed_haste"))
	check(is_equal_approx(stats.get_stat("attack_speed"), aspeed * 1.4) and is_equal_approx(stats.get_stat("dash_recharge"), recharge * 0.65), "Cursed Haste: +40%% attack speed, dash recharges 35%% slower")
	check(int(stats.get_stat("dodge_charges")) == 1, "the dash itself is kept")
	reset()
	var bleeder: Node = dummy_at(Vector3(8, 0, 8))
	bleeder.status.apply_bleed(10.0, 3.0)
	var normal_dps: float = bleeder.status.bleeds[0].dps
	bleeder.status.bleeds.clear()
	um.apply_upgrade(upgrade("cursed_wound"))
	bleeder.status.apply_bleed(10.0, 3.0)
	check(is_equal_approx(bleeder.status.bleeds[0].dps, normal_dps * 1.6) and is_equal_approx(stats.get_stat("max_health"), base_hp * 0.85), "Cursed Wound: bleeding +60%%, -15%% max HP")

	print("-- Cursed Mirror")
	reset()
	var mirror: Resource = load("res://resources/relics/cursed_mirror.tres")
	check(mirror.cursed and rman.relic_pool.any(func(r): return r.id == "cursed_mirror"), "Cursed Mirror is a Cursed relic in the pool")
	rman.add_relic(mirror)
	events.perfect_dodge.emit(null)
	check(EnemyTime.get_scale() == 0.0 and EnemyTime.time_left > 7.0, "Perfect Dodge freezes the enemies")
	events.hit_dealt.emit({"kind": "light", "damage": 5.0})
	check(EnemyTime.get_scale() == 1.0, "the first hit you land starts time again")
	var ctx := {"damage_multiplier": 1.5}
	kata.finisher_performed.emit(ctx)
	check(is_equal_approx(ctx.damage_multiplier, 3.0), "Finishers deal double damage")
	check(is_equal_approx(rules.process_incoming(10.0, null), 13.0), "hits taken hurt 30%% more")

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
