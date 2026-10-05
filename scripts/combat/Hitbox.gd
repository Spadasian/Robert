extends Area3D
## Deals damage to any Hurtbox it touches (once per activation). Ignores same-team hurtboxes.

@export var damage: float = 10.0
@export var team: String = "player"

var source: Node
var already_hit: Array = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func set_active(active: bool) -> void:
	if active:
		already_hit.clear()
	set_deferred("monitoring", active)


func _on_area_entered(area: Area3D) -> void:
	if not area.has_method("receive_hit"):
		return
	if area.team == team or area in already_hit:
		return
	already_hit.append(area)
	area.receive_hit(damage, source)
