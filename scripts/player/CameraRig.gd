extends Node3D
## Follows the player smoothly. The Camera3D child keeps the fixed isometric angle.

@export var follow_speed: float = 8.0

var target: Node3D


func _ready() -> void:
	target = get_tree().get_first_node_in_group("player") as Node3D
	if target:
		global_position = target.global_position


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var weight: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target.global_position, weight)
