extends "res://scripts/player/skills/PlayerSkill.gd"
## Q: Kaeshi, the counter stance. For a short time the player stands still; the first hit he takes in that time
## (melee or projectile) is cancelled and answered with a slash around him. A counter gives back part of the cooldown.
## If nothing hits him, the stance just ends after a short recovery.

enum Phase { STANCE, COUNTER, RECOVER }

@export var stance_time: float = 0.9
@export var counter_multiplier: float = 2.0 # times attack_damage
@export var counter_time: float = 0.15
@export var recover_time: float = 0.25 # after a stance that was not hit
@export var success_refund: float = 0.5 # share of the cooldown given back after a counter

@onready var hitbox: Area3D = $Hitbox
@onready var aura: MeshInstance3D = $Aura
@onready var burst: MeshInstance3D = $Burst

var phase: int = Phase.STANCE
var phase_time: float = 0.0


func _ready() -> void:
	super._ready()
	hitbox.source = player
	hitbox.team = "player"
	hitbox.set_active(false)
	aura.material_override = _make_glow_material(Color(0.4, 0.7, 1.0, 0.3))
	burst.material_override = _make_glow_material(Color(1.0, 1.0, 1.0, 0.6))
	aura.visible = false
	burst.visible = false


func _start() -> void:
	phase = Phase.STANCE
	phase_time = 0.0
	aura.visible = true
	AudioManager.play_sfx("kaeshi_stance")


func _tick(delta: float) -> void:
	phase_time += delta
	match phase:
		Phase.STANCE:
			if phase_time >= stance_time:
				aura.visible = false
				phase = Phase.RECOVER # nobody hit him
				phase_time = 0.0
		Phase.COUNTER:
			if phase_time >= counter_time:
				hitbox.set_active(false)
				burst.visible = false
				finish()
		Phase.RECOVER:
			if phase_time >= recover_time:
				finish()


func intercept_hit(_damage: float, _source: Node) -> bool:
	if not is_active or phase != Phase.STANCE:
		return false
	_counter()
	return true


func _counter() -> void:
	phase = Phase.COUNTER
	phase_time = 0.0
	aura.visible = false
	burst.visible = true
	hitbox.damage = player.stats.get_stat("attack_damage") * counter_multiplier
	hitbox.set_active(true)
	cooldown_left *= 1.0 - success_refund
	player._show_floating_text("COUNTER!", Color(0.6, 0.85, 1.0))
	AudioManager.play_sfx("kaeshi_counter")
	VFX.ring(player.global_position, 3.5, Color(0.7, 0.9, 1.0), 0.4)
	VFX.hit_spark(player.global_position + Vector3(0.0, 1.0, 0.0), Color(0.7, 0.9, 1.0))
	VFX.shake(0.18, 0.25)


func _cancel() -> void:
	hitbox.set_active(false)
	aura.visible = false
	burst.visible = false


func locks_movement() -> bool:
	return is_active


func is_invulnerable() -> bool:
	return is_active and phase == Phase.COUNTER
