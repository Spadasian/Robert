extends SceneTree

var failures: Array[String] = []
var player: CharacterBody3D
var kata: Node
var events: Node

func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func T(id: String) -> Resource:
	return load("res://resources/techniques/%s.tres" % id)

func place(dummies: Array, front: float, behind: float, far: float) -> void:
	var dir: Vector3 = player.aim.aim_direction
	var spots := [dir * front, -dir * behind, dir * far]
	for i in 3:
		if is_instance_valid(dummies[i]): dummies[i].global_position = player.global_position + spots[i]
	for d in dummies:
		if is_instance_valid(d): d.velocity = Vector3.ZERO
	await wait_seconds(0.25)

func open_with(flow_id: String, finisher_id: String = "") -> void:
	kata.set_technique(T("quick_draw")); kata.set_technique(T(flow_id))
	if finisher_id != "": kata.set_technique(T(finisher_id))
	events.dodge.emit()
	kata.flow_value = 0.0

func clear_signal_and_pick_upgrade() -> void:
	var rm: Node = get_first_node_in_group("room_manager")
	rm.room_cleared.emit()
	await wait_seconds(0.9)
	var uc: Node = root.find_child("UpgradeChoice", true, false)
	if uc.visible:
		uc.upgrade_chosen.emit(uc.current_choices[0])
	await wait_seconds(1.3)

func fresh() -> void:
	kata.close("test")
	kata.slots.clear()
	kata.is_awake = false
	kata.behaviors.clear()

func _initialize() -> void:
	root.get_node("GameManager").run_mode = root.get_node("GameManager").QUICK_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func _run() -> void:
	create_timer(80.0, true, false, true).timeout.connect(func(): print("WATCHDOG: test stuck"); quit(2))
	await wait_seconds(0.5)
	player = get_first_node_in_group("player")
	kata = player.get_node("KataComponent")
	events = player.get_node("KataEvents")
	var tm: Node = get_first_node_in_group("technique_manager")
	var rm: Node = get_first_node_in_group("room_manager")
	var C = TechniqueData.Category
	var light := {"kind": "light", "hit_count": 1}

	print("-- pool")
	check(tm.technique_pool.size() == 38, "38 techniques in the pool")
	var by_cat := [0, 0, 0, 0]
	for d in tm.technique_pool: by_cat[d.category] += 1
	check(by_cat == [9, 8, 11, 10], "9 openings, 8 flows, 11 finishers, 10 masters %s" % str(by_cat))

	print("-- the chain: an empty slot does nothing")
	fresh(); kata.set_technique(T("crimson_rhythm"))
	events.hit_dealt.emit(light); events.dodge.emit(); events.perfect_dodge.emit(null)
	check(not kata.is_open, "Flow only: nothing opens the Kata")
	check(not kata.begin_finisher(null).was_open, "Flow only: heavy is plain")
	fresh(); kata.set_technique(T("quick_draw"))
	events.dodge.emit()
	check(kata.is_open and kata.flow_value == 0.0, "Opening only: opens, but no Flow (start flow ignored)")
	events.hit_dealt.emit(light)
	check(kata.flow_value == 0.0, "Opening only: light hits add no Flow")
	var plain: Dictionary = kata.begin_finisher(null)
	check(plain.damage_multiplier == 1.0 and not plain.was_open and kata.is_open, "Opening only: heavy plain and the Kata keeps running")
	fresh(); kata.set_technique(T("quick_draw")); kata.set_technique(T("crimson_rhythm"))
	events.dodge.emit(); events.hit_dealt.emit(light); events.hit_dealt.emit(light)
	check(kata.flow_value > 0.7, "Opening+Flow: flow built (%.2f)" % kata.flow_value)
	plain = kata.begin_finisher(null)
	check(plain.damage_multiplier == 1.0 and not plain.was_open and kata.is_open, "Full Flow but no Finisher: heavy gets NO bonus")

	print("-- openings")
	fresh(); kata.set_technique(T("quick_draw")); kata.set_technique(T("crimson_rhythm"))
	events.hit_dealt.emit(light); check(not kata.is_open, "Quick Draw: light hit does not open")
	events.dodge.emit(); check(kata.is_open and is_equal_approx(kata.flow_value, 0.25), "Quick Draw: dodge opens, flow 0.25")
	fresh(); kata.set_technique(T("riposte_step")); kata.set_technique(T("crimson_rhythm"))
	events.dodge.emit(); check(not kata.is_open, "Riposte Step: plain dodge does not open")
	events.perfect_dodge.emit(null); check(kata.is_open and is_equal_approx(kata.flow_value, 0.6), "Riposte Step: perfect dodge opens, flow 0.6")
	fresh(); kata.set_technique(T("ghost_step")); kata.set_technique(T("crimson_rhythm"))
	events.hit_dealt.emit(light); check(not kata.is_open, "Ghost Step: front hit does not open")
	events.hit_dealt.emit({"kind": "light", "hit_count": 1, "from_behind": true}); check(kata.is_open and is_equal_approx(kata.flow_value, 0.52), "Ghost Step: back hit opens (0.3 + 0.22)")

	print("-- flows")
	fresh(); open_with("crimson_rhythm")
	events.hit_dealt.emit(light)
	check(is_equal_approx(kata.flow_value, 0.22), "Crimson Rhythm hit 1: 0.22 (%.2f)" % kata.flow_value)
	events.hit_dealt.emit(light)
	check(is_equal_approx(kata.flow_value, 0.22 + 0.29), "hit 2 worth more: %.2f" % kata.flow_value)
	events.damage_taken.emit(5.0)
	check(is_equal_approx(kata.flow_value, 0.21), "hit taken: -0.3 (%.2f)" % kata.flow_value)
	fresh(); open_with("untouched_edge")
	events.hit_dealt.emit(light); events.hit_dealt.emit(light)
	check(is_equal_approx(kata.flow_value, 0.8), "Untouched Edge: 0.4 per hit (%.2f)" % kata.flow_value)
	events.damage_taken.emit(5.0)
	check(kata.flow_value == 0.0 and kata.is_open, "first hit taken wipes the flow")

	print("-- finishers (context)")
	fresh(); open_with("untouched_edge", "moon_sever")
	events.hit_dealt.emit(light); events.hit_dealt.emit(light)   # flow 0.8
	var ctx: Dictionary = kata.begin_finisher(null)
	check(is_equal_approx(ctx.damage_multiplier, 1.8) and ctx.scale == 1.6 and ctx.was_open, "Moon Sever: x1.8 and scale 1.6")
	fresh(); open_with("untouched_edge", "crimson_execution")
	ctx = kata.begin_finisher(null)
	check(ctx.execute_below == 0.3, "Crimson Execution sets execute_below")
	fresh(); open_with("untouched_edge", "whirlwind")
	ctx = kata.begin_finisher(null)
	check(ctx.get("spin", false) and ctx.scale == 1.5, "Whirlwind sets spin")
	print("-- masters")
	fresh(); open_with("untouched_edge", "moon_sever"); kata.set_technique(T("perfect_draw"))
	ctx = kata.begin_finisher(null); check(not ctx.has("force_crit"), "Perfect Draw not armed: no crit")
	open_with("untouched_edge", "moon_sever"); events.perfect_dodge.emit(null)
	ctx = kata.begin_finisher(null); check(ctx.get("force_crit", false), "Perfect Draw armed by a Perfect Dodge")
	fresh(); kata.set_technique(T("quick_draw")); kata.set_technique(T("moon_sever")); kata.set_technique(T("perfect_draw"))
	events.perfect_dodge.emit(null)   # Kata closed: master still arms
	events.dodge.emit()
	ctx = kata.begin_finisher(null); check(ctx.get("force_crit", false), "Perfect Draw arms while the Kata is closed")
	fresh(); open_with("untouched_edge", "moon_sever"); kata.set_technique(T("shadow_doppelganger"))
	ctx = kata.begin_finisher(null); check(ctx.echo == 0.6, "Doppelganger sets echo")

	print("-- real heavy effects")
	fresh()
	var dummies: Array = []
	var dir: Vector3 = player.aim.aim_direction
	for i in 3:
		var d: Node3D = load("res://scenes/enemies/TrainingDummy.tscn").instantiate()
		d.position = player.global_position + Vector3(6.0 + i * 2.0, 0.0, 4.0) # not on top of the player (it would carry it like a platform)
		rm.current_room.enemies_root.add_child(d)
		dummies.append(d)
	await place(dummies, 1.5, 1.5, 7.0)
	for d in dummies: d.health.set_max_health(1000.0)
	await place(dummies, 1.5, 1.5, 7.0)
	var hp0: Array = dummies.map(func(d): return d.health.current_health)
	open_with("untouched_edge", "whirlwind"); events.hit_dealt.emit(light)
	Input.action_press("heavy"); await wait_seconds(0.1); Input.action_release("heavy")
	await wait_seconds(0.9)
	check(dummies[0].health.current_health < hp0[0] and dummies[1].health.current_health < hp0[1] and dummies[2].health.current_health == hp0[2], "Whirlwind hit the target in front AND the one behind")
	var heavy = player.get_node("HeavySkill")
	check(heavy.hitbox.scale == Vector3.ONE and heavy.shape_node.position == heavy.shape_base_position, "shape restored after the strike")
	await wait_seconds(0.2)
	fresh()
	await place(dummies, 1.5, 1.5, 4.8)
	hp0 = dummies.map(func(d): return d.health.current_health)
	open_with("untouched_edge", "moon_sever"); events.hit_dealt.emit(light)
	player.global_position = player.global_position  # same place
	Input.action_press("heavy"); await wait_seconds(0.1); Input.action_release("heavy")
	await wait_seconds(0.9)
	check(dummies[2].health.current_health < hp0[2], "Moon Sever reaches the far dummy")
	await wait_seconds(0.3)
	fresh()
	await place(dummies, 1.5, 1.5, 7.0)
	hp0 = dummies.map(func(d): return d.health.current_health)
	open_with("untouched_edge", "crimson_execution"); events.hit_dealt.emit(light)
	dummies[0].health.current_health = 100.0   # 10% of 1000
	Input.action_press("heavy"); await wait_seconds(0.1); Input.action_release("heavy")
	await wait_seconds(0.9)
	check(not is_instance_valid(dummies[0]) or dummies[0].health.is_dead(), "Crimson Execution killed the low-health dummy")
	await wait_seconds(0.3)
	fresh()
	var dm: Node3D = dummies[2]
	if is_instance_valid(dm):
		await place(dummies, 1.5, 1.5, 1.8)
		dm.health.set_max_health(5000.0)
		var before: float = dm.health.current_health
		open_with("untouched_edge", "moon_sever"); kata.set_technique(T("shadow_doppelganger")); events.hit_dealt.emit(light)
		Input.action_press("heavy"); await wait_seconds(0.1); Input.action_release("heavy")
		await wait_seconds(0.4)
		var first: float = before - dm.health.current_health
		await wait_seconds(0.9)
		var total: float = before - dm.health.current_health
		check(first > 0.0 and total > first * 1.3, "Doppelganger echo hit again (first %.1f total %.1f)" % [first, total])

	print("-- offer order: Opening, Flow, Finisher, then random")
	fresh()
	check(tm.next_chain_category() == C.OPENING, "empty Kata: next is Opening")
	var ch: Array = tm.get_choices([C.FINISHER], 3)
	check(ch.size() == 3 and ch.all(func(d): return d.category == C.OPENING), "1st offer: 3 Openings (whatever the source asked for)")
	kata.set_technique(T("quick_draw"))
	ch = tm.get_choices([C.OPENING], 3)
	check(ch.size() == 3 and ch.all(func(d): return d.category == C.FLOW), "2nd offer: 3 Flows")
	kata.set_technique(T("crimson_rhythm"))
	ch = tm.get_choices([C.OPENING], 3)
	check(ch.size() == 3 and ch.all(func(d): return d.category == C.FINISHER), "3rd offer: 3 Finishers")
	check(tm.get_choices([], 3, true).all(func(d): return d.category == C.FINISHER), "no Master card before the chain is complete")
	kata.set_technique(T("moon_sever"))
	check(tm.next_chain_category() == -1, "chain complete")
	var mixed := 0
	for i in 30:
		ch = tm.get_choices([], 3)
		var cats := {}
		for d in ch:
			cats[d.category] = true
			if kata.has_technique(d.id) or d.category == C.MASTER: mixed -= 1000
		if ch.size() == 3 and cats.size() == 3: mixed += 1
	check(mixed == 30, "after the chain: 3 cards of 3 different categories, nothing owned, no Master (%d/30)" % mixed)
	ch = tm.get_choices([], 3, true)
	check(ch.size() == 3 and ch.any(func(d): return d.category == C.MASTER), "add_master puts a Master card once the chain is complete")
	var shop_pick: Resource = tm.get_shop_technique()
	check(shop_pick != null and not kata.has_technique(shop_pick.id), "shop can sell anything not owned after the chain")
	fresh()
	check(tm.get_shop_technique().category == C.OPENING, "shop sells an Opening first")

	print("-- offer flow")
	fresh()
	var picked: Array = []
	var task := func(): picked.append(await tm.offer([C.FINISHER]))
	task.call()
	await wait_seconds(0.2)
	check(tm.choice_ui.visible and paused, "choice UI open, game paused")
	check(tm.choice_ui.title_label.text == "Choose your OPENING", "title says what is chosen: %s" % tm.choice_ui.title_label.text)
	tm.choice_ui.technique_chosen.emit(tm.choice_ui.current_choices[0])
	await wait_seconds(0.2)
	check(picked[0] != null and picked[0].category == C.OPENING and kata.get_technique(C.OPENING) == picked[0] and not paused, "pick equips an Opening, game resumes")
	check(kata.is_awake, "offer awakened the Kata")
	task.call()
	await wait_seconds(0.2)
	check(tm.choice_ui.title_label.text == "Choose your FLOW", "second title: Flow")
	tm.choice_ui.technique_chosen.emit(null)
	await wait_seconds(0.2)
	check(picked[1] == null and tm.next_chain_category() == C.FLOW, "Keep: nothing changes, Flow is still next")
	task.call()
	await wait_seconds(0.2)
	tm.choice_ui.technique_chosen.emit(tm.choice_ui.current_choices[0])
	await wait_seconds(0.2)
	check(kata.get_technique(C.FLOW) != null, "Flow learned")
	rm.boss_defeated.emit(true)
	await wait_seconds(1.6)
	check(not tm.choice_ui.visible, "final boss: no technique offer")
	rm.boss_defeated.emit(false)
	await wait_seconds(1.6)
	check(tm.choice_ui.visible and tm.choice_ui.current_choices.all(func(d): return d.category == C.FINISHER), "non-final boss: this is the 3rd offer, 3 Finishers")
	check(tm.choice_ui.card_row.get_child_count() == 3, "3 cards")
	tm.choice_ui.technique_chosen.emit(tm.choice_ui.current_choices[0])
	await wait_seconds(0.2)
	check(tm.next_chain_category() == -1, "chain complete after 3 offers")
	rm.boss_defeated.emit(false)
	await wait_seconds(1.6)
	check(tm.choice_ui.visible and tm.choice_ui.title_label.text == "Choose a technique", "4th offer: random parts")
	var replaced_text := false
	for card in tm.choice_ui.card_row.get_children():
		replaced_text = replaced_text or true
	tm.choice_ui.technique_chosen.emit(null)
	await wait_seconds(0.3)

	print("-- ordinary rooms give no technique")
	fresh()
	var rd := RoomData.new()
	rm.current_room_data = rd
	for t in [RoomData.RoomType.COMBAT, RoomData.RoomType.ELITE]:
		rd.room_type = t
		await clear_signal_and_pick_upgrade()
		check(not tm.choice_ui.visible, "room type %d cleared: no technique offered" % t)

	print("-- shop")
	var rman: Node = get_first_node_in_group("run_manager")
	var shop: Node3D = load("res://scenes/rooms/Room_Shop_01.tscn").instantiate()
	root.add_child(shop)
	await wait_seconds(0.2)
	var with_tech := 0
	var tech_stand: Node = null
	for i in 100:
		shop._stock_stands()
		var n := 0
		for st in shop.stands_root.get_children():
			if st.upgrade is TechniqueData:
				n += 1; tech_stand = st
		check(n <= 1, "at most one technique per shop") if n > 1 else null
		with_tech += 1 if n == 1 else 0
	check(with_tech > 5 and with_tech < 40, "technique stand is rare: %d of 100 shops" % with_tech)
	var max_regular: int = 0
	for p in shop.stands_root.get_children()[0].PRICES: max_regular = maxi(max_regular, p)
	var guard := 0
	while tech_stand == null or not (tech_stand.upgrade is TechniqueData):
		shop._stock_stands(); guard += 1
		for st in shop.stands_root.get_children():
			if st.upgrade is TechniqueData and st.visible: tech_stand = st
		if guard > 300: break
	check(tech_stand != null and tech_stand.price > max_regular, "technique price %d > most expensive item %d" % [tech_stand.price, max_regular])
	fresh()
	rman.gold = 0
	var tid: String = tech_stand.upgrade.id
	tech_stand.player_near = true
	tech_stand._try_buy()
	check(not kata.has_technique(tid) and not tech_stand.sold, "not enough gold: nothing bought")
	rman.gold = 1000
	tech_stand._try_buy()
	check(kata.has_technique(tid) and kata.is_awake and tech_stand.sold and rman.gold == 1000 - tech_stand.price, "bought: equipped, Kata awake, gold spent")

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
