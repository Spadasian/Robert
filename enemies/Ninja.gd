extends "res://scripts/enemies/Archer.gd"
## Ranged ninja. Same behaviour as the Archer, with two differences:
## 1) it throws a fan of shurikens (fan_count should be odd) instead of one arrow,
## 2) after every volley it blinks: it vanishes for a moment and reappears somewhere else around the player.
## It cannot be hit while it is vanished.

@export var fan_count: int = 3
@export var spread_degrees: float = 18.0
@export var blink_duration: float = 0.12 # time to vanish, and again to reappear

var is_blinking: bool = false


func _ready() -> void:
	super._ready()
	# One telegraph line per extra shuriken (the centre one is the scene's own line).
	for index in fan_count:
		var offset: float = index - (fan_count - 1) * 0.5
		if is_zero_approx(offset):
			continue
		var pivot := Node3D.new()
		aim_pivot.add_child(pivot)
		pivot.rotation.y = deg_to_rad(spread_degrees) * offset
		var line := aim_visual.duplicate() as MeshInstance3D
		line.material_override = visual_material
		pivot.add_child(line)


func _fire() -> void:
	AudioManager.play_sfx("shuriken")
	var forward: Vector3 = _forward()
	for index in fan_count:
		var offset: float = index - (fan_count - 1) * 0.5
		_spawn_projectile(forward.rotated(Vector3.UP, deg_to_rad(spread_degrees) * offset))


func _on_recover_started() -> void:
	_blink()


func _blink() -> void:
	var spot: Variant = _find_blink_spot()
	if spot == null:
		return # nowhere good to go, stay and keep shooting
	is_blinking = true
	AudioManager.play_sfx("blink")
	VFX.sparkle(global_position + Vector3(0.0, 0.9, 0.0), Color(0.8, 0.4, 1.0))
	hurtbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3.ONE * 0.01, blink_duration)
	tween.tween_callback(_teleport_to.bind(spot))
	tween.tween_property(model, "scale", Vector3.ONE, blink_duration)
	tween.tween_callback(_end_blink)


func _teleport_to(spot: Vector3) -> void:
	if health.is_dead():
		return
	global_position = spot
	velocity = Vector3.ZERO
	VFX.sparkle(spot + Vector3(0.0, 0.9, 0.0), Color(0.8, 0.4, 1.0))


func _end_blink() -> void:
	is_blinking = false
	if not health.is_dead():
		hurtbox.set_deferred("monitorable", true)


## A random walkable point at shooting distance from the player with a clear line of sight.
func _find_blink_spot() -> Variant:
	var map: RID = nav_agent.get_navigation_map()
	for attempt in 8:
		var angle: float = randf() * TAU
		var distance: float = randf_range(min_range + 1.0, max_range - 1.0)
		var candidate: Vector3 = target.global_position + Vector3(sin(angle), 0.0, cos(angle)) * distance
		var spot: Vector3 = NavigationServer3D.map_get_closest_point(map, candidate)
		spot.y = global_position.y
		if _flat(spot - candidate).length() > 1.5:
			continue # candidate was outside the room or inside an obstacle
		if _flat(spot - target.global_position).length() < min_range:
			continue
		if not _has_line_of_sight(spot):
			continue
		return spot
	return null
