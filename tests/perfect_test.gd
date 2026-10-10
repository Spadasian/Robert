extends SceneTree

var failures: Array[String] = []
var player: CharacterBody3D
var rm: Node
var events: Node
var perfect: Array = []

func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func reset() -> void:
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	EnemyTime.reset()
	player.perfect_cooldown_left = 0.0; player.perfect_guard_left = 0.0
	player.dash.is_dashing = false; player.dash.charges = player.dash.max_charges; player.dash.since_start = 999.0
	player.health.set_current(player.health.max_health)
	perfect.clear()

func attack_once() -> void:
	_attack_box.set_active(true)
	_attack_box.set_deferred("monitoring", false) # only the announcement counts, no real overlap hit

var _attack_box: Node

func bandit_at(offset: Vector3) -> Node:
	var b: Node3D = load("res://scenes/enemies/Bandit.tscn").instantiate()
	b.position = player.global_position + offset
	rm.current_room.enemies_root.add_child(b)
	b.set_physics_process(false) # it only attacks when the test says so
	return b

func _initialize() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.run_mode = gm.QUICK_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func(): print("WATCHDOG"); quit(2))
	await wait_seconds(0.6)
	player = get_first_node_in_group("player")
	rm = get_first_node_in_group("room_manager")
	events = player.get_node("KataEvents")
	events.perfect_dodge.connect(func(_s): perfect.append(1))
	for e in get_nodes_in_group("enemy"): e.set_physics_process(false) # only the test attacks
	var hud: Node = get_first_node_in_group("hud")
	var world: Environment = root.find_child("WorldEnvironment", true, false).environment

	print("-- near miss: the dash was early enough, the player is already out of reach")
	reset()
	var b: Node = bandit_at(Vector3(1.4, 0, 0))
	_attack_box = b.attack_hitbox
	await wait_seconds(0.2)
	player.global_position = Vector3(0, 0, 0)
	b.global_position = player.global_position + Vector3(1.4, 0, 0)
	b.attack_hitbox.global_position = b.global_position
	player.dash.try_dash(Vector3(-1, 0, 0))
	await wait_seconds(0.1)
	var hp: float = player.health.current_health
	attack_once() # the attack starts 0.1 s after the dash began
	check(perfect.size() == 1, "attack starting 0.1 s after the dash = Perfect Dodge")
	check(is_equal_approx(EnemyTime.scale, 0.2) and EnemyTime.time_left > 0.6, "enemies slowed to 20%% for ~0.7 s (%.2f)" % EnemyTime.time_left)
	attack_once()
	check(perfect.size() == 1, "only one Perfect Dodge per attack")
	await wait_seconds(0.4)
	check(player.health.current_health == hp, "no damage")

	print("-- too early / too far / ignored cases")
	reset()
	player.dash.try_dash(Vector3(-1, 0, 0))
	await wait_seconds(0.2)
	b.attack_hitbox.global_position = player.dash.start_position + Vector3(1.4, 0, 0)
	attack_once()
	check(perfect.size() == 0, "an attack 0.2 s after the dash began is too late/early: no Perfect Dodge")
	reset()
	player.global_position = Vector3(0, 0, 0)
	player.dash.try_dash(Vector3(-1, 0, 0))
	await wait_seconds(0.5)
	attack_once()
	check(perfect.size() == 0, "a dash that began 0.5 s earlier is no Perfect Dodge")
	reset()
	player.dash.try_dash(Vector3(-1, 0, 0))
	await wait_seconds(0.1)
	b.attack_hitbox.global_position = player.dash.start_position + Vector3(9, 0, 0)
	attack_once()
	check(perfect.size() == 0, "an attack aimed far from where the dash began is not countable")
	reset()
	b.attack_hitbox.global_position = player.global_position + Vector3(1.4, 0, 0)
	attack_once()
	check(perfect.size() == 0, "no dash at all: no Perfect Dodge")

	print("-- the guard and the old path")
	reset()
	player.dash.try_dash(Vector3(-1, 0, 0))
	await wait_seconds(0.05)
	b.attack_hitbox.global_position = player.dash.start_position + Vector3(1.4, 0, 0)
	attack_once()
	await wait_seconds(0.15) # the dash is over now (0.2 s), the guard still on
	hp = player.health.current_health
	player._on_hit_received(10.0, null) # the dodged attack lands anyway a moment later: the guard cancels it
	check(player.health.current_health == hp, "short guard after a Perfect Dodge")
	await wait_seconds(0.3)
	player._on_hit_received(10.0, null)
	check(player.health.current_health < hp, "the guard ends")
	reset()
	player.dash.is_dashing = true; player.dash.elapsed = 0.11
	player._on_hit_received(5.0, null)
	check(perfect.size() == 1, "a hit landing 0.11 s into the dash (old path, window 0.12)")
	reset()
	player.dash.is_dashing = true; player.dash.elapsed = 0.16
	player._on_hit_received(5.0, null)
	check(perfect.size() == 0 and player.health.current_health == player.health.max_health, "0.16 s: still invulnerable, but no Perfect Dodge")
	player.dash.is_dashing = false

	print("-- window upgrade")
	reset()
	var effect := UpgradeEffect.new()
	effect.stat = "perfect_window"; effect.operation = UpgradeEffect.Operation.ADD; effect.value = 1.0
	player.stats.add_modifier(effect)
	player.dash.try_dash(Vector3(-1, 0, 0))
	await wait_seconds(0.2) # 0.2 s: out of the normal 0.13 s, inside the doubled one (0.26 s)
	b.attack_hitbox.global_position = player.dash.start_position + Vector3(1.4, 0, 0)
	attack_once()
	check(perfect.size() == 1, "perfect_window doubles the near-miss window")
	player.stats.remove_modifier(effect)

	print("-- feedback: tint, colours, enemy glow")
	reset()
	EnemyTime.slow(0.2, 0.7)
	await wait_seconds(0.3)
	check(hud.slow_tint != null and hud.slow_tint.color.a > 0.1, "HUD tint during the slow (%.2f)" % (hud.slow_tint.color.a if hud.slow_tint else -1.0))
	check(world.adjustment_enabled and world.adjustment_saturation < 0.8, "Forward+ colours drain (saturation %.2f)" % world.adjustment_saturation)
	check(b.slow_tinted and b.body_material.emission_enabled, "slowed enemies glow blue")
	await wait_seconds(1.0)
	check(not world.adjustment_enabled and is_equal_approx(world.adjustment_saturation, 1.0), "the colours are restored")
	check(hud.slow_tint.color.a < 0.01 and not b.slow_tinted and not b.body_material.emission_enabled, "tint and glow gone")

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
