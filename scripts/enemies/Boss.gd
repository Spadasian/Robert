extends "res://scripts/enemies/Enemy.gd"
## Lord Kageyama, the boss of the vertical slice. Two phases, every attack is telegraphed in red first.
## Phase 1: 3-hit sword combo and a dash strike.
## Phase 2 (at half health): enrages, attacks faster, and adds a shockwave slam and a fan of shurikens.
## Flow of one attack: WINDUP (telegraph, aim follows the player, then locks) -> STRIKE -> RECOVER (punish window).

signal phase_changed(new_phase: int)

enum State { INTRO, CHASE, WINDUP, STRIKE, RECOVER, TRANSITION }
enum Attack { COMBO, DASH, SHOCKWAVE, FAN }

@export var boss_name: String = "Lord Kageyama"
@export var move_speed: float = 3.2
@export var acceleration: float = 25.0
@export var intro_time: float = 2.0
@export var transition_time: float = 1.4
@export var phase_two_ratio: float = 0.5 # phase 2 starts below this share of max health
@export var phase_two_speed: float = 1.25 # multiplies walk speed and attack speed in phase 2
@export var lock_time: float = 0.18 # end of the windup where the aim stops following the player
@export var far_attack_delay: float = 1.2 # chasing for this long makes it use a far attack
@export var path_update_interval: float = 0.2

@export_group("Combo")
@export var combo_damage: float = 14.0
@export var combo_range: float = 3.2 # starts the combo when the player is this close
@export var combo_hits: int = 3
@export var combo_windup: float = 0.55
@export var combo_next_windup: float = 0.35
@export var combo_lunge_speed: float = 6.0
@export var combo_recover: float = 0.9

@export_group("Dash strike")
@export var dash_damage: float = 20.0
@export var dash_speed: float = 20.0
@export var dash_duration: float = 0.35
@export var dash_windup: float = 0.7
@export var dash_recover: float = 1.0

@export_group("Shockwave (phase 2)")
@export var shock_damage: float = 18.0
@export var shock_windup: float = 0.8
@export var shock_recover: float = 1.0

@export_group("Shuriken fan (phase 2)")
@export var projectile_scene: PackedScene
@export var fan_damage: float = 8.0
@export var fan_count: int = 5 # keep it odd
@export var fan_spread_degrees: float = 14.0
@export var fan_windup: float = 0.7
@export var fan_recover: float = 0.9

const STRIKE_TIME: float = 0.15 # combo hit and shockwave burst
const FAN_STRIKE_TIME: float = 0.1

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: Node3D = $Model
@onready var slash_hitbox: Area3D = $SlashPivot/Hitbox
@onready var slash_visual: MeshInstance3D = $SlashPivot/Visual
@onready var dash_hitbox: Area3D = $DashPivot/Hitbox
@onready var dash_visual: MeshInstance3D = $DashPivot/Visual
@onready var shock_hitbox: Area3D = $ShockPivot/Hitbox
@onready var shock_visual: MeshInstance3D = $ShockPivot/Visual
@onready var aim_pivot: Node3D = $AimPivot
@onready var aim_visual: MeshInstance3D = $AimPivot/Visual

var state: int = State.INTRO
var state_time: float = 0.0
var attack: int = Attack.COMBO
var last_attack: int = -1
var combo_index: int = 0
var phase: int = 1
var speed_scale: float = 1.0
var dash_direction: Vector3 = Vector3.FORWARD
var path_timer: float = 0.0
var target: Node3D
var telegraph_material: StandardMaterial3D
var telegraph_visuals: Array[MeshInstance3D] = []


func _ready() -> void:
	super._ready()
	target = get_tree().get_first_node_in_group("player") as Node3D
	AudioManager.play_sfx("roar", -4.0) # the introduction

	slash_hitbox.damage = combo_damage
	dash_hitbox.damage = dash_damage
	shock_hitbox.damage = shock_damage
	for hitbox in [slash_hitbox, dash_hitbox, shock_hitbox]:
		hitbox.source = self
		hitbox.team = "enemy"
		hitbox.set_active(false)

	# One shared see-through red material for every telegraph.
	telegraph_material = StandardMaterial3D.new()
	telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph_material.albedo_color = Color(1.0, 0.2, 0.2, 0.3)
	telegraph_visuals = [slash_visual, dash_visual, shock_visual, aim_visual]
	for visual in telegraph_visuals:
		visual.material_override = telegraph_material
	_build_fan_lines()
	_hide_telegraphs()

	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_boss_bar(boss_name, health.max_health)
		hud.show_message(boss_name.to_upper(), intro_time)
		health.health_changed.connect(hud.update_boss_bar)


func _physics_process(delta: float) -> void:
	if health.is_dead() or target == null:
		return
	state_time += delta
	match state:
		State.INTRO:
			_stop(delta)
			_face(target.global_position - global_position, delta)
			if state_time >= intro_time:
				_set_state(State.CHASE)
		State.CHASE:
			_chase(delta)
		State.WINDUP:
			_windup(delta)
		State.STRIKE:
			_strike(delta)
		State.RECOVER:
			_recover(delta)
		State.TRANSITION:
			_transition(delta)
	move_and_slide()
	lock_to_floor()


# ---------------------------------------------------------------- states

func _set_state(new_state: int) -> void:
	state = new_state
	state_time = 0.0
	match new_state:
		State.CHASE:
			path_timer = 0.0
		State.WINDUP:
			_on_windup_start()
		State.STRIKE:
			_on_strike_start()
		State.RECOVER:
			_deactivate_hitboxes()
			_hide_telegraphs()


func _chase(delta: float) -> void:
	var to_target: Vector3 = _flat(target.global_position - global_position)
	var distance: float = to_target.length()
	if distance <= combo_range:
		_begin_attack(_pick([Attack.COMBO] if phase == 1 else [Attack.COMBO, Attack.SHOCKWAVE]))
		return
	if state_time >= far_attack_delay and distance >= 5.0:
		_begin_attack(_pick([Attack.DASH] if phase == 1 else [Attack.DASH, Attack.FAN]))
		return

	path_timer -= delta
	if path_timer <= 0.0:
		nav_agent.target_position = target.global_position
		path_timer = path_update_interval
	var to_next: Vector3 = _flat(nav_agent.get_next_path_position() - global_position)
	var direction: Vector3 = to_next.normalized() if to_next.length() > 0.05 else to_target.normalized()
	velocity.x = move_toward(velocity.x, direction.x * move_speed * speed_scale, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed * speed_scale, acceleration * delta)
	velocity.y = 0.0
	_face(direction, delta)


func _begin_attack(kind: int) -> void:
	attack = kind
	combo_index = 0
	_set_state(State.WINDUP)


func _on_windup_start() -> void:
	_hide_telegraphs()
	telegraph_material.albedo_color.a = 0.3
	match attack:
		Attack.COMBO:
			slash_visual.visible = true
		Attack.DASH:
			dash_visual.visible = true
		Attack.SHOCKWAVE:
			shock_visual.visible = true
		Attack.FAN:
			aim_pivot.visible = true
			aim_visual.visible = true


func _windup(delta: float) -> void:
	_stop(delta)
	var duration: float = _windup_duration()
	if attack != Attack.SHOCKWAVE and state_time < duration - lock_time:
		_face(target.global_position - global_position, delta)
	elif state_time >= duration - lock_time:
		telegraph_material.albedo_color.a = 0.85 # locked in: this is where it will land
	if state_time >= duration:
		_set_state(State.STRIKE)


func _windup_duration() -> float:
	var base: float = 0.5
	match attack:
		Attack.COMBO:
			base = combo_windup if combo_index == 0 else combo_next_windup
		Attack.DASH:
			base = dash_windup
		Attack.SHOCKWAVE:
			base = shock_windup
		Attack.FAN:
			base = fan_windup
	return base / speed_scale


func _on_strike_start() -> void:
	match attack:
		Attack.COMBO:
			slash_hitbox.set_active(true)
			AudioManager.play_sfx("boss_slash")
			VFX.slash_arc(global_position + Vector3(0.0, 0.9, 0.0), rotation.y, 3.2, 150.0, Color(1.0, 0.3, 0.3), 0.2)
		Attack.DASH:
			dash_direction = _forward()
			rotation.y = atan2(dash_direction.x, dash_direction.z)
			dash_hitbox.set_active(true)
			AudioManager.play_sfx("dash")
			VFX.dust(global_position)
		Attack.SHOCKWAVE:
			shock_hitbox.set_active(true)
			AudioManager.play_sfx("boom")
			VFX.ring(global_position, 4.5, Color(1.0, 0.3, 0.3))
			VFX.shake(0.25, 0.3)
		Attack.FAN:
			AudioManager.play_sfx("shuriken")
			_fire_fan()


func _strike(delta: float) -> void:
	match attack:
		Attack.COMBO:
			var forward: Vector3 = _forward()
			velocity.x = forward.x * combo_lunge_speed
			velocity.z = forward.z * combo_lunge_speed
		Attack.DASH:
			velocity.x = dash_direction.x * dash_speed
			velocity.z = dash_direction.z * dash_speed
		_:
			_stop(delta)
	if state_time >= _strike_duration():
		_deactivate_hitboxes()
		if attack == Attack.COMBO and combo_index < combo_hits - 1:
			combo_index += 1
			_set_state(State.WINDUP) # next hit of the combo
		else:
			_set_state(State.RECOVER)


func _strike_duration() -> float:
	match attack:
		Attack.DASH:
			return dash_duration
		Attack.FAN:
			return FAN_STRIKE_TIME
	return STRIKE_TIME


func _recover(delta: float) -> void:
	_stop(delta)
	if state_time >= _recover_duration():
		_set_state(State.CHASE)


func _recover_duration() -> float:
	var base: float = 0.8
	match attack:
		Attack.COMBO:
			base = combo_recover
		Attack.DASH:
			base = dash_recover
		Attack.SHOCKWAVE:
			base = shock_recover
		Attack.FAN:
			base = fan_recover
	return base / speed_scale


# ---------------------------------------------------------------- phase 2

func _on_damaged(amount: float) -> void:
	super(amount)
	if phase == 1 and not health.is_dead() and health.current_health <= health.max_health * phase_two_ratio:
		_begin_transition()


func _begin_transition() -> void:
	phase = 2
	_deactivate_hitboxes()
	_hide_telegraphs()
	velocity = Vector3.ZERO
	_set_state(State.TRANSITION)
	phase_changed.emit(phase)
	AudioManager.play_sfx("roar")
	VFX.shake(0.3, 0.9)
	VFX.ring(global_position, 5.0, Color(0.7, 0.2, 0.9), 0.6)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_message("%s is enraged!" % boss_name, transition_time)
	# The enraged look: purple, a little bigger.
	base_color = Color(0.4, 0.05, 0.45)
	body_material.albedo_color = base_color


func _transition(delta: float) -> void:
	_stop(delta)
	model.scale = Vector3.ONE * (1.1 + 0.06 * sin(state_time * 25.0))
	if state_time >= transition_time:
		model.scale = Vector3.ONE * 1.1
		speed_scale = phase_two_speed
		_set_state(State.CHASE)


## No damage while it introduces itself or changes phase.
func _on_hit_received(damage: float, source: Node) -> void:
	if state == State.INTRO or state == State.TRANSITION:
		return
	super(damage, source)


func _on_died() -> void:
	_deactivate_hitboxes()
	_hide_telegraphs()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.hide_boss_bar()
	AudioManager.play_sfx("boss_death")
	VFX.death_puff(global_position + Vector3(0.0, 1.2, 0.0), base_color, true)
	VFX.shake(0.4, 0.7)
	super._on_died()


# ---------------------------------------------------------------- helpers

func _fire_fan() -> void:
	if projectile_scene == null:
		push_warning("Boss: projectile_scene is not set")
		return
	var forward: Vector3 = _forward()
	for index in fan_count:
		var offset: float = index - (fan_count - 1) * 0.5
		var direction: Vector3 = forward.rotated(Vector3.UP, deg_to_rad(fan_spread_degrees) * offset)
		var projectile = projectile_scene.instantiate()
		projectile.damage = fan_damage
		projectile.team = "enemy"
		projectile.source = self
		get_parent().add_child(projectile) # removed together with the room
		projectile.launch(global_position + Vector3(0.0, 0.9, 0.0) + direction * 1.0, direction)


## One telegraph line per extra shuriken (the centre one is the scene's own line).
func _build_fan_lines() -> void:
	for index in fan_count:
		var offset: float = index - (fan_count - 1) * 0.5
		if is_zero_approx(offset):
			continue
		var pivot := Node3D.new()
		aim_pivot.add_child(pivot)
		pivot.rotation.y = deg_to_rad(fan_spread_degrees) * offset
		var line := aim_visual.duplicate() as MeshInstance3D
		line.material_override = telegraph_material
		pivot.add_child(line)
		telegraph_visuals.append(line)


func _pick(options: Array) -> int:
	var choices: Array = options.filter(func(kind): return kind != last_attack)
	if choices.is_empty():
		choices = options
	last_attack = choices.pick_random()
	return last_attack


func _hide_telegraphs() -> void:
	for visual in telegraph_visuals:
		visual.visible = false


func _deactivate_hitboxes() -> void:
	slash_hitbox.set_active(false)
	dash_hitbox.set_active(false)
	shock_hitbox.set_active(false)


func _forward() -> Vector3:
	return _flat(global_transform.basis.z).normalized()


func _flat(vector: Vector3) -> Vector3:
	vector.y = 0.0
	return vector


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	velocity.y = 0.0


func _face(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var target_angle: float = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, clampf(10.0 * delta, 0.0, 1.0))
