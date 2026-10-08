extends "res://scripts/enemies/Enemy.gd"
## Ranged enemy. Keeps its distance, aims with a red telegraph line, then shoots a projectile.
## The aim direction freezes shortly before the shot ("lock_time"), so the player can dodge sideways.
## Ninja reuses this script and changes how it fires (a fan) and what it does after firing (blink).

enum State { MOVE, AIM, RECOVER }

@export var move_speed: float = 3.0
@export var acceleration: float = 20.0
@export var min_range: float = 6.0 # closer than this: backs away
@export var max_range: float = 12.0 # farther than this (or no line of sight): walks closer
@export var projectile_scene: PackedScene
@export var projectile_damage: float = 10.0
@export var reaction_time: float = 0.5 # minimum time in MOVE before it may start aiming
@export var aim_time: float = 1.0
@export var lock_time: float = 0.3 # last part of aim_time where the aim no longer follows the player
@export var recover_time: float = 1.2
@export var path_update_interval: float = 0.2

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var aim_pivot: Node3D = $AimPivot
@onready var aim_visual: MeshInstance3D = $AimPivot/Visual
@onready var model: Node3D = $Model

var state: State = State.MOVE
var state_time: float = 0.0
var path_timer: float = 0.0
var strafe_sign: float = 1.0
var strafe_timer: float = 1.5
var target: Node3D
var visual_material: StandardMaterial3D


func _ready() -> void:
	super._ready()
	target = get_tree().get_first_node_in_group("player") as Node3D
	strafe_sign = 1.0 if randf() < 0.5 else -1.0
	visual_material = aim_visual.get_active_material(0).duplicate() as StandardMaterial3D
	aim_visual.material_override = visual_material
	aim_pivot.visible = false


func _physics_process(delta: float) -> void:
	if health.is_dead() or target == null:
		return
	delta *= time_scale() # Perfect Dodge slow, stun...
	state_time += delta
	strafe_timer -= delta
	match state:
		State.MOVE:
			_move(delta)
		State.AIM:
			_aim(delta)
		State.RECOVER:
			_recover(delta)
	slide()
	lock_to_floor()
	if state == State.MOVE and is_on_wall():
		_flip_strafe() # stuck against a wall or crate: go around the other way


func _move(delta: float) -> void:
	var to_target: Vector3 = _flat(target.global_position - global_position)
	var distance: float = to_target.length()
	var line_of_sight: bool = _has_line_of_sight(global_position)

	# When cornered (too close for a while) it shoots anyway instead of running forever.
	var can_aim: bool = line_of_sight and distance <= max_range and (distance >= min_range or state_time > 1.2)
	if can_aim and state_time >= reaction_time:
		_change_state(State.AIM)
		return

	if strafe_timer <= 0.0:
		_flip_strafe()

	var direction: Vector3
	if distance < min_range:
		direction = (-to_target.normalized()).rotated(Vector3.UP, deg_to_rad(40.0) * strafe_sign)
	elif not line_of_sight or distance > max_range:
		direction = _path_direction(to_target, delta)
	else:
		# Right distance: slowly sidestep while waiting to aim.
		direction = to_target.normalized().rotated(Vector3.UP, deg_to_rad(90.0) * strafe_sign) * 0.5
	_move_towards(direction, delta)
	_face(to_target, delta)


func _aim(delta: float) -> void:
	_stop(delta)
	if state_time < aim_time - lock_time:
		_face(target.global_position - global_position, delta)
	else:
		visual_material.albedo_color.a = 0.85 # locked: this is where the shot will go
	if state_time >= aim_time:
		_fire()
		_change_state(State.RECOVER)


func _recover(delta: float) -> void:
	_stop(delta)
	if state_time >= recover_time:
		_change_state(State.MOVE)


func _change_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	match new_state:
		State.AIM:
			visual_material.albedo_color.a = 0.3
			aim_pivot.visible = true
		State.RECOVER:
			aim_pivot.visible = false
			_on_recover_started()


## Subclasses change how the shot looks.
func _fire() -> void:
	AudioManager.play_sfx("arrow")
	_spawn_projectile(_forward())


## Subclasses can do something right after a shot (the Ninja blinks away).
func _on_recover_started() -> void:
	pass


func _spawn_projectile(direction: Vector3) -> void:
	if projectile_scene == null:
		push_warning("Archer: projectile_scene is not set on %s" % name)
		return
	var projectile = projectile_scene.instantiate()
	projectile.damage = projectile_damage
	projectile.team = "enemy"
	projectile.source = self
	get_parent().add_child(projectile) # same parent as the enemy, so it is removed with the room
	projectile.launch(global_position + Vector3(0.0, 0.9, 0.0) + direction * 0.7, direction)


func _forward() -> Vector3:
	return _flat(global_transform.basis.z).normalized()


func _flat(vector: Vector3) -> Vector3:
	vector.y = 0.0
	return vector


func _has_line_of_sight(from_position: Vector3) -> bool:
	var from: Vector3 = from_position + Vector3(0.0, 0.9, 0.0)
	var to: Vector3 = target.global_position + Vector3(0.0, 0.9, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1) # layer 1 = world
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _path_direction(to_target: Vector3, delta: float) -> Vector3:
	path_timer -= delta
	if path_timer <= 0.0:
		nav_agent.target_position = target.global_position
		path_timer = path_update_interval
	var to_next: Vector3 = _flat(nav_agent.get_next_path_position() - global_position)
	return to_next.normalized() if to_next.length() > 0.05 else to_target.normalized()


func _flip_strafe() -> void:
	strafe_sign = -strafe_sign
	strafe_timer = randf_range(1.0, 2.0)


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
	aim_pivot.visible = false
	super._on_died()
