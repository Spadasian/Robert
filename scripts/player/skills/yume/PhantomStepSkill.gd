extends "res://scripts/player/skills/PlayerSkill.gd"
## Shift (Yume): Phantom Step. A short, quick butterfly twist (4 m) towards the mouse, invulnerable while it lasts;
## she leaves a clone behind that cuts the spot a moment later. It counts as a dash for Butterfly Twist (the
## passive asks where she went with get_twist_direction()).

const PhantomClone = preload("res://scripts/player/skills/yume/PhantomClone.gd")

@export var distance: float = 4.0
@export var step_time: float = 0.14
@export var recover_time: float = 0.06
@export var clone_damage_multiplier: float = 1.0 # times attack_damage
@export var clone_radius: float = 2.6
@export var clone_delay: float = 0.3

var direction: Vector3 = Vector3.FORWARD
var time_in_skill: float = 0.0


func _start() -> void:
	time_in_skill = 0.0
	direction = player.aim.aim_direction
	direction.y = 0.0
	direction = direction.normalized()
	player.collision_mask = player.MASK_DASHING # slips through the enemies, not the walls
	_leave_clone()
	AudioManager.play_sfx("dash")
	VFX.streak(player.global_position + Vector3(0.0, 0.9, 0.0), player.global_position + Vector3(0.0, 0.9, 0.0) + direction * distance, 0.8, Color(0.98, 0.72, 0.88), 0.3)
	player.kata_events.skill_resolved.emit(self) # the step itself (Kata Opening / Flow, Butterfly Twist)


func _leave_clone() -> void:
	var clone := PhantomClone.new()
	clone.player = player
	clone.damage = player.stats.get_stat("attack_damage") * clone_damage_multiplier
	clone.radius = clone_radius
	clone.delay = clone_delay
	player.get_parent().add_child(clone)
	clone.global_position = player.global_position
	clone.global_position.y = 0.0


func _tick(delta: float) -> void:
	time_in_skill += delta
	if time_in_skill >= step_time:
		player.collision_mask = player.MASK_NORMAL
		player.velocity = Vector3.ZERO
	if time_in_skill >= step_time + recover_time:
		finish()


func _cancel() -> void:
	player.collision_mask = player.MASK_NORMAL


func get_twist_direction() -> Vector3:
	return direction


func locks_movement() -> bool:
	return is_active and time_in_skill >= step_time


func get_forced_velocity() -> Variant:
	if is_active and time_in_skill < step_time:
		return direction * (distance / step_time)
	return null


func is_invulnerable() -> bool:
	return is_active and time_in_skill < step_time + 0.04
