extends "res://scripts/player/skills/PlayerSkill.gd"
## Q (Yume): Mirror Dream. An illusion appears in front of her and draws the attacks of every enemy for 2 seconds,
## then bursts and hurts the enemies around it. She is free to move and fight meanwhile.

const MirrorDecoy = preload("res://scripts/player/skills/yume/MirrorDecoy.gd")

@export var decoy_distance: float = 2.6
@export var decoy_life: float = 2.0
@export var burst_radius: float = 3.5
@export var burst_multiplier: float = 2.0 # times attack_damage


func _start() -> void:
	var direction: Vector3 = player.aim.aim_direction
	direction.y = 0.0
	var decoy := MirrorDecoy.new()
	decoy.player = player
	decoy.life = decoy_life
	decoy.radius = burst_radius
	decoy.damage = player.stats.get_stat("attack_damage") * burst_multiplier
	player.get_parent().add_child(decoy)
	decoy.global_position = player.global_position + direction.normalized() * decoy_distance
	decoy.global_position.y = 0.0
	AudioManager.play_sfx("kaeshi_stance")
	VFX.ring(decoy.global_position + Vector3(0.0, 0.1, 0.0), 1.8, Color(0.98, 0.72, 0.88, 0.8), 0.4)
	player.kata_events.skill_resolved.emit(self)
	finish() # the illusion lives on its own: Yume is not held in place
