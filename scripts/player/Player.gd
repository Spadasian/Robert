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

@onready var model: Node3D = $Model
@onready var body_mesh: MeshInstance3D = $Model/Body
@onready var aim: Node = $AimComponent
@onready var stats: Node = $StatsComponent
@onready var health: Node = $HealthComponent
@onready var dash: Node = $DashComponent
@onready var hurtbox: Area3D = $Hurtbox
@onready var weapon: Node3D = $WeaponPivot


func _ready() -> void:
	health.set_max_health(stats.get_stat("max_health"))
	dash.set_max_charges(int(stats.get_stat("dodge_charges")))
	stats.stats_changed.connect(_on_stats_changed)
	hurtbox.hit_received.connect(_on_hit_received)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	dash.dash_started.connect(_on_dash_started)
	dash.dash_finished.connect(_on_dash_finished)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input_vector.x, 0.0, input_vector.y).rotated(Vector3.UP, deg_to_rad(CAMERA_YAW_DEGREES))

	# The player always faces the mouse.
	model.rotation.y = atan2(aim.aim_direction.x, aim.aim_direction.z)

	if Input.is_action_just_pressed("dash"):
		# Dash where you move; if standing still, dash towards the mouse.
		dash.try_dash(direction if direction != Vector3.ZERO else aim.aim_direction)

	if dash.is_dashing:
		velocity = dash.direction * dash.dash_speed
		move_and_slide()
		return

	var target_velocity: Vector3 = direction * stats.get_stat("move_speed")
	var rate: float = acceleration if direction != Vector3.ZERO else friction
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
	velocity.y = 0.0
	move_and_slide()


func _on_hit_received(damage: float, _source: Node) -> void:
	if dash.is_invulnerable() or health.is_dead():
		return
	health.take_damage(damage * stats.get_stat("damage_taken"))


func _on_stats_changed() -> void:
	health.change_max_health(stats.get_stat("max_health"))
	dash.set_max_charges(int(stats.get_stat("dodge_charges")))


func _on_damaged(amount: float) -> void:
	var number: Label3D = DAMAGE_NUMBER_SCENE.instantiate()
	get_tree().current_scene.add_child(number)
	number.global_position = global_position + Vector3(0.0, 2.4, 0.0)
	number.modulate = Color(1.0, 0.3, 0.3)
	number.play(amount)


func _on_died() -> void:
	hurtbox.set_deferred("monitorable", false)
	weapon.set_physics_process(false)
	velocity = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(model, "rotation:x", deg_to_rad(-90.0), 0.3)


func _on_dash_started() -> void:
	collision_mask = MASK_DASHING
	body_mesh.transparency = 0.6


func _on_dash_finished() -> void:
	collision_mask = MASK_NORMAL
	body_mesh.transparency = 0.0
