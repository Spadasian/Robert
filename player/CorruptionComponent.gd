extends Node
## Corruption 0-100 with thresholds at 25 / 50 / 75 / 100.
## For now it is only a number. Effects (bonus damage, visuals, 100% consequences) hook into the signals later.

signal corruption_changed(value: float, level: int)
signal threshold_reached(level: int)

const THRESHOLDS: Array[float] = [25.0, 50.0, 75.0, 100.0]

@export var max_corruption: float = 100.0

var value: float = 0.0
var level: int = 0 # 0 = below 25%, 4 = 100%


func add_corruption(amount: float) -> void:
	set_corruption(value + amount)


func set_corruption(new_value: float) -> void:
	var old_level: int = level
	value = clampf(new_value, 0.0, max_corruption)
	level = 0
	for threshold in THRESHOLDS:
		if value >= threshold:
			level += 1
	corruption_changed.emit(value, level)
	if level > old_level:
		threshold_reached.emit(level)
