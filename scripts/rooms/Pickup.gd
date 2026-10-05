extends Area3D
## Gold pickup. Spins and bobs; collected when the player touches it.

@export var amount: int = 10

@onready var visual: Node3D = $Visual

var time: float = 0.0


func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	time += delta
	visual.rotation.y += 3.0 * delta
	visual.position.y = 0.7 + sin(time * 3.0) * 0.15


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		collect()


## Called when the player touches the pickup, or automatically when leaving the room.
func collect() -> void:
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager:
		run_manager.add_gold(amount)
	queue_free()
