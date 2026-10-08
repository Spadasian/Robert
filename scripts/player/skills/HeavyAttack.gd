extends "res://scripts/player/skills/PlayerSkill.gd"
## Right click: the heavy attack. A short windup (the aim follows the mouse, then locks), then a step forward
## with a wide, hard slash. It is the Finisher of the Kata (see KataComponent), but works on its own too.

enum Phase { WINDUP, STRIKE, RECOVER }

@export var damage_multiplier: float = 1.8 # times attack_damage
@export var windup_time: float = 0.28
@export var lock_time: float = 0.06 # last part of the windup where the aim no longer follows the mouse
@export var strike_time: float = 0.14
@export var lunge_speed: float = 9.0 # the step forward during the strike
@export var recover_time: float = 0.22

@onready var hitbox: Area3D = $Hitbox
@onready var telegraph: MeshInstance3D = $Telegraph

var phase: int = Phase.WINDUP
var phase_time: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var telegraph_material: StandardMaterial3D
var shape_node: CollisionShape3D
var shape_base_position: Vector3
var telegraph_base_z: float = 1.7


func _ready() -> void:
	super._ready()
	hitbox.source = player
	hitbox.team = "player"
	hitbox.kind = "heavy"
	hitbox.set_active(false)
	shape_node = hitbox.get_node("CollisionShape3D")
	shape_base_position = shape_node.position
	telegraph_base_z = telegraph.position.z
	telegraph_material = _make_glow_material(Color(1.0, 0.7, 0.3, 0.25))
	telegraph.material_override = telegraph_material
	telegraph.visible = false


func _start() -> void:
	phase = Phase.WINDUP
	phase_time = 0.0
	telegraph_material.albedo_color.a = 0.25
	var reach: float = player.stats.get_stat("heavy_range") # the red zone grows with the upgrades too
	telegraph.scale = Vector3(reach, 1.0, reach)
	telegraph.position.z = telegraph_base_z * reach
	telegraph.visible = true
	AudioManager.play_sfx("iaijutsu_charge", -10.0)
	_aim()


func _tick(delta: float) -> void:
	phase_time += delta
	match phase:
		Phase.WINDUP:
			if phase_time < windup_time - lock_time:
				_aim()
			else:
				telegraph_material.albedo_color.a = 0.6 # locked in
			if phase_time >= windup_time:
				_begin_strike()
		Phase.STRIKE:
			if phase_time >= strike_time:
				_end_strike()
		Phase.RECOVER:
			if phase_time >= recover_time:
				finish()


func _aim() -> void:
	direction = player.aim.aim_direction
	global_rotation.y = atan2(direction.x, direction.z)


func _begin_strike() -> void:
	phase = Phase.STRIKE
	phase_time = 0.0
	# If a Kata is running, this strike is its Finisher: the techniques may multiply the damage and add effects.
	var context: Dictionary = player.kata.begin_finisher(self)
	hitbox.damage = player.stats.get_stat("attack_damage") * damage_multiplier * context.damage_multiplier * player.stats.get_stat("heavy_damage")
	_apply_finisher_shape(context)
	hitbox.force_crit = context.get("force_crit", false)
	hitbox.execute_below = context.get("execute_below", 0.0)
	hitbox.set_active(true)
	player.kata_events.heavy_attack.emit()
	telegraph.visible = false
	AudioManager.play_sfx("boss_slash", -6.0)
	var finisher: bool = context.was_open
	var arc_color: Color = Color(1.0, 0.3, 0.3) if finisher else Color(1.0, 0.75, 0.4)
	var arc_size: float = (4.0 if finisher else 3.4) * context.get("scale", 1.0)
	VFX.slash_arc(player.global_position + Vector3(0.0, 0.9, 0.0), global_rotation.y, arc_size, 360.0 if context.get("spin", false) else 170.0, arc_color, 0.22)
	VFX.shake(0.2 if finisher else 0.12, 0.2)
	if context.has("echo"):
		_echo_strike(context.echo, arc_size, arc_color)


## Finisher techniques can widen the slash ("scale") or turn it into a circle around the player ("spin").
func _apply_finisher_shape(context: Dictionary) -> void:
	var size: float = context.get("scale", 1.0) * player.stats.get_stat("heavy_range")
	hitbox.scale = Vector3(size, 1.0, size)
	shape_node.position = Vector3(shape_base_position.x, shape_base_position.y, 0.0 if context.get("spin", false) else shape_base_position.z)


## A second slash a moment later (Shadow Doppelganger): same direction, a share of the damage.
func _echo_strike(damage_share: float, arc_size: float, color: Color) -> void:
	var echo_damage: float = hitbox.damage * damage_share
	await get_tree().create_timer(0.45, false).timeout
	if not is_instance_valid(player) or player.health.is_dead():
		return
	hitbox.damage = echo_damage
	hitbox.set_active(true)
	VFX.slash_arc(player.global_position + Vector3(0.0, 0.9, 0.0), global_rotation.y, arc_size, 170.0, color.darkened(0.4), 0.22)
	AudioManager.play_sfx("boss_slash", -10.0)
	await get_tree().create_timer(strike_time, false).timeout
	hitbox.set_active(false)


func _end_strike() -> void:
	phase = Phase.RECOVER
	phase_time = 0.0
	hitbox.set_active(false)
	_reset_finisher_shape()
	player.velocity = Vector3.ZERO # stop where the step ends, no sliding


func _reset_finisher_shape() -> void:
	hitbox.scale = Vector3.ONE
	shape_node.position = shape_base_position
	hitbox.force_crit = false
	hitbox.execute_below = 0.0


func _cancel() -> void:
	hitbox.set_active(false)
	_reset_finisher_shape()
	telegraph.visible = false


func get_cooldown_multiplier() -> float:
	return player.stats.get_stat("heavy_cooldown")


func locks_movement() -> bool:
	return is_active and phase != Phase.STRIKE


func get_forced_velocity() -> Variant:
	if is_active and phase == Phase.STRIKE:
		return direction * lunge_speed
	return null
