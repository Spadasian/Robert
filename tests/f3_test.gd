extends SceneTree

var failures: Array[String] = []
var player: CharacterBody3D
var stats: Node
var rules: Node
var events: Node
var kata: Node
var rm: Node
var heavy: Node
var pool: Array = []

func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func T(id: String) -> Resource:
	return load("res://resources/techniques/%s.tres" % id)

func skill(name: String) -> Node:
	for s in player.skills:
		if s.display_name == name: return s
	return null

func fresh() -> void:
	kata.close("test"); kata.slots.clear(); kata.behaviors.clear(); kata.is_awake = false
	stats.modifiers.clear(); stats._recalculate()
	EnemyTime.reset()
	player.health.set_current(player.health.max_health)
	for n in rm.current_room.get_children():
		if n is HazardZone or n.name.begins_with("Wave"): n.queue_free()

## quick_draw opens on a dash; `others` are put in their slots
func open_with(others: Array) -> void:
	fresh()
	kata.set_technique(T("quick_draw"))
	for id in others: kata.set_technique(T(id))
	events.dodge.emit()
	kata.set_flow(0.0)

func dummy_at(offset: Vector3, hp: float = 1000.0) -> Node:
	var d: Node3D = load("res://scenes/enemies/TrainingDummy.tscn").instantiate()
	d.position = player.global_position + offset
	rm.current_room.enemies_root.add_child(d)
	d.health.set_max_health(hp)
	return d

func kill_dummies() -> void:
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	await wait_seconds(0.1)

func zones() -> Array:
	return rm.current_room.get_children().filter(func(n): return n is HazardZone)

func waves() -> Array:
	return rm.current_room.get_children().filter(func(n): return n.name.begins_with("Wave"))

func fire_heavy() -> void:
	heavy.cooldown_left = 0.0
	Input.action_press("heavy")
	await wait_seconds(0.08)
	Input.action_release("heavy")

func open_for_heavy(finisher: String, flow: float = 1.0) -> void:
	open_with(["crimson_rhythm", finisher])
	kata.set_flow(flow)

func _initialize() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.run_mode = gm.QUICK_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func _run() -> void:
	create_timer(170.0, true, false, true).timeout.connect(func(): print("WATCHDOG"); quit(2))
	await wait_seconds(0.6)
	player = get_first_node_in_group("player")
	stats = player.get_node("StatsComponent"); rules = player.get_node("RuleHost"); events = player.get_node("KataEvents")
	kata = player.get_node("KataComponent"); rm = get_first_node_in_group("room_manager")
	heavy = skill("Heavy")
	var tm: Node = get_first_node_in_group("technique_manager")
	var light := {"kind": "light", "hit_count": 1, "crit": false}
	var dir: Vector3 = player.aim.aim_direction
	heavy.direction = dir

	print("-- pool")
	pool = tm.technique_pool
	var counts := [0, 0, 0, 0]
	var ids := {}
	for t in pool:
		counts[t.category] += 1
		ids[t.id] = true
	check(pool.size() == 38 and ids.size() == 38, "38 unique techniques (%d)" % pool.size())
	check(counts == [9, 8, 11, 10], "9 openings, 8 flows, 11 finishers, 10 masters %s" % str(counts))
	check(not ids.has("many_faces"), "Many Faces is gone")
	check(pool.all(func(t): return t.behavior != null and t.description != "" and t.display_name != ""), "every technique has a script, a name and a description")

	print("-- openings")
	var opening_cases := [
		["wounded_resolve", func(): events.damage_taken.emit(5.0), 0.4 - 0.25],
		["crescent_entry", func(): events.skill_resolved.emit(skill("Iaijutsu")), 0.35],
		["shadow_vault", func(): events.skill_resolved.emit(skill("Kaeshi")), 0.35],
		["hunters_mark", func(): events.kill.emit({"kind": "light", "hit_count": 1}), 0.3],
		["critical_spark", func(): events.critical_hit.emit({"kind": "light", "hit_count": 1, "crit": true}), 0.3],
		["thousand_cuts", func(): events.hit_dealt.emit({"kind": "heavy", "hit_count": 1, "was_full": true}), 0.25],
	]
	for case in opening_cases:
		fresh(); kata.set_technique(T(case[0])); kata.set_technique(T("perfect_tempo"))
		check(not kata.is_open, "%s: closed at the start" % case[0])
		case[1].call()
		check(kata.is_open and is_equal_approx(kata.flow_value, case[2]), "%s opens the Kata with %.2f Flow (%.2f)" % [case[0], case[2], kata.flow_value])
	fresh(); kata.set_technique(T("crescent_entry")); kata.set_technique(T("perfect_tempo"))
	events.skill_resolved.emit(skill("Kaeshi")); events.skill_resolved.emit(skill("Heavy")); events.kill.emit({"kind": "light"})
	check(not kata.is_open, "Crescent Entry opens only with Iaijutsu")
	fresh(); kata.set_technique(T("thousand_cuts")); kata.set_technique(T("perfect_tempo"))
	events.hit_dealt.emit({"kind": "light", "hit_count": 1, "was_full": false})
	check(not kata.is_open, "Thousand Cuts: a hurt enemy does not open it")
	var d1: Node = dummy_at(dir * 4.0)
	fresh(); kata.set_technique(T("hunters_mark")); kata.set_technique(T("perfect_tempo"))
	events.kill.emit({"kind": "light"})
	check(d1.status.mark_left > 0.0 and d1.status.mark_bonus > 0.0, "Hunter's Mark marks the nearest enemy")
	await kill_dummies()

	var home: Vector3 = player.global_position
	print("-- skill openings need the skill to really happen")
	var kaeshi: Node = skill("Kaeshi")
	var iai: Node = skill("Iaijutsu")
	fresh(); kata.set_technique(T("shadow_vault")); kata.set_technique(T("perfect_tempo"))
	kaeshi.cooldown_left = 0.0
	Input.action_press("kaeshi") if InputMap.has_action("kaeshi") else kaeshi.try_activate()
	await wait_seconds(0.1)
	if InputMap.has_action("kaeshi"): Input.action_release("kaeshi")
	check(kaeshi.is_active and not kata.is_open, "pressing Kaeshi does not open the Kata")
	await wait_seconds(0.4)
	check(not kata.is_open, "...waiting in the stance does not either")
	kaeshi.intercept_hit(5.0, null)
	check(kata.is_open and is_equal_approx(kata.flow_value, 0.35), "the Kaeshi counter opens it (%.2f)" % kata.flow_value)
	await wait_seconds(0.6)
	fresh(); kata.set_technique(T("shadow_vault")); kata.set_technique(T("perfect_tempo"))
	kaeshi.cooldown_left = 0.0
	kaeshi.try_activate()
	await wait_seconds(1.4) # the stance ends and nobody hit him
	check(not kata.is_open, "a Kaeshi nobody hit never opens it")
	fresh(); kata.set_technique(T("crescent_entry")); kata.set_technique(T("perfect_tempo"))
	iai.cooldown_left = 0.0
	iai.try_activate()
	check(not kata.is_open, "pressing Iaijutsu does not open the Kata")
	var waited := 0.0
	while not kata.is_open and waited < 1.5:
		await physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	check(kata.is_open and waited > 0.05, "the Iaijutsu cut opens it after the windup (%.2f s)" % waited)
	await wait_seconds(0.8)
	fresh(); kata.set_technique(T("quick_draw")); kata.set_technique(T("skill_weaver"))
	events.dodge.emit(); kata.set_flow(0.0)
	events.skill_used.emit(skill("Iaijutsu"))
	check(kata.flow_value == 0.0, "Skill Weaver: pressing a skill adds nothing")
	player.global_position = home; player.velocity = Vector3.ZERO
	await wait_seconds(0.3)

	print("-- flows")
	open_with(["crit_current"]); events.critical_hit.emit({"kind": "light", "hit_count": 1})
	check(is_equal_approx(kata.flow_value, 0.4), "Crit Current: crit +0.4")
	events.hit_dealt.emit(light); check(is_equal_approx(kata.flow_value, 0.45), "Crit Current: light hit +0.05")
	open_with(["dancing_blade"]); events.dodge.emit()
	check(is_equal_approx(kata.flow_value, 0.2), "Dancing Blade: dash +0.2")
	open_with(["perfect_tempo"]); events.perfect_dodge.emit(null)
	check(is_equal_approx(kata.flow_value, 0.5), "Perfect Tempo: Perfect Dodge +0.5")
	open_with(["skill_weaver"]); events.skill_resolved.emit(skill("Iaijutsu"))
	check(is_equal_approx(kata.flow_value, 0.3), "Skill Weaver: Iaijutsu +0.3")
	events.skill_resolved.emit(skill("Heavy")); check(is_equal_approx(kata.flow_value, 0.3), "Skill Weaver: the Heavy gives nothing")
	events.skill_resolved.emit(skill("Moonlit Storm")); check(is_equal_approx(kata.flow_value, 0.6), "Skill Weaver: Moonlit Storm +0.3")
	open_with(["backstab_rhythm"]); events.hit_dealt.emit({"kind": "light", "hit_count": 1, "from_behind": true})
	check(is_equal_approx(kata.flow_value, 0.35), "Backstab Rhythm: light 0.05 + back 0.3")
	open_with(["backstab_rhythm"]); events.hit_dealt.emit({"kind": "light", "hit_count": 1, "from_behind": false})
	check(is_equal_approx(kata.flow_value, 0.05), "Backstab Rhythm: front hit only 0.05")
	open_with(["perfect_tempo"]); kata.set_flow(0.6); events.damage_taken.emit(3.0)
	check(is_equal_approx(kata.flow_value, 0.35), "Flows lose 0.25 when hit")
	open_with(["still_water"])
	await wait_seconds(1.0)
	check(kata.flow_value > 0.15 and kata.flow_value < 0.3, "Still Water: ~0.2 Flow per second (%.2f)" % kata.flow_value)
	check(kata.idle_time > 0.9, "Still Water does not keep the Kata alive by itself (idle %.2f)" % kata.idle_time)
	kata.set_flow(0.8); events.damage_taken.emit(3.0)
	check(is_equal_approx(kata.flow_value, 0.4), "Still Water: damage halves the Flow")
	var speed0: float = 0.0
	open_with(["untouched_edge"])
	speed0 = stats.get_stat("attack_speed")
	fresh(); kata.set_technique(T("quick_draw")); kata.set_technique(T("untouched_edge"))
	var base_speed: float = stats.get_stat("attack_speed")
	events.dodge.emit()
	check(is_equal_approx(stats.get_stat("attack_speed"), base_speed * 1.25), "Untouched Edge: +25%% attack speed while open (%.2f -> %.2f)" % [base_speed, stats.get_stat("attack_speed")])
	events.hit_dealt.emit(light)
	check(is_equal_approx(kata.flow_value, 0.4 + 0.25) or kata.flow_value > 0.3, "Untouched Edge still gives Flow per hit (%.2f)" % kata.flow_value)
	events.damage_taken.emit(4.0)
	check(is_equal_approx(stats.get_stat("attack_speed"), base_speed) and kata.flow_value == 0.0, "a hit taken removes the speed and wipes the Flow")
	kata.close("test"); events.dodge.emit(); kata.close("test")
	check(is_equal_approx(stats.get_stat("attack_speed"), base_speed), "closing the Kata removes the speed bonus (no stacking)")

	print("-- finishers: context")
	open_for_heavy("blood_harvest", 0.5)
	var ctx: Dictionary = kata.begin_finisher(heavy)
	check(is_equal_approx(ctx.damage_multiplier, 1.0 + 0.6 * 0.5), "flow-scaled damage multiplier (%.2f)" % ctx.damage_multiplier)
	player.health.set_current(50.0)
	for cb in ctx.on_hit: cb.call({"target": null, "damage": 30.0})
	check(is_equal_approx(player.health.current_health, 53.0), "Blood Harvest: 10%% of the damage dealt to each enemy (30 -> 3 HP)")
	var a1: Node = dummy_at(dir * 2.0); var a2: Node = dummy_at(dir * 2.5 + Vector3(1.0, 0.0, 0.0)); var a3: Node = dummy_at(-dir * 2.0)
	open_for_heavy("spirit_cleave", 0.0)
	ctx = kata.begin_finisher(heavy)
	check(ctx.get("enemies_in_arc", -1) == 2 and is_equal_approx(ctx.damage_multiplier, 1.4), "Spirit Cleave: 2 in the arc, 1 behind -> x1.4 (%s, %.2f)" % [str(ctx.get("enemies_in_arc")), ctx.damage_multiplier])
	open_for_heavy("shatter", 0.0)
	ctx = kata.begin_finisher(heavy)
	for cb in ctx.on_hit: cb.call({"target": a1})
	check(a1.status.stun_left > 1.4 and a1.status.mark_bonus >= 0.25, "Shatter: stun 1.5 s and mark +25%")
	open_for_heavy("crimson_rain", 0.0); ctx = kata.begin_finisher(heavy)
	check(zones().size() == 1 and zones()[0].bleed_per_second > 0.0, "Crimson Rain: a bleed zone")
	fresh(); await kill_dummies()
	var a4: Node = dummy_at(dir * 3.0)
	open_for_heavy("tremor", 0.0); ctx = kata.begin_finisher(heavy)
	check(zones().size() == 1 and zones()[0].damage_per_second > 0.0, "Tremor: a damage zone")
	var hp_before: float = a4.health.current_health
	await wait_seconds(1.0)
	check(a4.health.current_health < hp_before, "Tremor zone hurts the enemy standing in it")
	open_for_heavy("storm_step", 0.0); ctx = kata.begin_finisher(heavy)
	check(ctx.get("invulnerable", false), "Storm Step: the context asks for invulnerability")
	open_for_heavy("gale_slash", 0.0); ctx = kata.begin_finisher(heavy)
	check(waves().size() == 1, "Gale Slash: a wave is fired")
	fresh(); await kill_dummies()

	print("-- finishers: real Heavy on dummies")
	var far: Node = dummy_at(dir * 9.0)
	var near: Node = dummy_at(dir * 2.2)
	open_for_heavy("gale_slash", 1.0)
	await fire_heavy()
	await wait_seconds(1.3)
	check(near.health.current_health < 1000.0, "Gale Slash: the arc hits the near dummy")
	check(far.health.current_health < 1000.0, "Gale Slash: the wave reaches the dummy 9 m away")
	await kill_dummies()
	far = dummy_at(dir * 6.0); near = dummy_at(dir * 2.2)
	open_for_heavy("twin_fang", 1.0)
	await fire_heavy()
	await wait_seconds(1.3)
	check(near.health.current_health < 1000.0 and far.health.current_health < 1000.0, "Twin Fang: arc on the near dummy, thrust on the far one")
	await kill_dummies()
	near = dummy_at(dir * 2.2)
	open_for_heavy("shatter", 1.0)
	await fire_heavy()
	await wait_seconds(0.6)
	check(near.status.stun_left > 0.0 or near.status.mark_left > 0.0, "Shatter (real): the hit enemy is stunned/marked")
	await wait_seconds(0.6)
	await kill_dummies()
	near = dummy_at(dir * 2.2)
	player.health.set_current(40.0)
	open_for_heavy("blood_harvest", 1.0)
	player.health.set_current(40.0)
	await fire_heavy()
	await wait_seconds(0.7)
	check(player.health.current_health >= 41.0, "Blood Harvest (real): healed by the hit (%.1f)" % player.health.current_health)
	await wait_seconds(0.6)
	await kill_dummies()
	near = dummy_at(dir * 2.2)
	open_for_heavy("storm_step", 1.0)
	await fire_heavy()
	await wait_seconds(0.4)
	var hp_inv: float = player.health.current_health
	check(heavy.is_invulnerable(), "Storm Step (real): invulnerable during the strike")
	player._on_hit_received(5.0, null)
	check(player.health.current_health == hp_inv, "Storm Step (real): a hit does nothing")
	await wait_seconds(1.0)
	check(not heavy.is_invulnerable(), "Storm Step: ends with the recovery")
	player._on_hit_received(5.0, null)
	check(player.health.current_health < hp_inv, "after the Heavy a hit hurts again")
	await kill_dummies()
	near = dummy_at(dir * 2.2)
	open_for_heavy("spirit_cleave", 1.0)
	await fire_heavy()
	await wait_seconds(0.7)
	check(near.health.current_health < 1000.0, "Spirit Cleave (real): hits")
	await wait_seconds(0.6)
	await kill_dummies()

	print("-- masters")
	open_with(["moon_sever", "echo_opening"]); kata.set_flow(1.0)
	ctx = kata.begin_finisher(heavy)
	check(kata.is_open and is_equal_approx(kata.flow_value, 0.3), "Echo Opening: the Kata reopens with 30%% Flow (open=%s, %.2f)" % [str(kata.is_open), kata.flow_value])
	fresh(); kata.set_technique(T("quick_draw")); kata.set_technique(T("crimson_rhythm"))
	check(kata.get_technique(kata.EXTRA_OPENING) == null, "no extra Opening slot without the Master")
	kata.set_technique(T("double_opening"))
	check(kata.has_extra_slot(0) and not kata.has_extra_slot(1), "Double Opening opens an extra OPENING slot only")
	kata.set_technique(T("ghost_step"))
	check(kata.get_technique(0) == T("quick_draw") and kata.get_technique(kata.EXTRA_OPENING) == T("ghost_step"), "the new Opening goes to the extra slot")
	check(kata.get_replaced(T("thousand_cuts")) == T("quick_draw"), "a third Opening would replace the main one")
	check(kata.has_technique("ghost_step") and kata.has_technique("quick_draw"), "has_technique sees both Openings")
	events.hit_dealt.emit({"kind": "light", "hit_count": 1, "from_behind": true})
	check(kata.is_open and is_equal_approx(kata.flow_value, 0.3 + 0.22), "the second Opening opens the Kata, only it gives start Flow (%.2f)" % kata.flow_value)
	kata.close("test"); events.dodge.emit()
	check(kata.is_open and is_equal_approx(kata.flow_value, 0.25), "the main Opening works too (%.2f)" % kata.flow_value)
	kata.set_technique(T("perfect_draw"))
	check(not kata.has_extra_slot(0) and kata.get_technique(kata.EXTRA_OPENING) == null, "another Master closes the extra slot")
	fresh(); kata.set_technique(T("quick_draw")); kata.set_technique(T("crimson_rhythm")); kata.set_technique(T("dual_flow"))
	check(kata.has_extra_slot(1), "Dual Flow opens an extra FLOW slot")
	check(kata.get_replaced(T("dancing_blade")) == null, "a new Flow goes to the free extra slot (replaces nothing)")
	kata.set_technique(T("dancing_blade"))
	check(kata.get_technique(kata.EXTRA_FLOW) == T("dancing_blade") and kata.get_technique(1) == T("crimson_rhythm"), "the second Flow goes to the extra slot")
	events.dodge.emit(); kata.set_flow(0.0)
	events.dodge.emit()
	check(is_equal_approx(kata.flow_value, 0.2), "both Flows work (dash +0.2 from Dancing Blade) (%.2f)" % kata.flow_value)
	events.hit_dealt.emit(light)
	check(is_equal_approx(kata.flow_value, 0.2 + 0.22 + 0.05), "light hit feeds both Flows (%.2f)" % kata.flow_value)
	check(kata.get_replaced(T("untouched_edge")) == T("crimson_rhythm"), "both Flow slots full: the main one is replaced")
	fresh(); kata.set_technique(T("perfect_silence"))
	events.perfect_dodge.emit(null)
	check(EnemyTime.get_scale() == 0.0 and EnemyTime.time_left >= 0.99, "Perfect Silence: enemies frozen 1 s, even with the Kata closed")
	EnemyTime.reset()
	fresh(); kata.set_technique(T("blood_oath"))
	for i in 10: events.kill.emit({"kind": "light"})
	check(is_equal_approx(kata.behaviors[3].finisher_multiplier(kata), 1.1), "Blood Oath: 10 kills = +10%")
	for i in 200: events.kill.emit({"kind": "light"})
	check(is_equal_approx(kata.behaviors[3].finisher_multiplier(kata), 2.0), "Blood Oath: capped at +100%")
	kata.behaviors[3].on_room(kata)
	check(is_equal_approx(kata.behaviors[3].finisher_multiplier(kata), 1.0), "Blood Oath resets in a new room")
	fresh(); kata.set_technique(T("phantom_cut"))
	for i in 3: events.hit_dealt.emit(light)
	await wait_seconds(0.6)
	check(waves().is_empty(), "Phantom Cut: nothing after 3 hits")
	events.hit_dealt.emit(light)
	var seen_at: float = -1.0
	var elapsed: float = 0.0
	while elapsed < 1.0 and seen_at < 0.0:
		await physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
		if not waves().is_empty(): seen_at = elapsed
	check(seen_at > 0.4 and seen_at < 0.65, "Phantom Cut: the 4th hit leaves a phantom slash after ~0.5 s (seen at %.2f)" % seen_at)
	open_with(["eternal_flow"]); kata.set_technique(T("crimson_rhythm")); kata.set_flow(1.0)
	await wait_seconds(3.6)
	check(kata.is_open, "Eternal Flow: still open after the normal timeout")
	check(kata.flow_value < 0.9 and kata.flow_value > 0.7, "Eternal Flow: Flow drains slowly (%.2f)" % kata.flow_value)
	open_with(["moon_sever", "moonlit_execution"]); kata.set_flow(1.0)
	ctx = kata.begin_finisher(heavy)
	check(ctx.get("force_crit", false), "Moonlit Execution: full Flow = guaranteed crit")
	open_with(["moon_sever", "moonlit_execution"]); kata.set_flow(0.6)
	ctx = kata.begin_finisher(heavy)
	check(not ctx.get("force_crit", false), "Moonlit Execution: not at 60%% Flow")

	print("-- offers still follow the chain")
	fresh()
	check(tm.next_chain_category() == 0, "empty Kata: first offer is Openings")
	var choices: Array = tm.get_choices([], 3)
	check(choices.size() == 3 and choices.all(func(t): return t.category == 0), "3 Openings")
	kata.set_technique(T("quick_draw")); kata.set_technique(T("crimson_rhythm")); kata.set_technique(T("moon_sever"))
	choices = tm.get_choices([], 3, true)
	check(choices.size() == 3 and choices.any(func(t): return t.category == 3), "chain complete + add_master: one card is a Master")
	check(choices.all(func(t): return not kata.has_technique(t.id)), "owned techniques are not offered")

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
