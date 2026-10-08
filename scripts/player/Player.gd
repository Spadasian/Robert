extends CharacterBody3D
## Player: movement on the ground plane (XZ), dash, taking damage and dying.
## Attacking is in AttackComponent, aiming in AimComponent, dashing in DashComponent.

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/DamageNumber.tscn")

@export var acceleration: float = 40.0
@export var friction: float = 50.0

# Must match the camera yaw in CameraRig.tscn (45 degrees), so W moves "up" on screen.
const CAMERA_YAW_DEGREES: float = 45.0
# Layers: 1 = world, 4 = enemies. While dashing the player passes through enemies.
const MASK_NORMAL: int = 5
const MASK_DASHING: int = 1
# A hit that arrives this soon after a dash began is a Perfect Dodge (a dash lasts 0.18 s).
const PERFECT_DODGE_WINDOW: float = 0.10
# A Perfect Dodge slows the enemies (and their projectiles), not the player. Time Slip, Samurai Eye... make it last longer.
const PERFECT_SLOW_SCALE: float = 0.25
const PERFECT_SLOW_TIME: float = 0.4

@onready var model: Node3D = $Model
@onready var body_mesh: MeshInstance3D = $Model/Body
@onready var aim: Node = $AimComponent
@onready var stats: Node = $StatsComponent
@onready var health: Node = $HealthComponent
@onready var dash: Node = $DashComponent
@onready var hurtbox: Area3D = $Hurtbox
@onready var weapon: Node3D = $WeaponPivot
@onready var kata_events: Node = $KataEvents
@onready var kata: Node = $KataComponent
@onready var rules: Node = $RuleHost

var free_hits_left: int = 0 # hits still ignored in this room (Fox Mask)
var free_hits_max: int = 0
var skills: Array[PlayerSkill] = [] # right click, Shift, Q, E (children of this scene)
var ghost_timer: float = 0.0 # time until the next dash afterimage


func _ready() -> void:
	EnemyTime.reset()
	health.set_max_health(stats.get_stat("max_health"))
	dash.set_max_charges(int(stats.get_stat("dodge_charges")))
	dash.apply_stats(stats)
	stats.stats_changed.connect(_on_stats_changed)
	hurtbox.hit_received.connect(_on_hit_received)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	for child in get_children():
		if child is PlayerSkill:
			skills.append(child)
			child.activated.connect(func(): kata_events.skill_used.emit(child))
	add_child(preload("res://scripts/player/CorruptionVfx.gd").new()) # purple wisps that grow with Corruption
	dash.dash_started.connect(_on_dash_started)
	dash.dash_finished.connect(_on_dash_finished)
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager:
		room_manager.room_changed.connect(_on_room_changed)


func _physics_process(delta: float) -> void:
	EnemyTime.tick(delta)
	if health.is_dead():
		return
	_move(delta)
	_lock_to_floor()


## The game is flat: no jumping, no gravity. When the physics engine separates the player from an overlapping
## body (an enemy spawned on him, a dash that ended inside an enemy) it may push him UP, and nothing would ever
## pull him back down, so right after moving he is put back on the floor.
func _lock_to_floor() -> void:
	if absf(global_position.y) > 0.001:
		global_position.y = 0.0


func _move(delta: float) -> void:

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input_vector.x, 0.0, input_vector.y).rotated(Vector3.UP, deg_to_rad(CAMERA_YAW_DEGREES))

	# The player always faces the mouse.
	model.rotation.y = atan2(aim.aim_direction.x, aim.aim_direction.z)

	for skill in skills:
		if Input.is_action_just_pressed(skill.input_action):
			skill.try_activate()

	if Input.is_action_just_pressed("dash") and not is_busy():
		# Dash where you move; if standing still, dash towards the mouse.
		dash.try_dash(direction if direction != Vector3.ZERO else aim.aim_direction)

	if dash.is_dashing:
		velocity = dash.direction * dash.dash_speed
		move_and_slide()
		ghost_timer -= delta
		if ghost_timer <= 0.0:
			ghost_timer = 0.035
			VFX.ghost(body_mesh, Color(0.4, 0.9, 1.0))
		return

	# Skills can push the player (Iaijutsu strike) or hold him in place (windup, counter stance).
	for skill in skills:
		if not skill.is_active:
			continue
		var forced: Variant = skill.get_forced_velocity()
		if forced != null:
			velocity = forced
			move_and_slide()
			return
		if skill.locks_movement():
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta)
			velocity.y = 0.0
			move_and_slide()
			return

	var target_velocity: Vector3 = direction * stats.get_stat("move_speed") * _get_skill_speed_multiplier()
	var rate: float = acceleration if direction != Vector3.ZERO else friction
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
	velocity.y = 0.0
	move_and_slide()


## True while any skill is running: no second skill, no dash and no basic attack until it ends.
func is_busy() -> bool:
	for skill in skills:
		if skill.is_active:
			return true
	return false


func _get_skill_speed_multiplier() -> float:
	var multiplier: float = 1.0
	for skill in skills:
		multiplier *= skill.get_speed_multiplier()
	return multiplier


## Called by CombatManager after every hit this player lands (the ultimate charges from it).
func on_hit_dealt(target_health: Node, info: Dictionary = {}) -> void:
	var killed: bool = target_health != null and target_health.is_dead()
	for skill in skills:
		skill.on_player_hit_dealt(killed)
	# Tell the Kata and the relics what happened.
	info["killed"] = killed
	info["from_behind"] = _is_behind(info.get("target"))
	kata_events.hit_dealt.emit(info)
	if info.get("crit", false):
		kata_events.critical_hit.emit(info)
	if killed:
		kata_events.kill.emit(info)


## Called by EnemyStatus after every bleed tick: bleed kills count like any other kill.
func on_bleed_tick(enemy: Node, damage: float, killed: bool) -> void:
	kata_events.bleed_tick.emit(enemy, damage)
	if killed:
		var info: Dictionary = {"target": enemy, "damage": damage, "crit": false, "kind": "bleed", "hit_count": 1, "killed": true, "overkill": 0.0}
		kata_events.kill.emit(info)
		var heal_amount: float = stats.get_stat("life_on_kill")
		if heal_amount > 0.0:
			health.heal(heal_amount)


## True when the player is behind the target (the target looks away from him).
func _is_behind(target: Node) -> bool:
	var enemy := target as Node3D
	if enemy == null:
		return false
	var to_player: Vector3 = global_position - enemy.global_position
	to_player.y = 0.0
	if to_player.length() < 0.01:
		return false
	var enemy_forward: Vector3 = enemy.global_transform.basis.z
	enemy_forward.y = 0.0
	return enemy_forward.normalized().dot(to_player.normalized()) < -0.2


func _on_hit_received(damage: float, _source: Node) -> void:
	if health.is_dead():
		return
	if dash.is_invulnerable():
		if dash.elapsed <= PERFECT_DODGE_WINDOW * stats.get_stat("perfect_window"):
			kata_events.perfect_dodge.emit(_source)
			_show_floating_text("PERFECT", Color(0.5, 0.95, 1.0))
			EnemyTime.slow(PERFECT_SLOW_SCALE, PERFECT_SLOW_TIME + stats.get_stat("perfect_slow_bonus"))
		return
	var damage_taken_multiplier: float = 1.0
	for skill in skills:
		if skill.is_active and skill.is_invulnerable():
			return
		if skill.is_active and skill.intercept_hit(damage, _source):
			return # Kaeshi: the hit is cancelled and answered
		damage_taken_multiplier *= skill.get_damage_taken_multiplier()
	if randf() < stats.get_stat("evade_chance"): # Lucky Thread
		_show_floating_text("LUCKY", Color(0.9, 0.9, 0.5))
		return
	if free_hits_left > 0: # Fox Mask: the first hit of every room does nothing
		free_hits_left -= 1
		_show_floating_text("BLOCKED", Color(1.0, 0.7, 0.3))
		AudioManager.play_sfx("kaeshi_counter", -8.0)
		VFX.hit_spark(global_position + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.7, 0.3))
		return
	var final_damage: float = rules.process_incoming(damage * stats.get_stat("damage_taken") * damage_taken_multiplier, _source)
	if final_damage > 0.0:
		health.take_damage(final_damage)


func _on_stats_changed() -> void:
	health.change_max_health(stats.get_stat("max_health"))
	dash.set_max_charges(int(stats.get_stat("dodge_charges")))
	dash.apply_stats(stats)
	# A new free hit (Fox Mask picked up) is ready at once.
	var new_free_hits: int = int(stats.get_stat("free_hits_per_room"))
	free_hits_left = clampi(free_hits_left + (new_free_hits - free_hits_max), 0, new_free_hits)
	free_hits_max = new_free_hits


func _on_room_changed(_index: int, _total: int) -> void:
	free_hits_left = free_hits_max


func _on_damaged(amount: float) -> void:
	kata_events.damage_taken.emit(amount)
	_show_floating_text(str(int(round(amount))), Color(1.0, 0.3, 0.3))
	AudioManager.play_sfx("hurt")
	VFX.hit_spark(global_position + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.3, 0.25))
	VFX.shake(clampf(amount / 60.0, 0.08, 0.3), 0.2)


func _show_floating_text(text: String, color: Color) -> void:
	var number: Label3D = DAMAGE_NUMBER_SCENE.instantiate()
	get_tree().current_scene.add_child(number)
	number.global_position = global_position + Vector3(0.0, 2.4, 0.0)
	number.modulate = color
	number.play_text(text)


func _on_died() -> void:
	for skill in skills:
		skill.cancel()
	VFX.death_puff(global_position + Vector3(0.0, 0.9, 0.0), Color(0.9, 0.2, 0.25), true)
	hurtbox.set_deferred("monitorable", false)
	weapon.set_physics_process(false)
	velocity = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(model, "rotation:x", deg_to_rad(-90.0), 0.3)


func _on_dash_started() -> void:
	kata_events.dodge.emit()
	AudioManager.play_sfx("dash")
	VFX.dust(global_position)
	ghost_timer = 0.0
	collision_mask = MASK_DASHING
	body_mesh.transparency = 0.6


func _on_dash_finished() -> void:
	collision_mask = MASK_NORMAL
	body_mesh.transparency = 0.0
