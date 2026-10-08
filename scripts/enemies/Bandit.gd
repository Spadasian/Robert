extends "res://scripts/enemies/Enemy.gd"
## Melee enemy: chases the player around obstacles, telegraphs, then slashes.
## Heavy Bandit will reuse this script with different exported values.

enum State { CHASE, WINDUP, ATTACK, RECOVER }

@export var move_speed: float = 3.5
@export var acceleration: float = 20.0
@export var attack_damage: float = 8.0
@export var attack_range: float = 1.8
@export var windup_time: float = 0.5
@export var attack_time: float = 0.15
@export var recover_time: float = 0.6
@export var path_update_interval: float = 0.2

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var attack_hitbox: Area3D = $AttackPivot/Hitbox
@onready var attack_visual: MeshInstance3D = $AttackPivot/Visual

var state: State = State.CHASE
var state_time: float = 0.0
var path_timer: float = 0.0
var target: Node3D
var visual_material: StandardMaterial3D


func _ready() -> void:
	super._ready()
	target = get_tree().get_first_node_in_group("player") as Node3D
	attack_hitbox.source = self
	attack_hitbox.team = "enemy"
	attack_hitbox.damage = attack_damage
	attack_hitbox.set_active(false)
	visual_material = attack_visual.get_active_material(0).duplicate() as StandardMaterial3D
	attack_visual.material_override = visual_material
	attack_visual.visible = false


func _physics_process(delta: float) -> void:
	if health.is_dead() or target == null:
		return
	delta *= time_scale() # Perfect Dodge slow, stun...
	state_time += delta
	match state:
		State.CHASE:
			_chase(delta)
		State.WINDUP:
			_windup(delta)
		State.ATTACK:
			_attack()
		State.RECOVER:
			_recover(delta)
	slide()
	lock_to_floor()


func _chase(delta: float) -> void:
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	if to_target.length() <= attack_range and can_see_player():
		_change_state(State.WINDUP)
		return

	path_timer -= delta
	if path_timer <= 0.0:
		nav_agent.target_position = target.global_position
		path_timer = path_update_interval

	var to_next: Vector3 = nav_agent.get_next_path_position() - global_position
	to_next.y = 0.0
	var direction: Vector3 = to_next.normalized() if to_next.length() > 0.05 else to_target.normalized()
	_move_towards(direction, delta)
	_face(direction, delta)


func _windup(delta: float) -> void:
	_stop(delta)
	_face((target.global_position - global_position), delta)
	if state_time >= windup_time:
		_change_state(State.ATTACK)


func _attack() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if state_time >= attack_time:
		_change_state(State.RECOVER)


func _recover(delta: float) -> void:
	_stop(delta)
	if state_time >= recover_time:
		_change_state(State.CHASE)


func _change_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	match new_state:
		State.WINDUP:
			# Telegraph: the red zone shows where the hit will land.
			visual_material.albedo_color.a = 0.3
			attack_visual.visible = true
		State.ATTACK:
			visual_material.albedo_color.a = 0.85
			attack_hitbox.set_active(true)
			AudioManager.play_sfx("slash_enemy")
		State.RECOVER:
			attack_hitbox.set_active(false)
			attack_visual.visible = false


func _move_towards(direction: Vector3, delta: float) -> void:
	velocity.x = move_toward(velocity.x, direction.x * move_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, acceleration * delta)
	velocity.y = 0.0


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	velocity.y = 0.0


func _face(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var target_angle: float = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, clampf(12.0 * delta, 0.0, 1.0))


func _on_died() -> void:
	attack_hitbox.set_active(false)
	attack_visual.visible = false
	super._on_died()
