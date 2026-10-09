extends Node
## The screen reacts while time is slowed for the enemies (Perfect Dodge, Time Slip, Perfect Silence): a blue tint on
## the HUD and, on Forward+, the colours of the 3D world drain a little (Environment adjustments). It follows
## EnemyTime, so it needs no calls: it fades in fast and fades out during the last moments of the slow.
## A child of the Player.

const SATURATION: float = 0.45
const CONTRAST: float = 1.12
const FADE_OUT_TIME: float = 0.25
const RISE_SPEED: float = 10.0 # strength per second

var strength: float = 0.0
var applied: bool = false
var backup: Dictionary = {}


func _process(delta: float) -> void:
	var target: float = 0.0
	if EnemyTime.get_scale() < 0.6 and EnemyTime.time_left > 0.0:
		target = clampf(EnemyTime.time_left / FADE_OUT_TIME, 0.0, 1.0)
	strength = move_toward(strength, target, RISE_SPEED * delta if target > strength else 1.0 / FADE_OUT_TIME * delta)
	_apply()


func _apply() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.set_slow_tint(strength)
	var environment: Environment = _environment()
	if environment == null:
		return
	if strength > 0.001:
		if not applied:
			applied = true
			backup = {"enabled": environment.adjustment_enabled, "saturation": environment.adjustment_saturation, "contrast": environment.adjustment_contrast}
		environment.adjustment_enabled = true
		environment.adjustment_saturation = lerpf(backup.saturation, SATURATION, strength)
		environment.adjustment_contrast = lerpf(backup.contrast, CONTRAST, strength)
	elif applied:
		_restore(environment)


func _restore(environment: Environment) -> void:
	applied = false
	environment.adjustment_enabled = backup.enabled
	environment.adjustment_saturation = backup.saturation
	environment.adjustment_contrast = backup.contrast


func _environment() -> Environment:
	var node: Node = get_tree().root.find_child("WorldEnvironment", true, false)
	return node.environment if node else null


func _exit_tree() -> void:
	if applied:
		var environment: Environment = _environment()
		if environment:
			_restore(environment)
