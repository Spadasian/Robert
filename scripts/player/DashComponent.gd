extends Node
## Dash / dodge. The player is invulnerable while dashing.
## max_charges > 1 will be used by upgrades like "Shadow Step".

signal dash_started
signal dash_finished

@export var dash_speed: float = 18.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.7
@export var max_charges: int = 1

var charges: int
@onready var base_speed: float = dash_speed
@onready var base_cooldown: float = dash_cooldown
var is_dashing: bool = false
var direction: Vector3 = Vector3.ZERO
var time_left: float = 0.0
var elapsed: float = 0.0 # seconds since this dash began
var since_start: float = 999.0 # seconds since the last dash began (keeps counting after it ends)
var start_position: Vector3 = Vector3.ZERO # where the player stood when the last dash began
var recharge_left: float = 0.0


func _ready() -> void:
	charges = max_charges


## Dash upgrades (stats dash_recharge, dash_distance). Called by Player whenever the stats change.
func apply_stats(stats: Node) -> void:
	dash_cooldown = base_cooldown / maxf(stats.get_stat("dash_recharge"), 0.1)
	dash_speed = base_speed * stats.get_stat("dash_distance")


## Takes time off the current recharge (Quick Recovery).
func reduce_recharge(seconds: float) -> void:
	if charges < max_charges:
		recharge_left = maxf(recharge_left - seconds, 0.0)


func set_max_charges(new_max: int) -> void:
	if new_max > max_charges:
		charges += new_max - max_charges
	max_charges = new_max
	charges = mini(charges, max_charges)


func is_invulnerable() -> bool:
	return is_dashing


func try_dash(dash_direction: Vector3) -> bool:
	if is_dashing or charges <= 0 or dash_direction == Vector3.ZERO:
		return false
	charges -= 1
	if recharge_left <= 0.0:
		recharge_left = dash_cooldown
	direction = dash_direction.normalized()
	time_left = dash_duration
	elapsed = 0.0
	since_start = 0.0
	start_position = get_parent().global_position if get_parent() is Node3D else Vector3.ZERO
	is_dashing = true
	dash_started.emit()
	return true


func _physics_process(delta: float) -> void:
	since_start += delta
	if is_dashing:
		elapsed += delta
		time_left -= delta
		if time_left <= 0.0:
			is_dashing = false
			dash_finished.emit()
	if charges < max_charges:
		recharge_left -= delta
		if recharge_left <= 0.0:
			charges += 1
			recharge_left = dash_cooldown if charges < max_charges else 0.0
