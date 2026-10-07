extends "res://scripts/combat/Hitbox.gd"
## A projectile: flies in a straight line, damages the first Hurtbox of the other team it touches
## and disappears on walls or after its lifetime. Created by ranged enemies through launch().
## Hitbox does the damage work; this script only adds the movement.

@export var speed: float = 13.0
@export var lifetime: float = 3.0
@export var spin_speed: float = 0.0 # radians per second, used by shurikens

@onready var visual: Node3D = get_node_or_null("Visual")

var direction: Vector3 = Vector3.FORWARD
var age: float = 0.0


func _ready() -> void:
	super._ready()
	body_entered.connect(_on_body_entered)


## Call after add_child(). The direction must be flat (no Y part).
func launch(from_position: Vector3, move_direction: Vector3) -> void:
	direction = move_direction.normalized()
	global_position = from_position
	rotation.y = atan2(direction.x, direction.z)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	age += delta
	if age >= lifetime:
		queue_free()
		return
	if visual and spin_speed != 0.0:
		visual.rotation.y += spin_speed * delta


func _on_area_entered(area: Area3D) -> void:
	var hits_before: int = already_hit.size()
	super(area)
	if already_hit.size() > hits_before:
		queue_free() # it hit something, it is used up


func _on_body_entered(_body: Node3D) -> void:
	queue_free() # the mask only contains the world layer, so this is always a wall or obstacle
