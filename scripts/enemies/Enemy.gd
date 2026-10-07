extends CharacterBody3D
## Base class for all enemies. Handles health, hit feedback and death.
## Specific enemies (Bandit, Archer...) will extend this and add behaviour.

signal defeated(enemy: Node)

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/DamageNumber.tscn")

@export var max_health: float = 50.0

@onready var health: Node = $HealthComponent
@onready var hurtbox: Area3D = $Hurtbox
@onready var body_mesh: MeshInstance3D = $Model/Body

var body_material: StandardMaterial3D
var base_color: Color


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
	health.take_damage(damage)


## The game is flat. An enemy pushed off the floor by an overlapping body is put back (see Player.gd).
## Subclasses call this right after move_and_slide(); _process is a second safety net.
func lock_to_floor() -> void:
	if absf(global_position.y) > 0.001 and not health.is_dead():
		global_position.y = 0.0


func _process(_delta: float) -> void:
	lock_to_floor()


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
