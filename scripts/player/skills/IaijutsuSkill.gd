extends "res://scripts/player/skills/PlayerSkill.gd"
## Shift: Iaijutsu, the quick draw. The player plants his feet and a thin line shows the cut (it follows the
## mouse, then locks), then he flashes forward through enemies, invulnerable, and hits everything on the line hard.

enum Phase { WINDUP, STRIKE, RECOVER }

@export var damage_multiplier: float = 1.0 # times attack_damage
@export var windup_time: float = 0.35
@export var lock_time: float = 0.08 # last part of the windup where the aim no longer follows the mouse
@export var strike_speed: float = 35.0
@export var strike_time: float = 0.2 # strike_speed * strike_time = distance of the cut
@export var recover_time: float = 0.15

@onready var hitbox: Area3D = $Hitbox
@onready var line: MeshInstance3D = $Line

var phase: int = Phase.WINDUP
var phase_time: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var line_material: StandardMaterial3D
var strike_start: Vector3


func _ready() -> void:
	super._ready()
	hitbox.source = player
	hitbox.team = "player"
	hitbox.set_active(false)
	line_material = _make_glow_material(Color(0.7, 0.9, 1.0, 0.3))
	line.material_override = line_material
	line.visible = false


func _start() -> void:
	phase = Phase.WINDUP
	phase_time = 0.0
	line_material.albedo_color.a = 0.3
	line.visible = true
	AudioManager.play_sfx("iaijutsu_charge")
	_aim()


func _tick(delta: float) -> void:
	phase_time += delta
	match phase:
		Phase.WINDUP:
			if phase_time < windup_time - lock_time:
				_aim()
			else:
				line_material.albedo_color.a = 0.9 # locked in
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
	hitbox.damage = player.stats.get_stat("attack_damage") * damage_multiplier
	hitbox.set_active(true)
	player.collision_mask = player.MASK_DASHING # pass through enemies, not walls
	player.body_mesh.transparency = 0.5
	strike_start = player.global_position + Vector3(0.0, 0.9, 0.0)
	AudioManager.play_sfx("iaijutsu_strike")
	player.kata_events.skill_resolved.emit(self) # the cut itself, not the button press
	VFX.shake(0.15, 0.2)


func _end_strike() -> void:
	phase = Phase.RECOVER
	phase_time = 0.0
	hitbox.set_active(false)
	line.visible = false
	player.collision_mask = player.MASK_NORMAL
	player.body_mesh.transparency = 0.0
	player.velocity = Vector3.ZERO # stop where the cut ends, no sliding
	VFX.streak(strike_start, player.global_position + Vector3(0.0, 0.9, 0.0), 0.9, Color(0.8, 0.95, 1.0), 0.35)


func _cancel() -> void:
	hitbox.set_active(false)
	line.visible = false
	player.collision_mask = player.MASK_NORMAL
	player.body_mesh.transparency = 0.0


func locks_movement() -> bool:
	return is_active and phase != Phase.STRIKE


func get_forced_velocity() -> Variant:
	if is_active and phase == Phase.STRIKE:
		return direction * strike_speed
	return null


func is_invulnerable() -> bool:
	return is_active and phase == Phase.STRIKE
