extends "res://scripts/player/skills/yume/GhostBody.gd"
## Mirror Dream: an illusion that draws the attacks of every enemy while it lives; then it bursts and hurts the
## enemies around it (never the player).

const AreaStrike = preload("res://scripts/combat/AreaStrike.gd")
const HURTBOX_SCRIPT: Script = preload("res://scripts/combat/Hurtbox.gd")

var player: Node
var damage: float = 20.0
var radius: float = 3.5
var life: float = 2.0
var age: float = 0.0
var hurtbox: Area3D


func _ready() -> void:
	super._ready()
	add_to_group("decoy")
	hurtbox = Area3D.new()
	hurtbox.set_script(HURTBOX_SCRIPT)
	hurtbox.collision_layer = 32 # the layer of hurtboxes: enemy attacks hit it like they hit the player
	hurtbox.collision_mask = 0
	hurtbox.team = "player"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	hurtbox.add_child(shape)
	add_child(hurtbox)
	hurtbox.hit_received.connect(func(_damage: float, _source: Node): _flash())


func _physics_process(delta: float) -> void:
	age += delta
	set_alpha(0.5 + 0.15 * sin(age * 12.0))
	if age >= life:
		_burst()


func _flash() -> void:
	VFX.hit_spark(global_position + Vector3(0.0, 1.0, 0.0), Color(0.98, 0.72, 0.88))
	AudioManager.play_sfx("kaeshi_counter", -10.0)


func _burst() -> void:
	remove_from_group("decoy") # the enemies look for the player again
	if is_instance_valid(player):
		AreaStrike.spawn(get_parent(), global_position, radius, damage, player)
	VFX.ring(global_position + Vector3(0.0, 0.1, 0.0), radius, Color(0.98, 0.72, 0.88, 0.9), 0.4)
	VFX.shake(0.15, 0.2)
	AudioManager.play_sfx("kaeshi_counter", -4.0)
	queue_free()
