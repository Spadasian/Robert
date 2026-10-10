extends "res://scripts/player/skills/UltimateBase.gd"
## E (Yume): Dream Clones. Three clones appear around her and cut the nearest enemies for 4 seconds; Yume keeps
## fighting at their side. Charges only from kills (see UltimateBase).

const DreamClone = preload("res://scripts/player/skills/yume/DreamClone.gd")

@export var clone_count: int = 3
@export var clone_damage_multiplier: float = 0.8 # times attack_damage, per cut


func _ready() -> void:
	super._ready()
	duration = 4.0


func _start() -> void:
	spend_charge()
	for index in clone_count:
		var clone := DreamClone.new()
		clone.player = player
		clone.life = duration
		clone.damage = player.stats.get_stat("attack_damage") * clone_damage_multiplier
		player.get_parent().add_child(clone)
		var angle: float = TAU * index / float(clone_count)
		clone.global_position = player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 1.6
		clone.global_position.y = 0.0
	AudioManager.play_sfx("ultimate_start")
	VFX.ring(player.global_position, 3.4, Color(0.98, 0.72, 0.88), 0.5)
	VFX.shake(0.2, 0.3)
	finish() # the clones fight on their own, Yume stays free
