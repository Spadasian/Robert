extends SceneTree

var failures: Array[String] = []
var player: CharacterBody3D
var stats: Node
var rules: Node
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

func relic(id: String) -> void:
	rman.add_relic(load("res://resources/relics/%s.tres" % id))

func reset() -> void:
	stats.upgrades.clear(); stats.modifiers.clear(); rules.behaviors.clear(); rman.relics.clear()
	stats._recalculate(); stats.stats_changed.emit()
	rules.shield = 0.0; rules.hidden_left = 0.0
	player.health.set_current(player.health.max_health)
	kata.close("test"); kata.slots.clear(); kata.behaviors.clear(); kata.is_awake = false; kata.flow_shield_left = 0.0
	EnemyTime.reset()
	for z in rm.current_room.get_children():
		if z is HazardZone or z.get("kind") == "wave": z.queue_free()

func dummy_at(pos: Vector3, hp: float = 1000.0) -> Node:
	var d: Node3D = load("res://scenes/enemies/TrainingDummy.tscn").instantiate()
	d.position = pos
	rm.current_room.enemies_root.add_child(d)
	d.health.set_max_health(hp)
	return d

func zones() -> Array:
	return rm.current_room.get_children().filter(func(n): return n is HazardZone)

func _initialize() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.run_mode = gm.QUICK_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func _run() -> void:
	create_timer(110.0, true, false, true).timeout.connect(func(): print("WATCHDOG"); quit(2))
	await wait_seconds(0.6)
	player = get_first_node_in_group("player")
	stats = player.get_node("StatsComponent"); rules = player.get_node("RuleHost"); events = player.get_node("KataEvents")
	kata = player.get_node("KataComponent")
	rman = get_first_node_in_group("run_manager"); rm = get_first_node_in_group("room_manager")
	var light := {"kind": "light", "hit_count": 1, "crit": false}

	print("-- pool")
	check(rman.relic_pool.size() == 29, "29 relics in the pool (%d)" % rman.relic_pool.size())
	var ids := {}
	var empty := 0
	for r in rman.relic_pool:
		ids[r.id] = true
		if r.effects.is_empty() and r.behavior == null: empty += 1
	check(ids.size() == 29, "unique ids")
	check(empty == 1 and ids.has("wanderer_map"), "only Wanderer's Map has no effect/behavior (the minimap reads it)")
	for gone in ["ronin_sandal", "dancer_ribbon"]:
		check(not ids.has(gone), "%s (rejected) is not in the pool" % gone)
	check(rman.relic_pool.all(func(r): return r.price > 120 or r.id == "gold_frog" or r.id == "wanderer_map" or r.price >= 120), "relics cost at least 120")

	print("-- stat relics")
	reset()
	relic("black_pearl")
	check(is_equal_approx(stats.get_stat("gold_gain"), 1.2) and is_equal_approx(stats.get_stat("shop_discount"), 0.2), "Black Pearl: +20%% gold, -20%% prices")
	reset(); relic("samurai_eye")
	check(is_equal_approx(stats.get_stat("perfect_slow_bonus"), 0.3), "Samurai Eye: +0.3 s slow")
	player.dash.is_dashing = true; player.dash.elapsed = 0.01
	player._on_hit_received(1.0, null)
	check(is_equal_approx(EnemyTime.time_left, 1.0), "...a Perfect Dodge slows 1.0 s (0.7 base + 0.3) (%.2f)" % EnemyTime.time_left)
	player.dash.is_dashing = false
	reset(); relic("hannya_mask")
	check(is_equal_approx(stats.get_stat("crit_damage"), 1.0) and is_equal_approx(stats.get_stat("max_health"), 90.0), "Hannya Mask: crit +1.0, -10%% HP")
	reset(); relic("mountain_heart")
	check(is_equal_approx(stats.get_stat("max_health"), 130.0) and is_equal_approx(stats.get_stat("move_speed"), 5.4), "Heart of the Mountain: +30 HP, -10%% speed")
	reset(); relic("duel_scroll"); relic("calligraphy_ink"); relic("merchant_seal")
	check(stats.get_stat("reward_cards") == 1.0 and is_equal_approx(stats.get_stat("master_chance"), 0.25), "Scroll of Duels and Calligrapher's Ink")
	check(stats.get_stat("shop_extra_item") == 1.0 and is_equal_approx(stats.get_stat("shop_technique_mult"), 2.0), "Merchant's Seal: +1 item, techniques x2")
	reset(); relic("fox_mask"); relic("oni_horn")
	check(stats.get_stat("free_hits_per_room") == 1.0 and is_equal_approx(stats.get_stat("attack_damage"), 12.5), "Fox Mask and Oni Horn still work")

	print("-- Ultimate")
	reset(); relic("spirit_lantern")
	var ult: Node = player.get_node("UltimateSkill"); ult.charge = 0.0; ult.is_active = false
	ult.add_charge(10.0)
	check(is_equal_approx(ult.charge, 12.5), "Spirit Lantern: charges 25%% faster (%.1f)" % ult.charge)
	ult.is_active = true; ult.duration_bonus = 0.0
	events.kill.emit({"target": null})
	check(is_equal_approx(ult.duration_bonus, 0.5), "...kills during it extend it by 0.5 s")
	ult.is_active = false

	print("-- marks, heals, Finisher relics")
	reset(); relic("kurotsuki_eye")
	var d1: Node = dummy_at(Vector3(10, 0, 8)); var d2: Node = dummy_at(Vector3(12, 0, 8)); var d3: Node = dummy_at(Vector3(-10, 0, 8))
	events.kill.emit({"target": d1})
	check(d2.status.mark_left > 5.0 and is_equal_approx(d2.status.damage_taken_factor(), 1.25) and d3.status.mark_left <= 0.0, "Kurotsuki Eye: the nearest enemy is marked 6 s (+25%%)")
	events.kill.emit({"target": d2})
	check(d2.status.mark_left <= 0.0 and (d1.status.mark_left > 5.0 or d3.status.mark_left > 5.0), "...the next kill moves the mark to another enemy")
	reset(); relic("sakura_charm")
	player.health.set_current(50.0)
	events.kill.emit({"kind": "heavy", "target": d1})
	check(player.health.current_health == 50.0, "Sakura Charm: a heavy kill outside a Finisher heals nothing")
	kata.finisher_performed.emit({})
	events.kill.emit({"kind": "heavy", "target": d1, "damage": 40.0})
	check(is_equal_approx(player.health.current_health, 56.0), "Sakura Charm: a Finisher kill heals 15%% of its damage (40 -> 6)")
	reset(); relic("jade_bead")
	player.health.set_current(40.0); rman.level_up.emit(2)
	check(is_equal_approx(player.health.current_health, 70.0), "Jade Bead: +30%% HP on a level up")
	reset(); relic("gold_frog")
	player.health.set_current(40.0); rman.collect_gold(10)
	check(is_equal_approx(player.health.current_health, 41.0), "Gold Frog: +1 HP per coin pickup")
	reset(); relic("soul_syphon")
	player.health.set_current(40.0)
	d1.status.apply_bleed(20.0, 3.0)
	await wait_seconds(0.9)
	check(player.health.current_health > 40.0, "Soul Syphon: bleed ticks heal 50%% of their damage (%.0f)" % player.health.current_health)
	d1.status.bleeds.clear()
	reset(); relic("broken_hilt")
	var before: int = rm.current_room.get_children().filter(func(n): return n.get("kind") == "wave").size()
	kata.finisher_performed.emit({"damage_multiplier": 2.0})
	var waves: Array = rm.current_room.get_children().filter(func(n): return n.get("kind") == "wave")
	check(waves.size() == before + 1 and is_equal_approx(waves[-1].damage, (10.0 + 4.0) * 2.0 * 0.6), "Broken Katana Hilt: a wave leaves with the Finisher (%.1f)" % waves[-1].damage)

	print("-- Kata relics")
	reset(); relic("paper_lantern")
	kata.set_technique(load("res://resources/techniques/quick_draw.tres")); kata.set_technique(load("res://resources/techniques/crimson_rhythm.tres"))
	events.dodge.emit(); kata.flow_value = 0.6
	events.hit_dealt.emit(light)
	kata.add_flow(-0.3)
	check(kata.flow_value >= 0.6, "Paper Lantern: being hit right after a hit loses no Flow (%.2f)" % kata.flow_value)
	await wait_seconds(1.2)
	kata.flow_value = 0.6
	kata.add_flow(-0.3)
	check(is_equal_approx(kata.flow_value, 0.3), "...after 1 s Flow is lost normally")
	reset(); relic("moon_shard")
	kata.set_technique(load("res://resources/techniques/quick_draw.tres")); kata.set_technique(load("res://resources/techniques/crimson_rhythm.tres"))
	events.dodge.emit()
	check(kata.is_open and kata.flow_value >= 0.5, "Moon Shard: the Kata opens with at least 50%% Flow (%.2f)" % kata.flow_value)
	reset(); relic("whetstone")
	check(is_equal_approx(rules.damage_multiplier("light", d1.health), 1.0), "Whetstone: nothing while the Kata is closed")
	kata.is_awake = true; kata.is_open = true
	check(is_equal_approx(rules.damage_multiplier("light", d1.health), 1.15), "Whetstone: +15%% while it is open")
	kata.is_open = false
	reset(); relic("shrine_bell")
	kata.set_technique(load("res://resources/techniques/quick_draw.tres"))
	rules._each("on_room_entered", [RoomData.RoomType.COMBAT])
	check(not kata.is_open, "Shrine Bell: not in a normal room")
	rules._each("on_room_entered", [RoomData.RoomType.MINIBOSS])
	check(kata.is_open, "Shrine Bell: the Kata opens in a mini-boss room")

	print("-- Perfect Dodge relics")
	reset(); relic("tengu_fan")
	var near: Node = dummy_at(player.global_position + Vector3(2, 0, 0)); var far: Node = dummy_at(player.global_position + Vector3(9, 0, 0))
	events.perfect_dodge.emit(null)
	check(near.knock_velocity.length() > 10.0 and near.knock_velocity.x > 0.0 and far.knock_velocity.length() == 0.0, "Tengu Fan: the near enemy is pushed away, the far one is not")
	reset(); relic("vanish")
	check(not player.is_hidden(), "not hidden at first")
	events.perfect_dodge.emit(null)
	check(player.is_hidden() and is_equal_approx(rules.hidden_left, 0.8), "Vanish: hidden 0.8 s after a Perfect Dodge")
	var bandit: Node3D = load("res://scenes/enemies/Bandit.tscn").instantiate()
	bandit.position = player.global_position + Vector3(1.0, 0, 0)
	rm.current_room.enemies_root.add_child(bandit)
	await wait_seconds(0.2)
	check(bandit.state != bandit.State.WINDUP and not bandit.can_see_player(), "a hidden player is not attacked by a bandit right next to him (state %d)" % bandit.state)
	await wait_seconds(0.8)
	check(not player.is_hidden() and bandit.can_see_player(), "...and he is visible again after 0.8 s")
	bandit.queue_free()
	reset(); relic("kitsune_tail")
	events.perfect_dodge.emit(null)
	check(is_equal_approx(stats.get_stat("move_speed"), 7.8) and player.is_hidden(), "Kitsune Tail: +30%% speed and hidden")
	reset(); relic("iron_fan")
	var proj_scene: PackedScene = load("res://scenes/enemies/Arrow.tscn")
	var arrow_front = proj_scene.instantiate(); var arrow_back = proj_scene.instantiate()
	rm.current_room.add_child(arrow_front); rm.current_room.add_child(arrow_back)
	var aim_dir: Vector3 = player.aim.aim_direction
	arrow_front.global_position = player.global_position + aim_dir * 3.0
	arrow_back.global_position = player.global_position - aim_dir * 3.0
	events.heavy_attack.emit()
	check(not is_instance_valid(arrow_front) or arrow_front.is_queued_for_deletion(), "Iron Fan: the arrow in front is destroyed")
	check(is_instance_valid(arrow_back) and not arrow_back.is_queued_for_deletion(), "...the one behind is not")
	arrow_back.queue_free()

	print("-- zones")
	reset(); relic("crow_feather")
	player.dash.is_dashing = true; player.dash.time_left = 5.0
	await wait_seconds(0.3)
	player.dash.is_dashing = false; player.dash.time_left = 0.0
	check(zones().size() >= 3, "Crow Feather: the dash leaves a trail (%d zones)" % zones().size())
	var target: Node = dummy_at(zones()[0].global_position + Vector3(0.3, 0, 0))
	await wait_seconds(0.8)
	check(target.status.is_bleeding() and target.status.bleeds.size() == 1, "...an enemy standing in it bleeds with a single stack")
	reset(); relic("onibi_flame")
	for i in 60:
		events.kill.emit({"target": d1})
	var flames: int = zones().size()
	check(flames > 3 and flames < 25, "Onibi Flame: ~20%% of 60 kills left a flame (%d)" % flames)
	for z in zones(): z.queue_free()

	print("-- Wanderer's Map and Merchant's Seal")
	reset()
	var minimap: Node = get_first_node_in_group("hud").minimap
	check(not minimap._knows_room_types(), "no Wanderer's Map: the neighbours are '?'")
	relic("wanderer_map")
	check(minimap._knows_room_types(), "Wanderer's Map: the minimap knows the room types")

	print("-- Shop")
	var shop: Node3D = load("res://scenes/rooms/Room_Shop_01.tscn").instantiate()
	root.add_child(shop)
	await wait_seconds(0.2)
	reset()
	var count_visible = func(): return shop.stands_root.get_children().filter(func(s): return s.visible).size()
	shop._stock_stands()
	check(count_visible.call() == 3, "a Shop has 3 stands")
	relic("merchant_seal")
	shop._stock_stands()
	check(count_visible.call() == 4, "Merchant's Seal: a 4th stand")
	reset()
	var with_relic := 0
	var relic_stand: Node = null
	var found_stand: Node = null
	for i in 150:
		shop._stock_stands()
		for st in shop.stands_root.get_children():
			if st.visible and st.upgrade is RelicData:
				with_relic += 1; found_stand = st
		if found_stand != null and relic_stand == null:
			relic_stand = found_stand
	check(with_relic > 10 and with_relic < 60, "relics are rare in the Shop: %d of 150" % with_relic)
	while relic_stand == null or not (relic_stand.upgrade is RelicData):
		shop._stock_stands()
		for st in shop.stands_root.get_children():
			if st.visible and st.upgrade is RelicData: relic_stand = st
	check(relic_stand.price >= 120, "a relic costs %d" % relic_stand.price)
	rman.gold = 1000
	var gold0: int = rman.gold
	var rid: String = relic_stand.upgrade.id
	relic_stand.player_near = true
	relic_stand._try_buy()
	check(rman.has_relic(rid) and rman.gold == gold0 - relic_stand.price, "buying a relic adds it and spends the gold")
	var offered_owned := false
	for i in 100:
		shop._stock_stands()
		for st in shop.stands_root.get_children():
			if st.visible and st.upgrade is RelicData and st.upgrade.id == rid: offered_owned = true
	check(not offered_owned, "an owned relic is not offered again")

	print("-- Treasure")
	var offered: Array = rman.get_random_relics(3)
	check(offered.size() == 3 and offered.all(func(r): return not rman.has_relic(r.id)), "Treasure offers 3 relics that you do not own")

	print("-- rewards of Duel and Arena")
	reset(); relic("duel_scroll")
	var tm: Node = get_first_node_in_group("technique_manager")
	for id in ["quick_draw", "crimson_rhythm", "moon_sever"]:
		kata.set_technique(load("res://resources/techniques/%s.tres" % id))
	check(tm.get_choices([], 3 + int(stats.get_stat("reward_cards"))).size() == 4, "Scroll of Duels: 4 cards (chain complete)")

	print("-- Daruma Doll")
	reset(); relic("daruma_doll")
	check(rules.process_incoming(1000.0, null) == 0.0 and player.health.current_health == 1.0, "Daruma Doll: survives with 1 HP")
	player.health.set_current(50.0)
	check(rules.process_incoming(1000.0, null) == 1000.0, "...only once in a biome")
	rm.biome_started.emit(1)
	check(rules.process_incoming(1000.0, null) == 0.0, "...and again in the next biome")

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
