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

func _initialize() -> void:
	root.get_node("GameManager").run_mode = root.get_node("GameManager").QUICK_MODE
	var scene: Node = load("res://scenes/world/Run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_run.call_deferred()

func _run() -> void:
	create_timer(40.0, true, false, true).timeout.connect(func(): print("WATCHDOG: test stuck"); quit(2))
	await wait_seconds(0.5)
	player = get_first_node_in_group("player")
	kata = player.get_node("KataComponent")
	events = player.get_node("KataEvents")
	var rm: Node = get_first_node_in_group("room_manager")
	var C = TechniqueData.Category

	print("-- asleep")
	check(not kata.is_awake and kata.slots.is_empty(), "Kata starts asleep with no techniques")
	events.hit_dealt.emit({"kind": "light", "hit_count": 1})
	events.dodge.emit()
	check(not kata.is_open, "no technique: nothing opens the Kata")
	check(not kata.begin_finisher(null).was_open, "no technique: heavy is plain")
	var woke: Array = []
	kata.awakened.connect(func(): woke.append(1))
	var Q = load("res://resources/techniques/quick_draw.tres")
	kata.set_technique(Q)
	check(kata.is_awake and woke.size() == 1, "first technique awakens the Kata")
	kata.set_technique(load("res://resources/techniques/crimson_rhythm.tres"))
	kata.set_technique(load("res://resources/techniques/moon_sever.tres"))
	check(woke.size() == 1, "awakens only once")

	print("-- full chain with simulated events")
	events.hit_dealt.emit({"kind": "light", "hit_count": 1})
	check(not kata.is_open, "light hit does not open (Quick Draw wants a dash)")
	events.dodge.emit()
	check(kata.is_open and is_equal_approx(kata.flow_value, 0.25), "dash opens the Kata, flow 0.25")
	kata.close("test")
	events.dodge.emit()
	kata.flow_value = 0.0
	var context: Dictionary = kata.begin_finisher(null)
	check(is_equal_approx(context.damage_multiplier, 1.0) and context.was_open and context.scale == 1.6, "finisher with 0 flow: x1.0 and wide")
	check(not kata.is_open and kata.flow_value == 0.0, "the Kata closes after the finisher")
	var plain: Dictionary = kata.begin_finisher(null)
	check(plain.damage_multiplier == 1.0 and not plain.was_open, "heavy without a running Kata = normal heavy")

	print("-- timeout and room change")
	events.dodge.emit()
	check(kata.is_open, "opened again")
	await wait_seconds(3.4)
	check(not kata.is_open, "closed by timeout after ~3 s without activity")
	events.dodge.emit()
	rm.room_loaded.emit(null)
	check(not kata.is_open, "closed when a room is entered")

	print("-- real attacks on a dummy")
	var dummy: Node3D = load("res://scenes/enemies/TrainingDummy.tscn").instantiate()
	var dir: Vector3 = player.aim.aim_direction
	dummy.position = player.global_position + dir * 2.0
	rm.current_room.enemies_root.add_child(dummy)
	await wait_seconds(0.3)
	events.dodge.emit() # opens the Kata (Quick Draw); the real light hits then build Flow (Crimson Rhythm)
	kata.flow_value = 0.0
	dummy.health.set_max_health(500.0)
	var light_events: Array = []
	events.light_attack.connect(func(): light_events.append(1))
	Input.action_press("attack")
	await wait_seconds(0.55)
	Input.action_release("attack")
	check(light_events.size() >= 1, "light attack event emitted (%d)" % light_events.size())
	check(kata.is_open and kata.flow_value > 0.0, "Kata still open after real light hits (flow %.2f)" % kata.flow_value)
	var flow_before: float = kata.flow_value
	await wait_seconds(0.2)
	var hp_before: float = dummy.health.current_health
	Input.action_press("heavy")
	await wait_seconds(0.1)
	Input.action_release("heavy")
	await wait_seconds(0.8)
	var dealt: float = hp_before - dummy.health.current_health
	var expected: float = 14.0 * (1.0 + 1.0 * flow_before)
	check(absf(dealt - expected) < 0.05, "heavy as finisher dealt %.2f (expected %.2f with flow %.2f)" % [dealt, expected, flow_before])
	check(not kata.is_open, "the real heavy attack closed the Kata")

	print("-- perfect dodge")
	var perfect: Array = []
	events.perfect_dodge.connect(func(_source): perfect.append(1))
	player.health.heal(1000.0)
	check(player.dash.try_dash(Vector3(1, 0, 0)), "dash started")
	await physics_frame
	player._on_hit_received(10.0, null)
	check(perfect.size() == 1, "hit right after the dash began = perfect dodge")
	await wait_seconds(0.12)
	check(player.dash.is_dashing, "still dashing")
	player._on_hit_received(10.0, null)
	check(perfect.size() == 1, "hit late in the dash = normal dodge, no perfect")
	await wait_seconds(0.3)
	var hp: float = player.health.current_health
	player._on_hit_received(10.0, null)
	check(player.health.current_health < hp and perfect.size() == 1, "hit after the dash hurts")

	print("-- from behind")
	var infos: Array = []
	events.hit_dealt.connect(func(info): infos.append(info))
	dummy.rotation = Vector3.ZERO
	var fwd: Vector3 = dummy.global_transform.basis.z
	player.global_position = dummy.global_position - fwd * 2.0
	player.on_hit_dealt(dummy.health, {"target": dummy, "kind": "light"})
	player.global_position = dummy.global_position + fwd * 2.0
	player.on_hit_dealt(dummy.health, {"target": dummy, "kind": "light"})
	check(infos.size() == 2 and infos[0].from_behind and not infos[1].from_behind, "from_behind true behind the enemy, false in front")

	print("RESULT: ", "ALL PASSED" if failures.is_empty() else "%d FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
