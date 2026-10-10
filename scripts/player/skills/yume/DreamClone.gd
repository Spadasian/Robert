extends "res://scripts/player/skills/yume/GhostBody.gd"
## One of the Dream Clones (Yume's Ultimate): runs to the nearest enemy and cuts it every moment, for a few seconds.

const AreaStrike = preload("res://scripts/combat/AreaStrike.gd")

var player: Node
var damage: float = 8.0
var life: float = 4.0
var speed: float = 7.5
var strike_radius: float = 1.7
var strike_interval: float = 0.45
var age: float = 0.0
var strike_timer: float = 0.2


func _physics_process(delta: float) -> void:
	age += delta
	if age >= life or not is_instance_valid(player):
		queue_free()
		return
	set_alpha(0.55 * clampf((life - age) / 0.4, 0.0, 1.0))
	var target: Node3D = _nearest_enemy()
	if target:
		var offset: Vector3 = target.global_position - global_position
		offset.y = 0.0
		if offset.length() > strike_radius * 0.6:
			global_position += offset.normalized() * speed * delta
		rotation.y = atan2(offset.x, offset.z)
	else:
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() > 2.5:
			global_position += to_player.normalized() * speed * delta
	global_position.y = 0.0
	strike_timer -= delta
	if strike_timer <= 0.0 and target and (target.global_position - global_position).length() <= strike_radius + 0.6:
		strike_timer = strike_interval
		AreaStrike.spawn(get_parent(), global_position, strike_radius, damage, player, "skill", 0.1)
		VFX.slash_arc(global_position + Vector3(0.0, 0.9, 0.0), rotation.y, strike_radius * 1.4, 140.0, Color(0.98, 0.72, 0.88), 0.14)
		AudioManager.play_sfx("slash", -8.0)


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_distance: float = 14.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.health.is_dead():
			continue
		var distance: float = (enemy.global_position - global_position).length()
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best
