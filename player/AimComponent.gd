extends Node
## Finds where the mouse points on the ground and exposes the aim direction (flat, on XZ).

var aim_direction: Vector3 = Vector3(0.0, 0.0, 1.0)
var aim_point: Vector3 = Vector3.ZERO

# Height of the aiming plane: roughly weapon height, so the aim matches what you see.
const AIM_HEIGHT: float = 0.9


func _process(_delta: float) -> void:
	var body := get_parent() as Node3D
	var camera := get_viewport().get_camera_3d()
	if body == null or camera == null:
		return
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position)
	var plane := Plane(Vector3.UP, body.global_position.y + AIM_HEIGHT)
	var hit: Variant = plane.intersects_ray(ray_origin, ray_direction)
	if hit == null:
		return
	aim_point = hit
	var flat: Vector3 = aim_point - body.global_position
	flat.y = 0.0
	if flat.length() > 0.1:
		aim_direction = flat.normalized()
