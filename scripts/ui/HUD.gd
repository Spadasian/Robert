extends CanvasLayer
## Minimal HUD for now: player HP bar and the death screen. Real HUD comes in Phase 19.

@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPBar/Label
@onready var death_label: Label = $DeathLabel
@onready var message_label: Label = $MessageLabel

var player_dead: bool = false


func _ready() -> void:
	add_to_group("hud")
	death_label.visible = false
	message_label.visible = false
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var health: Node = player.get_node("HealthComponent")
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_player_died)
	_on_health_changed(health.current_health, health.max_health)


func _on_health_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d / %d" % [int(current), int(maximum)]


func _on_player_died() -> void:
	player_dead = true
	death_label.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if player_dead and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func show_message(text: String, duration: float = 2.0) -> void:
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	message_label.visible = false
