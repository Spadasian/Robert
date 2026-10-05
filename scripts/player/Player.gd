extends CharacterBody3D
## Player movement on the ground plane (XZ). Input is rotated to match the isometric camera.

@export var move_speed: float = 6.0
@export var acceleration: float = 40.0
@export var friction: float = 50.0
@export var turn_speed: float = 14.0

# Must match the camera yaw in Main.tscn (45 degrees), so W moves "up" on screen.
const CAMERA_YAW_DEGREES: float = 45.0

@onready var model: Node3D = $Model


func _physics_process(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input_vector.x, 0.0, input_vector.y).rotated(Vector3.UP, deg_to_rad(CAMERA_YAW_DEGREES))

	var target_velocity: Vector3 = direction * move_speed
	var rate: float = acceleration if direction != Vector3.ZERO else friction
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
	velocity.y = 0.0
	move_and_slide()

	# Temporary: face the movement direction. Task 4 will aim at the mouse instead.
	if direction != Vector3.ZERO:
		var target_angle: float = atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, clampf(turn_speed * delta, 0.0, 1.0))
