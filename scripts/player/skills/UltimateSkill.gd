extends "res://scripts/player/skills/UltimateBase.gd"
## E (Kazuma): Moonlit Storm, a storm of blades. While it lasts the player moves faster, takes less damage and
## everything around him is cut every tick. Basic attacks and other skills are not available during it.

@export var tick_interval: float = 0.25
@export var damage_multiplier: float = 0.9 # per tick, times attack_damage
@export var speed_multiplier: float = 1.2
@export var damage_taken_multiplier: float = 0.5

@onready var hitbox: Area3D = $Hitbox
@onready var disc: MeshInstance3D = $Disc
@onready var blades: Node3D = $Blades

var tick_timer: float = 0.0
var hit_window: float = 0.0


func _ready() -> void:
	super._ready()
	hitbox.source = player
	hitbox.team = "player"
	hitbox.set_active(false)
	disc.material_override = _make_glow_material(Color(0.6, 0.3, 0.9, 0.25))
	for blade in blades.get_children():
		blade.material_override = _make_glow_material(Color(0.9, 0.8, 1.0, 0.8))
	disc.visible = false
	blades.visible = false


func _start() -> void:
	spend_charge()
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
	if time_active >= duration + duration_bonus:
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
