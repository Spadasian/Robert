extends Node3D
## Follows the player smoothly. The Camera3D child keeps the fixed isometric angle.

@export var follow_speed: float = 8.0

@onready var camera: Camera3D = $Camera3D

var target: Node3D
var shake_strength: float = 0.0
var shake_time: float = 0.0
var shake_duration: float = 0.0


func _ready() -> void:
	add_to_group("camera_rig")
	target = get_tree().get_first_node_in_group("player") as Node3D
	if target:
		global_position = target.global_position


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var weight: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target.global_position, weight)


## Shakes the camera: the strongest shake that is running wins, and it fades out over `duration`.
func shake(strength: float, duration: float = 0.2) -> void:
	var remaining_strength: float = shake_strength * (shake_time / shake_duration) if shake_duration > 0.0 else 0.0
	if strength >= remaining_strength:
		shake_strength = strength
		shake_duration = maxf(duration, 0.01)
		shake_time = shake_duration


func _process(delta: float) -> void:
	if shake_time > 0.0:
		shake_time -= delta
		var amount: float = shake_strength * clampf(shake_time / shake_duration, 0.0, 1.0)
		camera.h_offset = randf_range(-amount, amount)
		camera.v_offset = randf_range(-amount, amount)
	elif camera.h_offset != 0.0 or camera.v_offset != 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func snap_to_target() -> void:
	if target:
		global_position = target.global_position
