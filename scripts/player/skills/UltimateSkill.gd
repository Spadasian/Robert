extends "res://scripts/player/skills/PlayerSkill.gd"
## E: the ultimate, a storm of blades. It has no cooldown: it charges as the player lands hits (and more for kills)
## and can be used when the meter is full. While it lasts the player moves faster, takes less damage and everything
## around him is cut every tick. Basic attacks and other skills are not available during it.

signal charge_changed(charge: float, maximum: float)

@export var max_charge: float = 100.0
@export var charge_per_hit: float = 2.0
@export var charge_per_kill: float = 6.0
@export var duration: float = 3.5
@export var tick_interval: float = 0.25
@export var damage_multiplier: float = 0.9 # per tick, times attack_damage
@export var speed_multiplier: float = 1.2
@export var damage_taken_multiplier: float = 0.5

@onready var hitbox: Area3D = $Hitbox
@onready var disc: MeshInstance3D = $Disc
@onready var blades: Node3D = $Blades

var charge: float = 0.0
var time_active: float = 0.0
var tick_timer: float = 0.0
var hit_window: float = 0.0


func _ready() -> void:
	super._ready()
	cooldown = 0.0
	hitbox.source = player
	hitbox.team = "player"
	hitbox.set_active(false)
	disc.material_override = _make_glow_material(Color(0.6, 0.3, 0.9, 0.25))
	for blade in blades.get_children():
		blade.material_override = _make_glow_material(Color(0.9, 0.8, 1.0, 0.8))
	disc.visible = false
	blades.visible = false


func is_available() -> bool:
	return charge >= max_charge


func add_charge(amount: float) -> void:
	if is_active:
		return # no recharging while it runs
	charge = minf(charge + amount, max_charge)
	charge_changed.emit(charge, max_charge)


func on_player_hit_dealt(target_killed: bool) -> void:
	add_charge(charge_per_kill if target_killed else charge_per_hit)


func _start() -> void:
	charge = 0.0
	charge_changed.emit(charge, max_charge)
	time_active = 0.0
	tick_timer = 0.0 # the first cut happens at once
	disc.visible = true
	blades.visible = true
	AudioManager.play_sfx("ultimate_start")
	VFX.ring(player.global_position, 3.8, Color(0.75, 0.5, 1.0), 0.5)
	VFX.shake(0.3, 0.5)


func _tick(delta: float) -> void:
	time_active += delta
	blades.rotation.y += TAU * 2.0 * delta
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		hitbox.damage = player.stats.get_stat("attack_damage") * damage_multiplier
		hitbox.set_active(true) # re-activating lets it hit everybody in range again
		AudioManager.play_sfx("ultimate_tick")
		hit_window = 0.1
	if hit_window > 0.0:
		hit_window -= delta
		if hit_window <= 0.0:
			hitbox.set_active(false)
	if time_active >= duration:
		_stop_effects()
		finish()


func _cancel() -> void:
	_stop_effects()


func _stop_effects() -> void:
	hitbox.set_active(false)
	disc.visible = false
	blades.visible = false


func get_speed_multiplier() -> float:
	return speed_multiplier if is_active else 1.0


func get_damage_taken_multiplier() -> float:
	return damage_taken_multiplier if is_active else 1.0


func get_unavailable_ratio() -> float:
	if is_active:
		return 0.0
	return 1.0 - charge / max_charge


func get_status_text() -> String:
	if is_active:
		return "%.1f" % maxf(duration - time_active, 0.0)
	return "READY" if charge >= max_charge else "%d%%" % int(charge / max_charge * 100.0)
