extends Node
## Holds health for any entity (player, enemies, bosses). Other nodes listen to the signals.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

@export var max_health: float = 100.0

var current_health: float
var heal_blocked: bool = false # Hunger Moon: nothing heals in the arena


func _ready() -> void:
	current_health = max_health


func set_max_health(value: float, refill: bool = true) -> void:
	max_health = value
	if refill:
		current_health = max_health
	health_changed.emit(current_health, max_health)


func change_max_health(new_max: float) -> void:
	var difference: float = new_max - max_health
	max_health = new_max
	if difference > 0.0:
		current_health += difference
	current_health = minf(current_health, max_health)
	health_changed.emit(current_health, max_health)


func take_damage(amount: float) -> void:
	if is_dead():
		return
	current_health = maxf(current_health - amount, 0.0)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()


## Sets the health directly (a life saver such as Second Chance uses it).
func set_current(value: float) -> void:
	current_health = clampf(value, 0.0, max_health)
	health_changed.emit(current_health, max_health)


func heal(amount: float) -> void:
	if is_dead() or heal_blocked:
		return
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return current_health <= 0.0
