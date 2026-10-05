extends Node3D
## Basic katana slash. Hold the attack button to keep slashing (limited by cooldown).

@export var damage: float = 10.0
@export var attack_cooldown: float = 0.35
@export var swing_time: float = 0.15
@export var swing_arc_degrees: float = 140.0

@onready var aim: Node = $"../AimComponent"
@onready var swing_pivot: Node3D = $SwingPivot
@onready var hitbox: Area3D = $SwingPivot/Hitbox
@onready var blade: MeshInstance3D = $SwingPivot/Blade

var cooldown_left: float = 0.0
var swing_side: float = 1.0
var swing_tween: Tween


func _ready() -> void:
	blade.visible = false
	hitbox.source = get_parent()
	hitbox.set_active(false)


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	rotation.y = atan2(aim.aim_direction.x, aim.aim_direction.z)
	if Input.is_action_pressed("attack") and cooldown_left <= 0.0:
		start_attack()


func start_attack() -> void:
	cooldown_left = attack_cooldown
	hitbox.damage = damage
	hitbox.set_active(true)
	blade.visible = true

	var half_arc: float = deg_to_rad(swing_arc_degrees * 0.5) * swing_side
	swing_pivot.rotation.y = -half_arc
	if swing_tween:
		swing_tween.kill()
	swing_tween = create_tween()
	swing_tween.tween_property(swing_pivot, "rotation:y", half_arc, swing_time)
	swing_tween.tween_callback(end_attack)
	swing_side *= -1.0 # alternate swing direction


func end_attack() -> void:
	hitbox.set_active(false)
	blade.visible = false
