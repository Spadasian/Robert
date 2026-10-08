class_name EnemyTime
extends RefCounted
## The speed of time for the enemies and their projectiles (the player is never slowed). A Perfect Dodge slows them
## for a moment; Player.gd ticks this every physics frame, so it does not run while the game is paused.
## Enemy scripts multiply their delta by get_scale(); an enemy can also be slowed alone (see EnemyStatus).

static var scale: float = 1.0
static var time_left: float = 0.0


## Slows every enemy to `factor` of the normal speed for `duration` seconds (0 = frozen). A stronger or longer
## effect replaces a weaker one that is still running.
static func slow(factor: float, duration: float) -> void:
	if time_left <= 0.0 or factor <= scale or duration > time_left:
		scale = factor if time_left <= 0.0 else minf(scale, factor)
		time_left = maxf(time_left, duration)


static func tick(delta: float) -> void:
	if time_left > 0.0:
		time_left -= delta
		if time_left <= 0.0:
			reset()


static func get_scale() -> float:
	return scale


static func reset() -> void:
	scale = 1.0
	time_left = 0.0
