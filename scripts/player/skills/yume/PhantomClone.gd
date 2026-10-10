extends "res://scripts/player/skills/yume/GhostBody.gd"
## Left behind by Phantom Step: a moment later it cuts everything around the spot where Yume stood.

const AreaStrike = preload("res://scripts/combat/AreaStrike.gd")

var player: Node
var damage: float = 10.0
var radius: float = 2.6
var delay: float = 0.3
var age: float = 0.0
var struck: bool = false


func _physics_process(delta: float) -> void:
	age += delta
	if not struck:
		set_alpha(0.25 + 0.35 * clampf(age / delay, 0.0, 1.0))
		if age >= delay:
			struck = true
			if is_instance_valid(player):
				AreaStrike.spawn(get_parent(), global_position, radius, damage, player)
			VFX.slash_arc(global_position + Vector3(0.0, 0.9, 0.0), rotation.y, radius * 1.3, 360.0, Color(0.98, 0.72, 0.88), 0.2)
			AudioManager.play_sfx("slash", -4.0)
			age = 0.0
	else:
		set_alpha(0.5 * (1.0 - clampf(age / 0.2, 0.0, 1.0)))
		if age >= 0.2:
			queue_free()
