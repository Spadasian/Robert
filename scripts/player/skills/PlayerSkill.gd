class_name PlayerSkill
extends Node3D
## Base class of the player's skills (right click, Q, E). Skills are children of the Player scene.
## A skill has a cooldown and is "active" while it runs. Player.gd reads the hooks below every frame to decide
## whether the player may move, is invulnerable, is pushed along, and so on. New skill = a script extending this
## one + a small scene with its hitbox and visuals, instanced in Player.tscn.

signal activated
signal finished

@export var display_name: String = ""
@export var key_label: String = "" # shown on the HUD slot: "RMB", "Q", "E"
@export var input_action: String = "" # action name from the Input Map
@export var cooldown: float = 6.0

var cooldown_left: float = 0.0
var current_cooldown: float = 0.0 # the cooldown of the last use, after upgrades (the HUD cover uses it)
var is_active: bool = false
var player: CharacterBody3D


func _ready() -> void:
	player = get_parent() as CharacterBody3D


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if is_active:
		_tick(delta)


## True when the skill could be used right now (cooldown or charge, ignoring what the player is doing).
func is_available() -> bool:
	return cooldown_left <= 0.0


func can_activate() -> bool:
	if is_active or not is_available():
		return false
	if player == null or player.health.is_dead():
		return false
	return not player.is_busy()


func try_activate() -> bool:
	if not can_activate():
		return false
	is_active = true
	current_cooldown = cooldown * get_cooldown_multiplier()
	cooldown_left = current_cooldown
	activated.emit()
	_start()
	return true


## Upgrades shorten the cooldown (Skill Haste for Iaijutsu and Kaeshi; the Heavy and the ultimate override this).
func get_cooldown_multiplier() -> float:
	return player.stats.get_stat("skill_cooldown") if player else 1.0


func finish() -> void:
	is_active = false
	finished.emit()


## Stops the skill at once without finishing normally (the player died).
func cancel() -> void:
	if is_active:
		_cancel()
		finish()


# ---- hooks the Player asks about every frame (only meaningful while the skill is active)

func locks_movement() -> bool:
	return false


## A velocity that replaces normal movement (a lunge), or null.
func get_forced_velocity() -> Variant:
	return null


func is_invulnerable() -> bool:
	return false


## Return true to swallow the hit (counter stance). Called before any damage is applied.
func intercept_hit(_damage: float, _source: Node) -> bool:
	return false


func get_speed_multiplier() -> float:
	return 1.0


func get_damage_taken_multiplier() -> float:
	return 1.0


## Called after every hit the player lands (the ultimate charges from this).
func on_player_hit_dealt(_target_killed: bool) -> void:
	pass


# ---- HUD

## 0 = ready, 1 = just used / empty. The HUD draws a cover of this height over the slot.
func get_unavailable_ratio() -> float:
	if current_cooldown <= 0.0:
		return 0.0
	return clampf(cooldown_left / current_cooldown, 0.0, 1.0)


func get_status_text() -> String:
	return "" if cooldown_left <= 0.0 else "%.1f" % cooldown_left


# ---- for the subclasses

func _start() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _cancel() -> void:
	pass


func _make_glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
