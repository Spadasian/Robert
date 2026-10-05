extends Area3D
## Receives hits from Hitboxes. Other nodes (health, enemies) listen to hit_received.

signal hit_received(damage: float, source: Node)

@export var team: String = "enemy"
@export var debug_print: bool = false


func receive_hit(damage: float, source: Node) -> void:
	if debug_print:
		print("Hit ", get_parent().name, " for ", damage)
	hit_received.emit(damage, source)
