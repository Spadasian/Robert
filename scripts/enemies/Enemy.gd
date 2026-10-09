extends CharacterBody3D
## Base class for all enemies. Handles health, hit feedback and death.
## Specific enemies (Bandit, Archer...) will extend this and add behaviour.

signal defeated(enemy: Node)

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/DamageNumber.tscn")

@export var max_health: float = 50.0
@export var xp_value: int = 6 # EXP given to the player when it dies

@onready var health: Node = $HealthComponent
@onready var hurtbox: Area3D = $Hurtbox
@onready var body_mesh: MeshInstance3D = $Model/Body

var body_material: StandardMaterial3D
var base_color: Color
var status: EnemyStatus = EnemyStatus.new(self) # bleed, stun, slow, mark
var knock_velocity: Vector3 = Vector3.ZERO
var slow_tinted: bool = false # blue glow while the Perfect Dodge slow is on
var hide_next_telegraph: bool = false # Eclipse: the first attack shows no warning


func _ready() -> void:
	add_to_group("enemy")
	health.set_max_health(max_health)
	hurtbox.hit_received.connect(_on_hit_received)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

	# Each enemy gets its own material copy so the hit flash only affects it.
	body_material = body_mesh.get_active_material(0).duplicate() as StandardMaterial3D
	body_mesh.material_override = body_material
	base_color = body_material.albedo_color


func _on_hit_received(damage: float, _source: Node) -> void:
	health.take_damage(damage * status.damage_taken_factor())


## How fast time runs for this enemy: the Perfect Dodge slow, a stun, an individual slow. Enemy scripts multiply
## their delta by this at the start of _physics_process and call slide() instead of move_and_slide().
func time_scale() -> float:
	return EnemyTime.get_scale() * status.speed_factor()


## Enemy scripts ask this before showing the red warning of an attack (false once when Eclipse hides it).
func telegraph_visible() -> bool:
	if hide_next_telegraph:
		hide_next_telegraph = false
		return false
	return true


## Pushed away (Tengu Fan): an extra velocity that fades out quickly. `direction` is flat, `strength` in m/s.
func knockback(direction: Vector3, strength: float) -> void:
	if can_be_stunned():
		knock_velocity = Vector3(direction.x, 0.0, direction.z).normalized() * strength


func can_see_player() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return not (player and player.has_method("is_hidden") and player.is_hidden())


## move_and_slide() at the speed of this enemy's own time (the stored velocity is not changed).
func slide() -> void:
	var factor: float = time_scale()
	var original: Vector3 = velocity
	velocity = original * factor + knock_velocity
	knock_velocity = knock_velocity.move_toward(Vector3.ZERO, 40.0 * get_physics_process_delta_time())
	move_and_slide()
	velocity = original


func can_be_stunned() -> bool:
	return true


## The game is flat. An enemy pushed off the floor by an overlapping body is put back (see Player.gd).
## Subclasses call this right after move_and_slide(); _process is a second safety net.
func lock_to_floor() -> void:
	if absf(global_position.y) > 0.001 and not health.is_dead():
		global_position.y = 0.0


func _process(delta: float) -> void:
	lock_to_floor()
	status.tick(delta)
	_update_slow_tint()


## Enemies glow blue while time is slowed for them (Perfect Dodge), so the effect is easy to see.
func _update_slow_tint() -> void:
	var slowed: bool = EnemyTime.get_scale() < 0.6 and not health.is_dead()
	if slowed == slow_tinted or body_material == null:
		return
	slow_tinted = slowed
	body_material.emission_enabled = slowed
	if slowed:
		body_material.emission = Color(0.3, 0.55, 1.0)
		body_material.emission_energy_multiplier = 0.9


func _on_damaged(amount: float) -> void:
	_spawn_damage_number(amount)
	body_material.albedo_color = Color.WHITE
	create_tween().tween_property(body_material, "albedo_color", base_color, 0.15)


func _on_died() -> void:
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	AudioManager.play_sfx("enemy_death")
	VFX.death_puff(global_position + Vector3(0.0, 0.9, 0.0), base_color)
	defeated.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25) # not ZERO: a zero scale makes Godot print "det == 0" errors
	tween.tween_callback(queue_free)


func _spawn_damage_number(amount: float) -> void:
	var number: Label3D = DAMAGE_NUMBER_SCENE.instantiate()
	get_tree().current_scene.add_child(number)
	number.global_position = global_position + Vector3(0.0, 2.2, 0.0)
	number.play(amount)
