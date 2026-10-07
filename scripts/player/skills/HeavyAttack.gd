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


func _ready() -> void:
	super._ready()
	hitbox.source = player
	hitbox.team = "player"
	hitbox.kind = "heavy"
	hitbox.set_active(false)
	telegraph_material = _make_glow_material(Color(1.0, 0.7, 0.3, 0.25))
	telegraph.material_override = telegraph_material
	telegraph.visible = false


func _start() -> void:
	phase = Phase.WINDUP
	phase_time = 0.0
	telegraph_material.albedo_color.a = 0.25
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
	hitbox.damage = player.stats.get_stat("attack_damage") * damage_multiplier * context.damage_multiplier
	hitbox.set_active(true)
	player.kata_events.heavy_attack.emit()
	telegraph.visible = false
	AudioManager.play_sfx("boss_slash", -6.0)
	var finisher: bool = context.was_open
	var arc_color: Color = Color(1.0, 0.3, 0.3) if finisher else Color(1.0, 0.75, 0.4)
	VFX.slash_arc(player.global_position + Vector3(0.0, 0.9, 0.0), global_rotation.y, 4.0 if finisher else 3.4, 170.0, arc_color, 0.22)
	VFX.shake(0.2 if finisher else 0.12, 0.2)


func _end_strike() -> void:
	phase = Phase.RECOVER
	phase_time = 0.0
	hitbox.set_active(false)
	player.velocity = Vector3.ZERO # stop where the step ends, no sliding


func _cancel() -> void:
	hitbox.set_active(false)
	telegraph.visible = false


func locks_movement() -> bool:
	return is_active and phase != Phase.STRIKE


func get_forced_velocity() -> Variant:
	if is_active and phase == Phase.STRIKE:
		return direction * lunge_speed
	return null
